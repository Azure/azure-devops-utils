#!/bin/bash

#echo "Usage:
#  1 bash create-service-principal.sh
#  2 bash create-service-principal.sh <Subscription ID>
# You need Azure CLI: https://github.com/Azure/azure-cli

SUBSCRIPTION_ID=$1

#echo ""
#echo "  Background article: https://azure.microsoft.com/documentation/articles/resource-group-authenticate-service-principal"
echo ""

#check if the user has subscriptions. If not she's probably not logged in
subscriptions_list=$(az account list)
subscriptions_list_count=$(echo $subscriptions_list | jq '. | length' 2>/dev/null)
if [ $? -ne 0 ] || [ "$subscriptions_list_count" -eq "0" ]
then
  az login
else
  echo "  You are already logged in with an Azure account so we won't ask for credentials again."
  echo "  If you want to select a subscription from a different account, before running this script you should either log out from all the Azure accounts or login manually with the new account."
  echo "  az login"
  echo ""
fi

if [ -z "$SUBSCRIPTION_ID" ]
then
  #prompt for subscription
  subscription_index=0
  subscriptions_list=$(az account list)
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

az account set --subscription="${SUBSCRIPTION_ID}"
echo "Creating service principal..."
az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/${SUBSCRIPTION_ID}"
