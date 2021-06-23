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
export GITHUB_TOKEN=<githubpersonalaccesstoken>
git checkout -b <newupgradebranchname>
git push --set-upstream origin <newupgradebranchname>
flux bootstrap github \
  --owner=18F \
  --repository=identity-gitlab \
  --branch=<newupgradebranchname> \
  --path=clusters/gitlab-cluster \
  --personal
```

It will then try to push it out there and make sure it's reconciled, which
probably won't work.  You can `^C` it, and then make sure you go back and change
the branch and url (https instead of git-ssh) in `gotk-sync.yaml`.

You can then merge that change into branch that will get deployed and tested
on a cluster, and then PR it into main.
