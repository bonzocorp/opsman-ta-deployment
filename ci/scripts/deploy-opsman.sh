#!/bin/bash

[[ ${DEBUG,,} == true ]] && set -x
set -eu

source pipeline/ci/scripts/common.sh

declare -r OUTPUT=output
mkdir -p $OUTPUT/stemcells

declare IS_UPGRADE=false

function check_opsman() {
  curl --head --fail --silent --url https://$OM_TARGET/setup -k --output /dev/null
}

function deploy_ova() {
  if $( check_opsman ); then
    echo "Opsman is already deployed"
    IS_UPGRADE=true

    if [[ $OM_TARGET =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      opsman_ip=$OM_TARGET
    else
      opsman_ip=$( dig +short $OM_TARGET )
    fi

    if [ -z "$opsman_ip" ]; then
      echo "Opsmn IP is blank" >&2
      return 1
    fi

    opsman_path=$(
      govc \
        find "$GOVC_FOLDER" \
        -type m \
        -guest.ipAddress "$opsman_ip" \
        -runtime.powerState poweredOn
    )

    if [ -z "$opsman_path" ]; then
      echo "Opsmn path is blank" >&2
      return 1
    fi

    download_installation_assets

    #echo "Release ip address"
    #govc device.disconnect -vm.ipath "$opsman_path" ethernet-0

    echo "stopvm"
    govc vm.power -off -vm.ipath "$opsman_path"

    echo "rename with stop timestamp. Eg: opsman-1.1.1-20180915000000"
    govc object.rename "$opsman_path" "$( basename $opsman_path )-$( date +%Y%m%d%H%M%S )"
  fi

  file_path=`find ./ova/ -name *.ova`
  version=$(cat ova/version | cut -d "#" -f1)

  if [ -n "$GOVC_CA_CERT" ]; then
    export GOVC_TLS_CA_CERTS=/tmp/vcenter-ca.pem
    echo "$GOVC_CA_CERT" > $GOVC_TLS_CA_CERTS
  fi

  echo "options.json file for version $version:"
  govc import.spec $file_path  | jq .

  spruce merge --prune meta $CONFIG_FILES 2>/dev/null | spruce 2>/dev/null json > merged-options.json

  jq --arg vmName opsman-"$version" \
      '.Name = $vmName' \
    merged-options.json > options.json

  if [[ -z "$(govc folder.info "$GOVC_FOLDER" 2>&1 | grep "$GOVC_FOLDER")"  ]]; then
    govc folder.create "$GOVC_FOLDER"
  fi
  govc import.ova -options=options.json $file_path

}

function wait_for_server() {
  until check_opsman ; do
    printf '.'
    sleep 5
  done
}

function configure_authentication() {
  om \
    $om_options \
    configure-authentication \
    --username "$OM_USERNAME" \
    --password "$OM_PASSWORD" \
    --decryption-passphrase "$OM_DECRYPTION_PASSWORD"
}

function install_certs() {
	ssh_command="sshpass -e ssh -i /tmp/om_private_ssh_key -t -o StrictHostKeyChecking=no ubuntu@${OM_TARGET} "
	scp_command="sshpass -e scp -i /tmp/om_private_ssh_key -o StrictHostKeyChecking=no "

	if [[ -z ${OM_CERT} || -z ${OM_CERT_KEY} || -z ${OM_PRIVATE_SSH_KEY} ]]; then
		echo "Opsman key, cert or private_ssh_key not provided"
	else
		echo "$OM_CERT" > /tmp/test.crt
		echo "$OM_CERT_KEY" > /tmp/test.key
    echo "${OM_PRIVATE_SSH_KEY}" > /tmp/om_private_ssh_key
    chmod 400 /tmp/om_private_ssh_key

		echo "Copying new key.."
		$scp_command /tmp/test.key ubuntu@${OM_TARGET}:/home/ubuntu/tempest1.key

		echo "Copying new cert.."
		$scp_command /tmp/test.crt ubuntu@${OM_TARGET}:/home/ubuntu/tempest1.crt

		echo "Moving old cert.."
		$ssh_command "echo ${SSHPASS}| sudo -S cp /var/tempest/cert/tempest.crt /var/tempest/cert/tempest.crt.old"

		echo "Moving old key.."
		$ssh_command "echo ${SSHPASS}| sudo -S cp /var/tempest/cert/tempest.key /var/tempest/cert/tempest.key.old"

		echo "Putting new key in place.."
		$ssh_command "echo ${SSHPASS}| sudo -S mv /home/ubuntu/tempest1.key /var/tempest/cert/tempest.key"

		echo "Putting new cert in place.."
		$ssh_command "echo ${SSHPASS}| sudo -S mv /home/ubuntu/tempest1.crt /var/tempest/cert/tempest.crt"

		echo "Restarting nginx.."
		$ssh_command "echo ${SSHPASS}| sudo -S service nginx restart"
	fi
}

function install_settings() {
  if [[ -f $OUTPUT/om-installation.zip ]]; then
    echo "Importing installation settings"
    om \
      $om_options \
        --decryption-passphrase "$OM_DECRYPTION_PASSWORD" \
      import-installation \
        --installation $OUTPUT/om-installation.zip \
  else
    echo "Configuring authentication instead"
    configure_authentication
  fi
}

function download_diagnostic_report() {
  if $( check_opsman ); then
    echo "Downloading diagnostic report"
    om \
      $om_options \
      curl --path /api/v0/diagnostic_report \
      > "${OUTPUT}/exported-diagnostic-report.json"
  fi
}

function download_installation_assets() {
  echo "download installation assets"
  om \
    $om_options \
    export-installation \
      --output-file $OUTPUT/om-installation.zip
}

function download_stemcells() {
  if [[ -f ${OUTPUT}/exported-diagnostic-report.json ]]; then
    echo "provisioning missing stemcells"
    ubuntu_jq_filter='.added_products.deployed[] | select(.name | contains("p-bosh") | not) | select(.stemcell | contains("windows") | not) | .stemcell'
    local -a ubuntu_stemcells=($( cat ${OUTPUT}/exported-diagnostic-report.json | jq -r "$ubuntu_jq_filter" | uniq ))
    if [ ${#ubuntu_stemcells[@]} -eq 0 ]; then
      echo "no installed products"
      return 0
    fi

		pivnet login --api-token="${PIVNET_TOKEN}"
		pivnet eula --eula-slug=pivotal_software_eula >/dev/null

		for stemcell in "${ubuntu_stemcells[@]}"; do
			local product_slug
			local stemcell_version

			stemcell_version=$(echo "$stemcell" | grep -Eo "[0-9]+(\.[0-9]+)?")

      if [[ $stemcell == *"xenial"* ]]; then
        product_slug="stemcells-ubuntu-xenial"
      else
        product_slug="stemcells"
      fi

			download_stemcell_version $product_slug $stemcell_version
		done
  fi
}

function download_stemcell_version() {
  local product_slug="$1"
  local stemcell_version="$2"

  pivnet_stemcell_response="$(pivnet pfs -p $product_slug -r "$stemcell_version" --format json)"

  # ensure the stemcell version found in the manifest exists on pivnet
  if [[ $pivnet_stemcell_response == *"release not found"* ]]; then
    echo "Could not find the required stemcell version ${stemcell_version}. This version might not be published on PivNet yet, try again later."
    return 1
  fi

  # loop over all the stemcells for the specified version and then download it if it's for the IaaS we're targeting
  for product_file_id in $( echo $pivnet_stemcell_response | jq .[].id); do
    local product_file_name
    product_file_name=$(pivnet product-file -p $product_slug -r "$stemcell_version" -i "$product_file_id" --format=json | jq .name)
    if echo "$product_file_name" | grep -iq "$IAAS_TYPE"; then
      pivnet download-product-files -p $product_slug -r "$stemcell_version" -i "$product_file_id" -d "$OUTPUT/stemcells" --accept-eula
      return 0
    fi
  done

  # shouldn't get here
  echo "Could not find stemcell ${stemcell_version} for ${IAAS_TYPE}. Did you specify a supported IaaS type for this stemcell version?"
  return 1
}

function upload_stemcells() {
	if [[ -n "$(ls $OUTPUT/stemcells/*.tgz)" ]]; then
		echo "Uploading stemcells"

		for stemcell in $(ls $OUTPUT/stemcells/*.tgz); do
			echo "Uploading stemcell: $stemcell"
			om \
				$om_options \
				upload-stemcell \
					--stemcell $stemcell
		done
	fi
}

function apply_changes(){
  echo "Applying changes in Opsman"
  om -t $OM_TARGET \
    $om_options \
    apply-changes \
      --skip-deploy-products
}

# Extra options to append to the OM command update
om_options="--target $OM_TARGET"
if [[ $OM_SKIP_SSL_VALIDATION == true ]]; then
  om_options+=" --skip-ssl-validation"
fi
if [[ $OM_TRACE == true ]]; then
  om_options+=" --trace"
fi
om_options+=" --request-timeout ${OM_REQUEST_TIMEOUT:-3600}"

load_custom_ca_certs
download_diagnostic_report
deploy_ova
wait_for_server
install_certs
install_settings
download_stemcells
upload_stemcells
if [[ "${DRY_RUN,,}" != "true" ]] ; then
  apply_changes
else
  log "Dry run ... Skipping apply changes"
fi
