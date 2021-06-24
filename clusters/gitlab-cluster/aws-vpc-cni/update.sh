#!/bin/sh
#
# update the aws-vpc-cni!
#
# You can find what releases are available by going here:
# https://github.com/aws/amazon-vpc-cni-k8s/releases
# Then find the url that they have for deploying the release
# you want and put it in here.
#

curl https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/v1.8.0/config/v1.8/aws-k8s-cni.yaml > aws-k8s-cni.yaml

