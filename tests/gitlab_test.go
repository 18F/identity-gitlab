package test

import (
	"crypto/tls"
	"fmt"
	"os"
	"strings"
	"testing"

	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/k8s"
)

var cluster_name = os.Getenv("CLUSTER_NAME")
var region = os.Getenv("REGION")
var domain = os.Getenv("DOMAIN")

// test that the autoscaler is running
func TestAutoScalerRunning(t *testing.T) {
	t.Parallel()

	options := k8s.NewKubectlOptions("", "", "kube-system")
	k8s.GetService(t, options, "eksclusterautoscaler-aws-cluster-autoscaler")
}

// test that the loadbalancer controller is running
func TestLBControllerRunning(t *testing.T) {
	t.Parallel()

	options := k8s.NewKubectlOptions("", "", "kube-system")
	k8s.GetService(t, options, "aws-load-balancer-webhook-service")
}

// Make sure that networkfw prevents us from getting out

// test that teleport is set up
// 	roles are there
// 	service is configured
//  dns is there
func TestTeleportExternallyAvailable(t *testing.T) {
	t.Parallel()

	options := k8s.NewKubectlOptions("", "", "teleport")

	service := k8s.GetService(t, options, "teleport-cluster")
	url := fmt.Sprintf("https://%s/", k8s.GetServiceEndpoint(t, options, service, 443))

	// set the ServerName so that we use SNI
	tlsconfig := &tls.Config{ServerName: fmt.Sprintf("teleport-%s.%s", cluster_name, domain)}

	// Scrape the page for some content and make sure it's a 200
	http_helper.HttpGetWithCustomValidation(t, url, tlsconfig, func(statusCode int, body string) bool {
		return statusCode == 200 && strings.Contains(body, "<script src=\"/web/config.js\"></script>")
	})
}

// test that teleport apps are accessible

// test that gitlab helm chart installed properly

// look for gitlab-runner not being able to register

// make sure that we can use git over ssh
