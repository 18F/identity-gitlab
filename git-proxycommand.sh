#!/bin/bash
#
# This script execs in to the gitlab-shell service
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

exec kubectl "$@" exec -q --stdin -n gitlab service/gitlab-gitlab-shell -- /usr/sbin/sshd -i
