
# Outputs needed by the terraform-k8s stuff

output "oidc_arn" {
  value = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_url" {
  value = aws_iam_openid_connect_provider.eks.url
}
