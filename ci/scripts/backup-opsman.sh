#!/bin/bash

source pipeline/ci/scripts/common.sh

function backup_opsman() {
  log "Export om installation"
  om --target $OM_TARGET \
    $om_options \
    export-installation \
    --output-file output/om-installation.zip
}

backup_opsman

