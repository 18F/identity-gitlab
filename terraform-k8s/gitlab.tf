
resource "kubernetes_namespace" "gitlab" {
  metadata {
    name = "gitlab"
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
