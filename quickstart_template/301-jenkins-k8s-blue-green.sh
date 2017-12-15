#!/bin/bash

function print_usage() {
  cat <<EOF
https://github.com/Azure/azure-quickstart-templates/tree/master/301-jenkins-k8s-blue-green
Command
  $0
Arguments
  --app_id|-ai                       [Required] : Service principal app id  used to dynamically manage resource in your subscription
  --app_key|-ak                      [Required] : Service principal app key used to dynamically manage resource in your subscription
  --subscription_id|-si              [Required] : Subscription Id
  --tenant_id|-ti                    [Required] : Tenant Id
  --resource_group|-rg               [Required] : Resource group containing your Kubernetes cluster
  --aks_name|-an                     [Required] : Name of the Azure Kubernetes Service
  --jenkins_fqdn|-jf                 [Required] : Jenkins FQDN
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

function install_kubectl() {
  if !(command -v kubectl >/dev/null); then
    kubectl_file="/usr/local/bin/kubectl"
    sudo curl -L -s -o $kubectl_file https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
    sudo chmod +x $kubectl_file
  fi
}

function install_az() {
  if !(command -v az >/dev/null); then
    sudo apt-get update && sudo apt-get install -y libssl-dev libffi-dev python-dev
    echo "deb [arch=amd64] https://apt-mo.trafficmanager.net/repos/azure-cli/ wheezy main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
    sudo apt-key adv --keyserver apt-mo.trafficmanager.net --recv-keys 417A0893
    sudo apt-get install -y apt-transport-https
    sudo apt-get -y update && sudo apt-get install -y azure-cli
  fi
}

artifacts_location="https://raw.githubusercontent.com/Azure/azure-devops-utils/master/"

while [[ $# > 0 ]]
do
  key="$1"
  shift
  case "$key" in
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
    --resource_group|-rg)
      resource_group="$1"
      shift
      ;;
    --aks_name|-an)
      aks_name="$1"
      shift
      ;;
    --jenkins_fqdn|-jf)
      jenkins_fqdn="$1"
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

throw_if_empty --app_id "$app_id"
throw_if_empty --app_key "$app_key"
throw_if_empty --subscription_id "$subscription_id"
throw_if_empty --tenant_id "$tenant_id"
throw_if_empty --resource_group "$resource_group"
throw_if_empty --aks_name "$aks_name"
throw_if_empty --jenkins_fqdn "$jenkins_fqdn"

install_kubectl

install_az

sudo apt-get install --yes jq

#install jenkins
#install jenkins
run_util_script "jenkins/install_jenkins.sh" \
  --jenkins_release_type verified \
  --jenkins_version_location "${artifacts_location}jenkins/blue-green/verified-jenkins-version${artifacts_location_sas_token}" \
  --jenkins_fqdn "${jenkins_fqdn}" \
  --artifacts_location "${artifacts_location}" \
  --sas_token "${artifacts_location_sas_token}"

run_util_script "jenkins/blue-green/bootstrap-k8s-blue-green.sh" \
    --resource_group "$resource_group" \
    --aks_name "$aks_name" \
    --sp_subscription_id "$subscription_id" \
    --sp_client_id "$app_id" \
    --sp_client_password "$app_key" \
    --sp_tenant_id "$tenant_id" \
    --artifacts_location "$artifacts_location" \
    --sas_token "$artifacts_location_sas_token"

run_util_script "jenkins/blue-green/add-blue-green-job.sh" \
    -j "http://localhost:8080/" \
    -ju "admin" \
    --aks_resource_group "$resource_group" \
    --aks_name "$aks_name" \
    --sp_subscription_id "$subscription_id" \
    --sp_client_id "$app_id" \
    --sp_client_password "$app_key" \
    --sp_tenant_id "$tenant_id" \
    --artifacts_location "$artifacts_location" \
    --sas_token "$artifacts_location_sas_token"

rm -f "$temp_key_path"
rm -f "$temp_pub_key"
