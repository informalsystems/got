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

###
## Check if a previous experiment is still running
###
PIDS="$(pidof tm-load-test || echo "")"
if [ -n "${PIDS}" ]; then
  echo "Previous running experiments were found at PID(s): ${PIDS}."
  if [ -n "${DEV}" ] && [ -n "${DEBUG}" ]; then
    echo "Initiating graceful shutdown of PID(s)."
    kill "${PIDS}"
  else
    echo "Please shut down experiments using 'stopxp' before starting a new one."
    exit 1
  fi
fi

###
## Run experiments
###
for XP in ${EXPERIMENTS}
do

    # Makes it easier to send it to the stemplate process
    export XP
    echo "Running experiment: ${XP}"

    # Stopgap for previous network polluting fresh seed node (hence failing fresh network).
    # Todo: When persistent_peers are set, this should be revised.
    if [ -n "${DEV}" ] && [ -n "${PREVIOUS_INFRA}" ]; then
      FULL=1 /usr/local/sbin/stopxp || echo "WARNING: Could not stop previous experiment processes. Continuing."
    fi

    # Set up tendermint seed node
    trap 'log seed 10' ERR
    log seed 1
    setup-tendermint "${XP}"
    log seed 0
    trap '' ERR

    ##
    # Set up terraform
    ##
    setup-terraform "${XP}"

    ##
    # Run experiment - if terraform was successful
    ##
    if [ ${TERRAFORM_RESULT} -eq 0 ]; then

      #When DEV=1, the infrastructure needs a kick to start.
      if [ -n "${DEV}" ]; then
        # 3 minutes timeout because new servers might still need time
        pssh -i -p "${MAX_PARALLEL_SSH}" -t 180 -H "$(get-all-starks-ip) $(get-all-whitewalkers-ip)" "sudo /usr/local/sbin/runxp \"${XP}\""
      fi

      # Set up and run tm-load-test master - wait until it finishes
      if [ -f "${EXPERIMENTS_DIR}/${XP}"/config.toml ]; then
        # We run stemplate twice to allow for double variable interpolation -
        # allows us to refer to variables from within the `config.toml` file too
        stemplate /usr/local/sbin/tm-load-test-master.bash --env -f "${EXPERIMENTS_DIR}/${XP}"/config.toml -o /tmp
        stemplate /tmp/tm-load-test-master.bash --env -f "${EXPERIMENTS_DIR}/${XP}"/config.toml -o /home/tm-load-test
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
      force-destroy-terraform "${XP}"
      log terraform_destroy 0
    fi

    # If one of the experiments failed while building the infrastructure, do not run the rest of the experiments.
    if [ ${TERRAFORM_RESULT} -ne 0 ]; then
      break
    fi

done
