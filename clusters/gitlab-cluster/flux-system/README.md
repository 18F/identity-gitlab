# FluxCD

Most k8s stuff should be deployed with this.  The only things that
terraform should be deploying in EKS are resources that need AWS
resources in them, like IAM role name annotations or RDS endpoints
or whatever.

## Upgrade

To upgrade, you should be able to follow the
[directions](https://fluxcd.io/docs/guides/installation/#bootstrap-upgrade)
to do this:
```
flux bootstrap github \
  --owner=18F \
  --repository=identity-gitlab \
  --branch=main \
  --path=clusters/gitlab-cluster \
  --personal
```
