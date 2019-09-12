#!/usr/bin/env bash
exec > /var/log/nightking/tm-load-test-slave-$(date +%Y%m%d-%H%M%S).output
exec 2>&1
set -euo pipefail
source /usr/local/sbin/library.bash

tm-load-test \
    -v \
    slave \
    --connect-timeout {{ .tm_load_test.slave_master_connect_timeout }} \
    --master "ws://${NIGHTKING_IP}:26670" \
    --id "whitewalker${ID}"
