#
# EKS Cluster Resources
#  * IAM Role to allow EKS service to manage other AWS services
#  * EC2 Security Group to allow networking traffic with EKS cluster
#  * EKS Cluster
#

resource "aws_cloudwatch_log_group" "eks" {
  # The log group name format is /aws/eks/<cluster-name>/cluster
  # Reference: https://docs.aws.amazon.com/eks/latest/userguide/control-plane-logs.html
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 365
}

resource "aws_eks_cluster" "eks" {
  name                      = var.cluster_name
  role_arn                  = aws_iam_role.eks-cluster.arn
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  vpc_config {
    security_group_ids      = [aws_security_group.eks-cluster.id]
    subnet_ids              = aws_subnet.eks[*].id
    endpoint_public_access  = var.k8s_public_api
    endpoint_private_access = true
  }

  lifecycle {
    #prevent_destroy = true
  }

  version = "1.20"

  depends_on = [
    aws_iam_role_policy_attachment.eks-cluster-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks-cluster-AmazonEKSServicePolicy,
    aws_cloudwatch_log_group.eks,
  ]
}

# XXX Such a terrible hack:  https://github.com/hashicorp/terraform-provider-aws/issues/10104
data "external" "thumbprint" {
  program = ["${path.module}/oidc-thumbprint.sh", var.region]
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.external.thumbprint.result.thumbprint]
  url             = aws_eks_cluster.eks.identity.0.oidc.0.issuer
}

resource "aws_iam_role" "eks-cluster" {
  name = "${var.cluster_name}-role"

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

resource "aws_iam_role_policy_attachment" "eks-cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks-cluster.name
}

resource "aws_iam_role_policy_attachment" "eks-cluster-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks-cluster.name
}

resource "aws_security_group" "eks-cluster" {
  name        = "${var.cluster_name}-eks-cluster"
  description = "Cluster communication with worker nodes for ${var.cluster_name}"
  vpc_id      = aws_vpc.eks.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-eks-cluster"
  }
}

# map IAM roles to users/groups here, so you can apply RBAC and allow
# things to access resources in the cluster.
resource "kubectl_manifest" "aws-auth" {
  depends_on = [aws_eks_cluster.eks]
  yaml_body  = <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - groups:
      - system:bootstrappers
      - system:nodes
      - system:node-proxier
      rolearn: arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.cluster_name}-noderole
      username: system:node:{{SessionName}}
  mapUsers: |
    - userarn: arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/AutoTerraform
      username: terraform
      groups:
        - system:masters
EOF
}
