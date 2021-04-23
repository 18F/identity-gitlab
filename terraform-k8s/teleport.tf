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

# This configmap is where we can pass stuff into flux/helm from terraform
resource "kubernetes_config_map" "terraform-teleport-info" {
  depends_on = [kubernetes_namespace.teleport]
  metadata {
    name      = "terraform-teleport-info"
    namespace = "teleport"
  }

  data = {
    "clusterName" = "teleport-${var.cluster_name}.${var.domain}",
    "acmeEmail" = var.certmanager-issuer,
    "kubeClusterName" = "teleport-${var.cluster_name}"
  }
}

# This is the join token
resource "random_password" "join-token" {
  length           = 26
  special          = true
  override_special = "/@£$"
}

resource "kubernetes_secret" "teleport-kube-agent-join-token" {
  depends_on = [kubernetes_namespace.teleport]
  metadata {
    name = "teleport-kube-agent-join-token"
    namespace = "teleport"
  }

  data = {
    auth-token = random_password.join-token.result
  }
}

# Ideally, this would be done through flux, but we need it to be live
# so we can reference the service to get the elb to put the CNAMEs on.
#
# Note:  there is a teleport-kube-agent helm release set up in flux
#        that should add kubernetes and the gitlab app in.  So the teleport
#        config is in _two_ places.
resource "helm_release" "teleport-cluster" {
  name       = "teleport-cluster"
  repository = "https://charts.releases.teleport.dev"
  chart      = "teleport-cluster"
  version    = "6.0.0"
  namespace  = "teleport"
   depends_on = [kubernetes_namespace.teleport, kubernetes_secret.teleport-kube-agent-join-token]

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
    value = var.certmanager-issuer
   }
 
  set {
    name  = "clusterName"
    value = "teleport-${var.cluster_name}.${var.domain}"
   }
 }
