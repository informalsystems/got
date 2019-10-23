#!/bin/bash

# Removes whitewalker and stark EC2 instances and SSH key-pairs.

set -euo pipefail

echo "Usage: $0"
echo -ne "jq needs to be present. "
which jq

for r in "us-east-1" "us-east-2" "us-west-1" "us-west-2" "ca-central-1" "sa-east-1" "eu-west-1" "eu-west-2" "eu-west-3" "eu-north-1" "eu-central-1" "ap-south-1" "ap-northeast-1" "ap-northeast-2" "ap-southeast-1" "ap-southeast-2"
do

  # Instances
  id=$(aws ec2 describe-instances --filters Name=tag:role,Values="whitewalker","stark" --region $r | jq -r '.Reservations[] | .Instances[].InstanceId')
  if [ -n "${id}" ]; then
    echo -e "Region ${r}, Found instance ID(s):\n${id}\nRemoving..."
    for i in ${id//\\n/ }
    do
      aws ec2 terminate-instances --instance-ids "${i}" --region "${r}" 2> /dev/null || echo "Did not remove ${i}. Moving on."
    done
  else
    echo "Did not find image in region ${r}. Moving on."
  fi

  # key-value pairs
  key_name=$(aws ec2 describe-key-pairs --region $r | jq -r '.KeyPairs[].KeyName | select((startswith("stark") or startswith("whitewalker")) and endswith("-ssh"))')
  if [ -n "${key_name}" ]; then
    echo -e "Region ${r}, Found key-pair name(s):\n${key_name}\nRemoving..."
    for i in ${key_name//\\n/ }
    do
      aws ec2 delete-key-pair --key-name "${i}" --region "${r}" 2> /dev/null || echo "Did not remove ${i}. Moving on."
    done
  else
    echo "Did not find key-pair in region ${r}. Moving on."
  fi

  # security groups
  sg_id=$(aws ec2 describe-security-groups --filter Name=owner-id,Values="400392161012" --region $r | jq -r '.SecurityGroups[] | select(.GroupName | (startswith("stark") or startswith("whitewalker")) and endswith("-ports")) | .GroupId')
  if [ -n "${sg_id}" ]; then
    echo -e "Region ${r}, Found security group ID(s):\n${sg_id}\nRemoving..."
    for i in ${sg_id//\\n/ }
    do
      aws ec2 delete-security-group --group-id "${i}" --region "${r}" 2> /dev/null || echo "Did not remove ${i}. Moving on."
    done
  else
    echo "Did not find security group in region ${r}. Moving on."
  fi
done
