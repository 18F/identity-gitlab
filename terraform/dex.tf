
resource "kubernetes_namespace" "dex" {
  depends_on = [aws_eks_node_group.eks]
  metadata {
    name = "dex"
  }
}

resource "kubernetes_config_map" "pivproxy-config" {
  depends_on = [kubernetes_namespace.dex]
  metadata {
    name      = "pivproxy-config"
    namespace = "dex"
  }

  data = {
    "fullhostname" = "gitlab-${var.cluster_name}.${var.domain}"
    "callback_url" = "https://dex_URL_XXX/dex/callback/piv?state=XXX"
    "uid_list"     = var.uid_list
  }
}

