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

run_util_script "spinnaker/install_spinnaker/install_spinnaker.sh" -san "$storage_account_name" -sak "$storage_account_key"  -al "$artifacts_location" -st "$artifacts_location_sas_token"

echo "Reconfiguring front50 to use ${front50_port} so that it doesn't conflict with Jenkins..."
sudo sed -i "s|front50:|front50:\n    port: $front50_port|" /opt/spinnaker/config/spinnaker-local.yml
sudo service spinnaker restart # We have to restart all services so that they know how to communicate to front50

run_util_script "spinnaker/configure_vmss/configure_vmss.sh" -ai "${app_id}" -ak "${app_key}" -ti "${tenant_id}" -si "${subscription_id}" -rg "${resource_group}" -vn "${vault_name}" -psa "${packer_storage_account}" -ju "${jenkins_username}" -jp "${jenkins_password}" -vf "${vm_fqdn}" -r "$region" -al "${artifacts_location}" -st "${artifacts_location_sas_token}"

run_util_script "jenkins/install_jenkins.sh" -jf "${vm_fqdn}" -al "${artifacts_location}" -st "${artifacts_location_sas_token}"

run_util_script "jenkins/init-aptly-repo.sh" -vf "${vm_fqdn}" -rn "${repository_name}"

run_util_script "jenkins/add-aptly-build-job.sh" -al "${artifacts_location}" -st "${artifacts_location_sas_token}"

echo "Setting up initial user..."
echo "jenkins.model.Jenkins.instance.securityRealm.createAccount(\"$jenkins_username\", \"$jenkins_password\")"  > addUser.groovy
run_util_script "jenkins/run-cli-command.sh" -cif "addUser.groovy" -c "groovy ="
rm "addUser.groovy"