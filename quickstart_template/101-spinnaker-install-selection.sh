#!/bin/bash

function print_usage() {
  cat <<EOF
Command
  $0 

Arguments
  --app_id|-ai                           [Required]: Service principal app id used by Spinnaker to dynamically manage resources
  --app_key|-ak                          [Required]: Service principal app key used by Spinnaker to dynamically manage resources
  --username|-u                          [Required]: username
  --tenant_id|-ti                        [Required]: Tenant id
  --subscription_id|-si                  [Required]: Subscription id
  --resource_group|-rg                   [Required]: Resource group containing your key vault and packer storage account
  --vault_name|-vn                       [Required]: Vault used to store default Username/Password for deployed VMSS
  --storage_account_name|-san            [Required]: Storage account name used for front50
  --storage_account_key|-sak             [Required]: Storage account key used for front50
  --vm_fqdn|-vf                          [Required]: FQDN for the Jenkins instance hosting the Aptly repository
  --use_ssh_public_key|-uspk             [Required]: Use ssh public key
  --jenkins_password|-jp                           : Jenkins password
  --aks_cluster_name|-acn                          : AKS ClusterName for deploy spinnaker
  --aks_resource_group|-arg                        : Resource group containing your aks
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
artifacts_location="https://raw.githubusercontent.com/Azure/azure-devops-utils/master/"
artifacts_location_sas_token=""

while [[ $# > 0 ]]
do
  key="$1"
  shift
  case $key in
    --app_id|-ai)
      app_id="$1";;
    --app_key|-ak)
      app_key="$1";;
    --username|-u)
      username="$1";;
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
    --aks_cluster_name|-acn)
      aks_cluster_name="$1";;
    --aks_resource_group|-arg)
      aks_resource_group="$1";;
    --region|-r)
      region="$1";;
    --vm_fqdn|-vf)
      vm_fqdn="$1";;
    --use_ssh_public_key|-uspk)
      use_ssh_public_key="$1";;
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
throw_if_empty username $username
throw_if_empty tenant_id $tenant_id
throw_if_empty subscription_id $subscription_id
throw_if_empty resource_group $resource_group
throw_if_empty vault_name $vault_name
throw_if_empty storage_account_name $storage_account_name
throw_if_empty storage_account_key $storage_account_key
throw_if_empty vm_fqdn $vm_fqdn
throw_if_empty use_ssh_public_key $use_ssh_public_key

#installed on the vmss if there is no aks_cluster_name, otherwise installed on aks
if [ -z "$aks_cluster_name" ]
then
      run_util_script "quickstart_template/301-jenkins-aptly-spinnaker-vmss.sh"  -ju "$username" -jp "$jenkins_password" -ai "$app_id" -ak "$app_key" -ti "$tenant_id" -si "$subscription_id" -rg "$resource_group" -vn "$vault_name" -san "$storage_account_name" -sak "$storage_account_key" -vf "$vm_fqdn" -r "$region" -al "$artifacts_location" -st "$artifacts_location_sas_token" -uspk "$use_ssh_public_key"
else
      run_util_script "quickstart_template/101-spinnaker-aks.sh"  -u "$username" -ai "$app_id" -ak "$app_key" -ti "$tenant_id" -si "$subscription_id" -rg "$resource_group" -vn "$vault_name" -acn "$aks_cluster_name" -arg "$aks_resource_group" -san "$storage_account_name" -sak "$storage_account_key" -r "$region" -al "$artifacts_location" -st "$artifacts_location_sas_token" -uspk "$use_ssh_public_key"
fi
