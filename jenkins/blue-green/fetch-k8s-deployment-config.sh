#!/bin/bash

function print_usage() {
  cat <<EOF
Command
  $0
Arguments
  --file|-f                                 : config file name to be downloaded, may be applied multiple times.
  --directory|-d                            : directory to store the downloaded files.
  --artifacts_location|-al                  : Url used to reference other scripts/artifacts.
  --sas_token|-st                           : A sas token needed if the artifacts location is private.
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

#set defaults
config_files=()
artifacts_location="https://raw.githubusercontent.com/Azure/azure-devops-utils/master/"
artifacts_location_sas_token=

while [[ $# > 0 ]]
do
  key="$1"
  shift
  case $key in
    --file|-f)
      config_files+=("$1")
      shift
      ;;
    --directory|-d)
      directory="$1"
      shift
      ;;
    --artifacts_location|-al)
      artifacts_location="$1"
      shift
      ;;
    --sas_token|-st)
      artifacts_location_sas_token="$1"
      shift
      ;;
    --help|-help|-h)
      print_usage
      exit 13
      ;;
    *)
      echo "ERROR: Unknown argument '$key' to script '$0'" 1>&2
      exit -1
  esac
done

throw_if_empty --artifacts_location "$artifacts_location"
if [[ "${#config_files[@]}" == 0 ]]; then
    config_files=(deployment.yml service.yml test-endpoint.yml)
fi

if [[ -n "$directory" ]]; then
    mkdir -p "$directory"
    cd "$directory"
fi

for file in "${config_files[@]}"; do
    wget -O "$file" "${artifacts_location}jenkins/blue-green/k8s/${file}${artifacts_location_sas_token}"
done
