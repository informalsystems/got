#!/bin/sh

##
# Destroy nightking server created by terraform
##
set +euo pipefail

MYIP="$(curl -s http://whatismyip.akamai.com/)"

terraform destroy -var user-ip="${MYIP}" -var nightking-ami="xxx" --force

