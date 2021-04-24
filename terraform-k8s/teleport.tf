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

resource "helm_release" "teleport-kube-agent" {
  name       = "teleport-kube-agent"
  repository = "https://charts.releases.teleport.dev"
  chart      = "teleport-kube-agent"
  version    = "0.0.4"
  namespace  = "teleport"
  depends_on = [helm_release.teleport-cluster, kubernetes_secret.teleport-kube-agent-join-token]

  set {
    name  = "namespace"
    value = "teleport"
  }

  set {
    name  = "roles"
    value = "kube,app"
  }

  # XXX temporary
  set {
    name  = "logLevel"
    value = "DEBUG"
  }

  set {
    name  = "proxyAddr"
    value = "teleport-${var.cluster_name}.${var.domain}"
  }

  set {
    name  = "kubeClusterName"
    value = "teleport-${var.cluster_name}"
  }

  set {
    name  = "apps[0].name"
    value = "gitlab"
  }

  set {
    name  = "apps[0].uri"
    value = "http://gitlab-webservice-default.gitlab:8181"
  }

  set {
    name  = "serviceAccountAnnotations.eks\.amazonaws\.com/role-arn"
    value = aws_iam_role.teleport.arn
  }
}


# set things up for the serviceaccount to have proper perms
resource "aws_iam_role" "teleport" {
  name               = "${var.cluster_name}-teleport"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${var.oidc_arn}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${var.oidc_url}:sub": "system:serviceaccount:teleport:teleport-kube-agent"
        }
      }
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy" "teleport" {
  name = "${var.cluster_name}-teleport-policy"
  role = aws_iam_role.teleport.id

  # This came from https://goteleport.com/docs/aws-oss-guide/#create-iam-policy-granting-list-clusters-and-describe-cluster-permissions-optional
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ListDescribeClusters",
            "Effect": "Allow",
            "Action": [
                "eks:DescribeCluster",
                "eks:ListClusters"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}
