
resource "kubernetes_namespace" "gitlab" {
  depends_on = [aws_eks_node_group.eks]
  metadata {
    name = "gitlab"
  }
}

# This configmap is where we can pass stuff into flux/helm from terraform
resource "kubernetes_config_map" "terraform-gitlab-info" {
  depends_on = [kubernetes_namespace.gitlab]
  metadata {
    name      = "terraform-gitlab-info"
    namespace = "gitlab"
  }

  data = {
    "cluster_name"             = var.cluster_name,
    "region"                   = var.region,
    "domain"                   = var.domain,
    "certmanager-issuer-email" = var.certmanager-issuer
    "pghost"                   = aws_db_instance.gitlab.address
    "pgport"                   = aws_db_instance.gitlab.port
    "redishost"                = aws_elasticache_replication_group.gitlab.primary_endpoint_address
    "redisport"                = var.redis_port
    "ingress-security-groups"  = aws_security_group.gitlab-ingress.id
    "gitlab_name"              = "gitlab.teleport-${var.cluster_name}.${var.domain}"
    "fullhostname"             = "gitlab-${var.cluster_name}.${var.domain}"
    "ci_server_url"            = "https://gitlab-${var.cluster_name}.${var.domain}"
    "cert-arn"                 = aws_acm_certificate.gitlab.arn
    "email-from"               = "gitlab@${var.cluster_name}.${var.domain}"
    "smtp-endpoint"            = "email-smtp.${var.region}.amazonaws.com"
    "email-domain"             = "${var.cluster_name}.${var.domain}"
    "smtp-username"            = aws_iam_access_key.gitlab-ses.id
    "runner-iam-role"          = aws_iam_role.gitlab-runner.arn
    "storage-iam-role"         = aws_iam_role.storage-iam-role.arn
    "registry-bucket"          = "${var.cluster_name}-registry"
    "lfs-bucket"               = "${var.cluster_name}-lfs"
    "artifacts-bucket"         = "${var.cluster_name}-artifacts"
    "uploads-bucket"           = "${var.cluster_name}-uploads"
    "packages-bucket"          = "${var.cluster_name}-packages"
    "backups-bucket"           = "${var.cluster_name}-backups"
    "runner-bucket"            = "${var.cluster_name}-runner"
  }
}

# This is actually created by the deploy script so that
# it is available when we do tf, but not stored in the state.
data "aws_secretsmanager_secret_version" "rds-pw-gitlab" {
  secret_id = "${var.cluster_name}-rds-pw-gitlab"
}
data "aws_secretsmanager_secret_version" "redis-pw-gitlab" {
  secret_id = "${var.cluster_name}-redis-pw-gitlab"
}

# SSO secrets
data "aws_secretsmanager_secret_version" "oidc-github-app-id" {
  secret_id = "${var.cluster_name}-oidc-github-app-id" 
}
data "aws_secretsmanager_secret_version" "oidc-github-app-secret" {
  secret_id = "${var.cluster_name}-oidc-github-app-secret" 
}
resource "kubernetes_secret" "gitlab-github-auth" {
  depends_on = [kubernetes_namespace.gitlab]
  metadata {
    name      = "gitlab-github-auth"
    namespace = "gitlab"
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes to labels, e.g. because helm adds stuff.
      metadata.0.labels,
    ]
  }

  data = {
    provider = jsonencode(
      {
        name       = "github"
        app_id     = data.aws_secretsmanager_secret_version.oidc-github-app-id.secret_string
        app_secret = data.aws_secretsmanager_secret_version.oidc-github-app-secret.secret_string
        args       = {
          scope = "user:email"
        }
      }
    )
  }
}

# This tells the storage stuff to use IAM roles for auth
resource "kubernetes_secret" "gitlab-storage" {
  depends_on = [kubernetes_namespace.gitlab]
  metadata {
    name      = "gitlab-storage"
    namespace = "gitlab"
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes to labels, e.g. because helm adds stuff.
      metadata.0.labels,
    ]
  }

  data = {
    connection = jsonencode(
      {
        provider = "AWS"
        region   = var.region
      }
    )
  }
}

