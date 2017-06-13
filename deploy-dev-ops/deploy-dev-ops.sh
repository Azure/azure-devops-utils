#!/usr/bin/env bash

#---------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
#---------------------------------------------------------------------------------------------

function print_usage() {
  cat <<EOF
Command
  ./deploy-dev-ops.sh

Arguments:
  --subscription_id|-s   : Subscription id, optional if a default is already set in the Azure CLI
  --deploy_target|-dt    : Deployment target for Spinnaker (either 'k8s' for a Kubernetes cluster or 'vmss' for VM Scale Sets), defaulted to 'k8s'
  --username|-u          : Username for the DevOps VM, defaulted to 'azureuser'
  --dns_prefix|-dp       : DNS prefix for the DevOps VM, defaulted to a generated string
  --resource_group|-rg   : Resource group to deploy to, defaulted to a generated string
  --location|-l          : Location to deploy to, e.g. 'westus', optional if a default is already set in the Azure CLI
  --app_id|-ai           : Service Principal App Id (also called client id), defaulted to a generated Service Principal
  --app_key|-ak          : Service Principal App Key (also called client secret), defaulted to a generated Service Principal
  --tenant_id|-ti        : Tenant Id (only necessary if you want this script to log in to the cli with the Service Principal credentials)
  --password|-p          : Password for the DevOps VM (only used for the 'vmss' scenario)
  --ssh_public_key|-spk  : SSH Public Key for the DevOps VM (only used for the 'k8s' scenario), defaulted to '~/.ssh/id_rsa.pub'
  --git_repository|-gr   : Git repository with a Dockerfile at the root (only used for the 'k8s' scenario), defaulted to 'https://github.com/azure-devops/spin-kub-demo'
  --quiet|-q             : If this flag is passed, the script will not prompt for any values. An error will be thrown if a required parameter is not specified.

Example Usage:
  To run interactively:
    bash <(curl -sL https://aka.ms/DeployDevOps)

  To run non-interactively:
    curl -sL https://aka.ms/DeployDevOps | bash -s -- <insert parameters here>
EOF
}

function exit_on_failure() {
  "$@"
  local return_value=$?
  if [ $return_value -ne 0 ]; then
    exit $return_value
  fi
}

function log_error() {
  >&2 echo -e "\033[31mError: $1\033[0m"
}

function log_info() {
  >&2 echo "$1"
}

function validate_az_cli() {
  if !(command -v az >/dev/null) && [[ "$quiet" != true ]]; then
    read -rp "===> Did not find Azure CLI 2.0. Do you want to install? (y/N): "
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
      curl -L https://aka.ms/InstallAzureCli | bash
    fi
  fi

  if !(command -v az >/dev/null); then
    log_error "Did not find Azure CLI 2.0. Run 'curl -L https://aka.ms/InstallAzureCli | bash' and verify 'az --verison' succeeds. See here for more information: https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit -1
  fi

  local account=$(az account show 2>/dev/null)
  if [ -z "$account" ]; then
    if [ -n "$app_id" ] && [ -n "$app_key" ] && [ -n "$tenant_id" ]; then
      exit_on_failure az login --service-principal -u "$app_id" -p "$app_key" --tenant "$tenant_id"
    elif [[ "$quiet" == true ]]; then
      log_error "The 'quiet' flag was passed, but no azure account was found. You must either sign in to the cli before running the script or pass the 'tenant_id', 'app_id' and 'app_key' to sign in with a service principal."
      exit -1
    else
      log_info "You must sign in to Azure to continue..."
      exit_on_failure az login >/dev/null
    fi
  fi
}

function set_subscription() {
  local subscription_ids=($(az account list --query [].id 2>/dev/null | tr -d '[],"'))
  local count=${#subscription_ids[@]}
  if [[ $count -gt 1 ]] && [ -z "$subscription_id" ] && [[ "$quiet" != true ]]; then
    >&2 echo
    log_info "In what Subscription would you like to deploy?"
    local i=-2 # Use -2 because there are two lines of headers in the table
    while read -r line; do
      if [ $i -lt 0 ]; then
        log_info "       $line"
      elif [ $i -lt 10 ]; then
        log_info "  [$i]  $line"
      else
        log_info "  [$i] $line"
      fi
      ((i++))
    done <<< "$(az account list -o table)"

    local min=0
    local max=$((count-1))
    while [ -z "$subscription_id" ]; do
      read -rp "===> Enter an integer between $min and $max (leave blank to use the default): "
      if [ -z "$REPLY" ]; then
        break
      elif [[ "$REPLY" =~ ^[0-9]+$ ]] && [ "$REPLY" -ge $min ] && [ "$REPLY" -le $max ]; then
        subscription_id="${subscription_ids[$REPLY]}"
      fi
    done
  fi

  if [ -n "$subscription_id" ]; then
    exit_on_failure az account set --subscription "$subscription_id"
  fi
}

function validate_deploy_target() {
  deploy_target=$(echo "$1" | awk '{print tolower($0)}')

  if [ -z "$deploy_target" ]; then
    deploy_target="k8s"
    valid=true
  elif [ "$deploy_target" != "k8s" ] && [ "$deploy_target" != "vmss" ]; then
    log_error "The deploy target must be either 'k8s' or 'vmss'."
    valid=false
  else
    valid=true
  fi
}

function validate_username() {
  username="$1"

  local min=1
  local max=64
  # This list is not meant to be exhaustive. It's only the list from here: https://docs.microsoft.com/azure/virtual-machines/linux/usernames
  local reserved_names=" adm admin audio backup bin cdrom crontab daemon dialout dip disk fax floppy fuse games gnats irc kmem landscape libuuid list lp mail man messagebus mlocate netdev news nobody nogroup operator plugdev proxy root sasl shadow src ssh sshd staff sudo sync sys syslog tape tty users utmp uucp video voice whoopsie www-data "
  if [ -z "$username" ]; then
    username="azureuser"
    valid=true
  elif [ ${#username} -lt $min ] || [ ${#username} -gt $max ]; then
    log_error "The username must be between $min and $max characters."
    valid=false
  elif ! [[ "$username" =~ ^[a-z][-a-z0-9_]*$ ]]; then
    log_error "The username must contain only lowercase letters, numbers, hyphens, and underscores. The first character must be a letter."
    valid=false
  elif [[ "$reserved_names" =~ " $username " ]]; then
    log_error "The username cannot be an Ubuntu reserved name. See here for more information: https://docs.microsoft.com/azure/virtual-machines/linux/usernames"
    valid=false
  else
    valid=true
  fi
}

function validate_dns_prefix() {
  dns_prefix="$1"
  local min=3
  local max=63
  if [ -z "$dns_prefix" ]; then
    dns_prefix="$scenario_name"
    valid=true
  elif [ ${#dns_prefix} -lt $min ] || [ ${#dns_prefix} -gt $max ]; then
    log_error "The dns prefix must be between $min and $max characters."
    valid=false
  elif ! [[ "$dns_prefix" =~ ^[a-z][-a-z0-9]*[a-z0-9]$ ]]; then
    log_error "The dns prefix must contain only lowercase letters, numbers, and hyphens. The first character must be a letter. The last character must be a letter or number."
    valid=false
  else
    valid=true
  fi
}

function validate_or_create_service_principal() {
  if [ -z "$app_id" ] || [ -z "$app_key" ]; then
    >&2 echo
    if [[ "$quiet" == true ]]; then
      log_info "The 'quiet' flag was passed without the app_id and/or app_key, so a new service principal will be created."
    else
      log_info "Spinnaker will use a service principal as credentials to dynamically manage resources in your subscription."
      read -rp "===> Do you have an existing service principal you would like to use? (y/N): "
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        while [ -z "$app_id" ]; do
          read -rp "===> Enter the app id of your service principal: "
          app_id="$REPLY"
        done

        while [ -z "$app_key" ]; do
          read -srp "===> Enter the app key of your service principal: "
          >&2 echo

          if [ -n "$REPLY" ]; then
            app_key="$REPLY"
            read -srp "===> Confirm the app key of your service principal: "
            >&2 echo
            if [ "$app_key" != "$REPLY" ]; then
              log_error "The app keys did not match."
              app_key=""
            fi
          fi
        done
      fi
    fi
  fi

  if [ -z "$app_id" ] || [ -z "$app_key" ]; then
    log_info "Creating service principal..."
    local service_principal=$(az ad sp create-for-rbac -n "$scenario_name")
    app_id=$(echo "$service_principal" | grep "appId" | cut -d '"' -f4)
    app_key=$(echo "$service_principal" | grep "password" | cut -d '"' -f4)
    log_info "Created service principal:"
    exit_on_failure az ad sp show --id "$app_id" -o table
  fi
}

function validate_or_create_resource_group() {
  # Check if resource group already exists
  local resource_group_data=$(az group show -n "$resource_group")
  if [ -z "$resource_group_data" ]; then
    if [ -z "$location" ] && [[ "$quiet" != true ]]; then
      local locations=($(az account list-locations --query [].name | tr -d '[],"'))
      local count=${#locations[@]}
      if [[ $count -lt 1 ]]; then
        log_error "Failed to list locations for this subscription."
        exit -1
      elif [[ $count -eq 1 ]]; then
        location="${locations[0]}"
      else
        >&2 echo
        log_info "In what location would you like to deploy?"
        for ((i = 0; i < $count; ++i)); do
          if [ $i -lt 10 ]; then
            log_info "  [$i]  ${locations[$i]}"
          else
            log_info "  [$i] ${locations[$i]}"
          fi
        done

        local min=0
        local max=$((count-1))

        local default="westus"
        if [[ " ${locations[*]} " != *" $default "* ]]; then
          # Use the first location if westus isn't available
          local default=${locations[0]}
        fi

        while [ -z "$location" ]; do
          read -rp "===> Enter an integer between $min and $max (leave blank to use '$default'): "
          if [ -z "$REPLY" ]; then
            location="$default"
          elif [[ "$REPLY" =~ ^[0-9]+$ ]] && [ "$REPLY" -ge $min ] && [ "$REPLY" -le $max ]; then
            location="${locations[$REPLY]}"
          fi
        done
      fi
    fi

    log_info "Creating resource group..."
    if [ -z "$location" ]; then
      # This will only work if the az cli has a default location configured
      exit_on_failure az group create -n "$resource_group" -o table
    else
      exit_on_failure az group create -n "$resource_group" -l "$location" -o table
    fi
  fi
}

function validate_password() {
  password="$1"

  local min=12
  local max=72
  if [ ${#password} -lt $min ] || [ ${#password} -gt $max ]; then
    log_error "The password must be between $min and $max characters."
    valid=false
  else
    valid=true
  fi
}

function validate_ssh_public_key() {
  ssh_public_key="$1"

  if [ -z "$ssh_public_key" ]; then
    local key_file_path="${default_private_key_file}.pub"

    if ! [ -e "$default_private_key_file" ]; then
      mkdir -p $(dirname "$default_private_key_file")
      if [[ "$quiet" == true ]]; then
        # If quiet, assume no passphrase because that requires interaction
        ssh-keygen -t rsa -b 2048 -f "$default_private_key_file" -N ""
      else
        ssh-keygen -t rsa -b 2048 -f "$default_private_key_file"
      fi
    fi
  elif [ -e "$ssh_public_key" ]; then # User specified a file path
    if [ ${ssh_public_key: -4} != ".pub" ]; then
      local key_file_path="${ssh_public_key}.pub"
    else
      local key_file_path="$ssh_public_key"
    fi
  else # User specified a public key
    local temp_file="$(mktemp).pub"
    echo "$ssh_public_key" > "$temp_file"
    local key_file_path="$temp_file"
  fi

  # This doesn't generate anything, it just validates it's a public key file
  ssh-keygen -l -f "$key_file_path" &>/dev/null
  if [ $? -ne 0 ]; then
    log_error "The public key specified was invalid."
    valid=false
  else
    valid=true
    ssh_public_key=$(cat "$key_file_path")
  fi

  if [ -e "$temp_file" ]; then
    rm "$temp_file"
  fi
}

scenario_name=$(date +devops-%Y-%m-%d-%H-%M-%S)
resource_group="$scenario_name"

if [[ "$-" == *s* ]]; then
  # If we don't run in quiet mode, each 'read' operation will take the next line of the script as input
  log_info "Defaulting to quiet mode because commands are being read from standard input."
  quiet=true
else
  quiet=false
fi

while [[ $# > 0 ]]
do
  key="$1"
  shift
  case $key in
    --subscription_id|-si)
      subscription_id="$1"
      shift;;
    --deploy_target|-dt)
      deploy_target="$1"
      shift;;
    --username|-u)
      username="$1"
      shift;;
    --dns_prefix|-dp)
      dns_prefix="$1"
      shift;;
    --resource_group|-rg)
      resource_group="$1"
      shift;;
    --location|-l)
      location="$1"
      shift;;
    --app_id|-ai)
      app_id="$1"
      shift;;
    --app_key|-ak)
      app_key="$1"
      shift;;
    --tenant_id|-ti)
      tenant_id="$1"
      shift;;
    --password|-p)
      password="$1"
      shift;;
    --ssh_public_key|-spk)
      ssh_public_key="$1"
      shift;;
    --git_repository|-gr)
      git_repository="$1"
      shift;;
    --quiet|-q)
      quiet=true;;
    --help|-help|-h)
      print_usage
      exit 13;;
    *)
      log_error "Unknown argument '$key'."
      exit -1
  esac
