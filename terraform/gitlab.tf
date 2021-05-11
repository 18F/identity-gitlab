
resource "kubernetes_namespace" "gitlab" {
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
    "domain"                   = var.domain,
    "certmanager-issuer-email" = var.certmanager-issuer
  }
}

# This is actually created by the deploy script so that
# it is available when we do tf, but not stored in the state.
data "aws_secretsmanager_secret_version" "rds-pw-gitlab" {
  secret_id = "${var.cluster_name}-rds-pw-gitlab"
}

resource "kubernetes_secret" "rds-pw-gitlab" {
  depends_on = [kubernetes_namespace.teleport]
  metadata {
    name      = "rds-pw-gitlab"
    namespace = "gitlab"
  }

  data = {
    password = data.aws_secretsmanager_secret_version.rds-pw-gitlab.secret_string
  }
}

resource "aws_db_subnet_group" "gitlab" {
  description = "${var.cluster_name} subnet group for gitlab"
  name        = "${var.cluster_name}-db-gitlab"
  subnet_ids  = aws_subnet.db.*.id

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
  backup_retention_period = var.rds_backup_retention_period
  backup_window           = var.rds_backup_window
  db_subnet_group_name    = aws_db_subnet_group.gitlab.id
}

resource "aws_db_parameter_group" "force_ssl" {
  name_prefix = "gitlab"

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
