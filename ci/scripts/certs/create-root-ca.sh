#!/usr/bin/env bash

scripts_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $scripts_dir/common.sh

function generate_ca(){
  local generate_ca_response=$(om curl -s --path /api/v0/certificate_authorities/generate \
    -x POST \
    -H "Content-Type: application/json" \
    -d '{}')

  echo $generate_ca_response | jq .guid -r > $OUTPUT/new_ca_cert_guid

}

generate_ca
list_ca_certs
