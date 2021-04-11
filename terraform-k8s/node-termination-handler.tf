
# This sets up the thing that will try to drain nodes nicely if
# the spot instance is pre-empted.
resource "helm_release" "aws-node-termination-handler" {
  name       = "aws-node-termination-handler"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-node-termination-handler"
  version    = "0.14.2"
  namespace  = "kube-system"
}
