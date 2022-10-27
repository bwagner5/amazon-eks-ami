#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

echo "--> Should yum update in the background with systemd services requiring restarts"
exit_code=0
export NEEDS_RESTARTING=service
export NEEDS_RESTARTING_SERVICES="foo.service bar.service"
/etc/eks/bootstrap.sh --b64-cluster-ca dGVzdA== --apiserver-endpoint http://my-api-endpoint test || exit_code=$?

if [[ ${exit_code} -ne 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${exit_code}'"
  exit 1
fi

if ! cat /tmp/systemctl-history | grep 'systemctl try-restart foo.service bar.service'; then
  echo "❌ Test Failed: expected foo.service and bar.service to be restarted"
  exit 1
fi
