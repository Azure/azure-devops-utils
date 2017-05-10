#!/bin/bash

function print_usage() {
  cat <<EOF
Command
  $0 

Arguments
  --app_id|-ai                  [Required]: Service principal app id used by Spinnaker to dynamically manage resources
  --app_key|-ak                 [Required]: Service principal app key used by Spinnaker to dynamically manage resources
  --tenant_id|-ti               [Required]: Tenant id
  --subscription_id|-si         [Required]: Subscription id
  --resource_group|-rg          [Required]: Resource group containing your key vault and packer storage account
  --vault_name|-vn              [Required]: Vault used to store default Username/Password for deployed VMSS
  --packer_storage_account|-psa [Required]: Storage account used for baked images
  --jenkins_username|-ju        [Required]: Username that Spinnaker will use to communicate with Jenkins
  --jenkins_password|-jp        [Required]: Password that Spinnaker will use to communicate with Jenkins
  --vm_fqdn|-vf                 [Required]: FQDN for the jenkins VM hosting the Aptly repository
  --region|-r                             : Region for VMSS created by Spinnaker, defaulted to westus
  --artifacts_location|-al                : Url used to reference other scripts/artifacts.
  --sas_token|-st                         : A sas token needed if the artifacts location is private.
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

# Set defaults
artifacts_location="https://raw.githubusercontent.com/Azure/azure-devops-utils/master/"
region="westus"

while [[ $# > 0 ]]
do
  key="$1"
  shift
  case $key in
    --app_id|-ai)
      app_id="$1";;
    --app_key|-ak)
      app_key="$1";;
    --tenant_id|-ti)
      tenant_id="$1";;
    --subscription_id|-si)
      subscription_id="$1";;
    --resource_group|-rg)
      resource_group="$1";;
    --vault_name|-vn)
      vault_name="$1";;
    --packer_storage_account|-psa)
      packer_storage_account="$1";;
    --jenkins_username|-ju)
      jenkins_username="$1";;
    --jenkins_password|-jp)
      jenkins_password="$1";;
    --vm_fqdn|-vf)
      vm_fqdn="$1";;
    --region|-r)
      region="$1";;
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

throw_if_empty app_id $app_id
throw_if_empty app_key $app_key
throw_if_empty tenant_id $tenant_id
throw_if_empty subscription_id $subscription_id
throw_if_empty resource_group $resource_group
throw_if_empty vault_name $vault_name
throw_if_empty packer_storage_account $packer_storage_account
throw_if_empty jenkins_username $jenkins_username
throw_if_empty jenkins_password $jenkins_password
throw_if_empty vm_fqdn $vm_fqdn
throw_if_empty region $region

spinnaker_config_dir="/opt/spinnaker/config/"

# Configure cloudddriver
clouddriver_config_file="${spinnaker_config_dir}clouddriver-local.yml"
sudo touch "$clouddriver_config_file"
sudo cat <<EOF >"$clouddriver_config_file"
azure:
  enabled: true
  accounts:
    - name: my-azure-account
      clientId: APP_ID
      appKey: APP_KEY
      tenantId: TENANT_ID
      subscriptionId: SUBSCRIPTION_ID
      defaultResourceGroup: RESOURCE_GROUP
      defaultKeyVault: VAULT_NAME
EOF
sudo sed -i "s|APP_ID|${app_id}|" $clouddriver_config_file
sudo sed -i "s|APP_KEY|${app_key}|" $clouddriver_config_file
sudo sed -i "s|TENANT_ID|${tenant_id}|" $clouddriver_config_file
sudo sed -i "s|SUBSCRIPTION_ID|${subscription_id}|" $clouddriver_config_file
sudo sed -i "s|RESOURCE_GROUP|${resource_group}|" $clouddriver_config_file
sudo sed -i "s|VAULT_NAME|${vault_name}|" $clouddriver_config_file

# Configure rosco
rosco_config_file="${spinnaker_config_dir}rosco-local.yml"
sudo touch "$rosco_config_file"
sudo cat <<EOF >"$rosco_config_file"
debianRepository: http://ppa.launchpad.net/openjdk-r/ppa/ubuntu trusty main;http://VM_FQDN:9999 trusty main
defaultCloudProviderType: azure
azure:
  enabled: true
  accounts:
    - name: my-azure-account
      clientId: APP_ID
      appKey: APP_KEY
      tenantId: TENANT_ID
      subscriptionId: SUBSCRIPTION_ID
      objectId:
      packerResourceGroup: PACKER_RESOURCE_GROUP
      packerStorageAccount: PACKER_STORAGE_ACCOUNT
EOF
sudo sed -i "s|VM_FQDN|${vm_fqdn}|" $rosco_config_file
sudo sed -i "s|APP_ID|${app_id}|" $rosco_config_file
sudo sed -i "s|APP_KEY|${app_key}|" $rosco_config_file
sudo sed -i "s|TENANT_ID|${tenant_id}|" $rosco_config_file
sudo sed -i "s|SUBSCRIPTION_ID|${subscription_id}|" $rosco_config_file
sudo sed -i "s|PACKER_RESOURCE_GROUP|${resource_group}|" $rosco_config_file
sudo sed -i "s|PACKER_STORAGE_ACCOUNT|${packer_storage_account}|" $rosco_config_file

# Configure igor
igor_config_file="${spinnaker_config_dir}igor-local.yml"
sudo touch "$igor_config_file"
sudo cat <<EOF >"$igor_config_file"
jenkins:
  enabled: true
  masters:
    - name: Jenkins
      address: http://localhost:8080
      username: JENKINS_USERNAME
      password: JENKINS_PASSWORD
EOF
sudo sed -i "s|JENKINS_USERNAME|${jenkins_username}|" $igor_config_file
sudo sed -i "s|JENKINS_PASSWORD|${jenkins_password}|" $igor_config_file

# Configure gate
gate_config_file="${spinnaker_config_dir}gate-local.yml"
sudo touch "$gate_config_file"
sudo cat <<EOF >"$gate_config_file"
services:
  igor:
    enabled: true
EOF

# Set Azure environment variables
spinnaker_env_vars="/etc/default/spinnaker"
sudo sed -i "s|SPINNAKER_AZURE_ENABLED=false|SPINNAKER_AZURE_ENABLED=true|" $spinnaker_env_vars
sudo sed -i "s|SPINNAKER_AZURE_DEFAULT_REGION=westus|SPINNAKER_AZURE_DEFAULT_REGION=$region|" $spinnaker_env_vars
sudo /opt/spinnaker/bin/reconfigure_spinnaker.sh

# Restart services
run_util_script "spinnaker/await_restart_service/await_restart_service.sh" --service clouddriver
run_util_script "spinnaker/await_restart_service/await_restart_service.sh" --service rosco
run_util_script "spinnaker/await_restart_service/await_restart_service.sh" --service igor
run_util_script "spinnaker/await_restart_service/await_restart_service.sh" --service gate