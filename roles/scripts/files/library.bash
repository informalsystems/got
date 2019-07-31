#!/usr/bin/env bash

##
# library.bash - a set of reusable bash functions. Usage: `source library.bash`
##


# Get public hostname
get-public-hostname() {
  test -f /var/log/nightking/public-hostname || curl -s http://169.254.169.254/latest/meta-data/public-hostname > /var/log/nightking/public-hostname
  cat /var/log/nightking/public-hostname
}

# Get public ip - always up-to-date
get-public-ip() {
  curl -s http://169.254.169.254/latest/meta-data/public-ipv4
}

# Get private ip - always up-to-date
get-private-ip() {
  hostname -I | tr -d ' '
}

# Get instance ID
get-instance-id() {
  test -f /var/log/nightking/instance-id || curl -s http://169.254.169.254/latest/meta-data/instance-id > /var/log/nightking/instance-id
  cat /var/log/nightking/instance-id
}

# Get instance ID
get-ami() {
  test -f /var/log/nightking/ami || curl -s http://169.254.169.254/latest/meta-data/ami-id > /var/log/nightking/ami
  cat /var/log/nightking/ami
}

# Get AWS region
get-aws-region() {
  test -f /var/log/nightking/aws-region || curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/[a-z]$//' > /var/log/nightking/aws-region
  cat /var/log/nightking/aws-region
}

# Get InfluxDB password for Telegraf
get-influx-telegraf-password() {
  if [ "$(get-role)" == "nightking" ]; then
    test -f /var/log/nightking/influx-telegraf-password || (openssl rand -base64 48 > /var/log/nightking/influx-telegraf-password && chmod 400 /var/log/nightking/influx-telegraf-password)
  else
    test -f /var/log/nightking/influx-telegraf-password || (aws ec2 describe-tags --region "$(get-aws-region)" --filters "Name=resource-id,Values=$(get-instance-id)" | jq -r '.Tags[] | select( .Key | ascii_downcase == "telegraf" ).Value' > /var/log/nightking/influx-telegraf-password && chmod 400 /var/log/nightking/influx-telegraf-password)
  fi
  cat /var/log/nightking/influx-telegraf-password
}

# Get InfluxDB password for Admin
get-influx-admin-password() {
  test -f /var/log/nightking/influx-admin-password || (openssl rand -base64 48 > /var/log/nightking/influx-admin-password && chmod 400 /var/log/nightking/influx-admin-password)
  cat /var/log/nightking/influx-admin-password
}

# Get password tag for website
get-password-tag() {
  test -f /var/log/nightking/password_tag || (aws ec2 describe-tags --region "$(get-aws-region)" --filters "Name=resource-id,Values=$(get-instance-id)" | jq -r '.Tags[] | select( .Key | ascii_downcase == "password" ).Value' > /var/log/nightking/password_tag && chmod 400 /var/log/nightking/password_tag && if [ -z "$(cat /var/log/nightking/password_tag)" ]; then echo "admin" > /var/log/nightking/password_tag; fi)
  cat /var/log/nightking/password_tag
}

# Get debug tag
get-debug-tag() {
  test -f /var/log/nightking/debug || (aws ec2 describe-tags --region "$(get-aws-region)" --filters "Name=resource-id,Values=$(get-instance-id)" | jq -r '.Tags[] | select( .Key | ascii_downcase == "debug" ).Value' > /var/log/nightking/debug && chmod 400 /var/log/nightking/debug)
  cat /var/log/nightking/debug
}

# Get experiments in a space-separated list - always up-to-date
get-experiments() {
  aws ec2 describe-tags --region "$(get-aws-region)" --filters "Name=resource-id,Values=$(get-instance-id)" | jq -r '.Tags[] | select( .Key | ascii_downcase == "experiments" ).Value' | tr ',' ' '
}

# Log script results to influx DB
# Todo: make it more versatile: it only works on nightking right now.
log() {
  influx -ssl -host "$(get-nightking-hostname)" -username telegraf -password "$(get-influx-telegraf-password)" -database telegraf -execute "INSERT $(get-role)$(get-id) ${1}=${2}"
}


