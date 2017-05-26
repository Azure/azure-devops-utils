# Deploy a Continuous Delivery pipeline [![Build Status](http://devops-ci.westcentralus.cloudapp.azure.com/job/qs/job/deploy-dev-ops/badge/icon)](http://devops-ci.westcentralus.cloudapp.azure.com/blue/organizations/jenkins/qs%2Fdeploy-dev-ops/activity)

This script deploys a DevOps pipeline targeting either a Kubernetes cluster or VM Scale Sets. It deploys an instance of Jenkins and Spinnaker on an Ubuntu 14.04 VM in Azure.

## Arguments
| Name | Description |
| --- | ---|
| --subscription_id<br/>-s   | Subscription id, optional if a default is already set in the Azure CLI |
| --deploy_target<br/>-dt    | Deployment target for Spinnaker (either 'k8s' for a Kubernetes cluster or 'vmss' for VM Scale Sets), defaulted to 'k8s' |
| --username<br/>-u          | Username for the DevOps VM, defaulted to 'azureuser' |
| --dns_prefix<br/>-dp       | DNS prefix for the DevOps VM, defaulted to a generated string |
| --resource_group<br/>-rg   | Resource group to deploy to, defaulted to a generated string |
| --location<br/>-l          | Location to deploy to, e.g. 'westus', optional if a default is already set in the Azure CLI |
| --app_id<br/>-ai           | Service Principal App Id (also called client id), defaulted to a generated Service Principal |
| --app_key<br/>-ak          | Service Principal App Key (also called client secret), defaulted to a generated Service Principal |
| --tenant_id<br/>-ti        | Tenant Id (only necessary if you want this script to log in to the cli with the Service Principal credentials) |
| --password<br/>-p          | Password for the DevOps VM (only used for the 'vmss' scenario) |
| --ssh_public_key<br/>-spk  | SSH Public Key for the DevOps VM (only used for the 'k8s' scenario), defaulted to '~/.ssh/id_rsa.pub' |
| --git_repository<br/>-gr   | Git repository with a Dockerfile at the root (only used for the 'k8s' scenario), defaulted to 'https://github.com/azure-devops/spin-kub-demo' |
| --quiet<br/>-q             | If this flag is passed, the script will not prompt for any values. An error will be thrown if a required parameter is not specified. |

## Example usage
To run interactively:
```bash
bash <(curl -sL https://aka.ms/DeployDevOps)
```

To run non-interactively:
```bash
curl -sL https://aka.ms/DeployDevOps | bash -s -- <insert parameters here>
```

## Questions/Comments? azdevopspub@microsoft.com