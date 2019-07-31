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
    # Todo: Create some warning messages is there's an invalid experiment in the list
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
    # Todo: Create some warning message if there is nothing to run in an experiment
    test -d /root/terraform-"${XP}" || continue
    cd /root/terraform-"${XP}"
    trap 'log terraform_build 11' ERR
    log terraform_build 2
    terraform init
    trap 'log terraform_build 10' ERR
    log terraform_build 1
    terraform apply --auto-approve
    log terraform_build 0

    # Set up and run tm-load-test master - wait until it finishes
    if [ -f /etc/experiments/"${XP}"/config.toml ]; then
      stemplate /etc/experiments/"${XP}"/load-test.toml --env -f /etc/experiments/"${XP}"/config.toml -o /home/tm-load-test
    else
      stemplate /etc/experiments/"${XP}"/load-test.toml -o /home/tm-load-test --env
    fi
    chown tm-load-test /home/tm-load-test/load-test.toml
    trap 'log tm-load-test 2' ERR
    log tm-load-test 1
    export LOAD_TEST_RESULT=0
    sudo -u tm-load-test tm-load-test -master -c /home/tm-load-test/load-test.toml || export LOAD_TEST_RESULT=$?
    if [ "${LOAD_TEST_RESULT}" -ne 0 ]; then
      log tm-load-test 2
    else
      log tm-load-test 0
    fi

    if [ -z "${DEBUG}" ]; then
      # Break down terraform
      trap 'log terraform_destroy 2' ERR
      log terraform_destroy 1
      terraform destroy --force
      log terraform_destroy 0
    fi
done
