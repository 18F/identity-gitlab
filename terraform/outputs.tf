
output "deploy_key" {
  value       = tls_private_key.main.public_key_pem
  description = "you can put this public ssh key into a repo as a deploy key"
}

output "teleport_url" {
  value       = "https://teleport-${var.cluster_name}.${var.domain}/"
  description = "The URL for teleport"
}

output "gitlab-privatelink-service_name" {
  value = aws_vpc_endpoint_service.gitlab.service_name
  description = "The service_name used by other VPCs to set up the gitlab privatelink"
}

output "gitlab-privatelink-service_type" {
  value = aws_vpc_endpoint_service.gitlab.service_type
  description = "The service_type used by other VPCs to set up the gitlab privatelink"
}
