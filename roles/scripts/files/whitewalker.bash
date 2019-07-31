#!/usr/bin/env bash
exec > /var/log/nightking/whitewalker-$(date +%Y%m%d-%H%M%S).output
exec 2>&1
set -euo pipefail
source /usr/local/sbin/library.bash

## Sanitize EXPERIMENT input
trap 'log node 10' ERR
if [ "${EXPERIMENTS}" == "" ] || [ ! -d /etc/experiments/"${EXPERIMENTS}" ]; then
  EXPERIMENTS=$(ls /etc/experiments | head -1)
fi
export XP="${EXPERIMENTS}"
log experiment 0

# Set up tm-load-test
trap 'log whitewalker 10' ERR
log "whitewalker{$ID}" 1
stemplate /etc/experiments/"${XP}"/load-test.toml -o /home/tm-load-test/load-test.toml --env -f /etc/experiments/"${XP}"/config.toml
chown tm-load-test /home/tm-load-test/load-test.toml
sudo -u tm-load-test tm-load-test -slave -c /home/tm-load-test/load-test.toml > "/home/tm-load-test/tm-load-test-$(date +%Y%m%h-%H%M%S).log"

log "whitewalker${ID}" 0
trap '' ERR
