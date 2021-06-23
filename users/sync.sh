#!/bin/sh

# TDOO: Get token from aws secrets
# Log in via teleport
tsh login --proxy teleport-akrito.gitlab.identitysandbox.gov:443 --user akrito
tsh app login gitlab
# TODO: Set up cert env vars
# TODO: Set up cluster name
# curl --user admin:admin \
#   --cacert $(tsh app config --format=ca) \
#   --cert $(tsh app config --format=cert) \
#   --key $(tsh app config --format=key) \
#     $(tsh app config --format=uri)/api/users

go run sync.go
