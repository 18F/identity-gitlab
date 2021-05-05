#!/bin/bash
#
# This script port-forwards in to the gitlab-shell service
# So you can use it in your ~/.ssh/config like this:
#
# Host gitlab.gitlab.identitysandbox.gov
#   ProxyCommand ~/bin/k8s-portforward.sh
#
# It should clean up the port-forward once it's done.
#

cleanup() {
    # kill all processes whose parent is this process
    pkill -P $$
}

for sig in INT QUIT HUP TERM; do
  trap "
    cleanup
    trap - $sig EXIT
    kill -s $sig "'"$$"' "$sig"
done
trap cleanup EXIT

kubectl port-forward service/gitlab-gitlab-shell 2222:22 -n gitlab >/dev/null 2>&1 &
while ! nc -z localhost 2222 >/dev/null 2>&1 ; do
	sleep 0.1
done

nc localhost 2222

