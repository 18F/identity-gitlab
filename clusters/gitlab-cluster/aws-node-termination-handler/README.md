# node termination handler

This is good when you are running with SPOT instances.  The handler
will hear when the node is scheduled for termination, will drain the
node, and try to make sure there are no disruptions or new things
being scheduled on it.

https://github.com/awslabs/karpenter might be a better way to do this,
but it seems not very mature yet.  Keep an eye on it.
