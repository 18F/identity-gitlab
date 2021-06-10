#!/bin/sh
#
# This script updates to the version specified in VERSION
#

VERSION="v1.8"
SRC="/tmp/amazon-vpc-cni-k8s.$$"

rm -rf "$SRC" yaml
git clone --depth 1 https://github.com/aws/amazon-vpc-cni-k8s.git "$SRC"
mkdir yaml
cp "$SRC/config/$VERSION/"* yaml/


cat <<EOF > kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
EOF

# The grep -v is to get rid of the cn and us-gov stuff.  We can only run one.
find yaml -name \*.yaml -type f | grep -Ev 'cni-metrics-helper-|aws-k8s-cni-' | while read line ; do
	echo "- $line" >> kustomization.yaml
done

#rm -rf "$SRC"