done

validate_az_cli

set_subscription

if [ -n "$deploy_target" ] || [[ "$quiet" == true ]]; then
  validate_deploy_target "$deploy_target"
  if [[ "$valid" != true ]]; then
    exit -1
  fi
else
  >&2 echo
  log_info "This script will deploy an instance of Jenkins and Spinnaker on an Ubuntu 14.04 VM in Azure."
  log_info "Do you want Spinnaker to target a Kubernetes Cluster (k8s) or VM Scale Sets (vmss)?"
  valid=false
  while [[ "$valid" != true ]]; do
    read -rp "===> Enter either 'vmss' or 'k8s' (leave blank to use 'k8s'): "
    validate_deploy_target "$REPLY"
  done
fi

if [ -n "$username" ] || [[ "$quiet" == true ]]; then
  validate_username "$username"
  if [[ "$valid" != true ]]; then
    exit -1
  fi
else
  >&2 echo
  valid=false
  while [[ "$valid" != true ]]; do
    read -rp "===> Enter a username for your VM (leave blank to use 'azureuser'): "
    validate_username "$REPLY"
  done
fi

if [ -n "$dns_prefix" ] || [[ "$quiet" == true ]]; then
  validate_dns_prefix "$dns_prefix"
  if [[ "$valid" != true ]]; then
    exit -1
  fi
