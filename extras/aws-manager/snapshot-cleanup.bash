#!/bin/bash

# Removes unused snapshots.

set -euo pipefail

echo "Usage: $0"
echo -ne "jq needs to be present. "
which jq

for r in "us-east-1" "us-east-2" "us-west-1" "us-west-2" "ca-central-1" "sa-east-1" "eu-west-1" "eu-west-2" "eu-west-3" "eu-north-1" "eu-central-1" "ap-south-1" "ap-northeast-1" "ap-northeast-2" "ap-southeast-1" "ap-southeast-2"
do
  id=$(aws ec2 describe-snapshots --owner-ids 400392161012 --filters Name=status,Values="completed" --filters Name=tag:OS,Values="Interchain Nightking Amazon Linux" --region $r | jq -r .Snapshots[].SnapshotId)
  if [ -n "${id}" ]; then
    echo -e "Region ${r}, Found ID(s):\n${id}\nRemoving..."
    for i in ${id//\\n/ }
    do
      aws ec2 delete-snapshot --snapshot-id "${i}" --region "${r}" 2> /dev/null || echo "Did not remove ${i}. Moving on."
    done
  else
    echo "Did not find image in region ${r}. Moving on."
  fi
done
