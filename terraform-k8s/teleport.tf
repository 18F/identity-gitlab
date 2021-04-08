
resource "kubernetes_namespace" "teleport" {
  depends_on = [null_resource.k8s_up]
  metadata {
    name = "teleport"
  }
}

resource "helm_release" "teleport-cluster" {
  name       = "teleport-cluster"
  repository = "https://charts.releases.teleport.dev" 
  chart      = "teleport"
  version    = "0.0.12"
  namespace  = "teleport"
  depends_on = [kubernetes_namespace.teleport, kubernetes_config_map.teleport-cluster]

  set {
    name  = "namespace"
    value = "teleport"
  }

  set {
    name  = "acme"
    value = "true"
  }

  set {
    name  = "acmeEmail"
    value = "security@login.gov"
  }

  set {
    name  = "clusterName"
    value = "teleport-${var.cluster_name}.${var.domain}"
  }

  set {
    name  = "customConfig"
    value = "true"
  }
}

# This is where the customConfig lives (same name as the helm release)
resource "kubernetes_config_map" "teleport-cluster" {
  depends_on = [kubernetes_namespace.teleport]
  metadata {
    name = "teleport-cluster"
    namespace = "teleport"
  }

  data = {
    "teleport.yaml" = <<CUSTOMCONFIG
teleport:
  nodename: teleport-cluster
  pid_file: /var/run/teleport.pid
  data_dir: /var/lib/teleport
  log:
    output: stderr
    severity: INFO
  # storage settings included
  storage:
    type: dir

  connection_limits:
    max_connections: 1000
    max_users: 250
auth_service:
  enabled: true
  license_file: /var/lib/license/license-enterprise.pem
  authentication:
    type: local
  tokens:
    - proxy,node,kube:dogs-are-much-nicer-than-cats
    - trusted_cluster:trains-are-superior-to-cars

  public_addr: teleport.example.com:3025
  cluster_name: teleport.example.com
  listen_addr: 0.0.0.0:3025
  client_idle_timeout: never
  disconnect_expired_cert: false
  keep_alive_interval: 5m
  keep_alive_count_max: 3

ssh_service:
  enabled: true
  public_addr: teleport-clusternode:3022
  listen_addr: 0.0.0.0:3022
  commands:
    - command:
      - uptime
      - -p
      name: uptime
      period: 30m
  labels:
    type: auth
  enhanced_recording:
    cgroup_path: /cgroup2
    command_buffer_size: 8
    disk_buffer_size: 128
    enabled: false
    network_buffer_size: 8
  pam:
    enabled: false
    service_name: teleport

proxy_service:
  enabled: true
  public_addr: teleport.example.com:3080
  web_listen_addr: 0.0.0.0:3080
  listen_addr:  0.0.0.0:3023
  tunnel_listen_addr:  0.0.0.0:3024
  ssh_public_addr: teleport.example.com:3023
  tunnel_public_addr: teleport.example.com:3024


  https_key_file: /var/lib/certs/tls.key
  https_cert_file: /var/lib/certs/tls.crt
  # kubernetes section configures
  # kubernetes proxy protocol support
  kubernetes:
    enabled: true
    public_addr: teleport.example.com:3026
    listen_addr: 0.0.0.0:3026
CUSTOMCONFIG
  }
}
