resource "aws_security_group" "db" {
  description = "Allow inbound and outbound postgresql traffic with app subnet in vpc"

  egress = []

  ingress {
    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"
    security_groups = [
      aws_security_group.gitlab.id,
    ]
  }

  name = "gitlab-db-${var.cluster_name}"

  tags = {
    Name = "gitlab-${var.cluster_name}"
  }

  vpc_id = aws_vpc.eks.id
}


