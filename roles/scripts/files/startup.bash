#!/usr/bin/env bash
exec > /var/log/nightking/startup.output
exec 2>&1
set -euo pipefail

if [ ! -f /var/log/nightking/flag/user-data-finished ]; then
  source /usr/local/sbin/library.bash || echo "At first run of startk/whitewalker, the library.bash can't populate until user-data finished."
  if [ "${ROLE}" != "nightking" ]; then
    # Wait for user-data to finish before everything else
    USERDATACOUNTER=0
    while [ ! -f /var/log/nightking/flag/user-data-finished ];
    do
      sleep 1
      USERDATACOUNTER="$(expr "USERDATACOUNTER" + 1)"
      if [ "USERDATACOUNTER" -ge 120 ]; then
        echo "Startup failed: could not wait for user-data to finish." > "${LOG_DIR}/startup-error"
        exit
      fi
    done
    #Repopulate cache
    rm "${CACHE_DIR}"/*
    source /usr/local/sbin/library.bash
  fi
else
  source /usr/local/sbin/library.bash
fi

rm -rf "${LOG_DIR}/startup-error"

#Run once
if [ -z "$(peek-flag startup-finished)" ]; then
  ntpdate pool.ntp.org || echo "ntpdate did not run. That's ok."
  systemctl start ntpd
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
  # Get a pool.key and do not autorun experiments in DEV mode
    POOLKEYCOUNTER=0
    while [ ! -f /var/log/nightking/cache/pool.key ];
    do
      sleep 1
      POOLKEYCOUNTER="$(expr "POOLKEYCOUNTER" + 1)"
      if [ "POOLKEYCOUNTER" -ge 120 ]; then
        echo "Startup failed: could not find pool key in DEV mode." > "${LOG_DIR}/startup-error"
        exit
      fi
    done
    exit
fi

#Do not autorun experiments if noautorun was defined at AMI build and no experimetns were defined in the tags
if [ "${EXPERIMENTS}" == "" ]; then
  get-flag noautorun
fi

/usr/local/sbin/run-role.bash
