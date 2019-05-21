#!/bin/bash

[[ ${DEBUG,,} == true ]] && set -x
set -eu
set -x

source pipeline/ci/scripts/common.sh

function configure_ldap() {
  om -t $OM_TARGET \
    $om_options \
    curl \
      --path /api/v0/setup \
      --request POST \
      --header "Content-Type: application/json" \
      --data '{ "setup": {
        "identity_provider": "ldap",
        "decryption_passphrase": "$OM_DECRYPTION_PASSWORD",
        "decryption_passphrase_confirmation":"$OM_DECRYPTION_PASSWORD",
        "eula_accepted": "$EULA_ACCEPTED",
        "ldap_settings": {
          "server_url": "$LDAP_SERVER_URL",
          "ldap_username": "$LDAP_USERNAME",
          "ldap_password": "$LDAP_PASSWORD",
          "user_search_base": "$LDAP_USER_SEARCH_BASE",
          "user_search_filter": "$LDAP_SEARCH_FILTER",
          "group_search_base": "$LDAP_GROUP_SEARCH_BASE",
          "group_search_filter": "$LDAP_GROUP_SEARCH_FILTER",
          "ldap_rbac_admin_group_name": "$LDAP_RBAC_ADMIN_GROUP_NAME",
          "email_attribute": "$LDAP_EMAIL_ATTRIBUTE",
          "ldap_referrals": "$LDAP_REFERRALS"
        }
      } }'
}

configure_ldap
