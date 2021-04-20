# GITLAB!

This will launch and configure a basic gitlab instance inside of EKS.

## Setup

The setup will only need to be run once per account.  It sets up the s3 bucket
and dynamodb stuff for remote state and locking and then goes on to do the deploy.

Run it like: `aws-vault exec sandbox-admin -- ./setup.sh gitlab-dev` where
`gitlab-dev` is the name of your cluster.

## Updates

`aws-vault exec sandbox-admin -- ./deploy.sh gitlab-dev` will deploy all the
latest changes you have there in your repo.

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
- Add yourself as a user: `kubectl exec -it deployment.apps/teleport-cluster -n teleport -- tctl users add yourusername --roles=editor,access,admin --logins=root,ubuntu,ec2-user`
- Go to the URL they give you and set up your 2fa
- You should then be able to go to the applications section and pull up gitlab.
- Longer term, we hope to configure more of this through code.


### Gitlab
You will also need to log into gitlab with the initial root password:
- Get the password using `kubectl get secret gitlab-gitlab-initial-root-password -ojsonpath='{.data.password}' -n gitlab | base64 --decode ; echo`
- Log in as root and start configuring!
- Longer term, we want to figure out how to configure this through code.

### Gitlab git-ssh
Right now, we need to access this via port-forwarding.
- Edit your `~/.ssh/config` file and add this: ```
Host gitlab
  HostName localhost
  Port 2222
```
- Run this command in a shell window.  It sets up a tunnel to the git-ssh port on the gitlab service: `kubectl port-forward service/gitlab-gitlab-shell 2222:22 -n gitlab`
- Git clone with a command like this:  `git clone git@gitlab:root/reponame.git`  The important thing is the hostname, which is `gitlab`, which refers to the `Host` entry that you made above in your ssh config file.
- Boom!  You have cloned the repo!!  You should be able to git push/pull/etc
  through this too.  If ever the port-forward dies, you will be unable to access
  gitlab, so restart it if you need to.
  

Have fun!!
