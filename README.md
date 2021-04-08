# GITLAB!

This will launch and configure a basic gitlab instance inside of EKS.

## Setup

The setup will only need to be run once per account.  It sets up the s3 bucket
and dynamodb stuff for remote state and locking and then goes on to do the deploy.

Run it like: `aws-vault exec sandbox-admin -- ./setup.sh gitlab-dev` where
`gitlab-dev` is the name of your cluster.

## Updates

`aws-vault exec sandbox-admin -- ./deploy.sh gitlab-dev` will deploy all the
latest changes you have there in your repo.

## Delete

`aws-vault exec sandbox-admin -- ./destroy.sh gitlab-dev`

Have fun!!
