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
  --storage_account_name|-san        [Required] : Storage Account name used for Spinnaker's persistent storage
  --storage_account_key|-sak         [Required] : Storage Account key used for Spinnaker's persistent storage
  --azure_container_registry|-acr    [Required] : Azure Container Registry url
  --jenkins_fqdn|-jf                 [Required] : Jenkins FQDN
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

function add_empty_image_to_acr() {
  # Install docker if not already installed
  if !(command -v docker >/dev/null); then
    sudo curl -sSL https://get.docker.com/ | sh
  fi
  sudo gpasswd -a $user_name docker

  # Add (virtually) empty container to ACR to properly initialize Spinnaker. This fixes two bugs:
  # 1. The pipeline isn't triggered on the first push to the ACR (according to the source code, Igor "avoids publishing an event if this account has no indexed images (protects against a flushed redis)")
  # 2. Some dropdowns in the UI for the pipeline display a 'loading' symbol rather than the repository we configured
  temp_dir=$(mktemp -d)
  touch "$temp_dir/README"
  echo "This container is intentionally empty and only used as a placeholder." >"$temp_dir/README"
  touch "$temp_dir/Dockerfile"
  echo -e "FROM scratch\nADD . README" >"$temp_dir/Dockerfile"
  # We added the user to the docker group above, but that doesn't take effect until the next login so we still need to use sudo here
  sudo docker login "$azure_container_registry" -u "$app_id" -p "$app_key"
  sudo docker build $temp_dir --tag "$azure_container_registry/$docker_repository"
  sudo docker push "$azure_container_registry/$docker_repository"
  sudo docker rmi "$azure_container_registry/$docker_repository"
  sudo docker logout
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

function add_bash_login() {
  bash_login="/home/${user_name}/.bash_login"
  touch "$bash_login"
  cat <<EOF > "$bash_login"
### Connect to Spinnaker ###
echo "Connecting to Spinnaker..."
hal deploy connect --no-validate &>/dev/null &

# Wait for connection
echo "while !(nc -z localhost 8084) || !(nc -z localhost 9000); do sleep 1; done" | timeout 20 bash

if [ $? -ne 0 ]; then
  echo "Failed to connect to Spinnaker."
else
  echo "Successfully connected to Spinnaker."
  echo "Enter 'Ctrl-C' in your terminal to exit the connection in the background."
fi

echo "Edit your ~/.bash_login file and remove the 'Connect to Spinnaker' section if you do not want to auto-connect on login."
### Connect to Spinnaker ###
EOF
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
    --jenkins_fqdn|-jf)
      jenkins_fqdn="$1"
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
throw_if_empty --storage_account_name $storage_account_name
throw_if_empty --storage_account_key $storage_account_key
throw_if_empty --azure_container_registry $azure_container_registry
throw_if_empty --docker_repository $docker_repository
throw_if_empty --pipeline_port $pipeline_port
throw_if_empty --jenkins_fqdn $jenkins_fqdn

add_empty_image_to_acr

install_kubectl

install_az

run_util_script "spinnaker/install_halyard/install_halyard.sh" -san "$storage_account_name" -sak "$storage_account_key" -u "$user_name"

# Copy kube config
az login --service-principal -u "$app_id" -p "$app_key" --tenant "$tenant_id"
az account set --subscription "$subscription_id"
run_util_script "spinnaker/copy_kube_config/copy_kube_config.sh" -un "$user_name" -rg "$resource_group" -mf "$master_fqdn"
az logout

# Configure Spinnaker Docker Registry Accounts
docker_hub_account="docker-hub-registry"
hal config provider docker-registry account add $docker_hub_account \
  --address "https://index.docker.io/" \
  --repositories "library/nginx" "library/redis" "library/ubuntu" # Spinnaker can't get the entire catalog for a public registry, so we have to list a few repos
acr_account="azure-container-registry"
echo "$app_key" | hal config provider docker-registry account add $acr_account \
  --address "https://$azure_container_registry/" \
  --username "$app_id" \
  --password
hal config provider docker-registry enable

# Configure Spinnaker Kubernetes Account
kubeconfig_path="/home/${user_name}/.kube/config"
my_kubernetes_account="my-kubernetes-account"
hal config provider kubernetes account add $my_kubernetes_account \
  --kubeconfig-file "$kubeconfig_path" \
  --context $(kubectl config current-context --kubeconfig "$kubeconfig_path") \
  --docker-registries "$docker_hub_account" "$acr_account"
hal config provider kubernetes enable

# Deploy Spinnaker to the Kubernetes cluster
hal config deploy edit --account-name $my_kubernetes_account --type distributed
hal deploy apply

# Automatically connect to Spinnaker when logging in to DevOps VM
add_bash_login

# Add Kubernetes pipeline
run_util_script "spinnaker/add_k8s_pipeline/add_k8s_pipeline.sh" \
  -an "$acr_account" \
  -rg "$azure_container_registry" \
  -rp "$docker_repository" \
  -p "$pipeline_port" \
  -al "$artifacts_location" \
  -st "$artifacts_location_sas_token"

run_util_script "quickstart_template/201-jenkins-acr.sh" -u "$user_name" \
  -g "$git_repository" \
  -r "https://$azure_container_registry" \
  -ru "$app_id" \
  -rp "$app_key" \
  -rr "$docker_repository" \
  -jf "$jenkins_fqdn" \
  -al "$artifacts_location" \
  -st "$artifacts_location_sas_token"