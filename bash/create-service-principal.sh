#!/bin/bash

cat <<EOF
********************************************** WARNING **********************************************
This script uses the Azure CLI 1.0 and has been deprecated. Please install the Azure CLI 2.0
(https://docs.microsoft.com/cli/azure/install-azure-cli) and use these 3 easy commands:

  az login
  az account set --subscription <Subscription ID>
  az ad sp create-for-rbac

By default, the last command creates a Service Principal with the 'Contributor' role scoped to the
current subscription. Pass the '--help' parameter for more info if you want to change the defaults.
********************************************** WARNING **********************************************
EOF

if !(command -v azure >/dev/null); then
  echo "ERROR: This script requires Azure CLI 1.0, but it could not be found. Is it installed and on your path?" 1>&2
  exit -1
fi

SUBSCRIPTION_ID=$1

#echo ""
#echo "  Background article: https://azure.microsoft.com/documentation/articles/resource-group-authenticate-service-principal"
echo ""

my_app_name_uuid=$(python -c 'import uuid; print (str(uuid.uuid4())[:8])')
MY_APP_NAME="app${my_app_name_uuid}"

MY_APP_KEY=$(python -c 'import uuid; print (uuid.uuid4().hex)')

my_app_id_URI="${MY_APP_NAME}_id"

#check if the user has subscriptions. If not she's probably not logged in
subscriptions_list=$(az account list --output json)
subscriptions_list_count=$(echo $subscriptions_list | jq '. | length' 2>/dev/null)
if [ $? -ne 0 ] || [ "$subscriptions_list_count" -eq "0" ]
then
  azure login
else
  echo "  You are already logged in with an Azure account so we won't ask for credentials again."
  echo "  If you want to select a subscription from a different account, before running this script you should either log out from all the Azure accounts or login manually with the new account."
  echo "  azure login"
  echo ""
fi

if [ -z "$SUBSCRIPTION_ID" ]
then
  #prompt for subscription
  subscription_index=0
  subscriptions_list=$(az account list --output json)
  subscriptions_list_count=$(echo $subscriptions_list | jq '. | length')
  if [ $subscriptions_list_count -eq 0 ]
  then
    echo "  You need to sign up an Azure Subscription here: https://azure.microsoft.com"
    exit 1
  elif [ $subscriptions_list_count -gt 1 ]
  then
    echo $subscriptions_list | jq -r 'keys[] as $i | "  \($i+1). \(.[$i] | .name)"'

    while read -r -t 0; do read -r; done #clear stdin
    subscription_idx=0
    until [ $subscription_idx -ge 1 -a $subscription_idx -le $subscriptions_list_count ]
    do
      read -p "  Select a subscription by typing an index number from above list and press [Enter]: " subscription_idx
      if [ $subscription_idx -ne 0 -o $subscription_idx -eq 0 2>/dev/null ]
      then
        :
      else
        subscription_idx=0
      fi
    done
    subscription_index=$((subscription_idx-1))
  fi

  SUBSCRIPTION_ID=`echo $subscriptions_list | jq -r '.['$subscription_index'] | .id'`
  echo ""
fi

az account set --subscription $SUBSCRIPTION_ID
if [ $? -ne 0 ]
then
  exit 1
else
  echo "  Using subscription ID $SUBSCRIPTION_ID"
  echo ""
fi

MY_SUBSCRIPTION_ID=$(az account show --output json | jq -r '.id')
MY_TENANT_ID=$(az account show --output json | jq -r '.tenantId')

#az config mode arm >/dev/null

my_error_check=$(az ad sp show --id http://$my_app_id_URI/ --output json | grep "displayName" | grep -c \"$MY_APP_NAME\" )

if [ $my_error_check -gt 0 ];
then
  echo "  Found an app id matching the one we are trying to create; we will reuse that instead"
else
  echo "  Creating application in active directory:"
  echo "  az ad app create --display-name $MY_APP_NAME --homepage http://$MY_APP_NAME --identifier-uris http://$my_app_id_URI/ --password $MY_APP_KEY"
  az ad app create --display-name $MY_APP_NAME --homepage http://$MY_APP_NAME --identifier-uris http://$my_app_id_URI/ --password $MY_APP_KEY
  if [ $? -ne 0 ]
  then
    exit 1
  fi
  # Give time for operation to complete
  echo "  Waiting for operation to complete...."
  sleep 20
  my_error_check=$(az ad app show --id http://$my_app_id_URI/ --output json | grep "displayName" | grep -c \"$MY_APP_NAME\" )

  if [ $my_error_check -gt 0 ];
  then
    my_app_object_id=$(az ad app show --output json --id http://$my_app_id_URI/ | jq -r '.objectId')
    MY_CLIENT_ID=$(az ad app show --output json --id http://$my_app_id_URI/ | jq -r '.appId')
    echo " "
    echo "  Creating the service principal in AD"
    echo "  az ad sp create --id $MY_CLIENT_ID"
    az ad sp create --id $MY_CLIENT_ID
    # Give time for operation to complete
    echo "  Waiting for operation to complete...."
    sleep 20
    my_app_sp_object_id=$(az ad sp show --id http://$my_app_id_URI/ --output json | jq -r '.objectId')

    echo "  Assign rights to service principle"
    echo "  az role assignment create --assignee $my_app_sp_object_id --role Owner"
    az role assignment create --assignee $my_app_sp_object_id --role Owner
    if [ $? -ne 0 ]
    then
      exit 1
    fi
  else
    echo " "
    echo "  We've encounter an unexpected error; please hit Ctr-C and retry from the beginning"
    read my_error
  fi
fi

MY_CLIENT_ID=$(az ad sp show --id http://$my_app_id_URI/ --output json | jq -r '.appId')

echo "  "
echo "  Your access credentials ============================="
echo "  "
echo "  Subscription ID:" $MY_SUBSCRIPTION_ID
echo "  Client ID:" $MY_CLIENT_ID
echo "  Client Secret:" $MY_APP_KEY
echo "  OAuth 2.0 Token Endpoint:" "https://login.microsoftonline.com/${MY_TENANT_ID}/oauth2/token"
echo "  Tenant ID:" $MY_TENANT_ID
echo "  "
echo "  You can verify the service principal was created properly by running:"
echo "  az login -u "$MY_CLIENT_ID" --service-principal --tenant $MY_TENANT_ID"
echo "  "
