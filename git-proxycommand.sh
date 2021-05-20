#!/bin/bash
#
# This script port-forwards in to the gitlab-shell service
# So you can use it in your ~/.ssh/config like this:
#
# Host gitlab-webservice-default
#   ProxyCommand ~/src/identity-gitlab/git-proxycommand.sh
#
# Or if you are doing this for automation, you need to add the kubeconfig argument like so:
#
# Host gitlab-webservice-default
#   ProxyCommand /full/path/to/git-proxycommand.sh --kubeconfig=/full/path/to/gitssh.kubeconfig
#
# It should clean up the port-forward once it's done.
#

cleanup() {
    # kill all processes whose parent is this process
    pkill -9 -P $$
}
trap cleanup EXIT

kubectl "$1" port-forward service/gitlab-gitlab-shell 2222:22 -n gitlab >/dev/null 2>&1 &
while ! nc -z localhost 2222 >/dev/null 2>&1 ; do
	sleep 0.1
done

# to make sure that cleanup happens, close the connection if it's
# idle more than 5 seconds.  Seems like there ought to be traffic
# the whole time you are doing a clone/pull, so this should be fine.
# But if not, increase this to something bigger.
nc -w 5 localhost 2222
