
resource "kubernetes_namespace" "dex" {
  depends_on = [aws_eks_node_group.eks]
  metadata {
    name = "dex"
  }
}

locals {
  dexhostname  = "dex-${var.cluster_name}.${var.domain}"
  pivproxyname = "pivproxy-${var.cluster_name}.${var.domain}"
}

resource "kubernetes_config_map" "pivproxy-config" {
  depends_on = [kubernetes_namespace.dex]
  metadata {
    name      = "pivproxy-config"
    namespace = "dex"
  }

  data = {
    "dex_hostname"  = local.dexhostname
    "callback_url"  = "https://${local.dexhostname}/dex/callback/piv"
    "dex_url"       = "https://${local.dexhostname}"
    "uid_list"      = join(", ", formatlist("\"%s\"", var.uid_list))
    "cert-arn"      = aws_acm_certificate.dex.arn
    "pivproxy_name" = local.pivproxyname
    "pivproxy-cert-arn"      = aws_acm_certificate.pivproxy.arn
  }
}

# cert for dex, attached to the network lb
resource "aws_acm_certificate" "dex" {
  domain_name       = local.dexhostname
  validation_method = "DNS"

  tags = {
    Name = local.dexhostname
  }
}

resource "aws_route53_record" "dex-validation" {
  for_each = {
    for dvo in aws_acm_certificate.dex.domain_validation_options : dvo.domain_name => {
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

resource "aws_acm_certificate_validation" "dex" {
  certificate_arn         = aws_acm_certificate.dex.arn
  validation_record_fqdns = [for record in aws_route53_record.dex-validation : record.fqdn]
}

# cert for pivproxy, attached to the network lb
resource "aws_acm_certificate" "pivproxy" {
  domain_name       = local.pivproxyname
  validation_method = "DNS"

  tags = {
    Name = local.pivproxyname
  }
}

resource "aws_route53_record" "pivproxy-validation" {
  for_each = {
    for dvo in aws_acm_certificate.pivproxy.domain_validation_options : dvo.domain_name => {
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

resource "aws_acm_certificate_validation" "pivproxy" {
  certificate_arn         = aws_acm_certificate.pivproxy.arn
  validation_record_fqdns = [for record in aws_route53_record.pivproxy-validation : record.fqdn]
}
