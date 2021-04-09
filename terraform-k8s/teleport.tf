
resource "kubernetes_namespace" "teleport" {
  metadata {
    name = "teleport"
  }
}

resource "helm_release" "teleport-cluster" {
  name       = "teleport-cluster"
  repository = "https://charts.releases.teleport.dev" 
  chart      = "teleport-cluster"
  version    = "6.0.0"
  namespace  = "teleport"
  depends_on = [kubernetes_namespace.teleport]

  set {
    name  = "namespace"
    value = "teleport"
  }

  set {
    name  = "acme"
    value = "true"
  }

  set {
    name  = "acmeEmail"
    value = "security@login.gov"
  }

  set {
    name  = "clusterName"
    value = "teleport-${var.cluster_name}.${var.domain}"
  }

  set {
    name  = "customConfig"
    value = "true"
  }
}

# This is where the customConfig lives (same name as the helm release)
resource "kubernetes_config_map" "teleport-cluster" {
  # depends_on = [helm_release.teleport-cluster]
  depends_on = [kubernetes_namespace.teleport]
  metadata {
    name = "teleport-cluster"
    namespace = "teleport"
  }

  data = {
    "teleport.yaml" = <<CUSTOMCONFIG
teleport:
  log:
    severity: ERROR
    output: stderr
auth_service:
  enabled: true
  cluster_name: teleport-${var.cluster_name}.${var.domain}
app_service:
  enabled: true
  apps:
    - name: gitlab
      uri: "http://gitlab-webservice-default.gitlab:8181"
kubernetes_service:
  enabled: true
  listen_addr: 0.0.0.0:3027
proxy_service:
  enabled: true
  public_addr: 'teleport-${var.cluster_name}.${var.domain}:443'
  kube_listen_addr: 0.0.0.0:3026
  acme:
    enabled: true
    email: security@login.gov
ssh_service:
  enabled: false

CUSTOMCONFIG
  }
}
