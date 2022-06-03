#!/usr/bin/env bash

function _get_token() {
  local token_result=
  local http_result=

  token_result=$(curl -s -w "\n%{http_code}" -X PUT -H "X-aws-ec2-metadata-token-ttl-seconds: 600" "http://169.254.169.254/latest/api/token")
  http_result=$(echo "$token_result" | tail -n 1)
  if [[ "$http_result" != "200" ]]
  then
      echo -e "Failed to get token:\n$token_result"
      return 1
  else
      echo "$token_result" | head -n 1
      return 0
  fi
}

function get_token() {
  local token=
  local retries=20
  local result=1

  while [[ retries -gt 0 && $result -ne 0 ]]
  do
    retries=$[$retries-1]
    token=$(_get_token)
    result=$?
    [[ $result != 0 ]] && sleep 5
  done
  [[ $result == 0 ]] && echo "$token"
  return $result
}

function _get_meta_data() {
  local path=$1
  local metadata_result=

  metadata_result=$(curl -s -w "\n%{http_code}" -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/$path)
  http_result=$(echo "$metadata_result" | tail -n 1)
  if [[ "$http_result" != "200" ]]
  then
      echo -e "Failed to get metadata:\n$metadata_result\nhttp://169.254.169.254/$path\n$TOKEN"
      return 1
  else
      local lines=$(echo "$metadata_result" | wc -l)
      echo "$metadata_result" | head -n $(( lines - 1 ))
      return 0
  fi
}

function get_meta_data() {
  local metadata=
  local path=$1
  local retries=20
  local result=1

  while [[ retries -gt 0 && $result -ne 0 ]]
  do
    retries=$[$retries-1]
    metadata=$(_get_meta_data $path)
    result=$?
    [[ $result != 0 ]] && TOKEN=$(get_token)
  done
  [[ $result == 0 ]] && echo "$metadata"
  return $result
}

echo "Starting Early Userdata at $(date +"%Y-%m-%dT%H:%M:%S%z")" >> /var/log/early-userdata.log
TOKEN=$(get_token)
get_meta_data 'latest/user-data' > /etc/eks/user-data.sh
chmod +x /etc/eks/user-data.sh
exec /etc/eks/user-data.sh
