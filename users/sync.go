package main

import (
	"io/ioutil"
	"net/http"
	"log"
	"os"
	"crypto/tls"
	
	"github.com/xanzy/go-gitlab"
	"gopkg.in/yaml.v2"
)

const userYaml = "../../identity-devops/terraform/master/global/users.yaml"
const gitlabTokenEnvVar = "GITLAB_API_TOKEN"

// TODO none of these will be hardcoded
const gitlabBaseURL = "https://gitlab.teleport-akrito.gitlab.identitysandbox.gov/api/v4"
const certFile = "/Users/alexandergkritikos/.tsh/keys/teleport-akrito.gitlab.identitysandbox.gov/akrito-app/teleport-akrito.gitlab.identitysandbox.gov/gitlab-x509.pem"
const keyFile = "/Users/alexandergkritikos/.tsh/keys/teleport-akrito.gitlab.identitysandbox.gov/akrito"

// TODO add dry-run flag

type Users struct {
	Users map[string][]string
}

func main() {
	// Get Users from YAML
	var users Users
	userFile, err := ioutil.ReadFile(userYaml)
	if err != nil {
		log.Fatalf("Error reading user YAML: %s", err)
	}
	err = yaml.Unmarshal(userFile, &users)
	if err != nil {
		log.Fatalf("Error parsing YAML: %s", err)
	}

	// Build HTTP client with Teleport certs
	cert, err := tls.LoadX509KeyPair(certFile, keyFile)
	if err != nil {
		log.Fatal(err)
	}
	httpClient := &http.Client{
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{
				Certificates: []tls.Certificate{cert},
			},
		},
	}
	
	// Set up GitLab connection
	git, err := gitlab.NewClient(
		os.Getenv(gitlabTokenEnvVar),
		gitlab.WithBaseURL(gitlabBaseURL),
		gitlab.WithHTTPClient(httpClient),
	)
	if err != nil {
		log.Fatalf("Failed to create client: %v", err)
	}

	// Get existing GitLab users
	gitUsers, _, err := git.Users.ListUsers(&gitlab.ListUsersOptions{})
	if err != nil {
		log.Fatalf("Failed to list users: %v", err)
	}
	log.Printf("Users: %v", gitUsers)


	// Get existing Teleport users
	// Create/enable necessary users
	// Disable unnecessary users

}
