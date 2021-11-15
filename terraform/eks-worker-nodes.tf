#
# EKS fargate
#  * IAM role allowing Kubernetes actions to access other AWS services
#  * EKS Node Group to launch worker nodes
#
resource "aws_eks_fargate_profile" "eks-system" {
  cluster_name           = aws_eks_cluster.eks.name
  fargate_profile_name   = "${var.cluster_name}-eks-system"
  pod_execution_role_arn = aws_iam_role.fargate.arn
  subnet_ids             = aws_subnet.eks[*].id

  timeouts {
    # For reasons unknown, Fargate profiles can take upward of 20 minutes to
    # delete! I've never seen them go past 30m, though, so this seems OK.
    delete = "30m"
  }

  selector {
    namespace = "amazon-cloudwatch"
  }
  selector {
    namespace = "flux-system"
  }
  selector {
    namespace = "kube-system"
  }
  selector {
    namespace = "kubernetes-dashboard"
  }
}

resource "aws_eks_fargate_profile" "eks" {
  cluster_name           = aws_eks_cluster.eks.name
  fargate_profile_name   = "${var.cluster_name}-eks"
  pod_execution_role_arn = aws_iam_role.fargate.arn
  subnet_ids             = aws_subnet.eks[*].id

  timeouts {
    # For reasons unknown, Fargate profiles can take upward of 20 minutes to
    # delete! I've never seen them go past 30m, though, so this seems OK.
    delete = "30m"
  }

  selector {
    namespace = "default"
  }
  selector {
    namespace = "gitlab"
  }
  selector {
    namespace = "teleport"
  }
}

resource "aws_iam_role" "fargate" {
  name = "${var.cluster_name}-noderole"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks-fargate-pods.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "AmazonEKSFargatePodExecutionRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.fargate.name
}

resource "aws_iam_role_policy_attachment" "eks-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.fargate.name
}

resource "aws_iam_role_policy" "ebs_csi_driver" {
  name = "${var.cluster_name}_ebs_csi_driver"
  role = aws_iam_role.fargate.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:AttachVolume",
        "ec2:CreateSnapshot",
        "ec2:CreateTags",
        "ec2:CreateVolume",
        "ec2:DeleteSnapshot",
        "ec2:DeleteTags",
        "ec2:DeleteVolume",
        "ec2:DescribeInstances",
        "ec2:DescribeSnapshots",
        "ec2:DescribeTags",
        "ec2:DescribeVolumes",
        "ec2:DetachVolume"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

# This gives perms to stuff that runs in our pods
# These are global.  You probably want to grant more specific policies with IRSA.
resource "aws_iam_role_policy" "workers" {
  name = "${var.cluster_name}_workers"
  role = aws_iam_role.fargate.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "es:ESHttp*",
      "Resource": "arn:aws:es:${var.region}:${data.aws_caller_identity.current.account_id}:domain/${var.cluster_name}/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeAutoScalingInstances",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:DescribeTags",
        "autoscaling:SetDesiredCapacity",
        "ec2:DescribeLaunchTemplateVersions",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}
