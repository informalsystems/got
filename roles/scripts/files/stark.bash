#!/usr/bin/env bash
exec > /var/log/nightking/stark-$(date +%Y%m%d-%H%M%S).output
exec 2>&1
set -euo pipefail
source /usr/local/sbin/library.bash

set -x

## Sanitize EXPERIMENT input
trap 'log node 10' ERR
if [ "${EXPERIMENTS}" == "" ] || [ ! -d /etc/experiments/"${EXPERIMENTS}" ]; then
  EXPERIMENTS=$(ls /etc/experiments | head -1)
fi
export XP="${EXPERIMENTS}"
log experiment 0

# Set up tendermint node
trap 'log node 10' ERR
log "node{$ID}" 1
sudo -u tendermint tendermint init
sudo -u tendermint tendermint unsafe_reset_all
if [ -f /etc/experiments/"${XP}"/genesis.json ]; then
  mkdir -p /home/tendermint/.tendermint/config/
  stemplate /etc/experiments/"${XP}"/genesis.json -o /home/tendermint/.tendermint/config/ --env -f /etc/experiments/"${XP}"/config.toml
fi
if [ -d /etc/experiments/"${XP}"/node ]; then
  mkdir -p /home/tendermint/.tendermint/config/
  stemplate /etc/experiments/"${XP}"/node/ -o /home/tendermint/.tendermint/ --env -f /etc/experiments/"${XP}"/config.toml --all
fi
if [ -d /etc/experiments/"${XP}"/node"${ID}" ]; then
  mkdir -p /home/tendermint/.tendermint/config/
  stemplate /etc/experiments/"${XP}"/node"${ID}" -o /home/tendermint/.tendermint/ --env -f /etc/experiments/"${XP}"/config.toml --all
fi
chown -R tendermint.tendermint /home/tendermint/.tendermint
sudo -u tendermint tendermint show_node_id > /var/log/nightking/node_id
systemctl start tendermint
log "node${ID}" 0
trap '' ERR
