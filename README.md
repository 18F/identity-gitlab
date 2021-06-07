# GITLAB!

This will launch and configure a basic gitlab instance inside of EKS.

Terraform configures the AWS resources required to get the cluster off
the ground (EKS/nodegroups/IAM Roles/RDS/etc.), and then
[fluxcd](https://toolkit.fluxcd.io/) deploys all of the kubernetes
resources inside the cluster.  These resources are basically what is
rendered when you do a `kustomize build clusters/gitlab-cluster/`,
so if you want more stuff to happen, make subdirs and edit `kustomization.yaml`
to make sure that it shows up in that.

You will undoubtably want to pass information from terraform (RDS endpoints,
role ARNs, whatever) into kubernetes.  You can do that by creating a
[ConfigMap](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map)
or [Secret](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret)
with terraform that contains the information you want to pass in,
and then [define environment variables using it](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/#define-container-environment-variables-using-configmap-data),
or by using [Flux's valuesFrom](https://docs.fluxcd.io/projects/helm-operator/en/stable/helmrelease-guide/values/#config-maps)
or [secretKeyRef](https://docs.fluxcd.io/projects/helm-operator/en/stable/helmrelease-guide/values/#secrets)
mechanisms.  Examples of this can be found in `terraform/gitlab.tf` and
`clusters/gitlab-cluster/gitlab/gitlab.yaml`.

## More Documentation

For more documentation, take a look at the [docs](docs/) directory here.
There is a lot of info there on the architecture, components, operational
tasks, etc.

## Setup

The setup make sure that the s3 bucket
and dynamodb stuff for remote state and locking are set up, then does
the base deployment of the cluster and it's services.  After that is done,
proceed to the Deploy step and execute that to complete the final resources.

Run it like: `aws-vault exec sandbox-admin -- ./setup.sh gitlab-dev` where
`gitlab-dev` is the name of your cluster.

NOTE:  Right now, you must run this in the account that is hosting the live
route53 domain that this uses.  Otherwise, it will write it's DNS entries into
the other account's route53, and nothing will ever see them.

## Deploy

`aws-vault exec sandbox-admin -- ./deploy.sh gitlab-dev` will deploy all the
latest changes you have there in your repo.

One thing to note:  If you want to have your cluster operate off of a
branch, just go edit `clusters/gitlab-cluster/flux-system/gotk-sync.yaml` and
change the branch there, then run `deploy.sh` as above to tell fluxcd
to pull from that branch instead of main.  You might want to make sure that
you change it back to master before you make your PR.

## Delete

`aws-vault exec sandbox-admin -- ./destroy.sh gitlab-dev`

Also, some namespaces won't delete right off.  You will need to
follow the procedure in here to make them actually go away:
https://craignewtondev.medium.com/how-to-fix-kubernetes-namespace-deleting-stuck-in-terminating-state-5ed75792647e

You may have to delete an ELB by hand too.  I think that EKS is deleted too
fast sometimes for teleport or gitlab to tear it down.

## Further Setup

### Teleport
In an ideal world, we would just expose gitlab to the world, and rely on ssh keys and gitlab auth for authentication.
However, we can't really do that because it exposes us to all sorts of interesting attacks.  To avoid
this, we are narrowing our attack surface to just [Teleport](https://github.com/gravitational/teleport),
which will help us with excellent [FedRAMP controls](https://goteleport.com/teleport/how-it-works/fedramp-ssh-kubernetes/).

To get access, you will need to configure teleport.
- Add yourself as a local admin: `kubectl exec -it deployment.apps/teleport-cluster -n teleport -- tctl users add <yourusername> --roles=editor,access,admin,k8s-admin --logins=root`
- Go to the URL they give you and set up your 2fa
- You can use kubernetes if you use tsh to log in: `tsh login --proxy teleport-<clustername>.<domain>:443 --user <yourusername>`
- You should then be able to go to the applications section and pull up gitlab.
- Longer term, we hope to configure more of this through code.

#### git-ssh

To allow people to clone repos from gitlab, make sure that they
are added as a teleport user with `kubectl exec -it deployment.apps/teleport-cluster -n teleport -- tctl users add <username> --roles=access,gitssh` and can do a `tsh login --proxy teleport-<clustername>.<domain>:443 --user <yourusername>`.  Then, have them edit `~/.ssh/ssh_config` and add this
to the end:
```
Host gitlab-<clustername>.<domain>
  ProxyCommand ~/src/identity-gitlab/git-proxycommand.sh
```
You may have to change the path to the `git-proxycommand.sh` script.

They then should be able to do `git clone git@gitlab-<clustername>.<domain>:root/repo.git`
to clone a repo on the gitlab server.

#### Automated git-ssh

The `gitlab-<clustername>.<domain>` endpoint should be plumbed up in the app environments
if you have turned `gitlab_enabled` on in tfvars, so things should be able to do a 
`git clone git@gitlab:root/repo.git` without hinderance.  *NOTE:* you will need to use
`gitlab` for the hostname instead of the proper `gitlab-<clustername>.<domain>` domain
because you need to get to the privatelink instead of the real load balancer endpoint.

#### Editing users/roles

If you want to edit users or roles, you should be able to do something like this:
```
$ tctl get users > /tmp/users.yaml
$ vi /tmp/users.yaml # edit user(s)
$ tctl create -f /tmp/users.yaml
user "username" has been updated
$ 
```

#### Updating
To update teleport, you can update the version of the `teleport-cluster` and
`teleport-kube-agent` helm charts in `terraform/teleport.tf` and re-run
`deploy.sh`.


### Gitlab
You will also need to log into gitlab with the initial root password:
- Get the password using `kubectl get secret gitlab-gitlab-initial-root-password -ojsonpath='{.data.password}' -n gitlab | base64 --decode ; echo`
- Log in as root and start configuring!
- Longer term, we want to figure out how to configure this through code.

#### Updates
To update gitlab, just go into `clusters/gitlab-cluster/gitlab/gitlab.yaml` and
change the version of the chart and check it in.  FluxCD should deploy it once it
detects the change in the branch that it is watching.  It will check once a minute,
or you can tell it to check right away by saying
`flux reconcile source git flux-system`.

You can find what the latest/greatest version of
the chart is by making sure that it's been added into your local helm repo list
with `helm repo add gitlab https://charts.gitlab.io/`, and then saying
`helm search repo gitlab` and seeing what the latest version of the `gitlab/gitlab`
chart is.

I have had a failed upgrade once, and I did a
```
helm rollback gitlab -n gitlab
helm get values gitlab -n gitlab  > /tmp/gitlab.yaml
helm upgrade gitlab gitlab/gitlab -f /tmp/gitlab.yaml -n gitlab
```
and it worked, so that might be a useful tool.
`helm history gitlab -n gitlab --debug` might also be a good tool
to see how the rollout went.

### Dashboard

If you want to see what is going on in the cluster, and you are a k8s-admin,
you can do `kubectl port-forward service/dashboard-kubernetes-dashboard 4430:443 -n kubernetes-dashboard`
and then go to http://localhost:4430/ to see almost everything.  It is running in a
read-only mode, with reduced privs, so it can't see things like secrets and so on.


Have fun!!
