# Gitlab!

Gitlab is awesome.  We are using it to host our code and automate our
software factory.

## Using the web UI

To use the docker UI, you will need to get in through the Teleport UI
(`https://teleport-<clustername>.gitlab.<domain>/web/login`) and then
click on the Applications menu item on the left, then on the gitlab
button.  You should then be proxied over to the gitlab UI.

## Git over ssh

To allow people to clone repos from gitlab, make sure that they
are added as a teleport user with `kubectl exec -it deployment.apps/teleport-cluster -n teleport -- tctl users add <username> --roles=access,gitssh` and can do a `tsh login --proxy teleport-<clustername>.<domain>:443 --user <yourusername>`.  Then, have them edit `~/.ssh/config` and add this
to the end:
```
Host gitlab-<clustername>.<domain>
  ProxyCommand ~/src/identity-gitlab/git-proxycommand.sh
```
You may have to change the path to the `git-proxycommand.sh` script.

They then should be able to do `git clone git@gitlab-<clustername>.<domain>:root/repo.git`
to clone a repo on the gitlab server.

## Automated git-ssh

The `gitlab-<clustername>.<domain>` endpoint should be plumbed up in the app environments
if you have turned `gitlab_enabled` on in tfvars, so things should be able to do a 
`git clone git@gitlab:root/repo.git` without hinderance.  *NOTE:* you will need to use
`gitlab` for the hostname instead of the proper `gitlab-<clustername>.<domain>` domain
because you need to get to the privatelink instead of the real load balancer endpoint.

## Container Repo

Gitlab has a nice internal container repo, but given that we are expecting to use it
in a lot of clusters, we have decided to expose it by using AWS ECR instead of using
the integrated one.

The gitlab runner should be using an IAM role that is allowed to do ECR stuff, and
thus all you need to do is set your pipeline up to get the repo password using the aws cli
and then use that to authenticate.

An example of how to do that is below.  Note that you will probably need to change the
`REPO` variable at the minimum.
```
default:
  image: circleci/ruby:2.7.3-node-browsers

variables:
  REPO: tspencertest
  REGION: us-west-2

stages:
  - creds
  - docker
  - test

get_creds:
  stage: creds
  image:
    name: amazon/aws-cli
    entrypoint: [""]
  script:
    - aws ecr get-login-password >/dev/null # This is to make sure we bail if we can't actually do this job
    - echo "export CI_REGISTRY_PASSWORD=\"$(aws ecr get-login-password)\"" >> ./creds.sh
    - echo "export CI_REGISTRY_USER=AWS" >> ./creds.sh
    - echo "export CI_REGISTRY=\"$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$REGION.amazonaws.com\"" >> ./creds.sh
    - . ./creds.sh
    - aws ecr create-repository --repository-name $REPO --region ${REGION} --image-scanning-configuration scanOnPush=true --encryption-configuration encryptionType=AES256 || true
  artifacts:
    paths:
    - creds.sh
    expire_in: 1 week

build_image:
  stage: docker
  image:
    name: gcr.io/kaniko-project/executor:debug
    entrypoint: [""]
  script:
    - . ./creds.sh
    - mkdir -p /kaniko/.docker
    - echo "{\"auths\":{\"$CI_REGISTRY\":{\"username\":\"$CI_REGISTRY_USER\",\"password\":\"$CI_REGISTRY_PASSWORD\"}}}" > /kaniko/.docker/config.json
    - /kaniko/executor --context $CI_PROJECT_DIR --dockerfile $CI_PROJECT_DIR/Dockerfile --destination $CI_REGISTRY/$REPO:$CI_PIPELINE_IID
```

One thing that is odd about ECR is you can't just push to a repo that does not exist.
You must create it first.  In the above pipeline, we do so in the step that gets the creds,
and we also have an opportunity to turn on scanning and encryption there too.
