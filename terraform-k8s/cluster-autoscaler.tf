
resource "helm_release" "eksclusterautoscaler" {
  name       = "eksclusterautoscaler"
  repository = "https://kubernetes.github.io/autoscaler" 
  chart      = "cluster-autoscaler-chart"
  version    = "2.0.0"
  namespace  = "kube-system"
  depends_on = [null_resource.k8s_up]

  set {
    name  = "awsRegion"
    value = var.region
  }

  set {
    name  = "extraArgs.skip-nodes-with-system-pods"
    value = "true"
  }

  set {
    name  = "autoDiscovery.clusterName"
    value = var.cluster_name
  }
}
