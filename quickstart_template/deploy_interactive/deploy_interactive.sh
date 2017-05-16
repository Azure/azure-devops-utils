#!/usr/bin/env bash

#---------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
#---------------------------------------------------------------------------------------------

function verify_az_cli() {
  if !(command -v az >/dev/null); then
    >&2 echo
    read -rp "===> Could not find Azure CLI 2.0. Do you want to install? (y/N): "
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
      curl -L https://aka.ms/InstallAzureCli | bash
    fi

    if !(command -v az >/dev/null); then
      >&2 echo "Did not find Azure CLI 2.0. Run 'curl -L https://aka.ms/InstallAzureCli | bash' and verify 'az --verison' succeeds."
      exit -1
    fi
  fi
}

function set_subscription() {
  local account=$(az account show 2>/dev/null)
  if [ -z "$account" ]; then
    >&2 echo
    >&2 echo "You must sign in to Azure to continue..."
    az login >/dev/null
  fi

  local subscription_ids=($(az account list --query [].id 2>/dev/null | tr -d '[],"'))
  local count=${#subscription_ids[@]}
  if [[ $count -lt 1 ]]; then
    >&2 echo "Failed to find subscriptions for this account. Run 'az login' and verify 'az account list' returns at least one subscription."
    exit -1
  elif [[ $count -gt 1 ]]; then
    >&2 echo
    >&2 echo "In what Subscription would you like to deploy Spinnaker?"
    local i=-2 # Use -2 because there are two lines of headers in the table
    while read -r line; do
      if [ $i -lt 0 ]; then
        >&2 echo "       $line"
      elif [ $i -lt 10 ]; then
        >&2 echo "  [$i]  $line"
      else
        >&2 echo "  [$i] $line"
      fi
      ((i++))
    done <<< "$(az account list -o table)"

    local min=0
    local max=$((count-1))
    read -rp "===> Enter the number corresponding to the subscription (leave blank to use the default): "
    while [ -n "$REPLY" ] && (! [[ "$REPLY" =~ ^[0-9]+$ ]] || [ "$REPLY" -lt $min ] || [ "$REPLY" -gt $max ]); do
      read -rp "===> Enter a valid integer between $min and $max (leave blank to use the default): "
    done

    if [ -n "$REPLY" ]; then
      az account set --subscription "${subscription_ids[$REPLY]}"
    fi
  fi
}

function get_service_principal() {
  local service_principal_name="$1"
  app_id=""
  app_key=""

  >&2 echo
  >&2 echo "Spinnaker will use a service principal as credentials to dynamically manage resources in your subscription."
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
          >&2 echo "The app keys did not match."
          app_key=""
        fi
      fi
    done
  else
    >&2 echo "Creating service principal..."
    local service_principal=$(az ad sp create-for-rbac -n "$service_principal_name")
    app_id=$(echo "$service_principal" | grep "appId" | cut -d '"' -f4)
    app_key=$(echo "$service_principal" | grep "password" | cut -d '"' -f4)
    >&2 echo "Created service principal:"
    az ad sp show --id "$app_id" -o table
  fi
}

function create_resource_group() {
  local resource_group_name="$1"

  local locations=($(az account list-locations --query [].name | tr -d '[],"'))
  local count=${#locations[@]}
  if [[ $count -lt 1 ]]; then
    >&2 echo "Failed to list locations for this subscription."
    exit -1
  elif [[ $count -eq 1 ]]; then
    local location="${locations[0]}"
  else
    >&2 echo
    >&2 echo "In what location would you like to deploy Spinnaker?"
    for ((i = 0; i < $count; ++i)); do
      if [ $i -lt 10 ]; then
        >&2 echo "  [$i]  ${locations[$i]}"
      else
        >&2 echo "  [$i] ${locations[$i]}"
      fi
    done

    local min=0
    local max=$((count-1))
    read -rp "===> Enter the number corresponding to the location: "
    while ! [[ "$REPLY" =~ ^[0-9]+$ ]] || [ "$REPLY" -lt $min ] || [ "$REPLY" -gt $max ]; do
      read -rp "===> Enter a valid integer between $min and $max: "
    done
    local location="${locations[$REPLY]}"
  fi

  >&2 echo "Creating resource group..."
  local provisioning_state=$(az group create -n "$resource_group_name" -l "$location" --query properties.provisioningState | tr -d '"')
  if [ "$provisioning_state" != "Succeeded" ]; then
    >&2 echo "Failed to create resource group '$resource_group_name' in location '$location'."
    exit -1
  else
    >&2 echo "Created resource group:"
    az group show --name "$resource_group_name" -o table
  fi
}

function get_username() {
  >&2 echo
  username=""
  while [ -z "$username" ]; do
    read -rp "===> Enter a username for your VM: "

    local min=1
    local max=64
    # This list is not meant to be exhaustive. It's only the list from here: https://docs.microsoft.com/azure/virtual-machines/linux/usernames
    local reserved_names=" adm admin audio backup bin cdrom crontab daemon dialout dip disk fax floppy fuse games gnats irc kmem landscape libuuid list lp mail man messagebus mlocate netdev news nobody nogroup operator plugdev proxy root sasl shadow src ssh sshd staff sudo sync sys syslog tape tty users utmp uucp video voice whoopsie www-data "
    if  [ ${#REPLY} -lt $min ] || [ ${#REPLY} -gt $max ]; then
      >&2 echo "The username must be between $min and $max characters."
    elif ! [[ "$REPLY" =~ ^[a-z][-a-z0-9_]*$ ]]; then
      >&2 echo "The username must contain only lowercase letters, numbers, hyphens, and underscores. The first character must be a letter."
    elif [[ "$reserved_names" =~ " $REPLY " ]]; then
      >&2 echo "The username cannot be an Ubuntu reserved name. See here for more information: https://docs.microsoft.com/azure/virtual-machines/linux/usernames"
    else
      username="$REPLY"
    fi
  done
}

function get_password() {
  >&2 echo
  password=""
  while [ -z "$password" ]; do
    read -srp "===> Enter a password for your VM: "
    >&2 echo

    local min=12
    local max=72
    if [ ${#REPLY} -lt $min ] || [ ${#REPLY} -gt $max ]; then
      >&2 echo "The password must be between $min and $max characters."
    else
      password="$REPLY"
      read -srp "===> Confirm your password: "
      >&2 echo
      if [ "$password" != "$REPLY" ]; then
        >&2 echo "The passwords did not match."
        password=""
      fi
    fi
  done
}

function get_dns_prefix() {
  >&2 echo
  dns_prefix=""
  while [ -z "$dns_prefix" ]; do
    read -rp "===> Enter a dns prefix for your VM: "

    local min=3
    local max=63
    if [ ${#REPLY} -lt $min ] || [ ${#REPLY} -gt $max ]; then
      >&2 echo "The dns prefix must be between $min and $max characters."
    elif ! [[ "$REPLY" =~ ^[a-z][-a-z0-9]*[a-z0-9]$ ]]; then
      >&2 echo "The dns prefix must contain only lowercase letters, numbers, and hyphens. The first character must be a letter. The last character must be a letter or number."
    else
      dns_prefix="$REPLY"
    fi
  done
}

function get_ssh_key() {
  local key_file_name="$1"
  public_key_file=""
  private_key_file=""

  >&2 echo
  read -rp "===> Do you have an existing ssh key you would like to use? (y/N): "
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    while [ -z "$public_key_file" ]; do
      read -rp "===> Enter the path to your public key file: "

      ssh_key_error="$(ssh-keygen -l -f "$REPLY" 2>&1 > /dev/null)" #Validate contents of pub key file
      if ! [ -e "$REPLY" ]; then
        >&2 echo "The file path '$REPLY' does not exist."
      elif [ ${REPLY: -4} != ".pub" ]; then
        >&2 echo "The file is not of the expected type '.pub'."
      elif [ -n "$ssh_key_error" ]; then
        >&2 echo "$ssh_key_error"
      else
        public_key_file="$REPLY"
        private_key_file="${public_key_file%????}"
      fi
    done
  else
    mkdir -p "$HOME/.ssh"
    private_key_file="$HOME/.ssh/${key_file_name}_rsa"
    ssh-keygen -t rsa -b 2048 -f "$private_key_file"
    public_key_file="${private_key_file}.pub"
    >&2 echo "***IMPORTANT***: Add '-i $private_key_file' when running an ssh command."
  fi
}

function get_deploy_target() {
  >&2 echo "This script will deploy an instance of Jenkins and Spinnaker on an Ubuntu 14.04 VM in Azure."
  read -rp "===> Do you want Spinnaker to target a Kubernetes Cluster (enter 'k8s') or VM Scale Sets (enter 'vmss')?: "
  deploy_target=$(echo "$REPLY" | awk '{print tolower($0)}')
  while [ "$deploy_target" != "k8s" ] && [ "$deploy_target" != "vmss" ]; do
    read -rp "===> Enter either 'vmss' or 'k8s': "
    deploy_target=$(echo "$REPLY" | awk '{print tolower($0)}')
  done
}

scenario_name=$(date +spinnaker-%Y-%m-%d-%H-%M-%S)

get_deploy_target
verify_az_cli
set_subscription
get_username
get_dns_prefix
create_resource_group "$scenario_name"
get_service_principal "$scenario_name"

if [ "$deploy_target" == "k8s" ]; then
  get_ssh_key "$scenario_name"
  key_file_note=", add '-i $private_key_file',"
  template_uri="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/301-jenkins-acr-spinnaker-k8s/azuredeploy.json"
  parameters=$(cat <<EOF
{
  "adminUsername": {
    "value": "$username"
  },
  "sshPublicKey": {
    "value": "$(cat ${public_key_file})"
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
else
  get_password
  key_file_note=""
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

>&2 echo
>&2 echo "Starting deployment..."
az group deployment create --name "$scenario_name" --resource-group "$scenario_name" --template-uri "$template_uri" --parameters "$parameters" --no-wait

>&2 cat <<EOF
The deployment has begun and will take about 15-20 minutes to complete (even though this script has exited).
Next steps:
  1. Run this command to check the status:
     az group deployment show --name "$scenario_name" --resource-group "$scenario_name" --query properties.provisioningState
  2. Run this command to view the outputs (after the status is "Succeeded"):
     az group deployment show --name "$scenario_name" --resource-group "$scenario_name" --query properties.outputs
  3. Copy the 'ssh' output variable from Step 2${key_file_note} and run the command to connect to your VM
  4. Navigate to http://localhost:8080 to view your Jenkins dashboard
  5. Navigate to http://localhost:9000 to view your Spinnaker dashboard
EOF