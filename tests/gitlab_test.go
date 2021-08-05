package test

import (
	"crypto/tls"
	// "encoding/json"
	"fmt"
	"net"
	"os"
	"regexp"
	"strconv"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/k8s"
	// "github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/aws/aws-sdk-go/service/elbv2"
	"github.com/stretchr/testify/assert"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

var cluster_name = os.Getenv("CLUSTER_NAME")
var region = os.Getenv("REGION")
var domain = os.Getenv("DOMAIN")
var timeout = 5

// make sure the containers within the pod are all started and ready
func IsPodAvailable(pod *corev1.Pod) bool {
	for _, containerStatus := range pod.Status.ContainerStatuses {
		isContainerStarted := containerStatus.Started
		isContainerReady := containerStatus.Ready
		if !isContainerReady || (isContainerStarted != nil && *isContainerStarted == false) {
			return false
		}
	}
	return pod.Status.Phase == corev1.PodRunning
}

// test that the autoscaler is running
func TestAutoScalerRunning(t *testing.T) {
	t.Parallel()

	options := k8s.NewKubectlOptions("", "", "kube-system")
	k8s.GetService(t, options, "eksclusterautoscaler-aws-cluster-autoscaler")

	pods := k8s.ListPods(t, options, metav1.ListOptions{LabelSelector: "app.kubernetes.io/name=aws-cluster-autoscaler"})
	assert.NotEqual(t, len(pods), 0)
	for _, pod := range pods {
		assert.True(t, IsPodAvailable(&pod))
	}
}

// test that the loadbalancer controller is running
func TestLBControllerRunning(t *testing.T) {
	t.Parallel()

	options := k8s.NewKubectlOptions("", "", "kube-system")
	k8s.GetService(t, options, "aws-load-balancer-webhook-service")

	pods := k8s.ListPods(t, options, metav1.ListOptions{LabelSelector: "app.kubernetes.io/name=aws-load-balancer-controller"})
	assert.NotEqual(t, len(pods), 0)
	for _, pod := range pods {
		assert.True(t, IsPodAvailable(&pod))
	}
}

// test that teleport is set up
func TestTeleportExternallyAvailable(t *testing.T) {
	t.Parallel()

	options := k8s.NewKubectlOptions("", "", "teleport")

	service := k8s.GetService(t, options, "teleport-cluster")
	serviceendpoint := k8s.GetServiceEndpoint(t, options, service, 443)
	url := fmt.Sprintf("https://%s/", serviceendpoint)

	// set the ServerName so that we use SNI
	hostname := fmt.Sprintf("teleport-%s.%s", cluster_name, domain)
	tlsconfig := &tls.Config{ServerName: hostname}

	// Scrape the page for some content and make sure it's a 200
	http_helper.HttpGetWithCustomValidation(
		t,
		url,
		tlsconfig,
		func(statusCode int, body string) bool {
			return statusCode == 200 && strings.Contains(body, "<script src=\"/web/config.js\"></script>")
		},
	)

	// Make sure that the endpoint matches the dns name
	cname, error := net.LookupCNAME(hostname)
	assert.NoError(t, error)
	// Remove the . at the end of the cname and add the port
	assert.Equal(t, strings.TrimSuffix(cname, ".")+":443", serviceendpoint)
}

// test that teleport apps are accessible:  if teleport-kube-agent is running,
// the apps should be there.  We cannot test this through https because we
// cannot disable auth for teleport, and it requires 2fa and passwords and so on.
func TestTeleportAppsRunning(t *testing.T) {
	t.Parallel()

	options := k8s.NewKubectlOptions("", "", "teleport")
	pods := k8s.ListPods(t, options, metav1.ListOptions{LabelSelector: "app=teleport-kube-agent"})
	assert.NotEqual(t, len(pods), 0)
	for _, pod := range pods {
		assert.True(t, IsPodAvailable(&pod))
	}
}

// test that makes sure the gitlab web front end is running
func TestGitlabAvailable(t *testing.T) {
	t.Parallel()

	options := k8s.NewKubectlOptions("", "", "gitlab")

	// open a tunnel to the service
	pods := k8s.ListPods(t, options, metav1.ListOptions{LabelSelector: "app=webservice"})
	tunnel := k8s.NewTunnel(options, k8s.ResourceTypePod, pods[0].Name, 0, 8080)
	defer tunnel.Close()
	tunnel.ForwardPort(t)

	// Scrape the page for some content and make sure it's a 200
	url := fmt.Sprintf("http://%s/", tunnel.Endpoint())
	http_helper.HttpGetWithCustomValidation(
		t,
		url,
		nil,
		func(statusCode int, body string) bool {
			return statusCode == 200 && strings.Contains(body, "This is a self-managed instance of GitLab")
		},
	)
}

// look for gitlab-runner being alive
func TestGitlabRunner(t *testing.T) {
	t.Parallel()

	options := k8s.NewKubectlOptions("", "", "gitlab")
	pods := k8s.ListPods(t, options, metav1.ListOptions{LabelSelector: "app=gitlab-gitlab-runner"})
	assert.NotEqual(t, len(pods), 0)
	for _, pod := range pods {
		assert.True(t, IsPodAvailable(&pod))
	}
}

// look for gitlab-runner having a role configured for it
func TestGitlabRunnerRole(t *testing.T) {
	t.Parallel()

	options := k8s.NewKubectlOptions("", "", "gitlab")
	pods := k8s.ListPods(t, options, metav1.ListOptions{LabelSelector: "app=gitlab-gitlab-runner"})
	assert.NotEqual(t, len(pods), 0)
	for _, pod := range pods {
		assert.True(t, IsPodAvailable(&pod))

		// see if the pod has AWS_ROLE_ARN set to a role
		foundRole := false
		for _, v := range pod.Spec.Containers[0].Env {
			// podJSON, err := json.MarshalIndent(v, "", "  ")
			// assert.NoError(t, err)
			// fmt.Printf("%s\n", string(podJSON))

			if v.Name == "AWS_ROLE_ARN" {
				foundRole = true
				assert.Regexp(t, "^arn:aws:iam::.*:role/.*-gitlab-runner$", v.Value)
			}
		}
		assert.True(t, foundRole)
	}
}

// test that the runner role can do ECR stuff
func TestGitlabRunnerRoleECR(t *testing.T) {
	t.Parallel()

	options := k8s.NewKubectlOptions("", "", "gitlab")
	pods := k8s.ListPods(t, options, metav1.ListOptions{LabelSelector: "app=gitlab-gitlab-runner"})
	assert.NotEqual(t, len(pods), 0)
	foundRole := ""
	for _, pod := range pods {
		assert.True(t, IsPodAvailable(&pod))

		// get the runner role ARN
		for _, v := range pod.Spec.Containers[0].Env {
			if v.Name == "AWS_ROLE_ARN" {
				foundRole = v.Value
				assert.Regexp(t, "^arn:aws:iam::.*:role/.*-gitlab-runner$", v.Value)
			}
		}
	}

	// Delete repo if it is there for some reason
	reponame := "terratest"
	repo, err := aws.GetECRRepoE(t, region, reponame)
	if err == nil {
		aws.DeleteECRRepo(t, region, repo)
	}
	// assume the runner role
	os.Setenv("TERRATEST_IAM_ROLE", foundRole)
	// Make sure we can create a repo with the runner role
	aws.CreateECRRepo(t, region, reponame)
	// Clean up afterwards
	os.Unsetenv("TERRATEST_IAM_ROLE")
	repo, err = aws.GetECRRepoE(t, region, reponame)
	aws.DeleteECRRepo(t, region, repo)
}

// look for gitlab-task-runner being alive
func TestGitlabTaskRunner(t *testing.T) {
	t.Parallel()

	options := k8s.NewKubectlOptions("", "", "gitlab")
	pods := k8s.ListPods(t, options, metav1.ListOptions{LabelSelector: "app=task-runner"})
	assert.NotEqual(t, len(pods), 0)
	for _, pod := range pods {
		assert.True(t, IsPodAvailable(&pod))
	}
}

func TestGitlabEmail(t *testing.T) {
	t.Parallel()

	options := k8s.NewKubectlOptions("", "", "gitlab")
	pods := k8s.ListPods(t, options, metav1.ListOptions{LabelSelector: "app=task-runner"})
	assert.NotEqual(t, len(pods), 0)

	pod := pods[0]

	kube_args := []string{
		"exec",
		pod.Name,
		"--",
		"/usr/local/bin/gitlab-rails",
		"runner",
		"Notify.test_email('identity-devops-bots+gitlab-testing@login.gov', 'GitLab Test - Please Ignore', 'Please Ignore').deliver_now",
	}
	k8s.RunKubectl(t, options, kube_args...)
}

// Test that network traffic through the LB is routed correctly, e.g. source IP
// is not preserved (response code 000) and proxy protocol v2 is not used
// (response code 400).
func TestLoadBalancer(t *testing.T) {
	t.Parallel()
	options := k8s.NewKubectlOptions("", "", "gitlab")

	pods := k8s.ListPods(t, options, metav1.ListOptions{LabelSelector: "app=webservice"})
	assert.NotEqual(t, len(pods), 0)
	pod := pods[0]

	url := fmt.Sprintf("https://gitlab-%s.gitlab.identitysandbox.gov", cluster_name)

	kube_args := []string{
		"exec",
		pod.Name,
		"-c",
		"webservice",
		"--",
		"/usr/bin/curl",
		"--silent",
		"--fail",
		"--output",
		"/dev/null",
		"--max-time",
		strconv.Itoa(timeout),
		"--write-out",
		"%{response_code}",
		url,
	}
	response_code, err := k8s.RunKubectlAndGetOutputE(t, options, kube_args...)

	assert.NoError(t, err)
	assert.Equal(t, "302", response_code)
}

// Tests required Target Group attributes
func TestTargetGroup(t *testing.T) {
	t.Parallel()
	options := k8s.NewKubectlOptions("", "", "gitlab")

	// Find the DNS name for the ingress.
	ingresses := k8s.ListIngresses(t, options, metav1.ListOptions{LabelSelector: "app=webservice"})
	assert.NotEmpty(t, ingresses)
	lbIngresses := ingresses[0].Status.LoadBalancer.Ingress
	assert.NotEmpty(t, lbIngresses)
	hostname := lbIngresses[0].Hostname

	// Get the AWS name, a substring of the DNS name.
	re := regexp.MustCompile(`^k8s-gitlab-gitlabng-[^-]+`)
	name := re.FindString(hostname)
	assert.NotEmpty(t, name)

	// Create an ELB client
	sess, err := aws.NewAuthenticatedSession(region)
	assert.NoError(t, err)
	elb := elbv2.New(sess)

	// Find the load balancer associated with that hostname
	lbIn := &elbv2.DescribeLoadBalancersInput{
		Names: []*string{
			&name,
		},
	}
	lbOut, err := elb.DescribeLoadBalancers(lbIn)
	assert.NoError(t, err)
	assert.NotEmpty(t, lbOut.LoadBalancers)

	lb := lbOut.LoadBalancers[0]
	// Sanity check the DNS names match
	assert.Equal(t, *lb.DNSName, hostname)

	// Get the target groups for the lb
	tgs_in := &elbv2.DescribeTargetGroupsInput{
		LoadBalancerArn: lb.LoadBalancerArn,
	}
	tgs_out, err := elb.DescribeTargetGroups(tgs_in)
	assert.NoError(t, err)
	assert.NotEmpty(t, tgs_out.TargetGroups)

	// Validate the target groups' attributes
	for _, targetGroup := range tgs_out.TargetGroups {
		attr_in := &elbv2.DescribeTargetGroupAttributesInput{
			TargetGroupArn: targetGroup.TargetGroupArn,
		}
		attr_out, err := elb.DescribeTargetGroupAttributes(attr_in)
		assert.NoError(t, err)
		for _, attr := range attr_out.Attributes {
			switch *attr.Key {
			case "proxy_protocol_v2.enabled":
				assert.Equal(t, "false", *attr.Value)
			case "preserve_client_ip.enabled":
				assert.Equal(t, "false", *attr.Value)
			}
		}
	}
}

// // make sure that we can use git over ssh
// // XXX not quite working yet
// func TestGitlabSsh(t *testing.T) {
// 	t.Parallel()

// 	options := k8s.NewKubectlOptions("", "", "gitlab")

// 	// open a tunnel to the service
// 	tunnel := k8s.NewTunnel(options, k8s.ResourceTypeService, "gitlab-gitlab-shell", 2975, 22)
// 	defer tunnel.Close()
// 	tunnel.ForwardPort(t)

// 	proxiedHost := ssh.Host{
// 		Hostname:    "localhost",
// 		CustomPort:  2975,
// 		SshUserName: "test",
// 		Password:    "test",
// 	}
// 	ssh.CheckSshConnection(t, proxiedHost)
// }

// Make sure that networkfw prevents us from getting out

// Test that logs are getting emitted

// Test that audit logs for terraform are in dynamodb
