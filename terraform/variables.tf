#
# Variables Configuration
#

variable "cluster_name" {
  type = string
}

variable "region" {
  default = "us-west-2"
  type    = string
}

variable "vpc_cidr" {
  default     = "10.0.0.0/16"
  description = "cidr block for VPC"
}

# networks which are allowed to talk with the k8s API
variable "kubecontrolnets" {
  default = ["98.146.223.15/32", "159.142.0.0/16", "50.46.2.51/32"]
  type    = list(string)
}

variable "nodetype" {
  default     = "SPOT"
  description = "make this be SPOT or ON_DEMAND"
}

variable "node_disk_size" {
  default     = 20
  description = "local disk size in GB for nodes"
}

variable "node_max_size" {
  default     = 14
  description = "maximum size for node group"
}

variable "node_instance_type" {
  default     = "t3a.large"
  description = "instance type for nodes"
}

variable "k8s_public_api" {
  default     = true
  description = "enable the public k8s API.  XXX cannot actually set this to false because the kubernetes/helm providers have to be able to work"
}
