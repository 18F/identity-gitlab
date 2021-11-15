
resource "aws_iam_role_policy" "efs-csi" {
  name = "${var.cluster_name}_AmazonEKS_EFS_CSI_Driver_Policy"
  role = aws_iam_role.efs-csi.id

  # This came from curl -o iam-policy-example.json https://raw.githubusercontent.com/kubernetes-sigs/aws-efs-csi-driver/v1.3.2/docs/iam-policy-example.json
  # which came from https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "elasticfilesystem:DescribeAccessPoints",
        "elasticfilesystem:DescribeFileSystems"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticfilesystem:CreateAccessPoint"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "aws:RequestTag/efs.csi.aws.com/cluster": "true"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": "elasticfilesystem:DeleteAccessPoint",
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:ResourceTag/efs.csi.aws.com/cluster": "true"
        }
      }
    }
  ]
}
EOF
}

# This is kinda magic that I stole from an existing eksctl cluster
resource "aws_iam_role" "efs-csi" {
  name               = "${var.cluster_name}-efs-csi"
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
        "StringEquals": {
          "${aws_iam_openid_connect_provider.eks.url}:sub": "system:serviceaccount:kube-system:efs-csi-controller-sa",
          "${aws_iam_openid_connect_provider.eks.url}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
POLICY
}

resource "kubernetes_service_account" "efs-csi" {
  metadata {
    name      = "efs-csi-controller-sa"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.efs-csi.arn
    }
  }
}
