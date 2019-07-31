#!/usr/bin/env bash
exec > /var/log/nightking/startup.output
exec 2>&1
set -euo pipefail

source /usr/local/sbin/library.bash

if [ ! -f /var/log/nightking/.startup-finished ]; then
  if [ "${ROLE}" == "nightking" ]; then
    # Create InfluxDB and Grafana for monitoring
    /usr/local/sbin/create-tls.bash
    /usr/local/sbin/setup-influx.bash
    /usr/local/sbin/setup-grafana.bash
  fi
  /usr/local/sbin/setup-telegraf.bash
  touch /var/log/nightking/.startup-finished
fi


case "${ROLE}" in
  "nightking")
    /usr/local/sbin/nightking.bash
    ;;
  "whitewalker")
    /usr/local/sbin/whitewalker.bash
    ;;
  "stark")
    /usr/local/sbin/stark.bash
    ;;
  *)
    echo "Cannot understand ROLE=${ROLE}" > /var/log/nightking/.startup-error
    ;;
esac
