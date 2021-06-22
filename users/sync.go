package main

import (
	"gopkg.in/yaml.v2"
	"io/ioutil"
	"log"
)

type Users struct {
	Users map[string][]string
}

func main() {
	var users Users
	userFile, err := ioutil.ReadFile("../../identity-devops/terraform/master/global/users.yaml")
	if err != nil {
		log.Fatalf("Error reading user YAML: %s", err)
	}
	err = yaml.Unmarshal(userFile, &users)
	if err != nil {
		log.Fatalf("Error parsing YAML: %s", err)
	}
	log.Printf("Parsed: %v", users)
}
