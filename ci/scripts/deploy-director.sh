#!/bin/bash

source pipeline/ci/scripts/common.sh


function fetch_opsman_creds() {
  log "Grabbing credentials from opsman"
	# Grab the guid of the product we are deploying
  product_guid=$(get_product_guid)

  tmp=$OUTPUT/tmp
  mkdir -p $tmp
  out=$OUTPUT/store.yml

  log "Initializing the store"
	# Set up initial running creds file
  {
    echo '---'
    echo '{}'
  } > $tmp/store.yml

  log "Adding each credential"
  count=0
	# Loop through each credential identifier
  for cred in $(om -t $OM_TARGET $om_options curl --path /api/v0/deployed/products/$product_guid/credentials | jq -r '.credentials[]'); do
    count=$((count+1))
		# Create an ops file to add the yaml entry the running creds file
    {
      echo "- type: replace"
      echo "  path: /$cred?"
      echo "  value: ((credential.value))"
    } > $tmp/ops.yml

		# Pull the value from opsman into a yaml file
    om \
      -t $OM_TARGET \
      $om_options \
      curl \
        --path /api/v0/deployed/products/$product_guid/credentials/$cred \
    | jq '.' \
    | spruce merge \
    > $tmp/vars.yml

		# Update the creds file with the value needed
    bosh int $tmp/store.yml \
			-o $tmp/ops.yml \
			-l $tmp/vars.yml \
		> $out

		# Replace the rolling creds file with the current
		cp $out $tmp/store.yml
  done

  log "Added $count credentials"
}

function sanitize_opsman_creds() {
  log "Sanitizing credentials from opsman"
  yaml2vault -f $OUTPUT/store.yml -p $YAML2VAULT_PREFIX > ${OUTPUT}/sanitized-store.yml
}


function configure_director(){

  echo "Configuring IaaS and Director..."
  om -t $OM_TARGET $om_options configure-director \
    --config                 $OUTPUT/config.json
}

function commit_config(){
  BUILD_NAME=$(cat metadata/build-name)
  BUILD_JOB_NAME=$(cat metadata/build-job-name)
  BUILD_PIPELINE_NAME=$(cat metadata/build-pipeline-name)
  BUILD_TEAM_NAME=$(cat metadata/build-team-name)
  ATC_EXTERNAL_URL=$(cat metadata/atc-external-url)

  log "Cloning config as config-mod"
  git clone config config-mod

  if [[ -s ${OUTPUT}/sanitized-store.yml ]]; then
    log "Adding store file"
    cp ${OUTPUT}/sanitized-store.yml ${STORE_FILE/config/config-mod}
    git -C config-mod add ${STORE_FILE/config\//}
  fi

  pushd config-mod > /dev/null
    log "Setting up git configurations"
    git config --global user.name $GIT_USERNAME
    git config --global user.email $GIT_EMAIL

    if ! git diff-index --quiet HEAD --; then
      log "Commiting"
      git commit -m "Updates store file: https://$ATC_EXTERNAL_URL/teams/$BUILD_TEAM_NAME/pipelines/$BUILD_PIPELINE_NAME/jobs/$BUILD_JOB_NAME/builds/$BUILD_NAME "
    fi
  popd > /dev/null
}

trap "commit_config" EXIT

generate_config
configure_director
if [[ "${DRY_RUN,,}" != "true" ]] ; then
  apply_changes p-bosh
  fetch_opsman_creds
  sanitize_opsman_creds
else
  log "Dry run ... Skipping apply changes"
fi
