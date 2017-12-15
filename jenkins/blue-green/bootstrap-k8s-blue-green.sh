#!/bin/bash

function print_usage() {
  cat <<EOF
Command
  $0
Arguments
  --resource_group|-g             [Required]: Resource group for the target Azure Kubernetes Service (AKS)
  --aks_name|-n                   [Required]: Name of the AKS
  --sp_subscription_id|-sps       [Required]: Subscription ID for the Azure service principal
  --sp_client_id|-spc             [Required]: Client ID for the Azure service principal
  --sp_client_password|-spp       [Required]: Client secrets for the Azure service principal
  --sp_tenant_id|-spt             [Required]: Tenant ID for the Azure service principal
  --sp_environment|-spe                     : Azure environment for the Azure service principal
  --artifacts_location|-al                  : Url used to reference other scripts/artifacts.
  --sas_token|-st                           : A sas token needed if the artifacts location is private.
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

#set defaults
sp_environment=Azure
artifacts_location="https://raw.githubusercontent.com/Azure/azure-devops-utils/master/"

while [[ $# > 0 ]]
do
  key="$1"
  shift
  case $key in
    --resource_group|-g)
      resource_group="$1"
      shift
      ;;
    --aks_name|-n)
      aks_name="$1"
      shift
      ;;
    --sp_subscription_id|-sps)
      sp_subscription_id="$1"
      shift
      ;;
    --sp_client_id|-spc)
      sp_client_id="$1"
      shift
      ;;
    --sp_client_password|-spp)
      sp_client_password="$1"
      shift
      ;;
    --sp_tenant_id|-spt)
      sp_tenant_id="$1"
      shift
      ;;
    --sp_environment|-spe)
      sp_environment="$1"
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

throw_if_empty --resource_group "$resource_group"
throw_if_empty --aks_name "$aks_name"
throw_if_empty --sp_subscription_id "$sp_subscription_id"
throw_if_empty --sp_client_id "$sp_client_id"
throw_if_empty --sp_client_password "$sp_client_password"
throw_if_empty --sp_tenant_id "$sp_tenant_id"
throw_if_empty --sp_environment "$sp_environment"

run_util_script jenkins/blue-green/fetch-k8s-deployment-config.sh \
  --artifacts_location "$artifacts_location" \
  --sas_token "${artifacts_location_sas_token}" \
  --directory k8s \
  -f deployment.yml -f service.yml -f test-endpoint.yml

sed -e 's/\${TARGET_ROLE}/blue/g; s/\${TOMCAT_VERSION}/7.0-jre8/g' k8s/deployment.yml >k8s/deployment-blue.yml
sed -e 's/\${TARGET_ROLE}/green/g; s/\${TOMCAT_VERSION}/7.0-jre8/g' k8s/deployment.yml >k8s/deployment-green.yml
sed -e 's/\${TARGET_ROLE}/blue/g; s/\${TOMCAT_VERSION}/7.0-jre8/g' k8s/service.yml >k8s/service-blue.yml
sed -e 's/\${TARGET_ROLE}/blue/g' k8s/test-endpoint.yml >k8s/test-endpoint-blue.yml
sed -e 's/\${TARGET_ROLE}/green/g' k8s/test-endpoint.yml >k8s/test-endpoint-green.yml

az login --service-principal -u "$sp_client_id" -p "$sp_client_password" -t "$sp_tenant_id"
az account set --subscription "$sp_subscription_id"
az aks get-credentials --resource-group "${resource_group}" --name "${aks_name}" --admin --file kubeconfig

kubectl --kubeconfig kubeconfig apply -f k8s/deployment-blue.yml
kubectl --kubeconfig kubeconfig apply -f k8s/deployment-green.yml
kubectl --kubeconfig kubeconfig apply -f k8s/service-blue.yml
kubectl --kubeconfig kubeconfig apply -f k8s/test-endpoint-blue.yml
kubectl --kubeconfig kubeconfig apply -f k8s/test-endpoint-green.yml

function wait_public_ip() {
  # wait 10 minutes for the service endpoint public IP to be ready
  # it takes a long time for Azure to provision the frontend load balancer and the public IP address
  local name="$1"
  local count=0
  while true; do
    count=$(expr $count + 1)
    endpoint_ip=$(kubectl --kubeconfig=kubeconfig get services "$name" --output json | jq -r '.status.loadBalancer.ingress[0].ip')
    if [ "$endpoint_ip" != null ]; then
      echo "$name ip: $endpoint_ip"
      break
    fi
    if [ "$count" -gt 60 ]; then
        echo "Timeout while waiting for the $name IP"
        exit 1
    fi
    echo "$name IP not ready, sleep 10 seconds..."
    sleep 10
  done
}

wait_public_ip "tomcat-service"
wait_public_ip "tomcat-test-blue"
wait_public_ip "tomcat-test-green"

# keep for diagnostics
#rm -rf k8s

az logout
