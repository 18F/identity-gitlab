#!/usr/bin/env bash

CHARTS="
	gitlab/gitlab
	eks/aws-load-balancer-controller
	eks/aws-node-termination-handler
	autoscaler/cluster-autoscaler
	kubernetes-dashboard/kubernetes-dashboard
	secrets-store-csi-driver/secrets-store-csi-driver
	teleport/teleport-cluster
	teleport/teleport-kube-agent
"

REPOS="
        tspencer                        https://timothy-spencer.github.io/helm-charts/                                          
        secrets-store-csi-driver        https://raw.githubusercontent.com/kubernetes-sigs/secrets-store-csi-driver/master/charts
        eks                             https://aws.github.io/eks-charts                                                        
        autoscaler                      https://kubernetes.github.io/autoscaler                                                 
        kubernetes-dashboard            https://kubernetes.github.io/dashboard/                                                 
        gitlab                          https://charts.gitlab.io/                                                               
        teleport                        https://charts.releases.teleport.dev                                                    
"

# make sure we have all the repos
for i in $REPOS ; do
	if [ -z "$REPO" ] ; then
		REPO=$i
	else
		helm repo add "$REPO" "$i" >&2
		unset REPO
	fi
done

helm repo update >&2
rm -f /tmp/charts.json.$$
#helm search repo . -r -o json > /tmp/charts.json.$$
for i in $CHARTS ; do
	#cat /tmp/charts.json.$$ | jq ".[] | select(.name == \"$i\")"
	helm search repo "$i" -r -o json
done
rm -f /tmp/charts.json.$$

