# map SSM policy and role to ssm serviceaccount

resource "kubernetes_namespace" "ssm" {
  metadata {
    name = "ssm"
  }
}

resource "kubernetes_service_account" "ssm" {
  metadata {
    name = "ssm"
    namespace = "ssm"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.ssm.arn
    }
  }
}

resource "aws_iam_role" "ssm" {
  name               = "${var.cluster_name}-ssm"
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
          "${var.oidc_url}:sub": "system:serviceaccount:ssm:ssm"
        }
      }
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "AmazonSSMManagedInstanceCore" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.ssm.name
}
