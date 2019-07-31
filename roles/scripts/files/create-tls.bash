#!/usr/bin/env bash

set -euo pipefail

test -f /var/log/nightking/.tls-setup-finished && exit

source /usr/local/sbin/library.bash

hostname "${PUBLIC_HOSTNAME}"
echo "127.0.0.1   ${PUBLIC_HOSTNAME}" >> /etc/hosts

DATE="$(date '+%Y-%m-%d %H:%M:%S')"
ca() {
  echo "CA"
  echo "Ontario"
  echo "Toronto"
  echo "Game of Tendermint"
  echo ""
  echo "Nightking CA - ${DATE}"
  echo "hello@interchain.io"
  echo ""
  echo ""
}

nightking() {
  echo "CA"
  echo "Ontario"
  echo "Toronto"
  echo "Game of Tendermint"
  echo ""
  echo "${PUBLIC_HOSTNAME}"
  echo "hello@interchain.io"
  echo ""
  echo ""
}

# Create CA
openssl genrsa -out /etc/pki/CA/private/cakey.pem
chmod 400 /etc/pki/CA/private/cakey.pem
ca | openssl req -key /etc/pki/CA/private/cakey.pem -new -x509 -days 365 -extensions v3_ca -out /etc/pki/CA/cacert.pem
test -f /etc/pki/CA/index.txt || touch /etc/pki/CA/index.txt
test -f /etc/pki/CA/serial || echo "00" > /etc/pki/CA/serial

# Accept CA certificate on system
cat /etc/pki/CA/cacert.pem >> /etc/ssl/certs/ca-bundle.crt
cat /etc/pki/CA/cacert.pem | tr '\n' '$' > /var/log/nightking/ca.crt
cp /etc/pki/CA/cacert.pem /usr/share/nginx/html/nightkingca.crt

# Nightking certificate
openssl genrsa -out /etc/ssl/nightking.key
chmod 440 /etc/ssl/nightking.key
nightking | openssl req -key /etc/ssl/nightking.key -new -out /root/nightking.csr
echo -ne "y\ny\n" | openssl ca -extensions v3_req -in /root/nightking.csr -out /etc/ssl/nightking.crt
chgrp grafana /etc/ssl/nightking.crt
chgrp grafana /etc/ssl/nightking.key

# InfluxDB certificate
cat /etc/ssl/nightking.key /etc/ssl/nightking.crt > /etc/ssl/influxdb.pem
chmod 400 /etc/ssl/influxdb.pem
chown influxdb.influxdb /etc/ssl/influxdb.pem

touch /var/log/nightking/.tls-setup-finished
