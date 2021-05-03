teleport:
  auth_token: "/etc/teleport-secrets/auth-token"
  auth_servers: ["${clusterName}:443"]
  log:
    severity: INFO
    output: stderr
ssh_service:
  enabled: "yes"

kubernetes_service:
  enabled: false
app_service:
  enabled: false
db_service:
  enabled: false
auth_service:
  enabled: false
proxy_service:
  enabled: false
