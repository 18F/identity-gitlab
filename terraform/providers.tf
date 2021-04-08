#
# Provider Configuration
#

provider "aws" {
  region  = var.region
  version = "~> 2.0"
}

terraform {
  backend "s3" {
  }
}

# Using these data sources allows the configuration to be
# generic for any region.
data "aws_region" "current" {}

data "aws_availability_zones" "available" {}

data "aws_caller_identity" "current" {} 

# EKS auth info
data "aws_eks_cluster" "eks" {
  name = var.cluster_name
}
