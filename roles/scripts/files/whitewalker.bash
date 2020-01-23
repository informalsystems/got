#!/usr/bin/env bash
exec > /var/log/nightking/whitewalker-$(date +%Y%m%d-%H%M%S).output
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

# Configure this node
export WHITEWALKER_ID="whitewalker${ID}"
# Set up and run tm-load-test master - wait until it finishes
if [ -f "${EXPERIMENTS_DIR}/${XP}"/config.toml ]; then
  # We run stemplate twice to allow for double variable interpolation - 
  # allows us to refer to variables from within the `config.toml` file too
  stemplate /usr/local/sbin/tm-load-test-slave.bash --env -f "${EXPERIMENTS_DIR}/${XP}"/config.toml -o /home/tm-load-test
else
  stemplate /usr/local/sbin/tm-load-test-slave.bash --env -o /home/tm-load-test
fi
chown tm-load-test /home/tm-load-test/tm-load-test-slave.bash
chmod +x /home/tm-load-test/tm-load-test-slave.bash

# Set up tm-load-test
trap 'log whitewalker 10' ERR
log "${WHITEWALKER_ID}" 1

sudo -u tm-load-test \
  /home/tm-load-test/tm-load-test-slave.bash

log "${WHITEWALKER_ID}" 0
trap '' ERR
