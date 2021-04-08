#
# Variables Configuration
#

variable "cluster_name" {
  type    = string
}

variable "region" {
  default = "us-west-2"
  type    = string
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
  description = "cidr block for VPC"
}

# networks which are allowed to talk with the k8s API
variable "kubecontrolnets" {
  default = ["98.146.223.15/32", "159.142.0.0/16", "50.46.2.51/32"]
  type    = list(string)
}
