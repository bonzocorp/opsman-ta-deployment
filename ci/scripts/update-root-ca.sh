#!/usr/bin/env bash

scripts_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $scripts_dir/common.sh

function enable_new_ca_cert(){
  local cert_guid=$(cat $OUTPUT/new_ca_cert_guid)
  om curl -s --path /api/v0/certificate_authorities/$cert_guid/activate \
    -x POST \
    -H "Content-Type: application/json" \
    -d '{}'
}

function generate_ca(){
  local generate_ca_response=$(om curl -s --path /api/v0/certificate_authorities/generate \
    -x POST \
    -H "Content-Type: application/json" \
    -d '{}')

  echo $generate_ca_response | jq .guid -r > $OUTPUT/new_ca_cert_guid

}

function list_ca_certs() {
  om curl -s --path /api/v0/certificate_authorities
}

generate_ca
list_ca_certs
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

