#!/bin/sh
#
# This came from https://docs.aws.amazon.com/eks/latest/userguide/calico.html
#

wget https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/master/config/master/calico-operator.yaml
wget https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/master/config/master/calico-crs.yaml

