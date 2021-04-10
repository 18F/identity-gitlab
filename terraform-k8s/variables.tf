
variable "cluster_name" {
  type        = string
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

variable "oidc_arn" {
  description = "OIDC arn for cluster"
}

variable "oidc_url" {
  description = "OIDC URL for cluster"
}
