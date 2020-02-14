#!/usr/bin/env bash

set -euo pipefail

source /usr/local/sbin/library.bash
# Not using get-flag here, because this might run multiple times and the calling script still has to continue (instead of exit 1)
if [ -n "$(peek-flag pool-setup-finished)" ]; then
  exit
fi

# Set up SSH keys
# I wish to use ed25519 keys but these keys also end up as key-pairs for AWS which only supports rsa.
ssh-keygen -f /root/pool.key -N '' -o -q -t rsa
cat /root/pool.key | tr '\n' '$' > /var/log/nightking/cache/pool.key
chmod 400 /var/log/nightking/cache/pool.key
mv /root/pool.key "${LOG_DIR}"

mv /root/pool.key.pub "${EXPERIMENTS_DIR}"/.pool
chmod 400 "${EXPERIMENTS_DIR}"/.pool
chown pool "${EXPERIMENTS_DIR}"/.pool

set-flag pool-setup-finished
