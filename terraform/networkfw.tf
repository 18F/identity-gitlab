locals {
  yaml_data  = yamldecode(file("${path.module}/validdomain.yaml"))
  domainlist = concat(local.yaml_data.domainAllowList, [".${var.domain}"])
}

resource "aws_networkfirewall_rule_group" "networkfw" {
  capacity    = 100
  description = "Permits TLS traffic to selected endpoints"
  name        = "${var.cluster_name}-gitlab-networkfw"
  type        = "STATEFUL"
  rule_group {
    rules_source {
      rules_source_list {
        generated_rules_type = "ALLOWLIST"
        target_types         = ["HTTP_HOST", "TLS_SNI"]
        targets              = local.domainlist
      }
    }
  }

  tags = {
    Name = "${var.cluster_name}-gitlab permit TLS to selected endpoints"
  }
}

resource "aws_networkfirewall_firewall_policy" "networkfw" {
  name = "${var.cluster_name}-gitlab-networkfw"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]
    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.networkfw.arn
    }
  }

  tags = {
    Name = "${var.cluster_name}-gitlab Network firewall rules"
  }
}

resource "aws_networkfirewall_firewall" "networkfw" {
  name                = "${var.cluster_name}-gitlab-networkfw"
  description         = "Network Firewall for ${var.cluster_name}-gitlab"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.networkfw.arn
  vpc_id              = aws_vpc.eks.id

  dynamic "subnet_mapping" {
    for_each = aws_subnet.public_eks.*.id
    content {
      subnet_id = subnet_mapping.value
    }
  }

  tags = {
    Name = "Network Firewall for ${var.cluster_name}-gitlab"
  }
}

resource "aws_subnet" "networkfw" {
  count = var.subnet_count

  vpc_id            = aws_vpc.eks.id
  cidr_block        = cidrsubnet(var.fw_cidr, ceil(log(2, var.subnet_count)), count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.cluster_name} firewall ${count.index}"
  }
}

resource "aws_route_table" "networkfw" {
  vpc_id = aws_vpc.eks.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks.id
  }

  tags = {
    Name = "${var.cluster_name} gitlab networkfw"
  }
}

resource "aws_route_table_association" "networkfw" {
  count          = var.subnet_count
  subnet_id      = aws_subnet.networkfw[count.index].id
  route_table_id = aws_route_table.networkfw.id
}

data "aws_vpc_endpoint" "networkfw" {
  count      = var.subnet_count
  depends_on = [aws_networkfirewall_firewall.networkfw]
  vpc_id     = aws_vpc.eks.id
  id         = [for x in aws_networkfirewall_firewall.networkfw.firewall_status.0.sync_states : x.attachment.0.endpoint_id if x.availability_zone == data.aws_availability_zones.available.names[count.index]][0]
}

resource "aws_cloudwatch_log_group" "fw_log_group_alerts" {
  name = "/${var.cluster_name}-gitlab/networkfw_alerts"
}
resource "aws_cloudwatch_log_group" "fw_log_group_flows" {
  name = "/${var.cluster_name}-gitlab/networkfw_flows"
}

resource "aws_networkfirewall_logging_configuration" "networkfw" {
  firewall_arn = aws_networkfirewall_firewall.networkfw.arn
  logging_configuration {
    log_destination_config {
      log_destination = {
        logGroup = "/${var.cluster_name}-gitlab/networkfw_alerts"
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "ALERT"
    }
    log_destination_config {
      log_destination = {
        logGroup = "/${var.cluster_name}-gitlab/networkfw_flows"
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "FLOW"
    }
  }
}
