
resource "kubernetes_namespace" "gitlab" {
  metadata {
    name = "gitlab"
  }
}

# This configmap is where we can pass stuff into flux/helm from terraform
resource "kubernetes_config_map" "terraform-gitlab-info" {
  depends_on = [kubernetes_namespace.gitlab]
  metadata {
    name      = "terraform-gitlab-info"
    namespace = "gitlab"
  }

  data = {
    "cluster_name" = var.cluster_name,
    "domain" = var.domain,
    "certmanager-issuer-email" = var.certmanager-issuer
  }
}
