resource "aws_iam_user_policy" "gitlab-ses-email" {
  name   = "${var.cluster_name}-gitlab-ses-email"
  user   = aws_iam_user.gitlab-ses.name
  policy = data.aws_iam_policy_document.ses_email_user_policy.json
}

resource "aws_iam_user" "gitlab-ses" {
  name = "${var.cluster_name}-gitlab-ses"
}

data "aws_iam_policy_document" "ses_email_user_policy" {
  statement {
    sid    = "AllowSendEmail"
    effect = "Allow"
    actions = [
      "ses:SendRawEmail",
      "ses:SendEmail",
    ]
    resources = [
      "*",
    ]
  }
}

resource "aws_ses_domain_identity" "gitlab" {
  domain = "${var.cluster_name}.${var.domain}"
}

resource "aws_route53_record" "gitlab_amazonses_verification_record" {
  zone_id = data.aws_route53_zone.gitlab.zone_id
  name    = "_amazonses.${var.cluster_name}.${var.domain}"
  type    = "TXT"
  ttl     = "600"
  records = [aws_ses_domain_identity.gitlab.verification_token]
}

resource "aws_ses_domain_dkim" "gitlab" {
  domain = aws_ses_domain_identity.gitlab.domain
}

resource "aws_route53_record" "gitlab_amazonses_dkim_record" {
  count   = 3
  zone_id = data.aws_route53_zone.gitlab.zone_id
  name    = "${element(aws_ses_domain_dkim.gitlab.dkim_tokens, count.index)}._domainkey"
  type    = "CNAME"
  ttl     = "600"
  records = ["${element(aws_ses_domain_dkim.gitlab.dkim_tokens, count.index)}.dkim.amazonses.com"]
}
