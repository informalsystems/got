#!/usr/bin/env bash

set -euo pipefail

test -f /var/log/nightking/.grafana-setup-finished && exit

source /usr/local/sbin/library.bash

# Enable HTTPS
sed -i 's/^\(\s\|;\|#\)*protocol\s*=.*$/protocol = https/' /etc/grafana/grafana.ini
# Set HTTPS port to 443
sed -i 's/^\(\s\|;\|#\)*http_port\s*=.*$/http_port = 443/' /etc/grafana/grafana.ini
# Enable gzip compression
sed -i 's/^\(\s\|;\|#\)*enable_gzip\s*=.*$/enable_gzip = true/' /etc/grafana/grafana.ini
# Set HTTPS public key
sed -i 's,^\(\s\|;\|#\)*cert_file\s*=.*$,cert_file = /etc/ssl/nightking.crt,' /etc/grafana/grafana.ini
# Set HTTPS private key
sed -i 's,^\(\s\|;\|#\)*cert_key\s*=.*$,cert_key = /etc/ssl/nightking.key,' /etc/grafana/grafana.ini

cat << EOF > /etc/grafana/provisioning/datasources/influx.yaml
apiVersion: 1
datasources:
  - name: influx
    type: influxdb
    access: proxy
    url: https://${PUBLIC_HOSTNAME}:8086
    user: telegraf
    password: ${INFLUX_TELEGRAF_PASSWORD}
    database: telegraf
    isDefault: true
    editable: false
    jsonData:
      httpMode: GET
EOF
chmod 440 /etc/grafana/provisioning/datasources/influx.yaml
chgrp grafana /etc/grafana/provisioning/datasources/influx.yaml

cat << EOF > /etc/grafana/provisioning/dashboards/nightking.yaml
apiVersion: 1
providers:
 - name: 'default'
   orgId: 1
   folder: ''
   type: file
   options:
     path: /var/lib/grafana/dashboards
EOF
chmod 440 /etc/grafana/provisioning/dashboards/nightking.yaml
chgrp grafana /etc/grafana/provisioning/dashboards/nightking.yaml

systemctl daemon-reload
systemctl enable grafana-server
systemctl start grafana-server
sleep 3

# Set Home page
set +e # Debug
NIGHTKING_ID="$(curl -s -H "Content-Type: application/json" "https://admin:admin@${PUBLIC_HOSTNAME}/api/search?folderIds=0&query=Nightking%20status" | jq .[0].id)"
curl -X PUT -s -H "Content-Type: application/json" "https://admin:admin@${PUBLIC_HOSTNAME}/api/user/preferences" -d "{\"homeDashboardId\":${NIGHTKING_ID}}"

touch /var/log/nightking/.grafana-setup-finished
log tick 0

# Change web password
set +e
LOG_PASSWORD=0
trap 'log password 11 ; exit' ERR
if [ "${PASSWORD_TAG}" == "admin" ]; then
  log password 12
  exit
else
  pw_data="{\"oldPassword\":\"admin\",\"newPassword\":\"${PASSWORD_TAG}\",\"confirmNew\":\"${PASSWORD_TAG}\"}"
  PW_RESULT="$(curl -X PUT -H "Content-Type: application/json" -d "${pw_data}" "https://admin:admin@${PUBLIC_HOSTNAME}/api/user/password")"
  if [[ "${PW_RESULT}" == "{\"message\":\"New password is too short\"}" ]]; then
    log password 10
    exit
  fi
fi

log password 0
set -e
