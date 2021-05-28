#
# Variables Configuration
#

variable "cluster_name" {
  type        = string
  description = "name of the cluster that we are deploying this stuff to"
}

variable "region" {
  default = "us-west-2"
  type    = string
}

variable "vpc_cidr" {
  default     = "10.0.0.0/16"
  description = "cidr block for VPC"
}

variable "subnet_count" {
  default     = 2
  description = "number of subnets we use for each layer in this cluster"
}

variable "service_cidr" {
  default     = "10.0.0.0/23"
  description = "cidr block for services"
}

variable "public_cidr" {
  default     = "10.0.2.0/23"
  description = "cidr block for internet-facing services"
}

variable "fw_cidr" {
  default     = "10.0.4.0/23"
  description = "cidr block for firewalls"
}

variable "nat_cidr" {
  default     = "10.0.6.0/23"
  description = "cidr block for NAT"
}

variable "eks_cidr" {
  default     = "10.0.8.0/21"
  description = "private cidr block for EKS"
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

variable "domain" {
  default = "gitlab.identitysandbox.gov"
  type    = string
}

variable "certmanager-issuer" {
  default = "security@login.gov"
  type    = string
}

variable "rds_backup_retention_period" {
  default = "34"
}

variable "rds_backup_window" {
  default = "08:00-08:34"
}

variable "redis_port" {
  default = 6379
}

variable "accountids" {
  type        = list(string)
  description = "list of AWS account ids that we should allow to find the gitlab privatelink service"
  # export TF_VAR_accountids='["1234", "2345", "5678"]'
}
