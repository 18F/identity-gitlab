
resource "kubernetes_namespace" "gitlab" {
  metadata {
    name = "gitlab"
  }
}

data "kubernetes_service" "gitlab-nginx-ingress-controller" {
  depends_on = [aws_db_instance.gitlab]
  metadata {
    name      = "gitlab-nginx-ingress-controller"
    namespace = "gitlab"
  }
}

resource "aws_route53_record" "gitlab" {
  zone_id = data.aws_route53_zone.gitlab.zone_id
  name    = "gitlab-${var.cluster_name}"
  type    = "CNAME"
  ttl     = "300"
  records = [data.kubernetes_service.gitlab-nginx-ingress-controller.status.0.load_balancer.0.ingress.0.hostname]
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
    "domain"                   = var.domain,
    "certmanager-issuer-email" = var.certmanager-issuer
    "pghost"                   = aws_db_instance.gitlab.address
    "pgport"                   = aws_db_instance.gitlab.port
    "redishost"                = aws_elasticache_replication_group.gitlab.primary_endpoint_address
    "redisport"                = var.redis_port
    "ingress-security-groups"  = aws_security_group.gitlab-ingress.id
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
  depends_on = [kubernetes_namespace.teleport]
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

data "aws_ip_ranges" "ec2" {
  regions  = [var.region]
  services = ["ec2"]
}

resource "aws_security_group" "gitlab-ingress" {
  name        = "${var.cluster_name}-gitlab-ingress"
  description = "security group attached to gitlab ingress for ${var.cluster_name}"
  vpc_id      = aws_vpc.eks.id

  # allow ec2 hosts from our region in
  # XXX eventually, once the networkfw gets put in, we will scrape the NAT gateways and put those in.
  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = data.aws_ip_ranges.ec2.cidr_blocks
    ipv6_cidr_blocks = data.aws_ip_ranges.ec2.ipv6_cidr_blocks
  }

  # allow kubernetes port-forward in to git-ssh
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.eks.vpc_config[0].cluster_security_group_id]
  }

  # Allow the gitlab app to access itself over the ingress
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks     = [var.vpc_cidr]
  }

  tags = {
    Name = "${var.cluster_name}-gitlab-ingress"
  }
}
