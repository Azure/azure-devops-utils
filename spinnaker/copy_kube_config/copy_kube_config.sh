#!/bin/bash

function print_usage() {
  cat <<EOF
Command
  $0

Arguments
  --user_name|-un          [Required]: User name for Kubernetes cluster
  --resource_group|-rg     [Required]: Resource group containing Kubernetes cluster
  --master_fqdn|-mf        [Required]: Master FQDN of Kubernetes master VMs

NOTE: This script requires the 'az' cli and assumes you have logged in and set the correct subscription
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
    --user_name|-un)
      admin_user_name="$1"
      shift
      ;;
    --resource_group|-rg)
      resource_group="$1"
      shift
      ;;
    --master_fqdn|-mf)
      master_fqdn="$1"
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

throw_if_empty --user-name $admin_user_name
throw_if_empty --resource_group $resource_group
throw_if_empty --master_fqdn $master_fqdn

config_path="/home/$admin_user_name/.kube/config"

# Setup temporary credentials to access kubernetes master vms
temp_user_name=$(uuidgen | sed 's/-//g')
temp_key_path=$(mktemp -d)/temp_key
ssh-keygen -t rsa -N "" -f $temp_key_path -V "+1d"
temp_pub_key=$(cat ${temp_key_path}.pub)

master_vm_ids=$(az vm list -g "$resource_group" --query "[].id" -o tsv | grep "k8s-master-")
>&2 echo "Master VM ids: $master_vm_ids"

# Enable temporary credentials on every kubernetes master vm (since we don't know which vm will be used when we scp)
az vm user update -u "$temp_user_name" --ssh-key-value "$temp_pub_key" --ids "$master_vm_ids"

# Copy kube config over from master kubernetes cluster and mark readable
sudo mkdir -p $(dirname "$config_path")
sudo sh -c "ssh -o StrictHostKeyChecking=no -i \"$temp_key_path\" $temp_user_name@$master_fqdn sudo cat \"$config_path\" > \"$config_path\""

# Remove temporary credentials on every kubernetes master vm
az vm user delete -u "$temp_user_name" --ids "$master_vm_ids"

# Delete temp key on spinnaker vm
rm $temp_key_path
rm ${temp_key_path}.pub

if [ ! -s "$config_path" ]; then
  >&2 echo "Failed to copy kubeconfig for kubernetes cluster."
  exit -1
fi

sudo chmod +r "$config_path"