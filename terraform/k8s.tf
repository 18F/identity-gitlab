
module "k8s" {
  source           = "../terraform-k8s"

  cluster_name     = var.cluster_name
  region           = var.region
  oidc_arn         = aws_iam_openid_connect_provider.eks.arn
  oidc_url         = aws_iam_openid_connect_provider.eks.url

  # XXX we really should start using tf 0.13 so we can use depends_on instead
  #     of the dumb k8s_endpoint thing.
  k8s_endpoint     = aws_eks_cluster.eks.endpoint
  # depends_on       = [aws_eks_node_group.eks]
}