else
  >&2 echo
  valid=false
  while [[ "$valid" != true ]]; do
    read -rp "===> Enter a DNS prefix for your VM: (leave blank to use '$scenario_name'): "
    validate_dns_prefix "$REPLY"
  done
fi

validate_or_create_resource_group

validate_or_create_service_principal

if [ "$deploy_target" == "k8s" ]; then
  default_private_key_file="$HOME/.ssh/id_rsa"

  if [ -n "$ssh_public_key" ] || [[ "$quiet" == true ]]; then
    validate_ssh_public_key "$ssh_public_key"
    if [[ "$valid" != true ]]; then
      exit -1
    fi
  else
    if [ -e "$default_private_key_file" ]; then
      default_message="leave blank to use '$default_private_key_file'"
    else
      default_message="leave blank to generate a new key at '$default_private_key_file'"
    fi

    >&2 echo
    valid=false
    while [[ "$valid" != true ]]; do
      read -rp "===> Enter an ssh public key or the path to a public key file ($default_message): "
      validate_ssh_public_key "$REPLY"
    done
  fi

  default_git_repository=https://github.com/azure-devops/spin-kub-demo
  if [ -z "$git_repository" ] && [[ "$quiet" != true ]]; then
    >&2 echo
    read -rp "===> Enter a git repository with a Dockerfile at the root: (leave blank to use '$default_git_repository'): "
    git_repository="$REPLY"
  fi

  if [ -z "$git_repository" ]; then
    git_repository="$default_git_repository"
  fi

  template_uri="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/301-jenkins-acr-spinnaker-k8s/azuredeploy.json"
  parameters=$(cat <<EOF
{
  "adminUsername": {
    "value": "$username"
  },
  "sshPublicKey": {
    "value": "$ssh_public_key"
  },
  "devopsDnsPrefix": {
    "value": "$dns_prefix"
  },
  "servicePrincipalAppId": {
    "value": "$app_id"
  },
  "servicePrincipalAppKey": {
    "value": "$app_key"
  },
  "gitRepository": {
    "value": "$git_repository"
  }
}
EOF
)
else
  if [ -n "$password" ] || [[ "$quiet" == true ]]; then
    validate_password "$password"
    if [[ "$valid" != true ]]; then
      exit -1
    fi
  else

    >&2 echo
    valid=false
    while [ -z "$password" ] || [[ "$valid" != true ]]; do
      read -srp "===> Enter a password for your VM: "
      >&2 echo

      validate_password "$REPLY"
      if [[ "$valid" == true ]]; then
        read -srp "===> Confirm your password: "
        >&2 echo
        if [ "$password" != "$REPLY" ]; then
          log_error "The passwords did not match."
          password=""
        fi
      fi
    done
  fi
  
  template_uri="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/301-jenkins-aptly-spinnaker-vmss/azuredeploy.json"
  parameters=$(cat <<EOF
{
  "adminUsername": {
    "value": "$username"
  },
  "adminPassword": {
    "value": "$password"
  },
  "devopsDnsPrefix": {
    "value": "$dns_prefix"
  },
  "servicePrincipalAppId": {
    "value": "$app_id"
  },
  "servicePrincipalAppKey": {
    "value": "$app_key"
  }
}
EOF
)
fi

>&2 cat <<EOF

Starting deployment...
The deployment will take about 15-20 minutes to complete. This is the last step and the deployment will continue even if you exit this script.
Next steps:
  1. Run this command to check the status:
     az group deployment show --name "$scenario_name" --resource-group "$resource_group" --query properties.provisioningState
  2. Run this command to view the outputs (after the status is "Succeeded"):
     az group deployment show --name "$scenario_name" --resource-group "$resource_group" --query properties.outputs
  3. Copy and run the 'ssh' output variable to connect to your VM
  4. Navigate to http://localhost:8080 to view your Jenkins dashboard
  5. Navigate to http://localhost:9000 to view your Spinnaker dashboard
EOF

exit_on_failure az group deployment create --name "$scenario_name" --resource-group "$resource_group" --template-uri "$template_uri" --parameters "$parameters" --query "{outputs: properties.outputs}"
