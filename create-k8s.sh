#!/usr/bin/env bash
set -euo pipefail

source ../common.sh

#check kubernetes is installed or not
command -v kubectl >/dev/null 2>&1 || { echo >&2 "Kebernetes is required but it's not installed.  Aborting."; exit 1; }

#check gcloud is installed or not
command -v gcloud >/dev/null 2>&1 || { echo >&2 "Gcloud is required but it's not installed.  Aborting."; exit 1; }

activate_gcloud_service_account

cd kubernetes

cat namespace.yaml | envsubst | kubectl apply -f -

cat create-pods.yaml | envsubst | kubectl apply -f -

function activate_gcloud_service_account() {

  # get_valid_zone_for_cluster... not required as we are passing it as ENV VARS
  #ZONE=$(gcloud container clusters list --filter="name=${NAME}" --limit=1 --format="value(zone)" --project=${PROJECT})
  #if [[ -z "$ZONE" ]]; then
   # echo "Could not determine zone for cluster ${NAME} in project ${PROJECT}" >&2
   # exit 1
  #fi

  ORIGINAL_KUBE_CONTEXT=$(kubectl config current-context)
  
  GOOGLE_CREDENTIAL_FILE = "../gocd-credentials.json"
  
  gcloud auth activate-service-account --key-file=$GOOGLE_CREDENTIAL_FILE
  
  add_exit_trap "gcloud auth revoke; kubectl config use-context ${ORIGINAL_KUBE_CONTEXT}"

  gcloud container clusters get-credentials ${NAME} --project=${PROJECT} --zone=${ZONE}

}


# Set a trap on EXIT without overwriting any existing traps
function add_exit_trap() {
  existing_trap_delimited=$(trap -p EXIT)
  if [[ "${existing_trap_delimited}" == *$1* ]]; then
    # This command already set on the trap
    return
  fi
  if [[ -z "${existing_trap_delimited}" ]]; then
    trap "$1" EXIT
  else
    existing_trap_suffixed=${existing_trap_delimited#trap -- \'}
    existing_trap=${existing_trap_suffixed%\' EXIT}
    if [[ "${existing_trap}" == *\; ]]; then
      trap "${existing_trap} $1" EXIT
    else
      trap "${existing_trap}; $1" EXIT
    fi
  fi
}