# XXX according to
# https://blog.gruntwork.io/a-comprehensive-guide-to-managing-secrets-in-your-terraform-code-1d586955ace1,
# this is a good way to store secrets.  I am suspicious that there
# is still stuff stored in the tf state that, even if encrypted, could
# be dangerous.  If we want to go the extra mile, we can turn on the
# secrets-store-csi and set up secret syncing so that there is no
# suspicion of this, but that would add a fair amount of complexity that the gruntwork
# article seems to say that we don't need to worry about, so for
# now, we are going to go with their recommendation.
resource "kubernetes_secret" "rds-pw-gitlab" {
  depends_on = [kubernetes_namespace.gitlab]
  metadata {
    name      = "rds-pw-gitlab"
    namespace = "gitlab"
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes to labels, e.g. because helm adds stuff.
      metadata.0.labels,
    ]
  }

  data = {
    password = data.aws_secretsmanager_secret_version.rds-pw-gitlab.secret_string
    redispw  = data.aws_secretsmanager_secret_version.redis-pw-gitlab.secret_string
  }
}

resource "aws_db_subnet_group" "gitlab" {
  description = "${var.cluster_name} subnet group for gitlab"
  name        = "${var.cluster_name}-db-gitlab"
  subnet_ids  = aws_subnet.service.*.id

  tags = {
    Name = "${var.cluster_name}-db-gitlab"
  }
}

resource "aws_db_instance" "gitlab" {
  allocated_storage       = 8
  max_allocated_storage   = 100
  engine                  = "postgres"
  engine_version          = "13.2"
  instance_class          = "db.t3.large"
  name                    = "gitlabhq_production"
  username                = "gitlab"
  password                = data.aws_secretsmanager_secret_version.rds-pw-gitlab.secret_string
  parameter_group_name    = aws_db_parameter_group.force_ssl.id
  skip_final_snapshot     = true
  multi_az                = true
  storage_encrypted       = true
  vpc_security_group_ids  = [aws_security_group.gitlab-db.id]
  backup_retention_period = var.rds_backup_retention_period
  backup_window           = var.rds_backup_window
  db_subnet_group_name    = aws_db_subnet_group.gitlab.id

  tags = {
    Name = "${var.cluster_name}-db-gitlab"
  }
}

resource "aws_db_parameter_group" "force_ssl" {
  name_prefix = "${var.cluster_name}-gitlab"

  # Before changing this value, make sure the parameters are correct for the
  # version you are upgrading to.  See
  # http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_WorkingWithParamGroups.html.
  family = "postgres13"

  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }

  # Setting to 30 minutes, RDS requires value in ms
  # https://aws.amazon.com/blogs/database/best-practices-for-amazon-rds-postgresql-replication/
  parameter {
    name  = "max_standby_archive_delay"
    value = "1800000"
  }

  # Setting to 30 minutes, RDS requires value in ms
  # https://aws.amazon.com/blogs/database/best-practices-for-amazon-rds-postgresql-replication/
  parameter {
    name  = "max_standby_streaming_delay"
    value = "1800000"
  }

  # Log all Data Definition Layer changes (ALTER, CREATE, etc.)
  parameter {
    name  = "log_statement"
    value = "ddl"
  }

  # Log all slow queries that take longer than specified time in ms
  parameter {
    name  = "log_min_duration_statement"
    value = "250" # 250 ms
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "gitlab-db" {
  name        = "${var.cluster_name}-gitlab-db"
  description = "gitlab db for ${var.cluster_name}"
  vpc_id      = aws_vpc.eks.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.eks.vpc_config[0].cluster_security_group_id]
  }

  tags = {
    Name = "${var.cluster_name}-gitlab-db"
  }
}

resource "aws_elasticache_replication_group" "gitlab" {
  automatic_failover_enabled    = true
  availability_zones            = [data.aws_availability_zones.available.names.0, data.aws_availability_zones.available.names.1]
  replication_group_id          = "${var.cluster_name}-gitlab"
  replication_group_description = "${var.cluster_name} redis for gitlab"
  node_type                     = "cache.m4.large"
  number_cache_clusters         = 2
  parameter_group_name          = "default.redis6.x"
  port                          = var.redis_port
  subnet_group_name             = aws_elasticache_subnet_group.gitlab.id
  security_group_ids            = [aws_security_group.gitlab-redis.id]
  snapshot_retention_limit      = 30
  at_rest_encryption_enabled    = true
  transit_encryption_enabled    = true
  auth_token                    = data.aws_secretsmanager_secret_version.redis-pw-gitlab.secret_string

  tags = {
    Name = "${var.cluster_name}-gitlab-redis"
  }
}

