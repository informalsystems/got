#!/usr/bin/env bash

set -euo pipefail

source /usr/local/sbin/library.bash
get-flag telegraf-setup-finished

# Disable example influxdb setup in main config
sed -i 's/^\(\s\|#\)*\[\[outputs\.influxdb\]\].*$/#[[outputs.influxdb]]/' /etc/telegraf/telegraf.conf
# Todo: Low priority cleanup: Change the global hostname instead of fixing the telegraf agent config
# This is implemented, but untested, so let's test it.
#sed -i 's/^\(\s\|#\)*hostname\s*=.*$/  hostname = "'"${ROLE}${ID}"'"/' /etc/telegraf/telegraf.conf

if [ "${ROLE}" != "nightking" ]; then
  echo "${NIGHTKING_IP}   nightking.got" >> /etc/hosts
  hostname "${ROLE}${ID}"

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
chmod 0440 /etc/telegraf/telegraf.d/influx.conf
chgrp telegraf /etc/telegraf/telegraf.d/influx.conf

systemctl enable telegraf
systemctl restart telegraf

set-flag telegraf-setup-finished
