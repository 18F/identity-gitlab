resource "aws_iam_role_policy" "gitlab-ses-email" {
  name   = "${var.cluster_name}-gitlab-ses-email"
  role       = aws_iam_role.gitlab-ses.name
  policy = data.aws_iam_policy_document.ses_email_role_policy.json
}

# XXX This is wrong, used as an example. Reviewer: what is right?
resource "aws_iam_role" "gitlab-ses" {
  name = "${var.cluster_name}-gitlab-ses-role"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

data "aws_iam_policy_document" "ses_email_role_policy" {
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
  domain = "gitlab.identitysandbox.com"
}

resource "aws_route53_record" "gitlab_amazonses_verification_record" {
  zone_id = data.aws_route53_zone.gitlab.zone_id
  name    = "_amazonses.gitlab.identitysandbox.gov"
  type    = "TXT"
  ttl     = "600"
  records = [aws_ses_domain_identity.gitlab.verification_token]
}

resource "aws_ses_domain_dkim" "gitlab" {
  domain = aws_ses_domain_identity.gitlab.domain
}

resource "aws_route53_record" "example_amazonses_dkim_record" {
  count   = 3
  zone_id = data.aws_route53_zone.gitlab.zone_id
  name    = "${element(aws_ses_domain_dkim.gitlab.dkim_tokens, count.index)}._domainkey"
  type    = "CNAME"
  ttl     = "600"
  records = ["${element(aws_ses_domain_dkim.gitlab.dkim_tokens, count.index)}.dkim.amazonses.com"]
}
