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
data "kubectl_file_documents" "logging" {
  content = file("${path.module}/logging.yaml")
}

resource "kubectl_manifest" "logging" {
  count     = length(data.kubectl_file_documents.logging.documents)
  yaml_body = element(data.kubectl_file_documents.logging.documents, count.index)
}
