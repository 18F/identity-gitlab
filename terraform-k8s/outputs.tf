output "deploy_key" {
  value       = tls_private_key.main.public_key_pem
  description = "you can put this public ssh key into a repo as a deploy key"
}
