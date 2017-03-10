#!/bin/bash

function print_usage() {
  cat <<EOF
Command
  $0
Arguments
  --storage_account_name|-san [Required] : Storage Account name used for Spinnaker's persistent storage
  --storage_account_key|-sak  [Required] : Storage Account key used for Spinnaker's persistent storage
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

#Set defaults
artifacts_location="https://raw.githubusercontent.com/Azure/azure-devops-utils/master/"

while [[ $# > 0 ]]
do
  key="$1"
  shift
  case $key in
    --storage_account_name|-san)
      storage_account_name="$1"
      shift
      ;;
    --storage_account_key|-sak)
      storage_account_key="$1"
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

throw_if_empty --storage_account_name $storage_account_name
throw_if_empty --storage_account_key $storage_account_key

#Install Spinnaker
curl --silent https://raw.githubusercontent.com/spinnaker/spinnaker/master/InstallSpinnaker.sh | sudo bash -s -- --quiet --noinstall_cassandra

# The install script sometimes fails to start spinnaker, so start it here
sudo service spinnaker start

# Disable all storage methods for front50 except for azs
sudo /opt/spinnaker/install/change_cassandra.sh --echo=inMemory --front50=azs

front50_config_file="/opt/spinnaker/config/front50-local.yml"
sudo touch "$front50_config_file"
sudo cat <<EOF >"$front50_config_file"
spinnaker:
  azs:
    enabled: true
    storageAccountName: REPLACE_STORAGE_ACCOUNT_NAME
    storageAccountKey: REPLACE_STORAGE_ACCOUNT_KEY
EOF

sudo sed -i "s|REPLACE_STORAGE_ACCOUNT_NAME|${storage_account_name}|" $front50_config_file
sudo sed -i "s|REPLACE_STORAGE_ACCOUNT_KEY|${storage_account_key}|" $front50_config_file

# Restart front50 so that config changes take effect
curl --silent "${artifacts_location}spinnaker/await_restart_service/await_restart_service.sh${artifacts_location_sas_token}" | sudo bash -s -- --service front50