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

# set it up with the s3 backend, push into the directory.
pushd "$SCRIPT_BASE/terraform"

terraform init -backend-config="bucket=$BUCKET" \
      -backend-config="key=tf-state/$TF_VAR_cluster_name" \
      -backend-config="dynamodb_table=eks_terraform_locks" \
      -backend-config="region=$REGION" \
      -upgrade

# launch everything!
terraform apply

# This updates the kubeconfig so that we can access the cluster using kubectl
aws eks update-kubeconfig --name "$TF_VAR_cluster_name"
popd
