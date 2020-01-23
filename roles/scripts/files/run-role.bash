#!/usr/bin/env bash
set -euo pipefail

source /usr/local/sbin/library.bash

case "${ROLE}" in
  "nightking")
    /usr/local/sbin/nightking.bash "$@"
    ;;
  "whitewalker")
    /usr/local/sbin/whitewalker.bash "$@"
    ;;
  "stark")
    /usr/local/sbin/stark.bash "$@"
    ;;
  *)
    echo "Cannot understand ROLE=${ROLE}" > "${LOG_DIR}/startup-error"
    ;;
esac
