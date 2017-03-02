#!/bin/bash

function print_usage() {
  cat <<EOF
Command
  $0 

Arguments
  --user_name|-un          [Required]: User name for Kubernetes cluster
  --resource_group|-rg     [Required]: Resource group containing Kubernetes cluster
  --master_fqdn|-mf        [Required]: Master FQDN of Kubernetes master VMs
  --master_count|-mc       [Required]: Count of Kubernetes master VMs

NOTE: This script requires the 'azure' cli and assumes you have logged in and set the correct subscription
EOF
}

function throw_if_unset() {
  local name="$1"
  local value="$2"
  if [ -z "$value" ]; then
    echo "Required parameter '$name' is not set." 1>&2
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
    --master_count|-mc)
      master_count="$1"
      shift
      ;;
    --help|-help|-h)
      print_usage
      exit 13
      ;;
    *)
      echo "ERROR: Unknown argument '$key'" 1>&2
      exit -1
  esac
done

throw_if_unset --user-name $admin_user_name
throw_if_unset --resource_group $resource_group
throw_if_unset --master_fqdn $master_fqdn
throw_if_unset --master_count $master_count

destination_file="/home/spinnaker/.kube/config"

# Get the unique suffix used for kubernetes vms

kubernetes_suffix=$(azure group deployment list $resource_group --json | python -c "
import json, sys;
data=json.load(sys.stdin);
for deployment in data:
  try:
    if deployment['properties']['outputs']['masterFQDN']['value'] == '$master_fqdn':
      print deployment['properties']['parameters']['nameSuffix']['value']
      sys.exit(0)
  except:
    pass
")

# Setup temporary credentials to access kubernetes master vms
temp_user_name=$(uuidgen | sed 's/-//g')
temp_key_path=$(mktemp -d)/temp_key
ssh-keygen -t rsa -N "" -f $temp_key_path -V "+1d"
temp_pub_key=$(cat ${temp_key_path}.pub)

# Enable temporary credentials on every kubernetes master vm (since we don't know which vm will be used when we scp)
for (( i=0; i<$master_count; i++ ))
do
  master_vm="k8s-master-${kubernetes_suffix}-$i"
  azure vm extension set $resource_group $master_vm VMAccessForLinux Microsoft.OSTCExtensions 1.4 --private-config "{ \"username\": \"$temp_user_name\", \"ssh_key\": \"$temp_pub_key\" }"
done

# Copy kube config over from master kubernetes cluster and mark readable
sudo mkdir -p $(dirname "$destination_file")
sudo sh -c "ssh -o StrictHostKeyChecking=no -i \"$temp_key_path\" $temp_user_name@$master_fqdn sudo cat /home/$admin_user_name/.kube/config > \"$destination_file\""
sudo chmod +r $destination_file

# Remove temporary credentials on every kubernetes master vm
for (( i=0; i<$master_count; i++ ))
do
  master_vm="k8s-master-${kubernetes_suffix}-$i"
  azure vm extension set $resource_group $master_vm VMAccessForLinux Microsoft.OSTCExtensions 1.4 --private-config "{ \"remove_user\": \"$temp_user_name\" }"
done

# Delete temp key on spinnaker vm
rm $temp_key_path
rm ${temp_key_path}.pub