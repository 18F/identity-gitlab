#!/bin/sh

eksctl create cluster -f gitlabcluster.yml

# install ALB ingress controller cruft
eksctl utils associate-iam-oidc-provider --cluster gitlab-cluster --approve
ALBARN=$(aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://alb_controller_iam_policy.json | jq -r .Policy.Arn)
eksctl create iamserviceaccount \
  --cluster=gitlab-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn="$ALBARN" \
  --override-existing-serviceaccounts \
  --approve
#kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"
kubectl apply -f TargetGroupBinding-crds.yaml
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm upgrade -i aws-load-balancer-controller eks/aws-load-balancer-controller \
  --set clusterName=gitlab-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  -n kube-system

# install gitlab stuff here
helm repo add gitlab https://charts.gitlab.io/
helm repo update
helm install gitlab gitlab/gitlab -f gitlab_values.yml

echo "The root password is...."
kubectl get secret gitlab-gitlab-initial-root-password -ojsonpath='{.data.password}' | base64 --decode ; echo

echo "Port forward like so..."
echo "kubectl port-forward service/gitlab-webservice-default 8181:8181"

