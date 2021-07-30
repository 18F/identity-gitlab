# GitHub -> GitLab sync

This repo contains a pipeline definition that syncs itself from GitHub when run
by a GitLab schedule.

## Authentication

`identity-gitlab` is a public GitHub repo, so no authentication is needed to
pull from there.  In order to push to GitLab, there is an `identity-servers`
GitLab user that is allowed to push to protected branches.

This user's password is in AWS Secrets Manager in the `login-tooling` account,
in the `gitlab/identity-servers/password.txt` secret.

An GitLab-instance-level access key for this user,
`gitlab_identity_servers_access_key`, is defined at
https://gitlab.teleport-$CLUSTER.gitlab.identitysandbox.gov/admin/application_settings/ci_cd -
only jobs running on protected branches have access to this key.
