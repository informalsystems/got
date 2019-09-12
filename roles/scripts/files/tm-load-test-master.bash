#!/usr/bin/env bash
exec > /var/log/nightking/tm-load-test-master-$(date +%Y%m%d-%H%M%S).output
exec 2>&1
set -euo pipefail
source /usr/local/sbin/library.bash

tm-load-test \
    --broadcast-tx-method {{ .tm_load_test.broadcast_tx_method }} \
    --client-factory {{ .tm_load_test.client_factory }} \
    -c {{ .tm_load_test.connections }} \
    -N {{ .tm_load_test.tx_count }} \
    -r {{ .tm_load_test.tx_rate }} \
    -p {{ .tm_load_test.tx_send_period }} \
    -s {{ .tm_load_test.tx_size }} \
    -T {{ .tm_load_test.time }} \
    --endpoint-select-method {{ .tm_load_test.endpoint_select_method }} \
    --endpoints "{{ .tm_load_test.endpoints }}" \
    --expect_peers {{ .tm_load_test.expect_peers }} \
    --max-endpoints {{ .tm_load_test.max_endpoints }} \
    --min-peer-connectivity $(expr {{ .tm_load_test.min_peer_connectivity  }}) \
    --peer-connect-timeout {{ .tm_load_test.peer_connect_timeout }} \
    -v \
    master \
    --bind "{{ .tm_load_test.master_bind }}" \
    --expect-slaves {{ .tm_load_test.master_expect_slaves }} \
    --connect-timeout {{ .tm_load_test.master_slave_connect_timeout }} \
    --shutdown-wait {{ .tm_load_test.master_shutdown_wait }}
