#
# To use this, you will need to create users.  There's probably
# a way to do this with code, but here is how you set it up:
# 
# aws-vault exec tooling-admin -- kubectl -n teleport exec --stdin --tty teleport-cluster-<whatever> /bin/bash
# tctl users add tspencer --roles=editor,access,admin --logins=root
#
# Then, you can go to teleport-${var.cluster_name}.gitlab.identitysandbox.gov
# and log in with your new creds
#

resource "kubernetes_namespace" "teleport" {
  depends_on = [aws_eks_node_group.eks]

  metadata {
    name = "teleport"
    labels = {
      namespace = "teleport"
    }
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
  count = var.bootstrap ? 0 : 1
  zone_id = data.aws_route53_zone.gitlab.zone_id
  name    = "teleport-${var.cluster_name}"
  type    = "CNAME"
  ttl     = "300"
  records = [data.kubernetes_service.teleport.status.0.load_balancer.0.ingress.0.hostname]
}

resource "aws_route53_record" "teleport-wildcard" {
  count = var.bootstrap ? 0 : 1
  zone_id = data.aws_route53_zone.gitlab.zone_id
  name    = "*.teleport-${var.cluster_name}"
  type    = "CNAME"
  ttl     = "300"
  records = [data.kubernetes_service.teleport.status.0.load_balancer.0.ingress.0.hostname]
}

resource "aws_route53_record" "dashboard" {
  count = var.bootstrap ? 0 : 1
  zone_id = data.aws_route53_zone.gitlab.zone_id
  name    = "dashboard-${var.cluster_name}"
  type    = "CNAME"
  ttl     = "300"
  records = [data.kubernetes_service.teleport.status.0.load_balancer.0.ingress.0.hostname]
}

# This is actually created by the deploy script so that
# it is available when we do tf, but not stored in the state.
data "aws_secretsmanager_secret_version" "join-token" {
  secret_id = "${var.cluster_name}-teleport-join-token"
}

# XXX according to
# https://blog.gruntwork.io/a-comprehensive-guide-to-managing-secrets-in-your-terraform-code-1d586955ace1,
# this is a good way to store secrets.  I am suspicious that there
# is still stuff stored in the tf state that, even if encrypted, could
# be dangerous.  If we want to go the extra mile, we can turn on the
# secrets-store-csi and set up secret syncing so that there is no
# suspicion of this, but that would add a fair amount of complexity that the gruntwork
# article seems to say that we don't need to worry about, so for
# now, we are going to go with their recommendation.
resource "kubernetes_secret" "teleport-kube-agent-join-token" {
  depends_on = [kubernetes_namespace.teleport]
  metadata {
    name      = "teleport-kube-agent-join-token"
    namespace = "teleport"
  }

  data = {
    auth-token = data.aws_secretsmanager_secret_version.join-token.secret_string
  }
}

# cert for teleport, attached to the network lb
resource "aws_acm_certificate" "teleport" {
  domain_name       = "teleport-${var.cluster_name}.${var.domain}"
  subject_alternative_names = ["*.teleport-${var.cluster_name}.${var.domain}"]
  validation_method = "DNS"

  tags = {
    Name = "teleport-${var.cluster_name}.${var.domain}"
  }
}

resource "aws_route53_record" "teleport-validation" {
  for_each = {
    for dvo in aws_acm_certificate.teleport.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.gitlab.zone_id
}

resource "aws_acm_certificate_validation" "teleport" {
  certificate_arn         = aws_acm_certificate.teleport.arn
  validation_record_fqdns = [for record in aws_route53_record.teleport-validation : record.fqdn]
}

# Ideally, this would be done through flux, but we need it to be live
# so we can reference the service to get the elb to put the CNAMEs on.
resource "helm_release" "teleport-cluster" {
  name = "teleport-cluster"
  # XXX remove the tspencer repo and add teleport back once these PRs get in:
  #  https://github.com/gravitational/teleport/pull/6619
  #  https://github.com/gravitational/teleport/pull/7287
  # repository = "https://charts.releases.teleport.dev"
  repository = "https://timothy-spencer.github.io/helm-charts"
  chart      = "teleport-cluster"
  version    = "6"
  namespace  = "teleport"
  depends_on = [kubernetes_secret.teleport-kube-agent-join-token, aws_iam_role.teleport, kubectl_manifest.fluxcd-sync]

  set {
    name  = "namespace"
    value = "teleport"
  }

  set {
    name  = "chartMode"
    value = "aws"
  }

  set {
    name  = "aws.backendTable"
    value = "${var.cluster_name}-teleport-state"
  }

  set {
    name  = "aws.auditLogTable"
    value = "${var.cluster_name}-teleport-events"
  }

  set {
    name  = "aws.sessionRecordingBucket"
    value = "${var.cluster_name}-teleport-sessions"
  }

  set {
    name  = "aws.region"
    value = var.region
  }

  set {
    name  = "aws.backups"
    value = true
  }

  set {
    name  = "acme"
    value = "false"
  }
  set {
    name  = "acmeEmail"
    value = var.certmanager-issuer
  }


  # set the loadbalancer up so that it uses SSL on the backend and the real
  # aws-load-balancer-controller instead of the in-tree one, which is only receiving
  # critical fixes now, for some reason.
  set {
    name  = "annotations.service.service\\.beta\\.kubernetes\\.io/aws-load-balancer-additional-resource-tags"
    value = "Name=${var.cluster_name}-teleport"
  }
  set {
    name  = "annotations.service.service\\.beta\\.kubernetes\\.io/aws-load-balancer-backend-protocol"
    value = "ssl"
  }
  set {
    name  = "annotations.service.service\\.beta\\.kubernetes\\.io/aws-load-balancer-ssl-ports"
    value = "443"
    type  = "string"
  }
  set {
    name  = "annotations.service.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = "external"
  }
  set {
    name  = "annotations.service.service\\.beta\\.kubernetes\\.io/aws-load-balancer-nlb-target-type"
    value = "instance"
  }
  set {
    name  = "annotations.service.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
    value = "internet-facing"
  }
  set {
    name  = "annotations.service.service\\.beta\\.kubernetes\\.io/aws-load-balancer-ssl-cert"
    value = aws_acm_certificate.teleport.arn
  }


  # # XXX temporary
  # set {
  #   name  = "logLevel"
  #   value = "DEBUG"
  # }

  set {
    name  = "clusterName"
    value = "teleport-${var.cluster_name}.${var.domain}"
  }

  set {
    name  = "kubeClusterName"
    value = "teleport-${var.cluster_name}"
  }

  set {
    name  = "annotations.serviceAccount.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.teleport.arn
  }
}

resource "helm_release" "teleport-kube-agent" {
  name = "teleport-kube-agent"
  # XXX remove the tspencer repo and add teleport back once these PRs get in:
  #  https://github.com/gravitational/teleport/pull/6619
  #  https://github.com/gravitational/teleport/pull/7287
  # repository = "https://charts.releases.teleport.dev"
  repository = "https://timothy-spencer.github.io/helm-charts"
  chart      = "teleport-kube-agent"
  version    = "6"
  namespace  = "teleport"
  # XXX temporary
  wait       = false
  depends_on = [kubernetes_secret.teleport-kube-agent-join-token, helm_release.teleport-cluster]

  set {
    name  = "namespace"
    value = "teleport"
  }

  set {
    name  = "roles"
    value = "app"
  }

  # # XXX temporary
  # set {
  #   name  = "logLevel"
  #   value = "DEBUG"
  # }

  set {
    name  = "proxyAddr"
    value = "teleport-${var.cluster_name}.${var.domain}:443"
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
    name  = "apps[1].name"
    value = "dashboard"
  }

  set {
    name  = "apps[1].uri"
    value = "http://dashboard-kubernetes-dashboard.kubernetes-dashboard:443"
  }

  set {
    name  = "annotations.serviceAccount.eks\\.amazonaws\\.com/role-arn"
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
        "Federated": "${aws_iam_openid_connect_provider.eks.arn}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "ForAnyValue:StringEquals": {
          "${aws_iam_openid_connect_provider.eks.url}:sub": [
            "system:serviceaccount:teleport:teleport-kube-agent",
            "system:serviceaccount:teleport:teleport-cluster"
          ]
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
  # and https://goteleport.com/docs/aws-oss-guide/#iam
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
        },
        {
            "Sid": "ClusterStateStorage",
            "Effect": "Allow",
            "Action": [
                "dynamodb:BatchWriteItem",
                "dynamodb:UpdateTimeToLive",
                "dynamodb:PutItem",
                "dynamodb:DeleteItem",
                "dynamodb:Scan",
                "dynamodb:Query",
                "dynamodb:DescribeStream",
                "dynamodb:UpdateItem",
                "dynamodb:DescribeTimeToLive",
                "dynamodb:CreateTable",
                "dynamodb:DescribeTable",
                "dynamodb:GetShardIterator",
                "dynamodb:GetItem",
                "dynamodb:UpdateTable",
                "dynamodb:UpdateContinuousBackups",
                "dynamodb:GetRecords"
            ],
            "Resource": [
                "arn:aws:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/${var.cluster_name}-teleport-state",
                "arn:aws:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/${var.cluster_name}-teleport-state/stream/*"
            ]
        },
        {
            "Sid": "ClusterEventsStorage",
            "Effect": "Allow",
            "Action": [
                "dynamodb:CreateTable",
                "dynamodb:BatchWriteItem",
                "dynamodb:UpdateTimeToLive",
                "dynamodb:PutItem",
                "dynamodb:DescribeTable",
                "dynamodb:DeleteItem",
                "dynamodb:GetItem",
                "dynamodb:Scan",
                "dynamodb:Query",
                "dynamodb:UpdateItem",
                "dynamodb:DescribeTimeToLive",
                "dynamodb:UpdateContinuousBackups",
                "dynamodb:UpdateTable"
            ],
            "Resource": [
                "arn:aws:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/${var.cluster_name}-teleport-events",
                "arn:aws:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/${var.cluster_name}-teleport-events/index/*"
            ]
        },
        {
            "Sid": "ClusterSessionsStorage",
            "Effect": "Allow",
            "Action": [
                "s3:PutEncryptionConfiguration",
                "s3:PutObject",
                "s3:GetObject",
                "s3:GetEncryptionConfiguration",
                "s3:GetObjectRetention",
                "s3:ListBucketVersions",
                "s3:CreateBucket",
                "s3:ListBucket",
                "s3:GetBucketVersioning",
                "s3:PutBucketVersioning",
                "s3:GetObjectVersion"
            ],
            "Resource": [
                "arn:aws:s3:::${var.cluster_name}-teleport-sessions/*",
                "arn:aws:s3:::${var.cluster_name}-teleport-sessions"
            ]
        }
    ]
}
EOF
}

# This is so we can allow people to port-forward in only to the git ssh service
# Adapted from https://community.goteleport.com/t/example-kubernetes-k8s-groups-configuration-with-teleport/907
resource "kubernetes_role" "teleport-gitssh" {
  depends_on = [kubernetes_namespace.teleport]
  metadata {
    name      = "teleport-gitssh"
    namespace = "gitlab"
  }

  rule {
    api_groups     = [""]
    resources      = ["services"]
    resource_names = ["gitlab-gitlab-shell"]
    verbs          = ["get", "list"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods/portforward"]
    verbs      = ["create"]
  }
}

resource "kubernetes_role_binding" "teleport-gitssh" {
  depends_on = [kubernetes_namespace.teleport]
  metadata {
    name      = "teleport-gitssh"
    namespace = "gitlab"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "teleport-gitssh"
  }
  subject {
    kind      = "Group"
    name      = "teleport-gitssh"
    api_group = "rbac.authorization.k8s.io"
    namespace = "teleport"
  }
}
