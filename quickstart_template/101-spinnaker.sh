#!/bin/bash

function print_usage() {
  cat <<EOF
Command
  $0
Arguments
  --storage_account_name|-san [Required] : Storage Account name used for Spinnaker's persistent storage
  --storage_account_key|-sak  [Required] : Storage Account key used for Spinnaker's persistent storage
  --username|-u               [Required] : User for which to install Halyard
  --artifacts_location|-al               : Url used to reference other scripts/artifacts.
  --sas_token|-st                        : A sas token needed if the artifacts location is private.
EOF
}

function throw_if_empty() {
  local name="$1"
  local value="$2"
  if [ -z "$value" ]; then
    echo "Parameter '$name' cannot be empty." 1>&2
    print_usage
    exit -1
  fi
}

function run_util_script() {
  local script_path="$1"
  shift
  curl --silent "${artifacts_location}${script_path}${artifacts_location_sas_token}" | sudo bash -s -- "$@"
  local return_value=$?
  if [ $return_value -ne 0 ]; then
    >&2 echo "Failed while executing script '$script_path'."
    exit $return_value
  fi
}

while [[ $# > 0 ]]
do
  key="$1"
  shift
  case $key in
    --storage_account_name|-san)
      storage_account_name="$1";;
    --storage_account_key|-sak)
      storage_account_key="$1";;
    --username|-u)
      username="$1";;
    --artifacts_location|-al)
      artifacts_location="$1";;
    --sas_token|-st)
      artifacts_location_sas_token="$1";;
    --help|-help|-h)
      print_usage
      exit 13;;
    *)
      echo "ERROR: Unknown argument '$key' to script '$0'" 1>&2
      exit -1
  esac
  shift
done

throw_if_empty storage_account_name $storage_account_name
throw_if_empty storage_account_key $storage_account_key
throw_if_empty username $username

run_util_script "spinnaker/install_halyard/install_halyard.sh" -san "$storage_account_name" -sak "$storage_account_key" -u "$username"

sudo hal deploy apply

# Wait for Spinnaker services to be up before returning
timeout=180
echo "while !(nc -z localhost 8084) || !(nc -z localhost 9000); do sleep 1; done" | timeout $timeout bash
return_value=$?
if [ $return_value -ne 0 ]; then
  >&2 echo "Failed to connect to Spinnaker within '$timeout' seconds."
  exit $return_value
fi