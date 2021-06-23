#!/bin/sh
#
# This script sets up the environment variables so that terraform and
# the tests can know how to run and what to test.
#

if [ -z "$1" ] || [ -z "$2" ]; then
	echo "usage:   $0 <cluster_name> <domain>"
	echo "example: $0 gitlabtest gitlab.foo.gov"
	exit 1
fi

export CLUSTER_NAME="$1"
export REGION=${REGION:="us-west-2"}
export DOMAIN="$2"

if kubectl version >/dev/null 2>&1 ; then
	echo "starting tests!"
else
	echo "kubernetes is not working.  Either use aws-vault or tsh to get this working!"
	exit 2
fi

go test -v -timeout 60m
