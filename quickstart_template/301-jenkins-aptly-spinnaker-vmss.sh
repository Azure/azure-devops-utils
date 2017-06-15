#!/bin/bash

function print_usage() {
  cat <<EOF
Command
  $0 

Arguments
  --app_id|-ai                           [Required]: Service principal app id used by Spinnaker to dynamically manage resources
  --app_key|-ak                          [Required]: Service principal app key used by Spinnaker to dynamically manage resources
  --jenkins_username|-ju                 [Required]: Jenkins username
  --jenkins_password|-jp                 [Required]: Jenkins password
  --tenant_id|-ti                        [Required]: Tenant id
  --subscription_id|-si                  [Required]: Subscription id
  --resource_group|-rg                   [Required]: Resource group containing your key vault and packer storage account
  --vault_name|-vn                       [Required]: Vault used to store default Username/Password for deployed VMSS
  --storage_account_name|-san            [Required]: Storage account name used for front50
  --storage_account_key|-sak             [Required]: Storage account key used for front50
  --packer_storage_account|-psa          [Required]: Storage account name used for baked images
  --vm_fqdn|-vf                          [Required]: FQDN for the Jenkins instance hosting the Aptly repository
  --region|-r                                      : Region for VMSS created by Spinnaker, defaulted to westus
  --artifacts_location|-al                         : Url used to reference other scripts/artifacts.
  --sas_token|-st                                  : A sas token needed if the artifacts location is private.
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
region="westus"
repository_name="hello-karyon-rxnetty"
artifacts_location="https://raw.githubusercontent.com/Azure/azure-devops-utils/master/"
artifacts_location_sas_token=""
front50_port="8081"

while [[ $# > 0 ]]
do
  key="$1"
  shift
  case $key in
    --app_id|-ai)
      app_id="$1";;
    --app_key|-ak)
      app_key="$1";;
    --jenkins_username|-ju)
      jenkins_username="$1";;
    --jenkins_password|-jp)
      jenkins_password="$1";;
    --tenant_id|-ti)
      tenant_id="$1";;
    --subscription_id|-si)
      subscription_id="$1";;
    --resource_group|-rg)
      resource_group="$1";;
    --vault_name|-vn)
      vault_name="$1";;
    --storage_account_name|-san)
      storage_account_name="$1";;
    --storage_account_key|-sak)
      storage_account_key="$1";;
    --packer_storage_account|-psa)
      packer_storage_account="$1";;
    --region|-r)
      region="$1";;
    --vm_fqdn|-vf)
      vm_fqdn="$1";;
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
throw_if_empty jenkins_username $jenkins_username
throw_if_empty jenkins_password $jenkins_password
throw_if_empty tenant_id $tenant_id
throw_if_empty subscription_id $subscription_id
throw_if_empty resource_group $resource_group
throw_if_empty vault_name $vault_name
throw_if_empty storage_account_name $storage_account_name
throw_if_empty storage_account_key $storage_account_key
throw_if_empty packer_storage_account $packer_storage_account
throw_if_empty vm_fqdn $vm_fqdn
throw_if_empty region $region

default_hal_config="/home/$jenkins_username/.hal/default"

run_util_script "spinnaker/install_halyard/install_halyard.sh" -san "$storage_account_name" -sak "$storage_account_key" -u "$jenkins_username"

# Change front50 port so it doesn't conflict with Jenkins
front50_settings="$default_hal_config/service-settings/front50.yml"
sudo -u $jenkins_username mkdir -p $(dirname "$front50_settings")
sudo -u $jenkins_username touch "$front50_settings"
echo "port: $front50_port" > "$front50_settings"

# Configure Azure provider for Spinnaker
echo "$app_key" | hal config provider azure account add my-azure-account \
  --client-id "$app_id" \
  --tenant-id "$tenant_id" \
  --subscription-id "$subscription_id" \
  --default-key-vault "$vault_name" \
  --default-resource-group "$resource_group" \
  --packer-resource-group "$resource_group" \
  --packer-storage-account "$packer_storage_account" \
  --app-key
hal config provider azure enable

# Configure Rosco (these params are not supported by Halyard yet)
rosco_config="$default_hal_config/profiles/rosco-local.yml"
sudo -u $jenkins_username mkdir -p $(dirname "$rosco_config")
sudo -u $jenkins_username touch "$rosco_config"
cat <<EOF > "$rosco_config"
debianRepository: http://ppa.launchpad.net/openjdk-r/ppa/ubuntu trusty main;http://$vm_fqdn:9999 trusty main
defaultCloudProviderType: azure
EOF

# Configure Jenkins for Spinnaker
echo "$jenkins_password" | hal config ci jenkins master add Jenkins \
    --address "http://localhost:8080" \
    --username "$jenkins_username" \
    --password
hal config ci jenkins enable

# Deploy Spinnaker to local VM
sudo hal deploy apply

run_util_script "jenkins/install_jenkins.sh" -jf "${vm_fqdn}" -al "${artifacts_location}" -st "${artifacts_location_sas_token}"

run_util_script "jenkins/init-aptly-repo.sh" -vf "${vm_fqdn}" -rn "${repository_name}"

run_util_script "jenkins/add-aptly-build-job.sh" -al "${artifacts_location}" -st "${artifacts_location_sas_token}"

echo "Setting up initial user..."
echo "jenkins.model.Jenkins.instance.securityRealm.createAccount(\"$jenkins_username\", \"$jenkins_password\")"  > addUser.groovy
run_util_script "jenkins/run-cli-command.sh" -cif "addUser.groovy" -c "groovy ="
rm "addUser.groovy"

# Wait for Spinnaker services to be up before returning
timeout=180
echo "while !(nc -z localhost 8084) || !(nc -z localhost 9000); do sleep 1; done" | timeout $timeout bash
return_value=$?
if [ $return_value -ne 0 ]; then
  >&2 echo "Failed to connect to Spinnaker within '$timeout' seconds."
  exit $return_value
fi