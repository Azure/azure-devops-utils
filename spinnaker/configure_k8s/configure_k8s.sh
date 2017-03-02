#!/bin/bash

function print_usage() {
  cat <<EOF
Command
  $0 

Arguments
  --storage_account_name|-san [Required]: Storage account name used by front50
  --storage_account_key|-sak  [Required]: Storage account key used by front50
  --registry|-rg              [Required]: Registry url
  --client_id|-ci             [Required]: Service principal client id used to access the registry
  --client_key|-ck            [Required]: Service principal client key used to access the registry
  --repository|-rp                      : DockerHub repository to configure
  --artifacts_location|-al              : Url used to reference other scripts/artifacts.
  --sas_token|-st                       : A sas token needed if the artifacts location is private.
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

# Set defaults
artifacts_location="https://raw.githubusercontent.com/Azure/azure-devops-utils/master/"

while [[ $# > 0 ]]
do
  key="$1"
  shift
  case $key in
    --storage_account_name|-san)
      storage_account_name="$1"
      shift
      ;;
    --storage_account_key|-sak)
      storage_account_key="$1"
      shift
      ;;
    --registry|-rg)
      registry="$1"
      # Remove http prefix and trailing slash from registry if they exist
      registry=${registry#"https://"}
      registry=${registry#"http://"}
      registry=${registry%"/"}
      shift
      ;;
    --client_id|-ci)
      client_id="$1"
      shift
      ;;
    --client_key|-ck)
      client_key="$1"
      shift
      ;;
    --repository|-rp)
      repository="$1"
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
      echo "ERROR: Unknown argument '$key'" 1>&2
      exit -1
  esac
done

throw_if_empty --storage_account_name $storage_account_name
throw_if_empty --storage_account_key $storage_account_key
throw_if_empty --registry $registry
throw_if_empty --client_id $client_id
throw_if_empty --client_key $client_key

spinnaker_config_dir="/opt/spinnaker/config/"
spinnaker_config_file="${spinnaker_config_dir}spinnaker-local.yml"
clouddriver_config_file="${spinnaker_config_dir}clouddriver-local.yml"
igor_config_file="${spinnaker_config_dir}igor-local.yml"

# Enable Azure storage for front50
sudo /opt/spinnaker/install/change_cassandra.sh --echo=inMemory --front50=azs
sudo sed -i "s|storageAccountName:|storageAccountName: ${storage_account_name}|" $spinnaker_config_file
sudo sed -i "s|storageAccountKey:|storageAccountKey: ${storage_account_key}|" $spinnaker_config_file

# Configure Spinnaker for Docker Hub and Azure Container Registry
sudo touch "$clouddriver_config_file"
sudo cat <<EOF >"$clouddriver_config_file"
kubernetes:
  enabled: true
  accounts:
    - name: my-kubernetes-account
      dockerRegistries:
        - accountName: docker-hub-registry
        - accountName: azure-container-registry

dockerRegistry:
  enabled: true
  accounts:
    - name: docker-hub-registry
      address: https://index.docker.io/
      repositories:
        - REPLACE_REPOSITORY
        - library/nginx
        - library/redis
        - library/ubuntu
    - name: azure-container-registry
      address: https://REPLACE_ACR_REGISTRY/
      username: REPLACE_ACR_USERNAME
      password: REPLACE_ACR_PASSWORD
EOF

sudo sed -i "s|REPLACE_ACR_REGISTRY|${registry}|" $clouddriver_config_file
sudo sed -i "s|REPLACE_ACR_USERNAME|${client_id}|" $clouddriver_config_file
sudo sed -i "s|REPLACE_ACR_PASSWORD|${client_key}|" $clouddriver_config_file

# Replace docker repository in config if specified
if [ -n "$repository" ]; then
    sudo sed -i "s|REPLACE_REPOSITORY|${repository}|" $clouddriver_config_file
else
    # Otherwise delete the line
    sudo sed -i "/REPLACE_REPOSITORY/d" $clouddriver_config_file
fi

# Enable docker registry in Igor so that docker triggers work
sudo touch "$igor_config_file"
sudo cat <<EOF >"$igor_config_file"
dockerRegistry:
  enabled: true
EOF

# Restart spinnaker so that config changes take effect
curl --silent "${artifacts_location}spinnaker/await_restart_spinnaker/await_restart_spinnaker.sh${artifacts_location_sas_token}" | sudo bash -s