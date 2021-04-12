# This is from https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-setup-logs-FluentBit.html#Container-Insights-FluentBit-setup
# and should make it so that logs are going to:
#  /aws/containerinsights/Cluster_Name/application
#  /aws/containerinsights/Cluster_Name/host
#  /aws/containerinsights/Cluster_Name/dataplane
#

resource "kubernetes_namespace" "amazon-cloudwatch" {
  metadata {
    name = "amazon-cloudwatch"
  }
}

resource "kubernetes_config_map" "fluent-bit-cluster-info" {
  depends_on = [kubernetes_namespace.amazon-cloudwatch]
  metadata {
    name      = "fluent-bit-cluster-info"
    namespace = "amazon-cloudwatch"
  }

  data = {
    "cluster.name" = var.cluster_name
    "logs.region"  = var.region
    "http.server"  = "Off"
    "http.port"    = ""
    "read.head"    = "On"
    "read.tail"    = "Off"
  }
}

# logging.yaml comes from:
#   curl https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/fluent-bit/fluent-bit.yaml
# which came from https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-setup-logs-FluentBit.html#Container-Insights-FluentBit-setup
resource "null_resource" "logging-daemonset" {
  depends_on = [kubernetes_namespace.amazon-cloudwatch, kubernetes_config_map.fluent-bit-cluster-info]
  provisioner "local-exec" {
    command = "kubectl apply -f logging.yaml"
  }

  triggers = {
    # Update this string to force a re-apply, like when you update logging.yaml.
    loggingversion = "04-12-2021"
  }
}