# Get server role (nightking/whitewalker/stark)
get-role() {
  test -f /var/log/nightking/role || (aws ec2 describe-tags --region "$(get-aws-region)" --filters "Name=resource-id,Values=$(get-instance-id)" | jq -r '.Tags[] | select( .Key | ascii_downcase == "role" ).Value' > /var/log/nightking/role && chmod 400 /var/log/nightking/role && if [ -z "$(cat /var/log/nightking/role)" ]; then echo "nightking" > /var/log/nightking/role; fi)
  cat /var/log/nightking/role
}

# Get nightking hostname
get-nightking-hostname() {
  if [ "$(get-role)" == "nightking" ]; then
    test -f /var/log/nightking/nightking-hostname || get-public-hostname > /var/log/nightking/nightking-hostname
  else
    test -f /var/log/nightking/nightking-hostname || (aws ec2 describe-tags --region "$(get-aws-region)" --filters "Name=resource-id,Values=$(get-instance-id)" | jq -r '.Tags[] | select( .Key | ascii_downcase == "nightking-hostname" ).Value' > /var/log/nightking/nightking-hostname && chmod 400 /var/log/nightking/nightking-hostname)
  fi
  cat /var/log/nightking/nightking-hostname
}

# Get nightking public IP
get-nightking-ip() {
  if [ "$(get-role)" == "nightking" ]; then
    test -f /var/log/nightking/nightking-ip || get-public-ip > /var/log/nightking/nightking-ip
  else
    test -f /var/log/nightking/nightking-ip || (aws ec2 describe-tags --region "$(get-aws-region)" --filters "Name=resource-id,Values=$(get-instance-id)" | jq -r '.Tags[] | select( .Key | ascii_downcase == "nightking-ip" ).Value' > /var/log/nightking/nightking-ip && chmod 400 /var/log/nightking/nightking-ip)
  fi
  cat /var/log/nightking/nightking-ip
}

# Get nightking private IP
get-nightking-private-ip() {
  if [ "$(get-role)" == "nightking" ]; then
    test -f /var/log/nightking/nightking-private-ip || get-private-ip > /var/log/nightking/nightking-private-ip
  else
    test -f /var/log/nightking/nightking-private-ip || (aws ec2 describe-tags --region "$(get-aws-region)" --filters "Name=resource-id,Values=$(get-instance-id)" | jq -r '.Tags[] | select( .Key | ascii_downcase == "nightking-private-ip" ).Value' > /var/log/nightking/nightking-private-ip && chmod 400 /var/log/nightking/nightking-private-ip)
  fi
  cat /var/log/nightking/nightking-private-ip
}

# Get node ID
get-id() {
  if [ "$(get-role)" == "nightking" ]; then
    test -f /var/log/nightking/id || echo "0" > /var/log/nightking/id
  else
    test -f /var/log/nightking/id || (aws ec2 describe-tags --region "$(get-aws-region)" --filters "Name=resource-id,Values=$(get-instance-id)" | jq -r '.Tags[] | select( .Key | ascii_downcase == "id" ).Value' > /var/log/nightking/id && chmod 400 /var/log/nightking/id)
  fi
  cat /var/log/nightking/id
}

# Get seed node ID
get-nightking-seed-node-id() {
  if [ "$(get-role)" == "nightking" ]; then
    test -f /var/log/nightking/seed_node_id || return
  else
    test -f /var/log/nightking/seed_node_id || (aws ec2 describe-tags --region "$(get-aws-region)" --filters "Name=resource-id,Values=$(get-instance-id)" | jq -r '.Tags[] | select( .Key | ascii_downcase == "nightking-seed-node-id" ).Value' > /var/log/nightking/seed_node_id && chmod 400 /var/log/nightking/seed_node_id)
  fi
  cat /var/log/nightking/seed_node_id
}

