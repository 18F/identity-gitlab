# it would be cool to use https://registry.terraform.io/providers/fluxcd/flux/latest/docs/guides/github,
# but it fights with what we installed in our repo, and thus we are just going to bootstrap from the
# repo directly.

# Kubernetes
resource "kubernetes_namespace" "flux_system" {
  depends_on = [aws_eks_node_group.eks]
  metadata {
    name = "flux-system"
  }

  lifecycle {
    ignore_changes = [
      metadata[0].labels,
      metadata[0].annotations,
    ]
  }
}

data "kubectl_file_documents" "fluxcd" {
  content = file("${path.module}/../clusters/gitlab-cluster/flux-system/gotk-components.yaml")
}
resource "kubectl_manifest" "fluxcd" {
  depends_on = [kubernetes_namespace.flux_system]
  count      = length(data.kubectl_file_documents.fluxcd.documents)
  yaml_body  = element(data.kubectl_file_documents.fluxcd.documents, count.index)
}

data "kubectl_file_documents" "fluxcd-sync" {
  content = file("${path.module}/../clusters/gitlab-cluster/flux-system/gotk-sync.yaml")
}
resource "kubectl_manifest" "fluxcd-sync" {
  depends_on = [kubernetes_namespace.flux_system]
  count      = length(data.kubectl_file_documents.fluxcd-sync.documents)
  yaml_body  = element(data.kubectl_file_documents.fluxcd-sync.documents, count.index)
}

# SSH
locals {
  known_hosts = "github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ=="
}

resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# This key is so you can pull the public key out and plug it
# into a repo as a read-only deploy key.
resource "kubernetes_secret" "main" {
  depends_on = [kubernetes_namespace.flux_system]

  metadata {
    name      = "flux-system"
    namespace = "flux-system"
  }

  data = {
    identity       = tls_private_key.main.private_key_pem
    "identity.pub" = tls_private_key.main.public_key_pem
    known_hosts    = local.known_hosts
  }
}
