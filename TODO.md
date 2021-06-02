# TODO!

This is a list of items that people can make issues out of and start work on:

* More Documentation!  We can always update this stuff and make it better.
* User Authentication!  Some way we can authenticate as a user to teleport, gitlab.
	* Some sort of IDP?  Everybody seems to expect you to have an IDP handy.
	  We do, but we can't use it because this is going to be helping manage our
	  idp, so we can't rely on it.  Surely there's a simple one we can set up.
	* PIV auth?  We can use this or something like it to get a user DN out and
	  use that:  https://github.com/timspencer/pivproxy  Gitlab supposedly does
	  PIV auth out of the box too:  https://docs.gitlab.com/ee/administration/auth/smartcard.html
	  This would be very zero-trust trendy.
	* Manual user creation:  Might be easy to do.  Certainly would be super
	  reliable because there's no service to go down.
* Do more FIPS investigation to see how FIPS-y we can make this thing.
* Get ACM to do Teleport cert:  will need to upgrade to latest helm chart probably
  so that you can add annotations to the service.  Also make it an NLB?
* Make sure that Teleport audit logs are getting into CloudWatch.
* PV backups for teleport and gitlab.  Snapshotting of the EBS volumes would
  probably work, but not sure how to turn that on.
* Infrastructure tests for gitlab cluster?  So cool.
* Get Falco going:  https://falco.org/  Make some alerts?  Make sure you don't
  bust the managed node barrier.  We want to inherit as much as possible of
  AWS' FedRAMP controls.
* Signed images:  DCR or https://github.com/sigstore/cosign,
  https://github.com/sse-secure-systems/connaisseur to verify.
  Are Teleport/gitlab signing yet?  Maybe premature.
* Start documenting FedRAMP controls in whatever format is trendy.
* Aqua or other runtime security product?
* Look at NewRelic support for watching k8s clusters?
* IPv6:  Let's do it!
