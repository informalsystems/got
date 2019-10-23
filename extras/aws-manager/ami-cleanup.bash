#!/bin/bash

# Removes AMI images.

set -euo pipefail

echo "Usage: $0 <Nightking_timestamp>"
test -n "$1"
echo -ne "jq needs to be present. "
which jq

for r in "us-east-1" "us-east-2" "us-west-1" "us-west-2" "ca-central-1" "sa-east-1" "eu-west-1" "eu-west-2" "eu-west-3" "eu-north-1" "eu-central-1" "ap-south-1" "ap-northeast-1" "ap-northeast-2" "ap-southeast-1" "ap-southeast-2"
do

  id=$(aws ec2 describe-images --owners 400392161012 --filters Name=name,Values="Interchain Nightking image ${1}" --region $r | jq -r .Images[0].ImageId)
  if [ "${id}" != "null" ]; then
    echo "Found instance ID ${id} in region ${r}. Removing..."
    aws ec2 deregister-image --image-id "${id}" --region "${r}"
  else
    echo "Did not find instance image in region ${r}. Moving on."
  fi

done
