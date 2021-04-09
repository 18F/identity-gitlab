#!/bin/sh
#
# This script deploys/updates the environment.
# 
set -e

if [ -z "$1" ]; then
     echo "usage:  $0 <cluster_name>"
     echo "example: ./deploy.sh gitlab-dev"
     echo "example: ./deploy.sh gitlab-dev"
     exit 1
else
     export TF_VAR_cluster_name="$1"
fi

checkbinary() {
     if which "$1" >/dev/null ; then
          return 0
     else
          echo no "$1" found: exiting
          exit 1
     fi
}

REQUIREDBINARIES="
     terraform
     aws
     jq
"
for i in ${REQUIREDBINARIES} ; do
     checkbinary "$i"
done


# some config
ACCOUNT=$(aws sts get-caller-identity | jq -r .Account)
REGION="us-west-2"
BUCKET="login-dot-gov-eks.${ACCOUNT}-${REGION}"
SCRIPT_BASE=$(dirname "$0")
RUN_BASE=$(pwd)

# clean up tfstate files so that we get them from the backend
find . -name terraform.tfstate -print0 | xargs -0 rm


# do terraform!
pushd "$SCRIPT_BASE/terraform"
terraform init -backend-config="bucket=$BUCKET" \
      -backend-config="key=tf-state/$TF_VAR_cluster_name" \
      -backend-config="dynamodb_table=eks_terraform_locks" \
      -backend-config="region=$REGION" \
      -upgrade
terraform apply

# Gather info from terraform to use in terraform-k8s
export TF_VAR_oidc_arn=$(terraform output oidc_arn)
export TF_VAR_oidc_url=$(terraform output oidc_url)

# This updates the kubeconfig so that we can access the cluster using kubectl
aws eks update-kubeconfig --name "$TF_VAR_cluster_name"
popd

# Now do terraform-k8s
# This is because we can't do terraform-k8s as a module yet:
# https://github.com/hashicorp/terraform-provider-kubernetes-alpha/issues/133
pushd "$SCRIPT_BASE/terraform-k8s"
terraform init -backend-config="bucket=$BUCKET" \
      -backend-config="key=tf-state/k8s-$TF_VAR_cluster_name" \
      -backend-config="dynamodb_table=eks_terraform_locks" \
      -backend-config="region=$REGION" \
      -upgrade
terraform apply
popd
