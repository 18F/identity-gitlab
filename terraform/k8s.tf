
module "k8s" {
  source           = "../terraform-k8s"

  cluster_name     = var.cluster_name
  region           = var.region

  # trying to make sure eks is up before we do the k8s config
  depends_on       = [aws_eks_node_group.eks]
}

# This is the main provider
provider "kubernetes" {
  version = "~> 2.0.3"
  host                   = aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
  load_config_file       = false
  exec {
    api_version = "client.authentication.k8s.io/v1alpha1"
    command = "aws" # this is the actual 'aws' cli tool
    args = ["--region", var.region, "eks", "get-token", "--cluster-name", var.cluster_name]
    env = {}
  }
}

# This is so we can do CRDs and arbitrary yaml
provider "kubernetes-alpha" {
  version = "~> 0.3.2"
  host                   = aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)

  exec = {
    api_version = "client.authentication.k8s.io/v1alpha1"
    command = "aws" # this is the actual 'aws' cli tool
    args = ["--region", var.region, "eks", "get-token", "--cluster-name", var.cluster_name]
    env = {}
  }
}

# This is so we can install helm stuff
provider "helm" {
  version = "~> 2.1.0"
  kubernetes {
  host                   = aws_eks_cluster.eks.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
    load_config_file       = false
    exec {
      api_version = "client.authentication.k8s.io/v1alpha1"
      command = "aws" # this is the actual 'aws' cli tool
      args = ["--region", var.region, "eks", "get-token", "--cluster-name", var.cluster_name]
      env = {}
    }
  }
}
