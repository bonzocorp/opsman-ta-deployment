#!/bin/bash

function generate_ca(){
  local generate_ca_response=$(om curl -s --path /api/v0/certificate_authorities/generate" \
      -X POST \
      -H "Authorization: Bearer YOUR-UAA-ACCESS-TOKEN" \
      -H "Content-Type: application/json" \
      -d '{}')

  echo $generate_ca_response | jq '.guid' -r
}

function list_ca_certs() {
  om curl -s --path /api/v0/certificate_authorities
}

function recreate_director_config(){
  cat << EOF
  ---
  director-configuration:
    bosh_recreate_on_next_deploy: true
  EOF > recreate_all.yml

  spruce merge $OUTPUT/config.json recreate_all.yml > $OUTPUT/config.json
}

new_cert_guid=generate_ca
list_ca_certs
generate_config
enable_recreate_all
configure_director
if [[ "${DRY_RUN,,}" != "true" ]] ; then
  apply_changes
else
  log "Dry run ... Skipping apply changes"
fi

#Select the Director Config pane.
#Select Recreate All VMs. This propagates the new CA to all VMs to prevent downtime.
#Go back to the Installation Dashboard. For each service tile you have installed:
#Click the tile.
#Click the Errands tab.
#If the service tile has the Recreate All Service Instances errand:
#Enable the Recreate All Service Instances errand.
#Click Review Pending Changes, then Apply Changes.
#If the service tile does not have the Recreate All Service Instances errand:
#Click Review Pending Changes, then Apply Changes.
#When the deploy finishes, manually push the BOSH NATS CA to each of its service instances. For each service instance, run:
#bosh -d SERVICE-INSTANCE-DEPLOYMENT recreate
#Where SERVICE-INSTANCE-DEPLOYMENT is the BOSH deployment name for the service instance.
#Continue to the next section, Step 2: Activate the CAs.
#
#Step 2: Activate the Root CA
#
#To activate the new root CA:
#
#Use curl to make an Ops Manager API call that activates the new CA:
#
#curl "https://OPS-MAN-FQDN/api/v0/certificate_authorities/CERT-GUID/activate" \
#  -X POST \
#  -H "Authorization: Bearer YOUR-UAA-ACCESS-TOKEN" \
#  -H "Content-Type: application/json" \
#  -d '{}'
#Where CERT-GUID is the GUID of your CA that you retrieved in the previous section.
#
#The API returns a successful response:
#HTTP/1.1 200 OK
#
