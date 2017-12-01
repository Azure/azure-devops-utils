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
  --acs_name|-an                     [Required] : Name of the ACS cluster with Kubernetes orchestrator
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

function allow_acs_nsg_access()
{
  local source_ip=$1
  local resource_group=$2

  local nsgs=($(az network nsg list --resource-group "$resource_group" --query '[].name' --output tsv | grep -e "^k8s-master-"))
  local port_range=22
  if [ "$source_ip" = Internet ]; then
    # web job deletes the rule if the port is set to 22 for wildcard internet access
    port_range="21-23"
  fi
  for nsg in "${nsgs[@]}"; do
    local name="allow_$source_ip"
    # used a fixed priority here
    local max_priority="$(az network nsg rule list -g "$resource_group" --nsg-name "$nsg" --query '[].priority' --output tsv | sort -n | tail -n1)"
    local priority="$(expr "$max_priority" + 50)"
    log_info "Add allow $source_ip rules to NSG $nsg in resource group $resource_group, with priority $priority"
    az network nsg rule create --priority "$priority" --destination-port-ranges "$port_range" --resource-group "$resource_group" \
        --nsg-name "$nsg" --name "$name" --source-address-prefixes "$source_ip"
    #az network nsg rule create --priority "$priority" --destination-port-ranges 22 --resource-group "$resource_group" \
    #    --nsg-name "$nsg" --name "$name" --source-address-prefixes "$source_ip"
  done
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
    --acs_name|-an)
      acs_name="$1"
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
throw_if_empty --acs_name "$acs_name"
throw_if_empty --jenkins_fqdn "$jenkins_fqdn"

install_kubectl

install_az

sudo apt-get install --yes jq

az login --service-principal -u "$app_id" -p "$app_key" --tenant "$tenant_id"
az account set --subscription "$subscription_id"
master_fqdn="$(az acs show --resource-group "$resource_group" --name "$acs_name" --query masterProfile.fqdn --output tsv)"
master_username="$(az acs show --resource-group "$resource_group" --name "$acs_name" --query linuxProfile.adminUsername --output tsv)"

temp_user_name="$(uuidgen | sed 's/-//g')"
temp_key_path="$(mktemp -d)/temp_key"
ssh-keygen -t rsa -N "" -f "$temp_key_path"
temp_pub_key="${temp_key_path}.pub"

# Allow Jenkins master to access the ACS K8s master via SSH
jenkins_ip=($(dig +short "$jenkins_fqdn"))
for ip in "${jenkins_ip[@]}"; do
  [[ -z "$ip" ]] && continue
  allow_acs_nsg_access "$ip" "$resource_group"
done

master_vm_ids=$(az vm list -g "$resource_group" --query "[].id" -o tsv | grep "k8s-master-")
>&2 echo "Master VM ids: $master_vm_ids"

# Add the generated SSH public key to the authroized keys for the Kubernetes master admin user in two steps:
#   1. add a temporary user using Azure CLI with the generated username and public key
#   2. login with the temporary user, and append its .ssh/authorized_keys which is the generated public key to the master user's authorized_keys list.
# this will be used in Jenkins to authenticate with the Kubernetes master node via SSH
az vm user update -u "$temp_user_name" --ssh-key-value "$temp_pub_key" --ids "$master_vm_ids"
ssh -o StrictHostKeyChecking=no -i "$temp_key_path" "$temp_user_name@$master_fqdn" "[ -d '/home/$master_username' ] && (cat .ssh/authorized_keys | sudo tee -a /home/$master_username/.ssh/authorized_keys)"

# Remove temporary credentials on every kubernetes master vm
az vm user delete -u "$temp_user_name" --ids "$master_vm_ids"
az logout

#install jenkins
run_util_script "jenkins/install_jenkins.sh" -jf "${jenkins_fqdn}" -al "${artifacts_location}" -st "${artifacts_location_sas_token}"

run_util_script "jenkins/run-cli-command.sh" -c "install-plugin ssh-agent -deploy"

run_util_script "jenkins/blue-green/add-blue-green-job.sh" \
    -j "http://localhost:8080/" \
    -ju "admin" \
    --acs_resource_group "$resource_group" \
    --acs_name "$acs_name" \
    --ssh_credentials_username "$master_username" \
    --ssh_credentials_key_file "$temp_key_path" \
    --sp_subscription_id "$subscription_id" \
    --sp_client_id "$app_id" \
    --sp_client_password "$app_key" \
    --sp_tenant_id "$tenant_id" \
    --artifacts_location "$artifacts_location" \
    --sas_token "$artifacts_location_sas_token"

rm -f "$temp_key_path"
rm -f "$temp_pub_key"
