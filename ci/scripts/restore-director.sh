#!/bin/bash

source pipeline/ci/scripts/common.sh

function restore_director() {
  echo -e "${BBR_SSH_KEY}" > /tmp/bbr.pem

  local bbr_cmd="bbr director
      --host $BOSH_TARGET
      --username bbr
      --private-key-path /tmp/bbr.pem"

  log "Restoring director from backup"
  bbr director \
    $bbr_cmd restore \
    --artifact-path director-backup/director.tgz

}
function clean_director() {

  local bbr_cmd="bbr director
      --host $BOSH_TARGET
      --username bbr
      --private-key-path /tmp/bbr.pem"

  bbr director \
    $bbr_cmd restore-cleanup
}

restore_director
cleanup_director
