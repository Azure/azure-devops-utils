#!/bin/bash

function print_usage() {
  cat <<EOF
Command
  $0
Arguments
  --jenkins_url|-j                [Required]: Jenkins URL
  --jenkins_username|-ju          [Required]: Jenkins user name
  --jenkins_password|-jp                    : Jenkins password. If not specified and the user name is "admin", the initialAdminPassword will be used
  --acs_resource_group|-ag        [Required]: Resource group for the target ACS with Kubernetes orchestrator
  --acs_name|-an                  [Required]: Name of the ACS cluster
  --ssh_credentials_id|-sci                 : Desired Jenkins SSH credentials ID
  --ssh_credentials_desc|-scd               : Desired Jenkins SSH credentials description
  --ssh_credentials_username|-scu [Required]: Username for the SSH credentials
  --ssh_credentials_key_file|-scp [Required]: Private key file for the SSH credentials
  --sp_credentials_id|-spi                  : Desired Jenkins Azure service principal ID
  --sp_credentials_desc|-spd                : Desired Jenkins Azure service princiapl description
  --sp_subscription_id|-sps       [Required]: Subscription ID for the Azure service principal
  --sp_client_id|-spc             [Required]: Client ID for the Azure service principal
  --sp_client_password|-spp       [Required]: Client secrets for the Azure service principal
  --sp_tenant_id|-spt             [Required]: Tenant ID for the Azure service principal
  --sp_environment|-spe                     : Azure environment for the Azure service principal
  --job_short_name|-jsn                     : Desired Jenkins job short name
  --job_display_name|-jdn                   : Desired Jenkins job display name
  --job_description|-jd                     : Desired Jenkins job description
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
ssh_credentials_id="k8s-ssh"
ssh_credentials_desc="SSH credentials to login to ACS Kubernetes master"
sp_credentials_id="sp"
sp_credentials_desc="Service Principal to manage Azure resources"
sp_environment="Azure"
job_short_name="acs-k8s-blue-green-deployment"
job_display_name="ACS Kubernetes Blue-green Deployment"
job_description="A pipeline that demonstrates the blue-green deployment to ACS Kubernetes with the azure-acs Jenkins plugin."
artifacts_location="https://raw.githubusercontent.com/Azure/azure-devops-utils/master/"

while [[ $# > 0 ]]
do
  key="$1"
  shift
  case $key in
    --jenkins_url|-j)
      jenkins_url="$1"
      shift
      ;;
    --jenkins_username|-ju)
      jenkins_username="$1"
      shift
      ;;
    --jenkins_password|-jp)
      jenkins_password="$1"
      shift
      ;;
    --acs_resource_group|-ag)
      acs_resource_group="$1"
      shift
      ;;
    --acs_name|-an)
      acs_name="$1"
      shift
      ;;
    --ssh_credentials_id|-sci)
      ssh_credentials_id="$1"
      shift
      ;;
    --ssh_credentials_desc|-scd)
      ssh_credentials_desc="$1"
      shift
      ;;
    --ssh_credentials_username|-scu)
      ssh_credentials_username="$1"
      shift
      ;;
    --ssh_credentials_key_file|-scp)
      ssh_credentials_key_file="$1"
      shift
      ;;
    --sp_credentials_id|-spi)
      sp_credentials_id="$1"
      shift
      ;;
    --sp_credentials_desc|-spd)
      sp_credentials_desc="$1"
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
    --job_short_name|-jsn)
      job_short_name="$1"
      shift
      ;;
    --job_display_name|-jdn)
      job_display_name="$1"
      shift
      ;;
    --job_description|-jd)
      job_description="$1"
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

throw_if_empty --jenkins_url "$jenkins_url"
throw_if_empty --jenkins_username "$jenkins_username"
if [ "$jenkins_username" != "admin" ]; then
  throw_if_empty --jenkins_password "$jenkins_password"
fi
throw_if_empty --acs_resource_group "$acs_resource_group"
throw_if_empty --acs_name "$acs_name"
throw_if_empty --ssh_credentials_id "$ssh_credentials_id"
throw_if_empty --ssh_credentials_username "$ssh_credentials_username"
throw_if_empty --ssh_credentials_key_file "$ssh_credentials_key_file"
if [ ! -f "$ssh_credentials_key_file" ]; then
    echo "ERROR: Cannot find SSH key file $ssh_credentials_key_file" >&2
    exit -1
