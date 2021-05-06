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

## Setup

The setup will only need to be run once per account.  It sets up the s3 bucket
and dynamodb stuff for remote state and locking and then goes on to do the deploy.

Run it like: `aws-vault exec sandbox-admin -- ./setup.sh gitlab-dev` where
`gitlab-dev` is the name of your cluster.

## Updates

`aws-vault exec sandbox-admin -- ./deploy.sh gitlab-dev` will deploy all the
latest changes you have there in your repo.

One thing to note:  If you want to have your cluster operate off of a
branch, just go edit `clusters/gitlab-cluster/flux-system/gotk-sync.yaml` and
change the branch there, then run `deploy.sh` as above to tell fluxcd
to pull from that branch instead of main.

## Delete

`aws-vault exec sandbox-admin -- ./destroy.sh gitlab-dev`

If it asks you for oidc stuff, just give it random stuff.
That will go away once we go back to a single tf run.

Also, some namespaces won't delete right off.  You will need to
follow the procedure in here to make them actually go away:
https://craignewtondev.medium.com/how-to-fix-kubernetes-namespace-deleting-stuck-in-terminating-state-5ed75792647e

## Further Setup

### Teleport
To get access, you will need to configure teleport.
- Create the teleport roles: `kubectl exec -it deployment.apps/teleport-cluster -n teleport -- tctl create -f < ./teleport-roles.yaml`
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
Host gitlab.gitlab.identitysandbox.gov
  ProxyCommand ~/src/identity-gitlab/git-proxycommand.sh
```
You may have to change the path to the `git-proxycommand.sh` script.

They then should be able to do `git clone git@gitlab.gitlab.identitysandbox.gov:root/repo.git`
to clone a repo on the gitlab server.

#### Editing users/roles

If you want to edit users or roles, you should be able to do something like this:
```
$ tctl get users > /tmp/users.yaml
$ vi /tmp/users.yaml # edit user(s)
$ tctl create -f /tmp/users.yaml
user "username" has been updated
$ 
```

### Gitlab
You will also need to log into gitlab with the initial root password:
- Get the password using `kubectl get secret gitlab-gitlab-initial-root-password -ojsonpath='{.data.password}' -n gitlab | base64 --decode ; echo`
- Log in as root and start configuring!
- Longer term, we want to figure out how to configure this through code.

Have fun!!
