
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
  depends_on = [kubernetes_namespace.gitlab, helm_release.alb-ingress-controller]

  set {
    name  = "global.hosts.hostSuffix"
    value = var.cluster_name
  }

  set {
    name  = "global.hosts.domain"
    value = var.domain
  }

  set {
    name  = "certmanager-issuer.email"
    value = var.certmanager-issuer
  }
}
