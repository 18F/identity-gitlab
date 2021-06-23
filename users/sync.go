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
// TODO build a map of needed env vars and Fatal if they don't exist
const gitlabTokenEnvVar = "GITLAB_API_TOKEN"
const gitlabBaseURLEnvVar = "GITLAB_BASE_URL"
const certFileEnv = "TELEPORT_CERT"
const keyFileEnv = "TELEPORT_KEY"

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
	cert, err := tls.LoadX509KeyPair(os.Getenv(certFileEnv), os.Getenv(keyFileEnv))
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
		gitlab.WithBaseURL(os.Getenv(gitlabBaseURLEnvVar)),
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
