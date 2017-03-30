#!/bin/bash

function print_usage() {
  cat <<EOF
https://github.com/Azure/azure-quickstart-templates/tree/master/301-jenkins-acr-spinnaker-k8s
Command
  $0
Arguments
  --app_id|-ai                       [Required] : Service principal app id  used to dynamically manage resource in your subscription
  --app_key|-ak                      [Required] : Service principal app key used to dynamically manage resource in your subscription
  --subscription_id|-si              [Required] : Subscription Id
  --tenant_id|-ti                    [Required] : Tenant Id
  --user_name|-un                    [Required] : Admin user name for your Spinnaker VM and Kubernetes cluster
  --git_repository|-gr               [Required] : Git URL with a Dockerfile in it's root
  --resource_group|-rg               [Required] : Resource group containing your Kubernetes cluster
  --master_fqdn|-mf                  [Required] : Master FQDN of your Kubernetes cluster
  --master_count|-mc                 [Required] : Master count of your Kubernetes cluster
  --storage_account_name|-san        [Required] : Storage Account name used for Spinnaker's persistent storage
  --storage_account_key|-sak         [Required] : Storage Account key used for Spinnaker's persistent storage
  --azure_container_registry|-acr    [Required] : Azure Container Registry url
  --docker_repository|-dr                       : Name of the docker repository to be created in your ACR
  --pipeline_port|-pp                           : Port to target in your pipeline
  --artifacts_location|-al                      : Url used to reference other scripts/artifacts.
  --sas_token|-st                               : A sas token needed if the artifacts location is private.
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
pipeline_port="8000"
artifacts_location="https://raw.githubusercontent.com/Azure/azure-devops-utils/master/"
docker_repository="${vm_user_name}/myfirstapp"

while [[ $# > 0 ]]
do
  key="$1"
  shift
  case $key in
    --app_id|-ai)
      app_id="$1"
      shift
      ;;
    --app_key|-ak)
      app_key="$1"
      shift
      ;;
    --subscription_id|-si)
      subscription_id="$1"
      shift
      ;;
    --tenant_id|-ti)
      tenant_id="$1"
      shift
      ;;
    --user_name|-un)
      user_name="$1"
      shift
      ;;
    --git_repository|-gr)
      git_repository="$1"
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
    --storage_account_name|-san)
      storage_account_name="$1"
      shift
      ;;
    --storage_account_key|-sak)
      storage_account_key="$1"
      shift
      ;;
    --azure_container_registry|-acr)
      azure_container_registry="$1"
      shift
      ;;
    --docker_repository|-dr)
      docker_repository="$1"
      shift
      ;;
    --pipeline_port|-pp)
      pipeline_port="$1"
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

throw_if_empty --app_id $app_id
throw_if_empty --app_key $app_key
throw_if_empty --subscription_id $subscription_id
throw_if_empty --tenant_id $tenant_id
throw_if_empty --user_name $user_name
throw_if_empty --git_repository $git_repository
throw_if_empty --resource_group $resource_group
throw_if_empty --master_fqdn $master_fqdn
throw_if_empty --master_count $master_count
throw_if_empty --storage_account_name $storage_account_name
throw_if_empty --storage_account_key $storage_account_key
throw_if_empty --azure_container_registry $azure_container_registry
throw_if_empty --docker_repository $docker_repository
throw_if_empty --pipeline_port $pipeline_port

include_kubernetes_pipeline="1"
pipeline_registry="$azure_container_registry"
front50_port="8081"

# Configure Spinnaker (do this first because the default InstallSpinnaker.sh script sets up front50 on port 8080 and that might fail if we did Jenkins first)
curl --silent "${artifacts_location}quickstart_template/spinnaker_vm_to_kubernetes.sh${artifacts_location_sas_token}" | sudo bash -s -- -ai "$app_id" -ak "$app_key" -si "$subscription_id" -ti "$tenant_id" -un "$user_name" -rg "$resource_group" -mf "$master_fqdn" -mc "$master_count" -san "$storage_account_name" -sak "$storage_account_key" -acr "$azure_container_registry" -ikp "$include_kubernetes_pipeline" -prg "$pipeline_registry" -prp "$docker_repository" -pp "$pipeline_port" -fp "$front50_port" -al "$artifacts_location" -st "$artifacts_location_sas_token"

# Configure Jenkins
curl --silent "${artifacts_location}quickstart_template/201-jenkins-to-azure-container-registry.sh${artifacts_location_sas_token}" | sudo bash -s -- -u "$user_name" -g "$git_repository" -r "https://$azure_container_registry" -ru "$app_id" -rp "$app_key" -rr "$docker_repository" -al "$artifacts_location" -st "$artifacts_location_sas_token"
