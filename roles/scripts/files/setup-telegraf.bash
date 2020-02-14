#!/usr/bin/env bash

set -euo pipefail

source /usr/local/sbin/library.bash
get-flag telegraf-setup-finished

# Disable example influxdb setup in main config
sed -i 's/^\(\s\|#\)*\[\[outputs\.influxdb\]\].*$/#[[outputs.influxdb]]/' /etc/telegraf/telegraf.conf

if [ "${ROLE}" != "nightking" ]; then
  echo "${NIGHTKING_IP}   nightking.got" >> /etc/hosts
  hostname "${ROLE}${ID}" #This is important so Grafana shows the right hostnames

  CERTCHECKCOUNTER=0
  while [ ! -f /var/log/nightking/ca.crt ];
  do
    sleep 1
    CERTCHECKCOUNTER="$(expr "$CERTCHECKCOUNTER" + 1)"
    if [ "$CERTCHECKCOUNTER" -ge 120 ]; then
      echo "Startup failed: could not find CA certificate." > "${LOG_DIR}/startup-error"
      exit
    fi
  done
fi

# Add real influx connection
cat << EOF > /etc/telegraf/telegraf.d/influx.conf
[[outputs.influxdb]]
  urls = ["https://nightking.got:8086"]
  skip_database_creation = true
  username = "telegraf"
  password = "${INFLUX_TELEGRAF_PASSWORD}"
EOF
echo "${INFLUX_TELEGRAF_PASSWORD}" > "${LOG_DIR}/influx-telegraf-password"
chmod 400 "${LOG_DIR}/influx-telegraf-password"
chmod 0440 /etc/telegraf/telegraf.d/influx.conf
chgrp telegraf /etc/telegraf/telegraf.d/influx.conf

systemctl enable telegraf
systemctl restart telegraf

set-flag telegraf-setup-finished
