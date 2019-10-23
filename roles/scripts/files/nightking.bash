#!/usr/bin/env bash
exec > /var/log/nightking/nightking-$(date +%Y%m%d-%H%M%S).output
exec 2>&1
set -euo pipefail
source /usr/local/sbin/library.bash

## Sanitize EXPERIMENT input
trap 'log experiment 10' ERR
if [ "${EXPERIMENTS}" == "" ]; then
  EXPERIMENTS=$(ls /etc/experiments)
else
  CLEANED_EXPERIMENTS=""
  for XP in ${EXPERIMENTS}
  do
    test -d /etc/experiments/"${XP}" || echo "Experiment ${XP} folder not found. Skipping..."
    test -d /etc/experiments/"${XP}" || continue
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

    # Set up tendermint seed node
    trap 'log seed 10' ERR
    log seed 1
    sudo -u tendermint tendermint init
    sudo -u tendermint tendermint unsafe_reset_all
    if [ -f /etc/experiments/"${XP}"/genesis.json ]; then
      mkdir -p /home/tendermint/.tendermint/config/
      stemplate /etc/experiments/"${XP}"/genesis.json --env -f /etc/experiments/"${XP}"/config.toml -o /home/tendermint/.tendermint/config/
    fi
    stemplate /etc/experiments/"${XP}"/seed/ -o /home/tendermint/.tendermint/ -f /etc/experiments/"${XP}"/config.toml --all
    chown -R tendermint.tendermint /home/tendermint/.tendermint
    sudo -u tendermint tendermint show_node_id > /var/log/nightking/seed_node_id
    export NIGHTKING_SEED_NODE_ID="$(cat /var/log/nightking/seed_node_id)"
    systemctl start tendermint
    log seed 0
    trap '' ERR

    # Set up terraform
    trap 'log terraform_build 12' ERR
        export SSH_KEY="$(tail -1 /home/ec2-user/.ssh/authorized_keys)"
    if [ -f /etc/experiments/"${XP}"/config.toml ]; then
      stemplate /usr/share/terraform-templates --env -f /etc/experiments/"${XP}"/config.toml -o /root/terraform-"${XP}" --all
      if [ -d /etc/experiments/"${XP}"/terraform ]; then
        stemplate /etc/experiments/"${XP}"/terraform --env -f /etc/experiments/"${XP}"/config.toml -o /root/terraform-"${XP}" --all
      fi
    else
      if [ -d /etc/experiments/"${XP}"/terraform ]; then
        stemplate /etc/experiments/"${XP}"/terraform -o /root/terraform-"${XP}" --env -f /etc/experiments/"${XP}"/config.toml --all
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
    export TERRAFORM_RESULT=0
    terraform apply --auto-approve -no-color || export TERRAFORM_RESULT=$?

    if [ ${TERRAFORM_RESULT} -ne 0 ]; then
      log terraform_build 10
    else
      log terraform_build 0

      # Set up and run tm-load-test master - wait until it finishes
      if [ -f /etc/experiments/"${XP}"/config.toml ]; then
        # We run stemplate twice to allow for double variable interpolation -
        # allows us to refer to variables from within the `config.toml` file too
        stemplate /usr/local/sbin/tm-load-test-master.bash --env -f /etc/experiments/"${XP}"/config.toml -o /tmp
        stemplate /tmp/tm-load-test-master.bash --env -f /etc/experiments/"${XP}"/config.toml -o /home/tm-load-test
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

    if [ -z "${DEBUG}" ]; then
      # Break down terraform
      trap 'log terraform_destroy 2' ERR
      log terraform_destroy 1
      terraform destroy --force -no-color
      log terraform_destroy 0
    fi

    if [ ${TERRAFORM_RESULT} -ne 0 ]; then
      break
    fi

done
