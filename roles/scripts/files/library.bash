#!/usr/bin/env bash

##
# library.bash - a set of reusable bash functions. Usage: `source library.bash`
##
# Optional variable $FAST can be set to avoid importing values that take a long time to look up: DEBUG, DEV, EXPERIMENTS


export LOG_DIR="/var/log/nightking"
export CACHE_DIR="${LOG_DIR}/cache"
export FLAG_DIR="${LOG_DIR}/flag"
export EXPERIMENTS_DIR=/etc/experiments

#Get meta tags, instance tags
get() {
  case "${1}" in
#Meta
    "public-ipv4")
        get-meta "${1}"
        ;;
    "instance-id")
        get-meta-cached "${1}"
        ;;
#Tag
    "debug" | "dev")
        get-tag "${1}"
        ;;
    "experiments") #space-separated list
        get-tag "${1}" | tr ',' ' '
        ;;
    "ami-id")
        get-tag-cached "${1}" "$(get-meta "${1}")" #Requires get-meta or else it would go into a loop
        ;;
    "nightking-seed-node-id")
        get-tag-cached "${1}"
        ;;
    "id") #nightking should always be 0, other nodes should always be set
        get-tag-cached "${1}" 0
        ;;
    "influx-telegraf-password" | "influx-admin-password")
        peek-cache "${1}" || get-tag-cached "${1}" "$(random)"
        ;;
    "password") #Grafana initial password
        get-tag-cached "${1}" admin
        ;;
    "role")
        get-tag-cached "${1}" nightking
        ;;
    "nightking-ip")
        peek-cache "${1}" || get-tag-cached "${1}" $(get public-ipv4)
        ;;
    "nightking-private-ip")
        peek-cache "${1}" || get-tag-cached "${1}" "$(get private-ip)"
        ;;
    "ami-owner") #nightking should have image owner, others tag
        peek-cache "${1}" || get-tag-cached "${1}" "$(get image-owner)"
        ;;
    "ami-name") #nightking should have image name, others tag
        peek-cache "${1}" || get-tag-cached "${1}" "$(get image-name)"
        ;;
    "pool.key") # Use it only when DEV=1
        peek-cache "${1}"
        ;;
    "nightking-host-key")
        peek-cache "${1}" || get-tag-cached "${1}" "[nightking.got]:2222 $(cat /etc/ssh/ssh_host_ed25519_key.pub)"
        ;;
#Custom command
    "private-ip")
        hostname -I | tr -d ' '
        ;;
    "aws-region") #Caches AWS region from availability zone
        test -f "${CACHE_DIR}/aws-region" || get-meta placement/availability-zone | sed 's/[a-z]$//' > "${CACHE_DIR}/aws-region"
        cat "${CACHE_DIR}/aws-region"
        ;;
    "image-owner")
        aws ec2 describe-images --region "$(get aws-region)" --image-ids "$(get ami-id)" | jq -r '.Images[0].OwnerId'
        ;;
    "image-name")
        aws ec2 describe-images --region "$(get aws-region)" --image-ids "$(get ami-id)" | jq -r '.Images[0].Name'
        ;;
    "ca-cert") #Only on nightking, only for terraform preparations
        test -f "${LOG_DIR}/ca.crt" && cat "${LOG_DIR}/ca.crt"
        ;;
    *)
        echo "get: invalid variable: ${1}"
        false
        ;;
  esac
}

# Get cache value if exists. If not set errorcode to 1.
peek-cache() {
  cat "${CACHE_DIR}/${1}"
}

# Get meta information from AWS endpoint
get-meta() {
  curl -s http://169.254.169.254/latest/meta-data/"${1}"
}

# Get meta information from cache or from AWS endpoint and store it in cache
get-meta-cached() {
  peek-cache "${1}" || get-meta "${1}" | tee "${CACHE_DIR}/${1}"
}

#Get AWS EC2 instance tag
get-tag() {
    aws ec2 describe-tags --region "$(get aws-region)" --filters "Name=resource-id,Values=$(get-meta-cached instance-id)" | \
      jq -r ".Tags[] | select( .Key | ascii_downcase == \"${1}\" ).Value"
}

# Get AWS EC2 instance tag from cache or from AWS and store it in cache
# $1 - tag name, $2 - default value
get-tag-cached() {
  # Set in cache
  if [ ! -f "${CACHE_DIR}/${1}" ]; then
    # Get from AWS
    get-tag "$@" > "${CACHE_DIR}/${1}"
    #Secure it
    chmod 440 "${CACHE_DIR}/${1}"
    #Set default
    test -n "$(cat "${CACHE_DIR}/${1}")" || echo "${2}" > "${CACHE_DIR}/${1}"
  fi
  # Get from cache
  cat "${CACHE_DIR}/${1}"
}

#Get a random string
random() {
  openssl rand -base64 48
}

# Log script results to influx DB
log() {
  influx -ssl -host nightking.got -username telegraf -password "$(get influx-telegraf-password)" -database telegraf -execute "INSERT $(get role)$(get id) ${1}=${2}"
}


#Check if a flag is set - exit if it is
get-flag() {
  test ! -f "${FLAG_DIR}/${1}" || exit
}

#Check if a flag is set - return 1 if it is
peek-flag() {
  test ! -f "${FLAG_DIR}/${1}" || echo "1"
}

#Set a flag
set-flag() {
  touch "${FLAG_DIR}/${1}"
}

## Game of Tendermint role variable $ROLE is used in this script
export ROLE="$(get role)"

## $ROLE-specific variables
case "${ROLE}" in
  "nightking")
	# InfluxDB Admin variable
	export INFLUX_ADMIN_PASSWORD="$(get influx-admin-password)"
	# Grafana web interface password set in AWS tag
	export PASSWORD_TAG="$(get password)"
	# Debug flag set in AWS tag
	test -n "${FAST:-}" || export DEBUG="$(get debug)"

	# Get AMI owner
	export AMI_OWNER="$(get ami-owner)"
	# Get AMI name
	export AMI_NAME="$(get ami-name)"
  	;;
  "stark"|"whitewalker")
	export NIGHTKING_SEED_NODE_ID="$(get nightking-seed-node-id)"
esac

## Common variables for all servers
# DEV flag set in AWS tag
test -n "${FAST:-}" || export DEV="$(get dev)"
# Public ip variable
export PUBLIC_IP="$(get public-ipv4)"
# Private ip variable
export PRIVATE_IP="$(get private-ip)"
# Instance ID variable
export INSTANCE_ID="$(get instance-id)"
# AWS AMI ID
export AMI="$(get ami)"
# AWS region variable
export AWS_REGION="$(get aws-region)"
# Get node ID
export ID="$(get id)"
# InfluxDB Telegraf password variable
export INFLUX_TELEGRAF_PASSWORD="$(get influx-telegraf-password)"
# Experiments listed in AWS tag
test -n "${FAST:-}" || export EXPERIMENTS="$(get experiments)"
# Nightking public IP variable
export NIGHTKING_IP="$(get nightking-ip)"
# Nightking IP variable
export NIGHTKING_PRIVATE_IP="$(get nightking-private-ip)"
# Get CA certificate
export CACERT="$(get ca-cert)"

## DEV=1 variables
if [ -n "${DEV:-}" ]; then
  export POOL_KEY="$(get pool.key || echo '')"
  export NIGHTKING_HOST_KEY="$(get nightking-host-key)"
fi