# Get CA certificate
get-ca-cert() {
  if [ "$(get-role)" != "nightking" ]; then
    test -f /var/log/nightking/ca.crt || (aws ec2 describe-tags --region "$(get-aws-region)" --filters "Name=resource-id,Values=$(get-instance-id)" | jq -r '.Tags[] | select( .Key | ascii_downcase == "cacert" ).Value' > /var/log/nightking/ca.crt && chmod 400 /var/log/nightking/ca.crt)
  fi
  cat /var/log/nightking/ca.crt
}

# Get AMI owner
get-ami-owner() {
  if [ "$(get-role)" == "nightking" ]; then
    test -f /var/log/nightking/ami-owner || (aws ec2 describe-images --region "$(get-aws-region)" --image-ids "$(get-ami)" | jq -r '.Images[0].OwnerId' > /var/log/nightking/ami-owner && chmod 400 /var/log/nightking/ami-owner)
  else
    test -f /var/log/nightking/ami-owner || (aws ec2 describe-tags --region "$(get-aws-region)" --filters "Name=resource-id,Values=$(get-instance-id)" | jq -r '.Tags[] | select( .Key | ascii_downcase == "ami-owner" ).Value' > /var/log/nightking/ami-owner && chmod 400 /var/log/nightking/ami-owner)
  fi
  cat /var/log/nightking/ami-owner
}

# Get AMI name
get-ami-name() {
  if [ "$(get-role)" == "nightking" ]; then
    test -f /var/log/nightking/ami-name || (aws ec2 describe-images --region "$(get-aws-region)" --image-ids "$(get-ami)" | jq -r '.Images[0].Name' > /var/log/nightking/ami-name && chmod 400 /var/log/nightking/ami-name)
  else
    test -f /var/log/nightking/ami-name || (aws ec2 describe-tags --region "$(get-aws-region)" --filters "Name=resource-id,Values=$(get-instance-id)" | jq -r '.Tags[] | select( .Key | ascii_downcase == "ami-name" ).Value' > /var/log/nightking/ami-name && chmod 400 /var/log/nightking/ami-name)
  fi
  cat /var/log/nightking/ami-name
}

## Game of Tendermint role variable $ROLE is used in this script to make it easier
export ROLE="$(get-role)"

## $ROLE-specific variables
case "${ROLE}" in
  "nightking")
	# InfluxDB Admin variable
	export INFLUX_ADMIN_PASSWORD="$(get-influx-admin-password)"
	# Grafana web interface password set in AWS tag
	export PASSWORD_TAG="$(get-password-tag)"
	# Debug flag set in AWS tag
	export DEBUG="$(get-debug-tag)"

	# Get AMI owner
	export AMI_OWNER="$(get-ami-owner)"
	# Get AMI name
	export AMI_NAME="$(get-ami-name)"
  	;;
  "stark"|"whitewalker")
	export NIGHTKING_SEED_NODE_ID="$(get-nightking-seed-node-id)"
esac

## Common variables for all servers
# Public hostname variable
export PUBLIC_HOSTNAME="$(get-public-hostname)"
# Public ip variable
export PUBLIC_IP="$(get-public-ip)"
# Private ip variable
export PRIVATE_IP="$(get-private-ip)"
# Instance ID variable
export INSTANCE_ID="$(get-instance-id)"
# AWS AMI ID
export AMI="$(get-ami)"
# AWS region variable
export AWS_REGION="$(get-aws-region)"
# InfluxDB Telegraf password variable

## Variables that are retrieved differently on different $ROLE servers
# Get node ID
export ID="$(get-id)"
export INFLUX_TELEGRAF_PASSWORD="$(get-influx-telegraf-password)"
# Experiments listed in AWS tag
export EXPERIMENTS="$(get-experiments)"
# Nightking hostname variable
export NIGHTKING_HOSTNAME="$(get-nightking-hostname)"
# Nightking public IP variable
export NIGHTKING_IP="$(get-nightking-ip)"
# Nightking IP variable
export NIGHTKING_PRIVATE_IP="$(get-nightking-private-ip)"
# Get CA certificate
export CACERT="$(get-ca-cert)"
