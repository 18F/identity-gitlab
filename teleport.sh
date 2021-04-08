helm repo add teleport https://charts.releases.teleport.dev
helm install teleport-cluster teleport/teleport-cluster --create-namespace --namespace=teleport-cluster --set clusterName=teleport.tooling.identitysandbox.gov --set acme=true --set acmeEmail=${EMAIL?} --set customConfig=true
cat << EOF > custom-config.yaml
apiVersion: v1
data:
  teleport.yaml: "teleport:\nauth_service:\n  enabled: true\n  cluster_name: teleport.tooling.identitysandbox.gov\napp_service:\n  enabled: yes\n  apps:\n    - name: gitlab\n      uri: \"http://10.100.105.171:8181\"\nkubernetes_service:\n
    \ enabled: true\n  listen_addr: 0.0.0.0:3027\n  labels:\nproxy_service:\n  public_addr:
    'teleport.tooling.identitysandbox.gov:443'\n  kube_listen_addr: 0.0.0.0:3026\n
    \ enabled: true\n  acme:\n    enabled: true\n    email: steven.harms@gsa.gov\n
    \   uri: \nssh_service:\n  enabled: false\n"
kind: ConfigMap
metadata:
  annotations:
    meta.helm.sh/release-name: teleport-cluster
    meta.helm.sh/release-namespace: teleport-cluster
  name: teleport-cluster
  namespace: teleport-cluster
EOF

kubectl -n teleport-cluster apply -f customer-config.yaml
