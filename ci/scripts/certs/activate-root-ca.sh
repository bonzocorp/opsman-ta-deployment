#!/usr/bin/env bash

scripts_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $scripts_dir/../common.sh

function enable_new_ca_cert(){
  list_ca_certs > all_certs.json
  local cert_guid=$(cat all_certs.json  | jq ". | .certificate_authorities | sort_by(.created_on)[-1] | .guid" -r)

  om curl -s --path /api/v0/certificate_authorities/$cert_guid/activate \
    -x POST \
    -H "Content-Type: application/json" \
    -d '{}'
}

enable_new_ca_cert
