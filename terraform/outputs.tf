
output "deploy_key" {
  value       = tls_private_key.main.public_key_pem
  description = "you can put this public ssh key into a repo as a deploy key"
}

output "teleport_url" {
  value       = "https://teleport-${var.cluster_name}.${var.domain}/"
  description = "The URL for teleport"
}

# XXX Temporarily disabled, as it may interfere with cluster teardown.
# output "gitlab-privatelink-service_name" {
#   value       = var.bootstrap ? "not defined: run terraform again without bootstrap set" : aws_vpc_endpoint_service.gitlab.0.service_name
#   description = "The service_name used by other VPCs to set up the gitlab privatelink"
# }
