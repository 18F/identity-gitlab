# This is from https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-setup-logs-FluentBit.html#Container-Insights-FluentBit-setup
# and should make it so that logs are going to:
#  /aws/containerinsights/Cluster_Name/application
#  /aws/containerinsights/Cluster_Name/host
#  /aws/containerinsights/Cluster_Name/dataplane
#

resource "kubernetes_namespace" "amazon-cloudwatch" {
  depends_on = [aws_eks_fargate_profile.eks]
  metadata {
    name = "aws-observability"
  }
}

resource "kubernetes_config_map" "fluent-bit-cluster-info" {
  depends_on = [kubernetes_namespace.amazon-cloudwatch]
  metadata {
    name      = "aws-logging"
    namespace = "aws-observability"
  }

  data = {
    "output.conf" = <<EOF
[OUTPUT]
    Name cloudwatch_logs
    Match   *
    region ${var.region}
    log_group_name /${var.cluster_name}-gitlab
    log_stream_prefix pod-output-
EOF
  }
}
