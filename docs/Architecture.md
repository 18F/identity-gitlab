# Architecture

The FedRAMP people are unable to certifiy that [GitHub](https://github.com/)
is a suitable platform for us to manage our systems, given that we use
GitOps to manage many aspects of our systems.  
Thus, we are building our own [Gitlab](https://about.gitlab.com/)
cluster out for us to host our code.

This system is set up to run Gitlab inside of EKS.  EKS was chosen because:
* It is a system that has been deemed FedRAMP Moderate.
* It is a system that is managed by AWS, and not us.  We just specify how
  big the cluster is and what we want running in it.
* Kubernetes is a platform that has a tremendous amount of industry momentum behind it,
  which brings benefits of well-supported open source software for it, as well as
  many people who are familiar with how it works, and thus new people can hit the
  ground running when hired by login.gov.

## Philosophy

The system was built with these philosophical things in mind:
* Things should be as simple as possible, but no simpler.
* AWS resources should be managed by [Terraform](https://www.terraform.io/docs/), 
  and Kubernetes resources should be managed by [FluxCD](https://fluxcd.io/)
  as much as possible.  This lets us use tools that play to their strengths.

## System Diagram

EKS is set up to run one managed node group which hosts all the workloads.
It uses SPOT instances by default, but you can make then be on demand too.
These instances are spread across (again, by default) 2 subnets in different AZs.
These nodes can talk to the world through a NAT gateway and Network 
Firewall and otherwise do not have public IPs.  Services in these nodes are
exposed through loadbalancers that land on the public subnets and can talk
to the private node group subnets.  There is also a "services" subnet that is
also not publicly accessible that hosts various AWS services that the cluster
needs to operate, like RDS databases or Elasticache or AWS VPC endpoints.

![System Diagram](SystemDiagram.png)

## Components

### AWS

AWS is the cloud provider that we run on.  We run in AWS East/West, which
allows us to inherit their FedRAMP Moderate controls for almost all services
that they provide.

### Gitlab

[Gitlab](https://about.gitlab.com/) is the reason for this project's existence.
It is installed with a helm chart, but it has a fair number of resources that
are created by terraform, such as RDS elasticache and postgres too.  People can
access it through Teleport.  The web UI is done through Teleport's "app" service,
and the git-ssh access is done through kubernetes port forwarding, which is also
managed by Teleport, along with regular kubernetes RBAC that allows users in
particular groups to access only the git-ssh port.

Right now, we are only attempting to use this service for our git repos, but
we see tremendous value in the auto-devops automation that it has.  We would like
to think that we will be using this capability to automatically build artifacts,
deploy, test, and promote changes to our various environments down the road.

### Teleport

[Teleport](https://goteleport.com/) is a service that can be used to manage access
to services.  It is kubernetes-aware, deployed with a helm chart, and is very
[FedRAMP aware](https://goteleport.com/teleport/how-it-works/fedramp-ssh-kubernetes/),
which helps with our compliance story.

### aws-load-balancer-controller

Kubernetes can specify 
[a few different ways to expose services to the world](https://medium.com/google-cloud/kubernetes-nodeport-vs-loadbalancer-vs-ingress-when-should-i-use-what-922f010849e0)
The [load balancer controller](https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html)
is a service that runs in a Kubernetes cluster and creates and configures load balancers
for Kubernetes `LoadBalancer` services and `Ingress`es.  You can configure those
loadbalancers by putting annotations on the Kubernetes resources that the controller
will make happen.

This service is useful because you can constrain the powers of exposing services
through loadbalancers to just this AWS-supported service, instead of making them
generally availble to things running in the cluster.  It also takes care of the
complexity of mapping loadbalancers onto endpoints automatically for you.

### aws-node-termination-handler

The [node termination handler](https://github.com/aws/aws-node-termination-handler)
is a service that runs as a daemonset (one on every node in the cluster) that listens
for AWS notifications that it is going to terminate the node, like if you are running
SPOT instances and you got outbid, and if it hears this, it starts tainting the node
so that new stuff won't get scheduled on it and starts rescheduling pods elsewhere.

This helps keep the cluster running smoothly without interruptions.

### cluster-autoscaler

The [cluster autoscaler](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md)
is a `Deployment` that runs in Kubernetes that manages the number of nodes in the
cluster. If there are pods that cannot be scheduled, it will launch more nodes so
that there is space for them to run.  It can also scale down the cluster if load
goes down too.

This is really useful because we can use
[horizontal pod autoscalers](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
to grow and shrink the number of workloads handling the loads in the cluster, and then
automatically shrink back down when load goes down.  This will save us money because the
cluster will always be the "right size".

### dashboard

The [dashboard](https://github.com/kubernetes/dashboard) is a useful tool for seeing
what is going on in the cluster.  It is deployed in a read-only mode that cannot look
at secrets or other sensitive information.  It is there for admins to investigate
problems.

### metrics-server

The [metrics server](https://github.com/kubernetes-sigs/metrics-server) is a service
that keeps track of resources used in the cluster.  It is used by the dashboard and
other tools like `kubectl top`.

### FluxCD

[FluxCD](https://fluxcd.io/) is a cloud-native tool that looks at various sources such
as Helm Charts and git repos, and if it detects a change, it will apply the yaml or
helm charts automatically to the cluster.  It also has a nice system to interpolate in
data from various sources so that the yaml can be customized for your cluster.
It is a very simple and easy way to deploy Kubernetes resources in a GitOps-style way.

It is the way that we are deploying most Kubernetes resources in this cluster.  The
interpolation function is useful to us because it lets us pass information that Terraform
knows about into kubernetes deployments.  For instance, if we want to pass an RDS endpoint
into the Gitlab helm chart, we can have terraform create a configmap or secret with the
endpoint or password or whatever, and fluxcd can be configured to pull values from that
configmap and put them into the helm chart it is deploying, so that gitlab can know
what database to point at.

### Logging (fluent-bit)

This is AWS' [preferred way to send logs to CloudWatch](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-setup-logs-FluentBit.html).

