#!/bin/sh

eksctl create cluster -f gitlabcluster.yml

helm repo add gitlab https://charts.gitlab.io/
helm install gitlab gitlab/gitlab -f gitlab_values.yml

echo "The root password is...."
kubectl get secret gitlab-gitlab-initial-root-password -ojsonpath='{.data.password}' | base64 --decode ; echo

echo "Port forward like so..."
echo "kubectl port-forward service/gitlab-webservice-default 8181:8181"

