#!/usr/bin/env bash

scripts_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $scripts_dir/../common.sh

function find_or_create_pending_products() {
  if [[ ! -s "$PENDING_PRODUCTS_FILE" ]] ; then
    om deployed-products --format=json \
      | jq ".[] | .name" -r > $PENDING_PRODUCTS_FILE

  fi
}

function remove_from_pending_products() {
  sed "/$1/d" $PENDING_PRODUCTS_FILE
}

function commit_config(){
  BUILD_NAME=$(cat metadata/build-name)
  BUILD_JOB_NAME=$(cat metadata/build-job-name)
  BUILD_PIPELINE_NAME=$(cat metadata/build-pipeline-name)
  BUILD_TEAM_NAME=$(cat metadata/build-team-name)
  ATC_EXTERNAL_URL=$(cat metadata/atc-external-url)

  log "Cloning config as config-mod"
  git clone config config-mod

  if [[ -s $PENDING_PRODUCTS_FILE ]]; then
    log "Adding pending redeploy products file"

    cp $PENDING_PRODUCTS_FILE  ${PENDING_PRODUCTS_FILE /config/config-mod}
    git -C config-mod add $PENDING_PRODUCTS_FILE
  fi

  pushd config-mod > /dev/null
    log "Setting up git configurations"
    git config --global user.name $GIT_USERNAME
    git config --global user.email $GIT_EMAIL

    if ! git diff-index --quiet HEAD --; then
      log "Commiting"
      git commit -m "Updates redeploy pending products file: https://$ATC_EXTERNAL_URL/teams/$BUILD_TEAM_NAME/pipelines/$BUILD_PIPELINE_NAME/jobs/$BUILD_JOB_NAME/builds/$BUILD_NAME "
    fi
  popd > /dev/null
}

trap "commit_config" EXIT

generate_config
enable_director_recreate_all
configure_director
find_or_create_pending_products

pending_products=$(cat $PENDING_PRODUCTS_FILE)

if [[ "${DRY_RUN,,}" != "true" ]] ; then
  for product_name in $pending_products[@]; do
    apply_changes $product_name --recreate-vms
    remove_from_pending_products $product_name
  done
  # recreate_all_service_instances_vms
else
  log "Dry run ... Skipping apply changes"
fi

delete_pending_products
rm $PENDING_PRODUCTS_FILE
