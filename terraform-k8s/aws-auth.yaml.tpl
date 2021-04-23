apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - groups:
      - system:bootstrappers
      - system:nodes
      rolearn: arn:aws:iam::${accountid}:role/${clustername}-noderole
      username: system:node:{{EC2PrivateDNSName}}
    - userarn: arn:aws:iam::${accountid}:role/${teleportrolename}
      username: teleport
      groups:
        - teleport-group
