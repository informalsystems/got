#!/usr/bin/env bash
exec > /var/log/nightking/stark-$(date +%Y%m%d-%H%M%S).output
exec 2>&1
set -euo pipefail
source /usr/local/sbin/library.bash

## Sanitize EXPERIMENT input
trap 'log node 10' ERR
set +u # Allow optional $1
if [ -n "${1}" ]; then
  export XP="${1}"
else
  export XP="${EXPERIMENTS}"
fi
set -u
log experiment 0

# Get experiment from nightking
if [ -n "${DEV}" ]; then
  rm -rf "${EXPERIMENTS_DIR}/${XP}"
  sftp -q -r -P 2222 -i "${CACHE_DIR}/pool.key" pool@nightking.got:"${XP}" "${EXPERIMENTS_DIR}"
fi

# Set up tendermint node
trap 'log node 10' ERR
log "node{$ID}" 1
setup-tendermint "${XP}"
log "node${ID}" 0
trap '' ERR
