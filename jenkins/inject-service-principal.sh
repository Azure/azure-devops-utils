#!/bin/bash
function print_usage() {
  cat <<EOF
Installs Jenkins and exposes it to the public through port 80 (login and cli are disabled)
Command
  $0
Arguments
  --service_principal_id|-id
  --service_principal_secret|-ss
  --subscription_id|-sid
  --tenant_id|-tid
  --artifacts_location|-al            : Url used to reference other scripts/artifacts.
  --sas_token|-st                     : A sas token needed if the artifacts location is private.
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

#defaults
artifacts_location="https://raw.githubusercontent.com/Azure/azure-devops-utils/master/"
jenkins_url="http://localhost:8080"

while [[ $# > 0 ]]
do
  key="$1"
  shift
  case $key in
    --service_principal_id|-id)
      service_principal_id="$1"
      shift
      ;;
    --service_principal_secret|-ss)
      service_principal_secret="$1"
      shift
      ;;
    --subscription_id|-sid)
      subscription_id="$1"
      shift
      ;;
    --tenant_id|-tid)
      tenant_id="$1"
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

throw_if_empty --service_principal_id "$service_principal_id"
throw_if_empty --service_principal_secret "$service_principal_secret"
throw_if_empty --subscription_id "$subscription_id"
throw_if_empty --tenant_id "$tenant_id"

sp_cred=$(cat <<EOF
<com.microsoft.azure.util.AzureCredentials>
  <scope>GLOBAL</scope>
  <id>main-sp</id>
  <description></description>
  <data>
    <subscriptionId>${subscription_id}</subscriptionId>
    <clientId>${service_principal_id}</clientId>
    <clientSecret>${service_principal_secret}</clientSecret>
    <oauth2TokenEndpoint>https://login.windows.net/${tenant_id}</oauth2TokenEndpoint>
    <serviceManagementURL>https://management.core.windows.net/</serviceManagementURL>
    <tenant>${tenant_id}</tenant>
    <authenticationEndpoint>https://login.microsoftonline.com/</authenticationEndpoint>
    <resourceManagerEndpoint>https://management.azure.com/</resourceManagerEndpoint>
    <graphEndpoint>https://graph.windows.net/</graphEndpoint>
  </data>
</com.microsoft.azure.util.AzureCredentials>
EOF
)
echo "$sp_cred" > sp_cred.xml

run_util_script "jenkins/run-cli-command.sh" -c "create-credentials-by-xml system::system::jenkins _" -cif sp_cred.xml
rm sp_cred.xml
