#!/bin/bash

function print_usage() {
  cat <<EOF
https://github.com/Azure/azure-quickstart-templates/tree/master/201-spinnaker-acr-k8s
Command
  $0
Arguments
  --app_id|-ai                       [Required] : Service principal app id  used to dynamically manage resource in your subscription
  --app_key|-ak                      [Required] : Service principal app key used to dynamically manage resource in your subscription
  --subscription_id|-si              [Required] : Subscription Id
  --tenant_id|-ti                    [Required] : Tenant Id
  --user_name|-un                    [Required] : Admin user name for your Spinnaker VM and Kubernetes cluster
  --resource_group|-rg               [Required] : Resource group containing your Kubernetes cluster
  --master_fqdn|-mf                  [Required] : Master FQDN of your Kubernetes cluster
  --storage_account_name|-san        [Required] : Storage Account name used for Spinnaker's persistent storage
  --storage_account_key|-sak         [Required] : Storage Account key used for Spinnaker's persistent storage
  --azure_container_registry|-acr    [Required] : Azure Container Registry url
  --include_kubernetes_pipeline|-ikp            : Include a kubernetes pipeline (off by default).
  --pipeline_registry|-prg                      : Registry to target in the pipeline
  --pipeline_repository|-prp                    : Repository to target in the pipeline
  --pipeline_port|-pp                           : Port to target in your pipeline
  --front50_port|-fp                            : Port used for Front50, defaulted to 8080
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

#Set defaults
include_kubernetes_pipeline="0"
pipeline_registry="index.docker.io"
pipeline_repository="lwander/spin-kub-demo"
pipeline_port="8000"
artifacts_location="https://raw.githubusercontent.com/Azure/azure-devops-utils/master/"
front50_port=8080

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
    --include_kubernetes_pipeline|-ikp)
      include_kubernetes_pipeline="$1"
      shift
      ;;
    --pipeline_registry|-prg)
      pipeline_registry="$1"
      shift
      ;;
    --pipeline_repository|-prp)
      pipeline_repository="$1"
      shift
      ;;
    --pipeline_port|-pp)
      pipeline_port="$1"
      shift
      ;;
    --front50_port|-fp)
      front50_port="$1"
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
throw_if_empty --resource_group $resource_group
throw_if_empty --master_fqdn $master_fqdn
throw_if_empty --storage_account_name $storage_account_name
throw_if_empty --storage_account_key $storage_account_key
throw_if_empty --azure_container_registry $azure_container_registry
throw_if_empty --front50_port $front50_port

spinnaker_kube_config_file="/home/spinnaker/.kube/config"
kubectl_file="/usr/local/bin/kubectl"
docker_hub_registry="index.docker.io"

# Configure Spinnaker to use Azure Storage
run_util_script "spinnaker/install_spinnaker/install_spinnaker.sh" -san "$storage_account_name" -sak "$storage_account_key"  -al "$artifacts_location" -st "$artifacts_location_sas_token"

# Front50 conflicts with the default Jenkins port, so allow for using a different port
if [ "$front50_port" != "8080" ]; then
  sudo sed -i "s|front50:|front50:\n    port: $front50_port|" /opt/spinnaker/config/spinnaker-local.yml
  sudo service spinnaker restart # We have to restart all services so that they know how to communicate to front50
fi

# Install Azure cli
if !(command -v az >/dev/null); then
  sudo apt-get update && sudo apt-get install -y libssl-dev libffi-dev python-dev
  echo "deb [arch=amd64] https://apt-mo.trafficmanager.net/repos/azure-cli/ wheezy main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
  sudo apt-key adv --keyserver apt-mo.trafficmanager.net --recv-keys 417A0893
  sudo apt-get install -y apt-transport-https
  sudo apt-get -y update && sudo apt-get install -y azure-cli
fi

# Login to azure cli using service principal
az login --service-principal -u "$app_id" -p "$app_key" --tenant "$tenant_id"
az account set --subscription "$subscription_id"

# Copy kube config to this VM
run_util_script "spinnaker/copy_kube_config/copy_kube_config.sh" -un "$user_name" -rg "$resource_group" -mf "$master_fqdn"

# If targeting docker, we have to explicitly add the repository to the config. For private registries, 
# there's no need because Spinnaker can dynamically retrieve the entire catalog of a registry.
if [ "$pipeline_registry" == "$docker_hub_registry" ]; then
    docker_repository="$pipeline_repository"
else
    docker_repository=""
fi

# Configure Spinnaker to target kubernetes
run_util_script "spinnaker/configure_k8s/configure_k8s.sh" -rg "$azure_container_registry" -ai "$app_id" -ak "$app_key" -rp "$docker_repository" -al "$artifacts_location" -st "$artifacts_location_sas_token"

# Install and setup Kubernetes cli for admin user
if !(command -v kubectl >/dev/null); then
  sudo curl -L -s -o $kubectl_file https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
  sudo chmod +x $kubectl_file
  mkdir -p /home/${user_name}/.kube
  sudo cp $spinnaker_kube_config_file /home/${user_name}/.kube/config
fi

# Create pipeline if enabled
if (( $include_kubernetes_pipeline )); then
    if [ "$pipeline_registry" == "$docker_hub_registry" ]; then
        docker_account_name="docker-hub-registry"
    else
        docker_account_name="azure-container-registry"
        pipeline_registry="$azure_container_registry"

        #install docker if not already installed
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
        sudo docker build $temp_dir --tag "$azure_container_registry/$pipeline_repository"
        sudo docker push "$azure_container_registry/$pipeline_repository"
        sudo docker rmi "$azure_container_registry/$pipeline_repository"
        sudo docker logout
    fi

    run_util_script "spinnaker/add_k8s_pipeline/add_k8s_pipeline.sh" -an "$docker_account_name" -rg "$pipeline_registry" -rp "$pipeline_repository" -p "$pipeline_port" -al "$artifacts_location" -st "$artifacts_location_sas_token"
fi