#!/bin/sh
#
# This script updates the alb ingress controller CRD yaml.
# 
# from: https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html
#

kustomize build "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master" > alb-TargetGroupBinding-crds.yaml
