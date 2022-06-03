#!/usr/bin/env bash

img=$1
region=$(echo "${img}" | cut -f4 -d ".")
ecr_password=$(aws ecr get-login-password --region $region)
API_RETRY_ATTEMPTS=5

for attempt in `seq 0 $API_RETRY_ATTEMPTS`; do
	rc=0
    if [[ $attempt -gt 0 ]]; then
        echo "Attempt $attempt of $API_RETRY_ATTEMPTS"
    fi
	### pull image from ecr
	### username will always be constant i.e; AWS
	sudo ctr --namespace k8s.io image pull "${img}" --user AWS:${ecr_password}
	rc=$?;
	if [[ $rc -eq 0 ]]; then
		break
	fi
	if [[ $attempt -eq $API_RETRY_ATTEMPTS ]]; then
        exit $rc
    fi
    jitter=$((1 + RANDOM % 10))
    sleep_sec="$(( $(( 5 << $((1+$attempt)) )) + $jitter))"
    sleep $sleep_sec
done
