
resource "kubernetes_namespace" "gitlab" {
  metadata {
    name = "gitlab"
  }
}

# This configmap is where we can pass stuff into flux/helm from terraform
resource "kubernetes_config_map" "gitlab-terraform-info" {
  depends_on = [kubernetes_namespace.gitlab]
  metadata {
    name      = "terraform-info"
    namespace = "gitlab"
  }

  data = {
    "cluster_name" = var.cluster_name,
    "domain" = var.domain,
    "certmanager-issuer-email" = var.certmanager-issuer
  }
}
