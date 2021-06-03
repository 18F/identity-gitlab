# Operations

If you are doing work in a fully functional cluster, you should be able to do a
`tsh login` to log into the last cluster you were using, or 
`tsh --proxy teleport-<cluster>.<domain>:443 login --user <username`
if you are logging in for the first time or want to log into another cluster.
Once you have logged in, you should be able to run kubernetes commands without hinderance,
like `kubectl get all -n gitlab` or whatever.  The key you will be issued will only work for XXX hours.

On the other hand, if teleport is not working, you may need to fall back to using
your IAM `FullAdministrator` role and going direct.  You can do that by assuming the
`FullAdministrator` role and then setting your kubeconfig up with
`aws eks update-kubeconfig --name <cluster>`.  After that, so long as you have
assumed the proper role, you can run kubernetes commands like
`aws-vault exec admin -- kubectl get all -n teleport`

## Adding Users/Roles

### Teleport

Right now, you can add a teleport user with
`kubectl exec -it deployment.apps/teleport-cluster -n teleport -- tctl users add <username> --roles=access,gitssh`.

If you want to add a teleport admin, you can run
`kubectl exec -it deployment.apps/teleport-cluster -n teleport -- tctl users add <yourusername> --roles=editor,access,admin,k8s-admin --logins=root`.

The roles can be configured by adding to `identity-gitlab/teleport-roles.yaml` and running `./deploy.sh` again.
You can see how those roles get mapped to kubernetes groups, which you can configure with RBAC to allow people
to do various things.  Like maybe someday we might want developers to be able to get logs directly or `describe`
pods to see why they aren't starting up, but not allow `delete`s or other things that let you change the cluster.
There is an example of how you can set the RBAC stuff up in `teleport.tf`, or you can do it in regular yaml files
with flux.

### Gitlab

XXX TBD

You can get the initial root password with `kubectl get secret gitlab-gitlab-initial-root-password -ojsonpath='{.data.password}' -n gitlab | base64 --decode ; echo`

## Looking at logs

### kubectl logs

You can grab logs directly from a pod with a command like `kubectl logs -n teleport deployment.apps/teleport-cluster`
or whatever.  There are a ton of logging related commands here:  https://kubernetes.io/docs/reference/kubectl/cheatsheet/#interacting-with-running-pods

### CloudWatch

You can use the normal CloudWatch Insights stuff in the AWS console.  Logs for your cluster
are under `/aws/containerinsights/<cluster>/`.  `application` is logs from apps running in
the cluster, `dataplane` is Kubernetes API logging, `host` is logs from the managed node
group(s).

You can also get firewall logs under `/<cluster>-gitlab/networkfw_alerts` for disallowed
host events and other alerts, and `/<cluster>-gitlab/networkfw_flows` for network flows.
A useful query for finding hosts that the cluster is trying to access but being
disallowed is:
```
fields @timestamp, event.tls.sni
| filter event.alert.signature == "not matching any TLS allowlisted FQDNs"
| sort @timestamp desc
```

## Upgrading/Changing stuff

In general, kubernetes yaml is located in a subdir of `identity-gitlab/clusters/gitlab-cluster/`.
The subdirs should be named something that lets you know what it is, and ideally there is
a `README.md` in there too.

In general, AWS resources are managed in the `identity-gitlab/terraform` directory.

### Helm Charts

First of all, we are assuming that you have all the helm chart repos on your local system
that are being used in the cluster.
You can add a repo by saying `helm repo add gitlab <repo_url>` like `helm repo add gitlab https://charts.gitlab.io/`.
You can make sure you have all the latest and greatest updates with `helm repo update`.

Helm charts get updated all the time.  You can see if there are updates to the helm chart
you are interested in by doing a `helm search repo <chart>`, like `helm search repo gitlab`.
Look for the version of the repo that is being deployed.

If it is updated, and you want to deploy it, you should be able to tell FluxCD to deploy
the new version by updating the helm release version.  
For example, `identity-gitlab/clusters/gitlab-cluster/gitlab/gitlab.yaml` has this at the start:
```
---
apiVersion: source.toolkit.fluxcd.io/v1beta1
kind: HelmRepository
metadata:
  name: gitlab
  namespace: flux-system
spec:
  interval: 1m
  url: https://charts.gitlab.io/

---
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: gitlab
  namespace: gitlab
spec:
  interval: 5m
  chart:
    spec:
      chart: gitlab
      version: "4.11.4"
      sourceRef:
        kind: HelmRepository
        name: gitlab
        namespace: flux-system
      interval: 1m
  values:
...
```
The `HelmRepository` resource specifies the helm repo, and the `HelmRelease` version
is set to `4.11.4`.  If you update the version and check it in, Fluxcd will attempt to upgrade
the helm release to whatever version you just plugged in.  Be aware that you might need to
add/update values that the helm release consumes, as sometimes they change how the release
is configured.  Look at release notes if you can.

You can watch how the upgrade is going with a command like
`watch "kubectl describe helmrelease gitlab -n gitlab | tail -50"`
and/or
`watch kubectl get all -n gitlab`

If it fails, FluxCD usually rolls back, or maybe you can roll it back by hand?
XXX Go make sure.

#### Terraform helm stuff

We have a couple of helm releases managed by terraform because we required the
release to be going so we could extract service infomation from it for use in
creating AWS resources.  So messy.

For these, you will need to change the version in the .tf file and then run
`./deploy.sh` again.

### Other Kubernetes Things

In general, kubernetes things in this cluster are deployed through FluxCD.
It watches this repo on the branch specified in `identity-gitlab/clusters/gitlab-cluster/flux-system/gotk-sync.yaml`
and if it changes, it will run `kustomize build` on `identity-gitlab/clusters/gitlab-cluster` and
apply the resulting yaml to the kubernetes cluster.  So you make changes, PR
them in, and they will roll out.

[Kustomize](https://github.com/kubernetes-sigs/kustomize) is a really cool tool
that lets you manage your kubernetes yaml in a declarative template way.  It
can be very powerful.  What you need to know is that if you add yaml files,
you will need to add them to the `kustomization.yaml` file
in that directory, or if you are adding a new subdirectory, you will need to
add it to the `kustomization.yaml` file in the top level there, and make
sure that all the yaml files are listed in the kustomization file in the
subdir too.  You should be able to test that this is working by doing a
`kustomize build identity-gitlab/clusters/gitlab-cluster/` and making
sure it doesn't error out, and that it has your new content in it.

Some of the kubernetes resources under `identity-gitlab/clusters/gitlab-cluster/`
have static yaml in them, because that is how many things seem to want to be deployed.
Wherever possible, there is an update script in the subdirectory that can be used
to pull updates down, or there is a `README.md` that tells how to do it.

#### Trying out new stuff on a branch

If you want to have your cluster operate off of it's own branch, you can change
the `identity-gitlab/clusters/gitlab-cluster/flux-system/gotk-sync.yaml` file
to point to your branch instead of main and then run `./deploy.sh`.  It will then track
your branch, so you can do development work on your branch on your cluster.

*NOTE:* Be sure to change your branch to point back at main when you PR it in.
Otherwise, the production cluster will switch over to deploying from your branch!

### EKS Managed Node Groups


### EKS


## Creating New Things

### New AWS resources

passing arns and endpoints and so on to fluxcd/helm/k8s

### New Kubernetes resources

### PrivateLink services and Endpoints

### Teleport groups/RBAC


## Misc Tasks

### Deleting a cluster

### Fluxcd Helm Magic

force sync
check status of helmrelease, helm
fluxcd logs

### How to run a pod in the cluster

### kubectl common commands

