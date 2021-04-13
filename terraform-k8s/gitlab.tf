
resource "kubernetes_namespace" "gitlab" {
  metadata {
    name = "gitlab"
  }
}

resource "helm_release" "gitlab" {
  name       = "gitlab"
  repository = "https://charts.gitlab.io/"
  chart      = "gitlab"
  version    = "4.10.2"
  namespace  = "gitlab"
  depends_on = [kubernetes_namespace.gitlab, helm_release.alb-ingress-controller]

  set {
    name  = "global.hosts.hostSuffix"
    value = var.cluster_name
  }

  set {
    name  = "global.hosts.domain"
    value = var.domain
  }

  # we are using teleport to get into the GUI, so don't expose it.
  # XXX probably will need to turn this off for git ssh
  set {
    name  = "global.ingress.enabled"
    value = false
  }

  set {
    name  = "certmanager-issuer.email"
    value = var.certmanager-issuer
  }
}

resource "aws_db_subnet_group" "services" {
  name       = "services"
  subnet_ids = aws_subnet.services.*.id

  tags = {
    Name = "${var.cluster_name}-services"
  }
}

resource "aws_db_parameter_group" "force_ssl" {
  name_prefix = "services"

  # Before changing this value, make sure the parameters are correct for the
  # version you are upgrading to.  See
  # http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_WorkingWithParamGroups.html.
  family = "postgres12"

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

  tags = {
    Name = "${var.cluster_name}-gitlab"
  }
}

resource "aws_db_instance" "gitlab" {
  allocated_storage       = 100
  backup_retention_period = 31
  db_subnet_group_name    = aws_db_subnet_group.services.id
  engine                  = "postgres"
  engine_version          = "12.6"
  identifier              = "gitlab"
  instance_class          = "db.t3.medium"
  multi_az                = true
  parameter_group_name    = aws_db_parameter_group.force_ssl.name
  password                = var.rds_password # change this by hand after creation
  storage_encrypted       = true
  username                = var.rds_username

  # we want to push these via Terraform now
  auto_minor_version_upgrade  = true
  allow_major_version_upgrade = true
  apply_immediately           = true

  tags = {
    Name = "${var.cluster_name}-gitlab"
  }

  # enhanced monitoring
  monitoring_interval = 60
  monitoring_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.rds_monitoring_role_name}"

  vpc_security_group_ids = [aws_security_group.db.id]

  # send logs to cloudwatch
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # If you want to destroy your database, you need to do this in two phases:
  # 1. Uncomment `skip_final_snapshot=true` and
  #    comment `prevent_destroy=true` and `deletion_protection = true` below.
  # 2. Perform a terraform/deploy "apply" with the additional
  #    argument of "-target=aws_db_instance.idp" to mark the database
  #    as not requiring a final snapshot.
  # 3. Perform a terraform/deploy "destroy" as needed.
  #
  #skip_final_snapshot = true
  lifecycle {
    prevent_destroy = true

    # we set the password by hand so it doesn't end up in the state file
    ignore_changes = [password]
  }

  deletion_protection = true
}

output "gitlab_db_endpoint" {
  value = aws_db_instance.gitlab.endpoint
}
