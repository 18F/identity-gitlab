#!/bin/sh

# TDOO: Get token from aws secrets
# Log in via teleport
tsh app login gitlab
# TODO: Set up cert env vars
# TODO: Set up cluster name
go run sync.go
