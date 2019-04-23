#!/bin/bash

source pipeline/ci/scripts/common.sh

function restore_opsman() {
  log "Export om installation"
  om --target $OM_TARGET \
    $om_options \
    import-installation \
    --installation backup/om-installation.zip \
    --decryption-passphrase "$OM_DECRYPTION_PASSWORD"
}

restore_opsman

