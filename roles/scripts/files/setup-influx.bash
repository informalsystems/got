#!/usr/bin/env bash

set -euo pipefail

test -f /var/log/nightking/.influx-setup-finished && exit

source /usr/local/sbin/library.bash
# Do not use the log function here, since influxdb is not set up yet.

systemctl start influxdb
sleep 5
influx -precision rfc3339 -execute "CREATE USER admin WITH PASSWORD '${INFLUX_ADMIN_PASSWORD}' WITH ALL PRIVILEGES; CREATE DATABASE telegraf; CREATE USER telegraf WITH PASSWORD '${INFLUX_TELEGRAF_PASSWORD}'; GRANT ALL ON telegraf TO telegraf"
systemctl stop influxdb

#Set up minimal config changes
# Enable HTTPS
sed -i 's/^\(\s\|#\)*https-enabled =.*$/  https-enabled = true/' /etc/influxdb/influxdb.conf
# Enable user authentication over HTTPS
sed -i 's/^\(\s\|#\)*auth-enabled =.*$/  auth-enabled = true/' /etc/influxdb/influxdb.conf
# Enforce min/max TLS version
sed -i 's/^\(\s\|#\)*\(min\|max\)-version/  \2-version/' /etc/influxdb/influxdb.conf

systemctl enable influxdb
systemctl start influxdb
sleep 5

touch /var/log/nightking/.influx-setup-finished
