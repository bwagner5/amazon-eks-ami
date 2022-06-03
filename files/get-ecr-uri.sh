#!/usr/bin/env bash
set -euo pipefail

region=$1
aws_domain=$2
if [[ $# -eq 3 ]] && [[ ! -z $3 ]]; then 
    acct=$3
else 
    case "${region}" in
    ap-east-1)
        acct="800184023465";;
    me-south-1)
        acct="558608220178";;
    cn-north-1)
        acct="918309763551";;
    cn-northwest-1)
        acct="961992271922";;
    us-gov-west-1)
        acct="013241004608";;
    us-gov-east-1)
        acct="151742754352";;
    us-iso-east-1)
        acct="725322719131";;
    us-isob-east-1)
        acct="187977181151";;
    af-south-1)
        acct="877085696533";;
    eu-south-1)
        acct="590381155156";;
    ap-southeast-3)
        acct="296578399912";;
    *)
        acct="602401143452";;
    esac
fi

echo "${acct}.dkr.ecr.${region}.${aws_domain}"
