# Cluster Autoscaler

This keeps an eye on the cluster and will scale nodegroups out in
response to nodes filling up.  It should also try to shrink the cluster
down if demand reduces.  So horizontal pod autoscalers will scale
workloads up, and then this will take care of making sure there are
nodes to schedule them on.

https://github.com/awslabs/karpenter might be a better way to do this,
but it seems not very mature yet.  Keep an eye on it.
