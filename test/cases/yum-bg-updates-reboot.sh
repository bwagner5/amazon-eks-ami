#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

echo "--> Should yum update in the background with a reboot required"
exit_code=0
export NEEDS_RESTARTING=reboot
/etc/eks/bootstrap.sh --b64-cluster-ca dGVzdA== --apiserver-endpoint http://my-api-endpoint test || exit_code=$?

if [[ ${exit_code} -ne 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${exit_code}'"
  exit 1
fi
