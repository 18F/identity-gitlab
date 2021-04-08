
variable "cluster_name" {
  type    = string
  description = "name of the cluster that we are deploying this stuff to"
}

variable "region" {
  default = "us-west-2"
  type    = string
}

variable "domain" {
  default = "gitlab.identitysandbox.gov"
  type    = string
}

variable "certmanager-issuer" {
  default = "security@login.gov"
  type    = string
}

variable "k8s_endpoint" {
  description = "this is so we will run the module after k8s comes up"
}

resource "null_resource" "k8s_up" {
  triggers = {
    dependency_id = var.k8s_endpoint
  }
}