resource "aws_elasticache_subnet_group" "gitlab" {
  description = "${var.cluster_name} redis subnet group for gitlab"
  name        = "${var.cluster_name}-redis-gitlab"
  subnet_ids  = aws_subnet.service.*.id

  tags = {
    Name = "${var.cluster_name}-redis-gitlab"
  }
}

resource "aws_security_group" "gitlab-redis" {
  name        = "${var.cluster_name}-gitlab-redis"
  description = "gitlab redis for ${var.cluster_name}"
  vpc_id      = aws_vpc.eks.id

  ingress {
    from_port       = var.redis_port
    to_port         = var.redis_port
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.eks.vpc_config[0].cluster_security_group_id]
  }

  tags = {
    Name = "${var.cluster_name}-gitlab-redis"
  }
}

locals {
  nat_cidrs = formatlist("%s/32", aws_nat_gateway.nat.*.public_ip)
}

resource "aws_security_group" "gitlab-ingress" {
  name        = "${var.cluster_name}-gitlab-ingress"
  description = "security group attached to gitlab ingress for ${var.cluster_name}"
  vpc_id      = aws_vpc.eks.id

  # allow kubernetes port-forward in to git-ssh
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.eks.vpc_config[0].cluster_security_group_id]
  }

  # this allows the gitlab runners to register with gitlab
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = local.nat_cidrs
  }

  # this allows the gitlab runners to git pull
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = local.nat_cidrs
  }

  tags = {
    Name = "${var.cluster_name}-gitlab-ingress"
  }
}

# cert for gitlab, attached to the network lb
resource "aws_acm_certificate" "gitlab" {
  domain_name       = "gitlab-${var.cluster_name}.${var.domain}"
  validation_method = "DNS"

  tags = {
    Name = "gitlab-${var.cluster_name}.${var.domain}"
  }
}

resource "aws_route53_record" "gitlab-validation" {
  for_each = {
    for dvo in aws_acm_certificate.gitlab.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.gitlab.zone_id
}

resource "aws_acm_certificate_validation" "gitlab" {
  certificate_arn         = aws_acm_certificate.gitlab.arn
  validation_record_fqdns = [for record in aws_route53_record.gitlab-validation : record.fqdn]
}

resource "aws_route53_record" "gitlab" {
  count   = var.bootstrap ? 0 : 1
  zone_id = data.aws_route53_zone.gitlab.zone_id
  name    = "gitlab-${var.cluster_name}"
  type    = "CNAME"
  ttl     = "300"
  records = [data.kubernetes_service.gitlab-nginx-ingress-controller.status.0.load_balancer.0.ingress.0.hostname]
}

data "kubernetes_service" "gitlab-nginx-ingress-controller" {
  depends_on = [aws_db_instance.gitlab]
  metadata {
    name      = "gitlab-nginx-ingress-controller"
    namespace = "gitlab"
  }
}

# until https://github.com/hashicorp/terraform-provider-aws/issues/12265 gets solved:
data "aws_lb" "gitlab" {
  count = var.bootstrap ? 0 : 1
  name  = regex("^(?P<name>.+)-.+\\.elb\\..+\\.amazonaws\\.com", data.kubernetes_service.gitlab-nginx-ingress-controller.status.0.load_balancer.0.ingress.0.hostname)["name"]
}

locals {
  fulladmins   = formatlist("arn:aws:iam::%s:role/FullAdministrator", var.accountids)
  autotfs      = formatlist("arn:aws:iam::%s:role/AutoTerraform", var.accountids)
  terraformers = formatlist("arn:aws:iam::%s:role/Terraform", var.accountids)
  principals   = concat(local.fulladmins, local.autotfs, local.terraformers)
}

# VPC endpoint service so that we can set up VPC endpoints that go to this
resource "aws_vpc_endpoint_service" "gitlab" {
  count                      = var.bootstrap ? 0 : 1
  acceptance_required        = false
  allowed_principals         = local.principals
  network_load_balancer_arns = [data.aws_lb.gitlab.0.arn]

  tags = {
    Name = "gitlab-${var.cluster_name}.${var.domain}"
  }
}

# This role is assigned with IRSA to the gitlab runner.
# You can attach policies to this to give the runner MOAR POWAH!
resource "aws_iam_role" "gitlab-runner" {
  name               = "${var.cluster_name}-gitlab-runner"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "allowRunnerServiceAccount",
      "Effect": "Allow",
      "Principal": {
        "Federated": "${aws_iam_openid_connect_provider.eks.arn}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "ForAnyValue:StringEquals": {
          "${aws_iam_openid_connect_provider.eks.url}:sub": [
            "system:serviceaccount:gitlab:gitlab-gitlab-runner"
          ]
        }
      }
    },
    {
      "Sid": "AllowAdmins",
      "Effect": "Allow",
      "Principal": {
          "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/AutoTerraform",
          "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/FullAdministrator"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy" "gitlab-runner" {
  name = "${var.cluster_name}-gitlab-runner"
  role = aws_iam_role.gitlab-runner.id

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "GitlabRunners",
            "Effect": "Allow",
            "Resource": "*",
            "Action": [
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:BatchCheckLayerAvailability",
                "ecr:PutImage",
                "ecr:GetAuthorizationToken",
                "ecr:CreateRepository",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload",
                "ecr:DescribeRepositories",
                "ecr:GetRepositoryPolicy",
                "ecr:ListImages"
            ]
        },
        {
            "Sid": "S3",
            "Effect": "Allow",
            "Resource": [
              "arn:aws:s3:::${var.cluster_name}_runner/*",
              "arn:aws:s3:::${var.cluster_name}_runner/"
            ],
            "Action": [
                "s3:*"
            ]
        }
    ]
}
EOF
}


