#!/usr/bin/env bash

[[ ${DEBUG,,} == true ]] && set -x
set -eu

scripts_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $scripts_dir/common.sh

function enable_new_ca_cert(){
  local cert_guid=$(cat $OUTPUT/new_ca_cert_guid)
  om curl -s --path /api/v0/certificate_authorities/$cert_guid/activate \
    -x POST \
    -H "Content-Type: application/json" \
    -d '{}'
}

function recreate_all_vms(){
  local deployments=$(bosh deployments --column=name --json | jq '.Tables[0].Rows | .[] | .name' -r)

   for deployment in $deployments; do
     bosh -d $deployment -n recreate
   done
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

function enable_recreate_all(){
cat << EOF > recreate_all.yml
---
properties-configuration:
  director-configuration:
    bosh_recreate_on_next_deploy: true
EOF

  cp $OUTPUT/config.json $OUTPUT/default_config.json
  spruce merge $OUTPUT/default_config.json recreate_all.yml | spruce json > $OUTPUT/config.json
}

generate_ca
list_ca_certs
generate_config
enable_recreate_all
configure_director
if [[ "${DRY_RUN,,}" != "true" ]] ; then
  apply_changes
  recreate_all_vms
  enable_new_ca_cert
else
  log "Dry run ... Skipping apply changes"
fi
