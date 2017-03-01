#!/bin/bash

while getopts :i:p:s:t:u:g:f:c:n:k:r:e:a:o:l:y:x: option; do
  case "${option}" in
        i) client_id="${OPTARG}";;
        p) client_key="${OPTARG}";;
        s) subscription_id="${OPTARG}";;
        t) tenant_id="${OPTARG}";;
        u) admin_user_name="${OPTARG}";;
        g) resource_group="${OPTARG}";;
        f) master_fqdn="${OPTARG}";;
        c) master_count="${OPTARG}";;
        n) storage_account_name="${OPTARG}";;
        k) storage_account_key="${OPTARG}";;
        r) azure_container_registry="${OPTARG}";;
        e) include_kubernetes_pipeline="${OPTARG}";;
        l) pipeline_registry="${OPTARG}";;
        y) pipeline_repository="${OPTARG}";;
        x) pipeline_port="${OPTARG}";;
        a) artifacts_location="${OPTARG}";;
        o) artifacts_location_sas_token="${OPTARG}";;
    esac
done

spinnaker_kube_config_file="/home/spinnaker/.kube/config"
kubectl_file="/usr/local/bin/kubectl"
docker_hub_registry="index.docker.io"

#Install Spinnaker
curl --silent https://raw.githubusercontent.com/spinnaker/spinnaker/master/InstallSpinnaker.sh | sudo bash -s -- --quiet --noinstall_cassandra

# Install Azure cli
curl -sL https://deb.nodesource.com/setup_4.x | sudo -E bash -
sudo apt-get -y install nodejs
sudo npm install -g azure-cli

# Login to azure cli using service principal
azure telemetry --disable
azure login --service-principal -u $client_id -p $client_key --tenant $tenant_id
azure account set $subscription_id

# Copy kube config to this VM
curl --silent "${artifacts_location}spinnaker/copy_kube_config/copy_kube_config.sh${artifacts_location_sas_token}" | sudo bash -s -- -un "$admin_user_name" -rg "$resource_group" -mf "$master_fqdn" -mc "$master_count" -al "$artifacts_location" -st "$artifacts_location_sas_token"

# If targeting docker, we have to explicitly add the repository to the config. For private registries, 
# there's no need because Spinnaker can dynamically retrieve the entire catalog of a registry.
if [ "$pipeline_registry" == "$docker_hub_registry" ]; then
    docker_repository="$pipeline_repository"
else
    docker_repository=""
fi

# Configure Spinnaker to target kubernetes
curl --silent "${artifacts_location}spinnaker/configure_k8s/configure_k8s.sh${artifacts_location_sas_token}" | sudo bash -s -- -san "$storage_account_name" -sak "$storage_account_key" -rg "$azure_container_registry" -ci "$client_id" -ck "$client_key" -rp "$docker_repository" -al "$artifacts_location" -st "$artifacts_location_sas_token"

# Install and setup Kubernetes cli for admin user
sudo curl -L -s -o $kubectl_file https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
sudo chmod +x $kubectl_file
mkdir /home/${admin_user_name}/.kube
sudo cp $spinnaker_kube_config_file /home/${admin_user_name}/.kube/config

# Create pipeline if enabled
if (( $include_kubernetes_pipeline )); then
    if [ "$pipeline_registry" == "$docker_hub_registry" ]; then
        docker_account_name="docker-hub-registry"
        pipeline_registry_url="$docker_hub_registry"
    else
        docker_account_name="azure-container-registry"
        pipeline_registry_url="$azure_container_registry"
    fi

    curl --silent "${artifacts_location}spinnaker/add_k8s_pipeline/add_k8s_pipeline.sh${artifacts_location_sas_token}" | sudo bash -s -- -an "$docker_account_name" -rg "$pipeline_registry_url" -rp "$pipeline_repository" -p "$pipeline_port" -al "$artifacts_location" -st "$artifacts_location_sas_token"
fi