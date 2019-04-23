#!/bin/bash

source pipeline/ci/scripts/common.sh

function cleanup_director() {
  echo -e "${BBR_SSH_KEY}" > /tmp/bbr.pem

  local bbr_ssh_key_file=/tmp/bbr.pem

  log "Cleaning up director"
  bbr director \
    --host "$BOSH_TARGET" \
    --username "${BBR_USERNAME:-bbr}" \
    --private-key-path $bbr_ssh_key_file \
      backup-cleanup
}

cleanup_director

