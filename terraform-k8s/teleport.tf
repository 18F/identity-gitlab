#
# To use this, you will need to create users.  There's probably
# a way to do this with code, but here is how you set it up:
# 
# aws-vault exec tooling-admin -- kubectl -n teleport exec --stdin --tty teleport-cluster-<whatever> /bin/bash
# tctl users add tspencer --roles=editor,access,admin --logins=root,ubuntu
#
# Then, you can go to teleport-${var.cluster_name}.gitlab.identitysandbox.gov
# and log in with your new creds
#

resource "kubernetes_namespace" "teleport" {
  metadata {
    name = "teleport"
  }
}

data "aws_route53_zone" "gitlab" {
  name = var.domain
}

data "kubernetes_service" "teleport" {
  depends_on = [helm_release.teleport-cluster]
  metadata {
    name      = "teleport-cluster"
    namespace = "teleport"
  }
}

resource "aws_route53_record" "teleport" {
  zone_id = data.aws_route53_zone.gitlab.zone_id
  name    = "teleport-${var.cluster_name}"
  type    = "CNAME"
  ttl     = "300"
  records = [data.kubernetes_service.teleport.status.0.load_balancer.0.ingress.0.hostname]
}

resource "aws_route53_record" "teleport-gitlab" {
  zone_id = data.aws_route53_zone.gitlab.zone_id
  name    = "gitlab.teleport-${var.cluster_name}"
  type    = "CNAME"
  ttl     = "300"
  records = [data.kubernetes_service.teleport.status.0.load_balancer.0.ingress.0.hostname]
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
    name      = "teleport-cluster"
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
      uri: "https://gitlab-webservice-default.gitlab:8181"
kubernetes_service:
  enabled: true
  listen_addr: 0.0.0.0:3027
proxy_service:
  enabled: true
  public_addr: 'teleport-${var.cluster_name}.${var.domain}:443'
  kube_listen_addr: 0.0.0.0:3026
  acme:
    enabled: true
    email: ${var.certmanager-issuer}
ssh_service:
  enabled: false

CUSTOMCONFIG
  }
}
