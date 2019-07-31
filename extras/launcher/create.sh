#!/bin/sh

##
# Create a new nightking server using terraform
##
set +euo pipefail

if [ -z "${1}" ]; then
  echo "Usage: ${0} <ami-1234456785>"
  exit 1
fi

MYIP="$(curl -s http://whatismyip.akamai.com/)"

terraform init
terraform apply -var user-ip="${MYIP}" -var nightking-ami="${1}" --auto-approve

