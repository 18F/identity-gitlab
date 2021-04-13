
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

resource "helm_release" "gitlab" {
  name       = "gitlab"
  repository = "https://charts.gitlab.io/"
  chart      = "gitlab"
  version    = "4.10.2"
  namespace  = "gitlab"
  depends_on = [kubernetes_namespace.gitlab]

  set {
    name  = "global.hosts.hostSuffix"
    value = var.cluster_name
  }

  set {
    name  = "global.hosts.domain"
    value = var.domain
  }

  # we are using teleport to get into the GUI, so don't expose it.
  # XXX probably will need to turn this off for git ssh
  set {
    name  = "global.ingress.enabled"
    value = false
  }

  set {
    name  = "certmanager-issuer.email"
    value = var.certmanager-issuer
  }
}
