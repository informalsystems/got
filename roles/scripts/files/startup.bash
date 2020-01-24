#!/usr/bin/env bash
exec > /var/log/nightking/startup.output
exec 2>&1
set -euo pipefail

# Check if user-data has finished on stark and whitewalker nodes. Only start execution after that.
if [ ! -f /var/log/nightking/flag/user-data-finished ]; then
  source /usr/local/sbin/library.bash light
  if [ "$(get role)" != "nightking" ]; then
    wait_for_file /var/log/nightking/flag/user-data-finished || (echo "Startup failed: could not wait for user-data to finish." > "${LOG_DIR}/startup-error"; exit)
  fi
fi

source /usr/local/sbin/library.bash
rm -rf "${LOG_DIR}/startup-error"

#Run once and setup basic services
if [ -z "$(peek-flag startup-finished)" ]; then
  if [ "${ROLE}" == "nightking" ]; then
    # Create InfluxDB and Grafana for monitoring
    /usr/local/sbin/create-tls.bash
    /usr/local/sbin/setup-influx.bash
    /usr/local/sbin/setup-grafana.bash
  fi
  /usr/local/sbin/setup-telegraf.bash
  set-flag startup-finished
  systemctl enable ntpd
fi

#Check at every startup - DEV mode settings
if [ -n "${DEV}" ]; then
  if [ "${ROLE}" == "nightking" ]; then
    /usr/local/sbin/setup-pool.bash
    systemctl start sftpd
  else
    mkdir -p "${HOME}/.ssh"
    echo "${NIGHTKING_HOST_KEY}" > "${HOME}/.ssh/known_hosts"
    chmod 500 "${HOME}/.ssh"
    chmod 400 "${HOME}/.ssh/known_hosts"
  fi
    # Get a pool.key
    wait_for_file /var/log/nightking/cache/pool.key || (echo "Startup failed: could not find pool key in DEV mode." > "${LOG_DIR}/startup-error"; exit)
    # Do not autorun experiments in DEV mode
    exit
fi

#Do not autorun experiments if noautorun was defined at AMI build and no experiments were defined in the tags
if [ "${EXPERIMENTS}" == "" ]; then
  get-flag noautorun
fi

# Execute the role of the server
/usr/local/sbin/runxp
