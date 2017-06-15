#!/bin/bash

function print_usage() {
  cat <<EOF
Command
  $0
Arguments
  --storage_account_name|-san [Required] : Storage Account name used for Spinnaker's persistent storage
  --storage_account_key|-sak  [Required] : Storage Account key used for Spinnaker's persistent storage
  --username|-u               [Required] : User for which to install Halyard
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

# Install Halyard
curl --silent "https://raw.githubusercontent.com/spinnaker/halyard/master/install/stable/InstallHalyard.sh" | sudo bash -s -- --user "$username" -y

# Set Halyard to use the latest released/validated version of Spinnaker
hal config version edit --version $(hal version latest -q)

# Configure Spinnaker persistent store
hal config storage azs edit --storage-account-name "$storage_account_name" --storage-account-key "$storage_account_key"
hal config storage edit --type azs