#!/bin/sh

# TDOO: Get token from aws secrets
# Log in via teleport
tsh app login gitlab
# TODO: Set up cert env vars
export TELEPORT_CERT=$(tsh app config --format=cert)
export TELEPORT_KEY=$(tsh app config --format=key)
export GITLAB_BASE_URL=$(tsh app config --format=uri)/

go run sync.go
