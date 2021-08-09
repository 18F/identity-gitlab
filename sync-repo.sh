#!/bin/sh
#
# This syncs a repo from the location specified to our local ECR repo.
# The default is to get it from the Google docker hub mirror,
# but if you supply two args, it gets it from the specified registry.

usage() {
	echo "usage:   $0 <repo> <tag> [<registry>]"
	echo "example: $0 alpine/git latest"
	echo "example: $0 amazonlinux/amazonlinux latest public.ecr.aws"
	echo "also:  the REGION, CI_REGISTRY_PASSWORD, CI_REGISTRY, CI_REGISTRY_USER environment variables must be set"
	exit 1
}

if [ -z "$1" ] ; then
	echo "missing repo"
	usage
else
	REPO="$1"
fi
if [ -z "$2" ] ; then
	echo "missing tag"
	usage
else
	TAG="$2"
fi
if [ -z "$3" ] ; then
	REGISTRY="mirror.gcr.io"
else
	REGISTRY="$3"
fi

if [ -z "$REGION" ] ; then
	echo "missing REGION variable"
	usage
fi
if [ -z "$CI_REGISTRY_PASSWORD" ] ; then
	echo "missing CI_REGISTRY_PASSWORD variable"
	usage
fi
if [ -z "$CI_REGISTRY" ] ; then
	echo "missing CI_REGISTRY variable"
	usage
fi
if [ -z "$CI_REGISTRY_USER" ] ; then
	echo "missing CI_REGISTRY_USER variable"
	usage
fi

# AWS won't let you push to a repo unless you've created it
aws ecr create-repository --repository-name "$REPO" --region "$REGION" --image-scanning-configuration scanOnPush=true --encryption-configuration encryptionType=AES256 || true

skopeo copy -a --dest-creds "$CI_REGISTRY_USER:$CI_REGISTRY_PASSWORD" "docker://$REGISTRY/$REPO:$TAG" "docker://$CI_REGISTRY/$REPO:$TAG"
