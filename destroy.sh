#!/bin/sh
#
# This script destroys an EKS environment.
# 
set -e

if [ -z "$1" ]; then
     echo "usage:   $0 <cluster_name>"
     echo "example: ./destroy.sh gitlab-dev"
     exit 1
else
     export TF_VAR_cluster_name="$1"
fi

/bin/echo -n "are you SURE you want to destroy ${1}? (yes/no) "
read -r yesno
if [ "$yesno" != "yes" ] ; then
  echo "aborting!"
  exit 0
fi

ACCOUNT=$(aws sts get-caller-identity | jq -r .Account)
REGION="us-west-2"
BUCKET="login-dot-gov-eks.${ACCOUNT}-${REGION}"
SCRIPT_BASE=$(dirname "$0")
RUN_BASE=$(pwd)

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
"
for i in ${REQUIREDBINARIES} ; do
     checkbinary "$i"
done

# do the deed
cd "$RUN_BASE/$SCRIPT_BASE/terraform"
terraform init -backend-config="bucket=$BUCKET" \
      -backend-config="key=tf-state/$TF_VAR_cluster_name" \
      -backend-config="dynamodb_table=eks_terraform_locks" \
      -backend-config="region=$REGION" \
      -upgrade
terraform destroy
