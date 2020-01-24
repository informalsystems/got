#!/usr/bin/env bash
exec > /var/log/nightking/nightking-$(date +%Y%m%d-%H%M%S).output
exec 2>&1
set -euo pipefail
source /usr/local/sbin/library.bash

###
## Sanitize EXPERIMENT input
###
trap 'log experiment 10' ERR
# If there was an input parameter, override tag defaults.
set +u # Allow optional $1
if [ -n "${1}" ]; then
  EXPERIMENTS="${1}"
fi
set -u
# If there were no tags, run all experiments.
if [ "${EXPERIMENTS}" == "" ]; then
  EXPERIMENTS=$(ls "${EXPERIMENTS_DIR}")
# If experiments were defined (either in the command-line or on the tag), run the ones that have config.
else
  CLEANED_EXPERIMENTS=""
  for XP in ${EXPERIMENTS}
  do
    test -d "${EXPERIMENTS_DIR}/${XP}" || echo "Experiment ${XP} folder not found. Skipping..."
    test -d "${EXPERIMENTS_DIR}/${XP}" || continue
    CLEANED_EXPERIMENTS="${CLEANED_EXPERIMENTS} ${XP}"
  done
  EXPERIMENTS="${CLEANED_EXPERIMENTS# }"
fi
log experiment 0

for XP in ${EXPERIMENTS}
do

    # Makes it easier to send it to the stemplate process
    export XP
    echo "Running experiment: ${XP}"

    XP_DIR="${EXPERIMENTS_DIR}/${XP}"
    # Set up tendermint seed node
    trap 'log seed 10' ERR
    log seed 1
    sudo -u tendermint tendermint init
    sudo -u tendermint tendermint unsafe_reset_all
    if [ -f "${XP_DIR}"/genesis.json ]; then
      mkdir -p /home/tendermint/.tendermint/config/
      stemplate "${XP_DIR}"/genesis.json --env -f "${XP_DIR}"/config.toml -o /home/tendermint/.tendermint/config/
    fi
    stemplate "${XP_DIR}"/seed/ -o /home/tendermint/.tendermint/ -f "${XP_DIR}"/config.toml --all
    chown -R tendermint.tendermint /home/tendermint/.tendermint
    sudo -u tendermint tendermint show_node_id > "${CACHE_DIR}/nightking-seed-node-id"
    export NIGHTKING_SEED_NODE_ID="$(get nightking-seed-node-id)"
    systemctl start tendermint
    log seed 0
    trap '' ERR

    ##
    # Set up terraform
    ##
    PREVIOUS_INFRA="$(peek-cache infra || echo '')"
    export TERRAFORM_RESULT=0
    # Build a new infra
    if [ -z "${PREVIOUS_INFRA}" ]; then
      trap 'log terraform_build 12' ERR
      if [ -n "${DEV}" ]; then
        export SSH_KEY="$(tail -1 /etc/experiments/.pool)"
      else
        export SSH_KEY="$(tail -1 /home/ec2-user/.ssh/authorized_keys)"
      fi
      if [ -f "${XP_DIR}"/config.toml ]; then
        stemplate /usr/share/terraform-templates --env -f "${XP_DIR}"/config.toml -o /root/terraform-"${XP}" --all
        if [ -d "${XP_DIR}"/terraform ]; then
          stemplate "${XP_DIR}"/terraform --env -f "${XP_DIR}"/config.toml -o /root/terraform-"${XP}" --all
        fi
      else
        if [ -d "${XP_DIR}"/terraform ]; then
          stemplate "${XP_DIR}"/terraform -o /root/terraform-"${XP}" --env -f "${XP_DIR}"/config.toml --all
        fi
      fi
      test -d /root/terraform-"${XP}" || echo "Experiment folder /root/terraform-${XP} not found."
      test -d /root/terraform-"${XP}" || continue
      cd /root/terraform-"${XP}"
      trap 'log terraform_build 11' ERR
      log terraform_build 2
      terraform init
      trap 'log terraform_build 10' ERR
      log terraform_build 1
      terraform apply --auto-approve -no-color || export TERRAFORM_RESULT=$?
    else
      cd /root/terraform-"${PREVIOUS_INFRA}"
    fi

    ##
    # Run experiment
    ##
    if [ ${TERRAFORM_RESULT} -ne 0 ]; then
      log terraform_build 10
    else
      if [ -z "${PREVIOUS_INFRA}" ]; then
        echo "${XP}" > "${CACHE_DIR}/infra" #Keep a record of the infra that is fully built
      fi
      log terraform_build 0

      #When DEV=1, the infrastructure needs a kick to start.
      if [ -n "${DEV}" ]; then
        IP_LIST="$(terraform show ./terraform.tfstate -no-color | grep "^  public_ip =" | sed "s/^  public_ip = //" | tr '\n' ' ')"
        # Get some time for new infrastructure to come up
        if [ -z "${PREVIOUS_INFRA}" ]; then
          echo "Waiting for infrastructure to stabilize in the cloud."
          sleep 90
        fi
        # 3 minutes timeout because new servers might still need time
        pssh -l ec2-user -p 20 -t 180 -i -O "StrictHostKeyChecking no" -O "LogLevel ERROR" -x "-i ${LOG_DIR}/pool.key" -H "${IP_LIST}" "sudo /usr/local/sbin/runxp \"${XP}\""
      fi

      # Set up and run tm-load-test master - wait until it finishes
      if [ -f "${XP_DIR}"/config.toml ]; then
        # We run stemplate twice to allow for double variable interpolation -
        # allows us to refer to variables from within the `config.toml` file too
        stemplate /usr/local/sbin/tm-load-test-master.bash --env -f "${XP_DIR}"/config.toml -o /tmp
        stemplate /tmp/tm-load-test-master.bash --env -f "${XP_DIR}"/config.toml -o /home/tm-load-test
      else
        stemplate /usr/local/sbin/tm-load-test-master.bash --env -o /tmp
        stemplate /tmp/tm-load-test-master.bash --env -o /home/tm-load-test
      fi
      chown tm-load-test /home/tm-load-test/tm-load-test-master.bash
      chmod +x /home/tm-load-test/tm-load-test-master.bash

      trap 'log tm-load-test 2' ERR
      log tm-load-test 1
      export LOAD_TEST_RESULT=0

      # Execute the tm-load-test master
      sudo -u tm-load-test \
        /home/tm-load-test/tm-load-test-master.bash || export LOAD_TEST_RESULT=$?

      if [ "${LOAD_TEST_RESULT}" -ne 0 ]; then
        log tm-load-test 2
      else
        log tm-load-test 0
      fi
    fi

    ##
    # Finish experiment
    ##
    if [ -z "${DEBUG}" ]; then
      # Break down terraform
      trap 'log terraform_destroy 2' ERR
      log terraform_destroy 1
      terraform destroy --force -no-color
      rm -f "${CACHE_DIR}/infra"
      log terraform_destroy 0
    fi

    # If one of the experiments failed while building the infrastructure, do not run the rest of the experiments.
    if [ ${TERRAFORM_RESULT} -ne 0 ]; then
      break
    fi

done