# This role is assigned with IRSA to a bunch of things.
resource "aws_iam_role" "storage-iam-role" {
  name               = "${var.cluster_name}-storage-iam-role"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "allowS3",
      "Effect": "Allow",
      "Principal": {
        "Federated": "${aws_iam_openid_connect_provider.eks.arn}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "ForAnyValue:StringEquals": {
          "${aws_iam_openid_connect_provider.eks.url}:sub": [
            "system:serviceaccount:gitlab:gitlab-gitlab-runner"
          ]
        }
      }
    },
    {
      "Sid": "AllowAdmins",
      "Effect": "Allow",
      "Principal": {
          "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/AutoTerraform",
          "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/FullAdministrator"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy" "storage-iam-role" {
  name = "${var.cluster_name}-storage-iam-role"
  role = aws_iam_role.storage-iam-role.id

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "S3",
            "Effect": "Allow",
            "Resource": [
              "arn:aws:s3:::${var.cluster_name}-registry/*",
              "arn:aws:s3:::${var.cluster_name}-registry/",
              "arn:aws:s3:::${var.cluster_name}-lfs/*",
              "arn:aws:s3:::${var.cluster_name}-lfs/",
              "arn:aws:s3:::${var.cluster_name}-artifacts/*",
              "arn:aws:s3:::${var.cluster_name}-artifacts/",
              "arn:aws:s3:::${var.cluster_name}-uploads/*",
              "arn:aws:s3:::${var.cluster_name}-uploads/",
              "arn:aws:s3:::${var.cluster_name}-packages/*",
              "arn:aws:s3:::${var.cluster_name}-packages/",
              "arn:aws:s3:::${var.cluster_name}-backups/*",
              "arn:aws:s3:::${var.cluster_name}-backups/"
            ],
            "Action": [
                "s3:*"
            ]
        }
    ]
}
EOF
}

locals {
  buckets = [
    "${var.cluster_name}-registry",
    "${var.cluster_name}-lfs",
    "${var.cluster_name}-artifacts",
    "${var.cluster_name}-uploads",
    "${var.cluster_name}-packages",
    "${var.cluster_name}-backups",
    "${var.cluster_name}-runner"
  ]
}

# s3 buckets used for various components of gitlab
resource "aws_s3_bucket" "gitlab_bucket" {
  count = length(local.buckets)
  bucket = local.buckets[count.index]

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}
