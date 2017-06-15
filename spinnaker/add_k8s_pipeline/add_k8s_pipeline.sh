#!/bin/bash

function print_usage() {
  cat <<EOF
Command
  $0 

Arguments
  --account_name|-an       [Required]: Spinnaker account name for registry
  --registry|-rg           [Required]: Registry url targeted by pipeline
  --repository|-rp         [Required]: Repository targeted by pipeline
  --port|-p                          : Port for loadbalancers used in pipeline, defaulted to '8000'
  --user_name|-un                    : User name for pipeline metadata, defaulted to '[anonymous]'
  --user_email|-ue                   : User email for pipeline metadata, defaulted to 'anonymous@Fabrikam.com'
  --artifacts_location|-al           : Url used to reference other scripts/artifacts.
  --sas_token|-st                    : A sas token needed if the artifacts location is private.
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
port="8000"
user_name="[anonymous]"
user_email="anonymous@Fabrikam.com"
artifacts_location="https://raw.githubusercontent.com/Azure/azure-devops-utils/master/"

while [[ $# > 0 ]]
do
  key="$1"
  shift
  case $key in
    --account_name|-an)
      account_name="$1"
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
    --repository|-rp)
      repository="$1"
      shift
      ;;
    --port|-p)
      port="$1"
      shift
      ;;
    --user_name|-un)
      user_name="$1"
      shift
      ;;
    --user_email|-ue)
      user_email="$1"
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

throw_if_empty --account_name $account_name
throw_if_empty --registry $registry
throw_if_empty --repository $repository
throw_if_empty --port $port
throw_if_empty --user_name $user_name
throw_if_empty --user_email $user_email

# Validate and parse repository
if [[ "$repository" =~ ^([^[:space:]\/]+)\/([^[:space:]\/]+)$ ]]; then
    organization="${BASH_REMATCH[1]}"
    app_name="${BASH_REMATCH[2]}"
    app_name=$(echo "${app_name,,}" | tr -cd '[[:alnum:]]') # Convert to lowercase and remove symbols from application name. Kubernetes only supports ^[a-z0-9]+$
else
    echo "Expected repository to be of the form 'organization/applicationname', but instead received '$repository'." 1>&2
    exit 1
fi

# Connect to k8s cluster in the background
hal deploy connect --service-names gate &
timeout=30
echo "while !(nc -z localhost 8084); do sleep 1; done" | timeout $timeout bash
return_value=$?
if [ $return_value -ne 0 ]; then
  >&2 echo "Failed to connect to Spinnaker within '$timeout' seconds."
  exit $return_value
fi

# Create application
application_data=$(curl -s ${artifacts_location}spinnaker/add_k8s_pipeline/application.json${artifacts_location_sas_token})
application_data=${application_data//REPLACE_APP_NAME/$app_name}
application_data=${application_data//REPLACE_USER_NAME/$user_name}
application_data=${application_data//REPLACE_USER_EMAIL/$user_email}
curl -X POST -H "Content-type: application/json" --data "$application_data" http://localhost:8084/applications/${app_name}/tasks

# Create pipeline
pipeline_data=$(curl -s ${artifacts_location}spinnaker/add_k8s_pipeline/pipeline.json${artifacts_location_sas_token})
pipeline_data=${pipeline_data//REPLACE_APP_NAME/$app_name}
pipeline_data=${pipeline_data//REPLACE_ACCOUNT_NAME/$account_name}
pipeline_data=${pipeline_data//REPLACE_REGISTRY/$registry}
pipeline_data=${pipeline_data//REPLACE_REPOSITORY/$repository}
pipeline_data=${pipeline_data//REPLACE_ORGANIZATION/$organization}
pipeline_data=${pipeline_data//REPLACE_PORT/$port}
curl -X POST -H "Content-type: application/json" --data "$pipeline_data" http://localhost:8084/pipelines

# Create dev load balancer
load_balancer_data=$(curl -s ${artifacts_location}spinnaker/add_k8s_pipeline/load_balancer.json${artifacts_location_sas_token})
dev_load_balancer_data=${load_balancer_data//REPLACE_APP_NAME/$app_name}
dev_load_balancer_data=${dev_load_balancer_data//REPLACE_USER_NAME/$user_name}
dev_load_balancer_data=${dev_load_balancer_data//REPLACE_PORT/$port}
dev_load_balancer_data=${dev_load_balancer_data//REPLACE_STACK/"dev"}
dev_load_balancer_data=${dev_load_balancer_data//REPLACE_SERVICE_TYPE/"ClusterIP"}
curl -X POST -H "Content-type: application/json" --data "$dev_load_balancer_data" http://localhost:8084/applications/${app_name}/tasks

# Create prod load balancer
prod_load_balancer_data=${load_balancer_data//REPLACE_APP_NAME/$app_name}
prod_load_balancer_data=${prod_load_balancer_data//REPLACE_USER_NAME/$user_name}
prod_load_balancer_data=${prod_load_balancer_data//REPLACE_PORT/$port}
prod_load_balancer_data=${prod_load_balancer_data//REPLACE_STACK/"prod"}
prod_load_balancer_data=${prod_load_balancer_data//REPLACE_SERVICE_TYPE/"LoadBalancer"}
curl -X POST -H "Content-type: application/json" --data "$prod_load_balancer_data" http://localhost:8084/applications/${app_name}/tasks

# Stop background connection to Spinnaker
pkill kubectl