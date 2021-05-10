# set things up for the serviceaccount to have proper perms so it can scale stuff.
resource "aws_iam_role" "cluster-autoscaler" {
  name               = "${var.cluster_name}-cluster-autoscaler"
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
            "system:serviceaccount:kube-system:eksclusterautoscaler-aws-cluster-autoscaler"
          ]
        }
      }
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy" "cluster-autoscaler" {
  name = "${var.cluster_name}-cluster-autoscaler-policy"
  role = aws_iam_role.cluster-autoscaler.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:SetDesiredCapacity",
        "autoscaling:TerminateInstanceInAutoScalingGroup"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/enabled": "true",
          "autoscaling:ResourceTag/kubernetes.io/cluster/${var.cluster_name}": "owned"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeAutoScalingInstances",
        "autoscaling:DescribeTags",
        "autoscaling:DescribeLaunchConfigurations",
        "ec2:DescribeLaunchTemplateVersions"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}
