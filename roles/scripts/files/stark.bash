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
systemctl stop tendermint
sudo -u tendermint tendermint init
sudo -u tendermint tendermint unsafe_reset_all
if [ -f "${EXPERIMENTS_DIR}/${XP}/genesis.json" ]; then
  mkdir -p /home/tendermint/.tendermint/config/
  stemplate "${EXPERIMENTS_DIR}/${XP}/genesis.json" -o /home/tendermint/.tendermint/config/ --env -f "${EXPERIMENTS_DIR}/${XP}/config.toml"
fi
if [ -d "${EXPERIMENTS_DIR}/${XP}/node" ]; then
  mkdir -p /home/tendermint/.tendermint/config/
  stemplate "${EXPERIMENTS_DIR}/${XP}/node/" -o /home/tendermint/.tendermint/ --env -f "${EXPERIMENTS_DIR}/${XP}/config.toml" --all
fi
if [ -d "${EXPERIMENTS_DIR}/${XP}/node${ID}" ]; then
  mkdir -p /home/tendermint/.tendermint/config/
  stemplate "${EXPERIMENTS_DIR}/${XP}/node${ID}" -o /home/tendermint/.tendermint/ --env -f "${EXPERIMENTS_DIR}/${XP}/config.toml" --all
fi
chown -R tendermint.tendermint /home/tendermint/.tendermint
sudo -u tendermint tendermint show_node_id > /var/log/nightking/node_id
systemctl start tendermint
log "node${ID}" 0
trap '' ERR
