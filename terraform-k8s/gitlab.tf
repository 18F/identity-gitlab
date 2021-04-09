
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
    name  = "gitlab.name"
    value = "${var.cluster_name}.${var.domain}"
  }

  set {
    name  = "global.hosts.domain"
    value = var.domain
  }

  set {
    name  = "global.hosts.https"
    value = true
  }

  set {
    name  = "certmanager-issuer.email"
    value = var.certmanager-issuer
  }
}
