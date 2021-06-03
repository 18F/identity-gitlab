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

You can get the initial admin password with `kubectl get secret gitlab-gitlab-initial-root-password -ojsonpath='{.data.password}' -n gitlab | base64 --decode ; echo`

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

## Upgrading

### Helm Charts

### Other Kubernetes Things

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

