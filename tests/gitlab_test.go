package test

import (
	"bytes"
	"crypto/tls"
	"fmt"
	"net"
	"os"
	"strings"
	"testing"

	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/k8s"
	// "github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/stretchr/testify/assert"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

var cluster_name = os.Getenv("CLUSTER_NAME")
var region = os.Getenv("REGION")
var domain = os.Getenv("DOMAIN")

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

// test that github auth button is proper
func TestGitHubAuthButton(t *testing.T) {
	t.Parallel()

	options := k8s.NewKubectlOptions("", "", "gitlab")

	// open a tunnel to the service
	pods := k8s.ListPods(t, options, metav1.ListOptions{LabelSelector: "app=webservice"})
	tunnel := k8s.NewTunnel(options, k8s.ResourceTypePod, pods[0].Name, 0, 8080)
	defer tunnel.Close()
	tunnel.ForwardPort(t)

	// Scrape the page for the button and make sure it's a 200
	url := fmt.Sprintf("http://%s/", tunnel.Endpoint())
	expectedBody := "oauth-login-github"
	http_helper.HttpGetWithCustomValidation(
		t,
		url,
		nil,
		func(statusCode int, body string) bool {
			return statusCode == 200 && strings.Contains(body, expectedBody)
		},
	)

	// Scrape the auth page for the proper hostname and make sure it's a 200
	url = fmt.Sprintf("http://%s/users/auth/github", tunnel.Endpoint())
	hostname := fmt.Sprintf("teleport-%s.%s", cluster_name, domain)
	body := bytes.NewReader([]byte(hostname))
	http_helper.HTTPDoWithCustomValidation(
		t,
		"POST",
		url,
		body,
		nil,
		func(statusCode int, body string) bool {
			return statusCode == 200 && strings.Contains(body, hostname)
		},
		nil,
	)
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
