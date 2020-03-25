#!/usr/bin/env bash

scripts_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $scripts_dir/common.sh

regenerate_non_configurable_leaf_certs(){
  om curl -s --path /api/v0/certificate_authorities/active/regenerate \
    -x POST \
    -H ‘Content-Type: application/json’ -d ‘{}’
}

regenerate_non_configurable_leaf_certs
generate_config
enable_director_recreate_all
configure_director
if [[ "${DRY_RUN,,}" != "true" ]] ; then
  apply_changes
  recreate_all_vms
  enable_new_ca_cert
else
  log "Dry run ... Skipping apply changes"
fi

