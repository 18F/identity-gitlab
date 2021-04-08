#!/usr/bin/env bash
#
# This is to get around https://github.com/hashicorp/terraform-provider-aws/issues/10104
#

echo | openssl s_client -servername "oidc.eks.${1}.amazonaws.com" -showcerts -connect "oidc.eks.${1}.amazonaws.com:443" 2>&- | awk '/-----BEGIN/{f="cert."(n++)} f{print>f} /-----END/{f=""}'
 
certificates=()

for c in cert.*; do
   certificates+=($(openssl x509 <"$c" -noout -fingerprint))
done
rm cert.* 

thumbprint=$(echo ${certificates[${#certificates[@]}-1]} | sed 's/://g' | awk -F= '{print tolower($2)}')
thumbprint_json="{\"thumbprint\": \"${thumbprint}\"}"
echo "$thumbprint_json"
