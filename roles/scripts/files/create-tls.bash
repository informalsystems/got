#!/usr/bin/env bash

set -euo pipefail

source /usr/local/sbin/library.bash
get-flag tls-setup-finished

hostname "nightking.got"
echo "127.0.0.1   nightking.got" >> /etc/hosts

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
  echo "nightking.got"
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
cat /etc/pki/CA/cacert.pem >> /etc/ssl/certs/ca-bundle.crt #OS Trusted CA
cat /etc/pki/CA/cacert.pem | tr '\n' '$' > "${LOG_DIR}/ca.crt" #Prepare for terraform shipping
cp /etc/pki/CA/cacert.pem /usr/share/nginx/html/nightkingca.crt #File offered on HTTP for download

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

set-flag tls-setup-finished
