# This is the one and only place we should be configuring this for this cluster.

resource "kubectl_manifest" "aws-auth" {
  yaml_body = templatefile(
    "${path.module}/aws-auth.yaml.tpl",
    {
      accountid = data.aws_caller_identity.current.account_id,
      clustername = var.cluster_name,
      teleportrolename = "${var.cluster_name}-teleport"
    }
  )
}

resource "aws_iam_role" "teleport" {
  name               = "${var.cluster_name}-teleport"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
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
