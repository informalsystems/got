#!/usr/bin/env bash
###
### For developer use
###
set -euo pipefail
FAST=1 source /usr/local/sbin/library.bash

PREVIOUS_INFRA="$(peek-cache infra || echo '')"

if [ -n "${PREVIOUS_INFRA}" ]; then
  cd /root/terraform-"${PREVIOUS_INFRA}"
  terraform destroy --force
  rm -f "${CACHE_DIR}/infra"
fi
