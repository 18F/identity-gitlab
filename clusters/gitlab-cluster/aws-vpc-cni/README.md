# aws-vpc-cni

https://docs.aws.amazon.com/eks/latest/userguide/pod-networking.html

https://github.com/aws/amazon-vpc-cni-k8s

It also installs calico so you can do NetworkPolicy stuff too.

This is already partially set up with the managed node groups, but doesn't
seem to be working, so this lets us choose the version we want.

## Updates

Run `./update.sh` while in this directory.  

The tricky bit is that there are
currently configs specific for China and GovCloud in there that you cannot use,
so it filters those out.  If anything ever gets added to that list or they
change the way it's done, you may have to fiddle a bit.
