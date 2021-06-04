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

**NOTE:** Be sure to change your branch to point back at main when you PR it in.
Otherwise, the production cluster will switch over to deploying from your branch!

### EKS Managed Node Groups

Pretty regularly, Amazon will update the AMIs in their managed node groups, and
you probably will want to roll that out.  I haven't found a way to do this in terraform
automatically, but in the console, you just need to click a button, and it will automatically
do this.

You can also run the `aws eks update-nodegroup-version` command, and it should
do the same thing as the console button.  We should consider running this
weekly.

### EKS

New versions of kubernetes come out.  When you want to upgrade, you can do it
through updating the version in `identity-gitlab/terraform/eks-cluster.tf`
and running `./deploy.sh` again.

Someday, we should look at `aws eks describe-addon-versions`, which can be used
to find available versions, and have a script that alerts us when there are
new versions that we should consider updating to.

## Creating New Things

### New AWS resources

Creating new AWS resources is just an exercise in terraform-ing.  But you will
probably want to have these resources used by kubernetes services.  There are
a couple of ways to pass this information in:

#### Create a ConfigMap or Secret that the application uses directly for it's config.

Basically, you learn how your app is configured, and you set up a ConfigMap or
Secret using Terraform that contains the data that the app needs.  When the
app launches, it uses the ConfigMap/Secret that you configured.

An example of this is in `identity-gitlab/terraform/logging.tf`, where a
ConfigMap has been set up that is used by `identity-gitlab/clusters/gitlab-cluster/logging/logging.yaml`
to configure itself.

#### Create a ConfigMap or Secret and use valuesFrom to pull values into your helm chart.

To use this, create a ConfigMap or Secret that contains the data you want to use in a helm release.
Then, you can use [valuesFrom]](https://docs.fluxcd.io/projects/helm-operator/en/stable/helmrelease-guide/values/#values-from-sources)
to pull data out of your ConfigMap/Secret and use it as a value when helm is deploying
the release.

An example can be found in the `terraform-gitlab-info` ConfigMap in
`identity-gitlab/terraform/gitlab.tf`, which contains the data that needs to
be passed to helm.  The `identity-gitlab/clusters/gitlab-cluster/gitlab/gitlab.yaml`
file then has a `valuesFrom` section which maps the ConfigMap data into
helm chart values.

### New Kubernetes resources

If you want to deploy kubernetes things, you should:
* Create a subdirectory under `identity-gitlab/clusters/gitlab-cluster/` that
  lets people know what the code under there is doing.
* Create/copy the yaml in that you need to get the thing going.  This can be a
  `HelmRelease` that FluxCD will deploy, or it can be regular kubernetes yaml.
* Create a `kustomization.yaml` file that includes all of the yaml that you
  want deployed to the cluster.  If you want to use Kustomize's super clever
  generators or variable substitution or other features, you can do that.
* Make sure that `identity-gitlab/clusters/gitlab-cluster/kustomization.yaml`
  has your subdir in it.
* Run `kustomize build identity-gitlab/clusters/gitlab-cluster/` and make
  sure it renders without errors.
* Test it out by pushing these changes to a branch that is deployed by a
  test cluster and see how it rolls out.
* Iterate until it's awesome!
* PR the change into main.

### PrivateLink services and Endpoints

Services can be exposed to other VPCs by doing the following:
* Making sure that your service is using an NLB.  You should be able to do this by
  making the service be a LoadBalancer, and some helm charts allow you to add
  annotations or other ingress config that tells it to be an NLB and have
  ACM certs on it, etc.  If you cannot make it be an NLB, you cannot use PrivateLink,
  and you will have to expose the service another way, like allowing it out
  to the world and limiting it to IP addresses or something ugly like that.
* Setting up a `aws_vpc_endpoint_service` for the service.  You can see an example
  for that in `identity-gitlab/terraform/gitlab.tf`.  Note that there are also
  security groups, ACM certs, and other stuff there that you probably will want
  to adapt as well.  Of note, there is a list of account IDs and roles that you have to
  configure that will allow those entities to discover the service.
* Run `./deploy.sh` and get the name of the service from the output.
* Setting up PrivateLink in the other VPCs.  A good example of that can
  be found here:  https://github.com/18F/identity-devops/pull/3512, but it's
  basically that you need to create an `aws_vpc_endpoint` with the name
  that you got in the previous step.
* Dance!

### Teleport groups/RBAC


## Misc Tasks

### Deleting a cluster

### Fluxcd Helm Magic

force sync
check status of helmrelease, helm
fluxcd logs

### How to run a pod in the cluster

### kubectl common commands

