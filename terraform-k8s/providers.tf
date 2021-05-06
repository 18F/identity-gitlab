#
# Provider Configuration
#

provider "aws" {
  region  = var.region
  version = "~> 3.35"
}

terraform {
  required_version = ">= 0.13"
  backend "s3" {
  }
  required_providers {
    kubectl = {
      source = "gavinbunney/kubectl"
    }
    flux = {
      source  = "fluxcd/flux"
      version = ">= 0.0.13"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "3.1.0"
    }
  }
}

# Using these data sources allows the configuration to be
# generic for any region.
data "aws_region" "current" {}

data "aws_availability_zones" "available" {}

data "aws_caller_identity" "current" {}

# EKS info
data "aws_eks_cluster" "eks" {
  name = var.cluster_name
}

# This is the main provider
provider "kubernetes" {
  version                = "~> 2.0.3"
  host                   = data.aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1alpha1"
    command     = "aws" # this is the actual 'aws' cli tool
    args        = ["--region", var.region, "eks", "get-token", "--cluster-name", var.cluster_name]
    env         = {}
  }
}

# This is so we can install helm stuff
provider "helm" {
  version = "~> 2.1.0"
  kubernetes {
    host                   = data.aws_eks_cluster.eks.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
    exec {
      api_version = "client.authentication.k8s.io/v1alpha1"
      command     = "aws" # this is the actual 'aws' cli tool
      args        = ["--region", var.region, "eks", "get-token", "--cluster-name", var.cluster_name]
      env         = {}
    }
  }
}

provider "kubectl" {
  version          = ">= 1.10.0"
  load_config_file = false
  # apply_retry_count      = 15
  host                   = data.aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1alpha1"
    command     = "aws" # this is the actual 'aws' cli tool
    args        = ["--region", var.region, "eks", "get-token", "--cluster-name", var.cluster_name]
    env         = {}
  }
}
