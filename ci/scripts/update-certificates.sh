#!/bin/bash

source pipeline/ci/scripts/common.sh

function update_certificates() {
  local six_month_certs="$(om curl -s --path /api/v0/deployed/certificates?expires_within=6m | jq '.certificates' -r)"
  local three_month_certs="$(om curl -s --path /api/v0/deployed/certificates?expires_within=3m | jq '.certificates' -r)"

  log "\nNON ROTATABLE CERTIFICATES:"
  log "expiring <6m:"
  echo $six_month_certs | jq '.[] | select(.variable_path=="/opsmgr/bosh_dns/tls_ca") | .property_reference' -r
  log "expiring <3m:"
  echo $three_month_certs | jq '.[] | select(.variable_path=="/opsmgr/bosh_dns/tls_ca") | .property_reference' -r


  log "\nNON CONFIGURABLE CERTIFICATES:"
  log "expiring <6m:"
  echo $three_month_certs | jq '.[] | select(.configurable==false) | select(.location|test("opsman|credhub"))| .property_reference' -r
  log "expiring <3m:"
  echo $six_month_certs | jq '.[] | select(.configurable==false) | select(.location|test("opsman|credhub"))| .property_reference' -r

  log "\nCONFIGURABLE CERTIFICATE:"
  log "expiring <6m:"
  echo $six_month_certs | jq '.[] | select(.configurable==true) | ' -r
  log "expiring <3m:"
  echo $three_month_certs | jq '.[] | select(.configurable==true) | .property_reference' -r

}

update_certificates

