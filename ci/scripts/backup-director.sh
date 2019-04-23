#!/bin/bash

source pipeline/ci/scripts/common.sh

function backup_director() {

  echo -e "${BBR_SSH_KEY}" > /tmp/bbr.pem

  local build_dir=$PWD/build
  mkdir -p $build_dir

  local output_dir=$PWD/output

  local bbr_cmd="bbr director
      --host $BOSH_TARGET
      --username bbr
      --private-key-path /tmp/bbr.pem"

  mkdir -p $build_dir/director
  pushd $build_dir/director
    log "Pre checking the director backup"
    $bbr_cmd pre-backup-check

    log "Backing up director"
    $bbr_cmd backup

    log "Compressing backup files"
    tar -cvzf $output_dir/director.tgz *
    rm -rf *
  popd > /dev/null
}

backup_director

