#!/usr/bin/env bash

##
# library.bash - a set of reusable bash functions. Usage: `source library.bash`
##
# Optional variable $FAST can be set to avoid importing values that take a long time to look up: DEBUG, DEV, EXPERIMENTS.
# Optional input parameter "light" can be set to avoid filling up variables and import only functions.

export LOG_DIR="/var/log/nightking"
export CACHE_DIR="${LOG_DIR}/cache"
export FLAG_DIR="${LOG_DIR}/flag"
export EXPERIMENTS_DIR=/etc/experiments
export MAX_PARALLEL_SSH=20

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
    "nightking-namestamp")
        peek-cache "${1}" || get-tag-cached "${1}" "$(random 8)"
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
    "infra")
        peek-cache infra || echo ''
        ;;
    *)
        echo "get: invalid variable: ${1}"
        false
        ;;
  esac
}

# Get cache value if exists. If not, set errorcode to 1.
peek-cache() {
  cat "${CACHE_DIR}/${1}" 2> /dev/null
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
# $1 - tag name, $2 - (optional) default value
get-tag-cached() {
  # Set in cache
  if [ ! -f "${CACHE_DIR}/${1}" ]; then
    # Get from AWS
    get-tag "${1}" > "${CACHE_DIR}/${1}"
    #Secure it
    #chmod 440 "${CACHE_DIR}/${1}"
    #Set default
    test -n "$(cat "${CACHE_DIR}/${1}")" || echo "${2:-}" > "${CACHE_DIR}/${1}"
  fi
  # Get from cache
  peek-cache "${1}"
}

#Get a random string. Optionally, enter length. (defaults to 32)
random() {
  openssl rand -base64 48 | tr -dc a-zA-Z0-9 | head -c "${1:-32}"
}

# Log script results to influx DB
log() {
  influx -ssl -host nightking.got -username telegraf -password "$(get influx-telegraf-password)" -database telegraf -execute "INSERT $(get role)$(get id) ${1}=${2}" || echo "Logging $1 $2 failed." >> "${LOG_DIR}/error.log"
}

wait_for_file() {
  COUNTER=0
  while [ "${COUNTER}" -lt 120 ] && [ ! -f "${1}" ];
  do
    sleep 1
    COUNTER="$(expr "${COUNTER}" + 1)"
  done
  test -f "${1}"
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

# Set up tendermint configuration and service.
# Input parameter: experiment name
# Todo: collapse setting up Nightking seed node and any other node. Possibly node0 should be the nightking Tendermint node.
setup-tendermint() {
  systemctl stop tendermint || true
  sudo -u tendermint tendermint init
  sudo -u tendermint tendermint unsafe_reset_all
  if [ -f "${EXPERIMENTS_DIR}/${1}/genesis.json" ]; then
    mkdir -p /home/tendermint/.tendermint/config/
    stemplate "${EXPERIMENTS_DIR}/${1}/genesis.json" -o /home/tendermint/.tendermint/config/ --env -f "${EXPERIMENTS_DIR}/${1}/config.toml"
  fi
  if [ $(get role) != "nightking" ]; then
    if [ -d "${EXPERIMENTS_DIR}/${1}/node" ]; then
      mkdir -p /home/tendermint/.tendermint/config/
      stemplate "${EXPERIMENTS_DIR}/${1}/node/" -o /home/tendermint/.tendermint/ --env -f "${EXPERIMENTS_DIR}/${1}/config.toml" --all
    fi
    if [ -d "${EXPERIMENTS_DIR}/${1}/node${ID}" ]; then
      mkdir -p /home/tendermint/.tendermint/config/
      stemplate "${EXPERIMENTS_DIR}/${1}/node${ID}" -o /home/tendermint/.tendermint/ --env -f "${EXPERIMENTS_DIR}/${1}/config.toml" --all
    fi
  else
    mkdir -p /home/tendermint/.tendermint/config/
    stemplate "${EXPERIMENTS_DIR}/${1}/seed/" -o /home/tendermint/.tendermint/ --env -f "${EXPERIMENTS_DIR}/${1}/config.toml" --all
  fi
  chown -R tendermint.tendermint /home/tendermint/.tendermint
  sudo -u tendermint tendermint show_node_id > "${LOG_DIR}/node_id"
  if [ $(get role) == "nightking" ]; then
    sudo -u tendermint tendermint show_node_id > "${CACHE_DIR}/nightking-seed-node-id"
    export NIGHTKING_SEED_NODE_ID="$(get nightking-seed-node-id)"
  fi
  systemctl start tendermint
}

# Create terraform infrastructure if it does not exist.
# Uses 'log' to log into InfluxDB.
# Changes directory to the terraform infrastructure directory under /root/terraform-<infra>.
setup-terraform() {
  export PREVIOUS_INFRA="$(get infra)"
  export TERRAFORM_RESULT=0
  # Build a new infra
  if [ -z "${PREVIOUS_INFRA}" ]; then
    trap 'log terraform_build 12' ERR
    if [ -n "${DEV}" ]; then
      export SSH_KEY="$(tail -1 /etc/experiments/.pool)"
    else
      export SSH_KEY="$(tail -1 /home/ec2-user/.ssh/authorized_keys)"
    fi
    if [ -f "${EXPERIMENTS_DIR}/${1}"/config.toml ]; then
      stemplate /usr/share/terraform-templates --env -f "${EXPERIMENTS_DIR}/${1}"/config.toml -o /root/terraform-"${1}" --all
    fi
    if [ -d "${EXPERIMENTS_DIR}/${1}"/terraform ]; then
      stemplate "${EXPERIMENTS_DIR}/${1}"/terraform --env -f "${EXPERIMENTS_DIR}/${1}"/config.toml -o /root/terraform-"${1}" --all
    fi
    test -d /root/terraform-"${1}" || echo "Experiment folder /root/terraform-${1} not found."
    test -d /root/terraform-"${1}" || continue
    cd /root/terraform-"${1}"
    trap 'log terraform_build 11' ERR
    log terraform_build 2
    terraform init
    trap 'log terraform_build 10' ERR
    log terraform_build 1
    terraform apply --auto-approve -no-color || export TERRAFORM_RESULT=$?
    if [ ${TERRAFORM_RESULT} -ne 0 ]; then
      log terraform_build 10
      if [ -z "${DEV}" ] && [ -z "${DEBUG}" ]; then
        force-destroy-terraform "${1}"
      fi
    else
      echo "${1}" > "${CACHE_DIR}/infra" #Keep a record of the infra that is fully built
      export PREVIOUS_INFRA="$(get infra)"
      log terraform_build 0
      #When DEV=1, the infrastructure needs to be available before we continue.
      if [ -n "${DEV}" ]; then
        echo "Waiting for infrastructure to stabilize in the cloud."
        sleep 90
      fi
    fi
  else
    cd /root/terraform-"${PREVIOUS_INFRA}"
  fi
}

force-destroy-terraform() {
  echo "Invoking terraform to destroy infrastructure '${1}'."
  cd /root/terraform-"${1}"
  terraform destroy --force
  rm -f "${CACHE_DIR}/infra"
}

_get-terraform-ip() {
    terraform output -state=/root/terraform-"${PREVIOUS_INFRA}"/terraform.tfstate -no-color "${1}"
}

get-all-starks-ip() {
  if [ -n "${PREVIOUS_INFRA}" ]; then
      STARKS_NUM="$(stoml "${EXPERIMENTS_DIR}/${PREVIOUS_INFRA}/config.toml" starks)"
      IP_LIST=""
      for i in $(seq 0 $(expr "${STARKS_NUM}" - 1))
      do
        IP_LIST="${IP_LIST} $(_get-terraform-ip stark"${i}")"
      done
      echo "${IP_LIST## }"
  fi
}

get-all-whitewalkers-ip() {
  if [ -n "${PREVIOUS_INFRA}" ]; then
      WHITEWALKERS_NUM="$(stoml "${EXPERIMENTS_DIR}/${PREVIOUS_INFRA}/config.toml" whitewalkers)"
      IP_LIST=""
      for i in $(seq 0 $(expr "${WHITEWALKERS_NUM}" - 1))
      do
        IP_LIST="${IP_LIST} $(_get-terraform-ip whitewalker"${i}")"
      done
      echo "${IP_LIST## }"
  fi
}

import-vars() {
  ## Game of Tendermint role variable $ROLE is used in this script
  export ROLE="$(get role)"

  ## $ROLE-specific variables
  case "${ROLE}" in
    "nightking")
      # Debug flag set in AWS tag (slow)
      test -n "${FAST:-}" || export DEBUG="$(get debug)"
      # InfluxDB Admin variable
      export INFLUX_ADMIN_PASSWORD="$(get influx-admin-password)"
      # Grafana web interface password set in AWS tag
      export PASSWORD_TAG="$(get password)"
      # Fully-built terraform infrastructure name - managed by setup-terraform/destroy-terraform scripts
      export PREVIOUS_INFRA="$(peek-cache infra || echo '')"
      # Nightking namestamp is used in AWS to distinguish between infrastructure elements created by different nightking nodes
      export NIGHTKING_NAMESTAMP="$(get nightking-namestamp)"

      # Get AMI owner
      export AMI_OWNER="$(get ami-owner)"
      # Get AMI name
      export AMI_NAME="$(get ami-name)"

      ;;
    "stark"|"whitewalker")
    export NIGHTKING_SEED_NODE_ID="$(get nightking-seed-node-id)"
  esac

  ## Common variables for all servers
  # DEV flag set in AWS tag (slow)
  test -n "${FAST:-}" || export DEV="$(get dev)"
  # Experiments listed in AWS tag (slow)
  test -n "${FAST:-}" || export EXPERIMENTS="$(get experiments)"
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
}

##
# Automatically create and export all variables used by scripts and terraform.
# The "light" option does not populate all variables. Useful at startup when not everything can be populated yet.
##
if [ "${1:-}" != "light" ]; then
  import-vars
fi

complete -W "$(get role) startup tm-load-test" nlog
complete -W "nightking startup tm-load-test tendermint" rlog