fi
ssh_credentials_private_key=$(cat "$ssh_credentials_key_file")
throw_if_empty "SSH private key" "$ssh_credentials_private_key"
throw_if_empty --sp_credentials_id "$sp_credentials_id"
throw_if_empty --sp_subscription_id "$sp_subscription_id"
throw_if_empty --sp_client_id "$sp_client_id"
throw_if_empty --sp_client_password "$sp_client_password"
throw_if_empty --sp_tenant_id "$sp_tenant_id"
throw_if_empty --sp_environment "$sp_environment"

#download dependencies
job_xml=$(curl -s ${artifacts_location}/jenkins/blue-green/acs-k8s-blue-green-job.xml${artifacts_location_sas_token})
ssh_credentials_xml=$(curl -s ${artifacts_location}/jenkins/blue-green/ssh-credentials.xml${artifacts_location_sas_token})
sp_credentials_xml=$(curl -s ${artifacts_location}/jenkins/blue-green/sp-credentials.xml${artifacts_location_sas_token})

#prepare job.xml
job_xml=${job_xml//'{insert-job-display-name}'/${job_display_name}}
job_xml=${job_xml//'{insert-job-description}'/${job_description}}
job_xml=${job_xml//'{insert-acs-resource-group}'/${acs_resource_group}}
job_xml=${job_xml//'{insert-acs-name}'/${acs_name}}

#prepare ssh-credentials.xml
ssh_credentials_xml=${ssh_credentials_xml//'{insert-ssh-credentials-id}'/${ssh_credentials_id}}
ssh_credentials_xml=${ssh_credentials_xml//'{insert-ssh-credentials-desc}'/${ssh_credentials_desc}}
ssh_credentials_xml=${ssh_credentials_xml//'{insert-ssh-username}'/${ssh_credentials_username}}
ssh_credentials_xml=${ssh_credentials_xml//'{insert-ssh-private-key}'/${ssh_credentials_private_key}}

#prepare sp-credentials.xml
sp_credentials_xml=${sp_credentials_xml//'{insert-sp-credentials-id}'/${sp_credentials_id}}
sp_credentials_xml=${sp_credentials_xml//'{insert-sp-credentials-desc}'/${sp_credentials_desc}}
sp_credentials_xml=${sp_credentials_xml//'{insert-sp-subscription-id}'/${sp_subscription_id}}
sp_credentials_xml=${sp_credentials_xml//'{insert-sp-client-id}'/${sp_client_id}}
sp_credentials_xml=${sp_credentials_xml//'{insert-sp-client-password}'/${sp_client_password}}
sp_credentials_xml=${sp_credentials_xml//'{insert-sp-tenant-id}'/${sp_tenant_id}}
sp_credentials_xml=${sp_credentials_xml//'{insert-sp-environment}'/${sp_environment}}

#add SSH credentials
echo "${ssh_credentials_xml}" >ssh-credentials.xml
run_util_script "jenkins/run-cli-command.sh" -j "$jenkins_url" -ju "$jenkins_username" -jp "$jenkins_password" -c 'create-credentials-by-xml SystemCredentialsProvider::SystemContextResolver::jenkins (global)' -cif "ssh-credentials.xml"

#add Azure service principal credentials
echo "${sp_credentials_xml}" >sp-credentials.xml
run_util_script "jenkins/run-cli-command.sh" -j "$jenkins_url" -ju "$jenkins_username" -jp "$jenkins_password" -c 'create-credentials-by-xml SystemCredentialsProvider::SystemContextResolver::jenkins (global)' -cif "sp-credentials.xml"

#add job
echo "${job_xml}" >job.xml
run_util_script "jenkins/run-cli-command.sh" -j "$jenkins_url" -ju "$jenkins_username" -jp "$jenkins_password" -c "create-job ${job_short_name}" -cif "job.xml"

# clean up
rm -f ssh-credentials.xml sp-credentials.xml job.xml
