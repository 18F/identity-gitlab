
resource "aws_ecr_repository" "gitlab" {
  name                 = "gitlab-${var.cluster_name}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "gitlab-${var.cluster_name}"
  }
}

# This is used to limit access to our gitlab ECR instance.
resource "aws_ecr_repository_policy" "gitlab" {
  repository = aws_ecr_repository.gitlab.name

  policy = <<EOF
{
    "Version": "2008-10-17",
    "Statement": [
        {
            "Sid": "Allow gitlab runners to read/pull/push",
            "Effect": "Allow",
            "Principal": "${aws_iam_role.gitlab-runner.arn}",
            "Action": [
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:BatchCheckLayerAvailability",
                "ecr:PutImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload",
                "ecr:DescribeRepositories",
                "ecr:GetRepositoryPolicy",
                "ecr:ListImages"
            ]
        },
        {
            "Sid": "Allow this EKS cluster to read/pull",
            "Effect": "Allow",
            "Principal": "${aws_iam_role.eks-cluster.arn}",
            "Action": [
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:BatchCheckLayerAvailability",
                "ecr:DescribeRepositories",
                "ecr:GetRepositoryPolicy",
                "ecr:ListImages"
            ]
        }
    ]
}
EOF
}
