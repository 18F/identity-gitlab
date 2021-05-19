#!/bin/sh
#
# This script attempts to discover the different IPs that will need to
# be allowed into the git-ssh loadbalancer.  It is specific to login.gov's application
# environments right now, but could be adapted to discover anything.
#

usage() {
	echo "usage:  $0 <profilepattern>"
	echo "        where profilepattern is a regex that can be used to select profiles from aws-vault list"
	echo "example:  $0 admin"
	exit 1
}
if [ -z "$1" ] ; then
	usage
fi

ENVS=$(aws-vault list | awk '{print $1}' | grep -E -e "$1")

for i in $ENVS ; do
	aws-vault exec "$i" -- aws ec2 describe-instances --filters "Name=tag:prefix,Values=outboundproxy" "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[*].{IP:PublicIpAddress}' \
		| jq -r '.[] | .[] | "- " + .IP + "/32"'
done
