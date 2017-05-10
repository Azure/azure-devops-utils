# Configure Spinnaker for VM Scale Sets

Automatically configure a Spinnaker instance to target VM Scale Sets and a Jenkins instance hosting an Aptly repository. This script assumes Aptly is running on the Jenkins instance and is already setup.

## Prerequisites
This must be executed on a machine with an existing Spinnaker instance.

## Arguments
| Name | Description |
|---|---|
| --app_id<br/>-ai | The Service Principal app id used by Spinnaker to dynamically manage resources. |
| --app_key<br/>-ak | The Service Principal app key used by Spinnaker to dynamically manage resources. |
| --tenant_id<br/>-ti | Tenant id for your subscription. |
| --subscription_id<br/>-si | Subscription id. |
| --resource_group<br/>-rg | Resource group containing your key vault and packer storage account. |
| --vault_name<br/>-vn | Vault used to store default Username/Password for deployed VMSS. |
| --packer_storage_account<br/>-psa | Storage account used for baked images. |
| --jenkins_username<br/>-ju | Username that Spinnaker will use to communicate with Jenkins. |
| --jenkins_password<br/>-jp | Password that Spinnaker will use to communicate with Jenkins. |
| --vm_fqdn<br/>-vf | FQDN for the jenkins VM hosting the Aptly repository. |
| --region<br/>-r | (optional) Region for VMSS created by Spinnaker, defaulted to westus. |
| --artifacts_location<br/>-al | (optional) The url for referencing other scripts/artifacts. The default is this github repository. |
| --sas_token<br/>-st | (optional) A sas token needed if the artifacts location is private. |

## Example usage
```bash
./configure_k8s.sh --app_id "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" --app_key "password" --tenant_id "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" --subscription_id "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" --resource-group "devopsgroup" --vault_name "devopsVault" --packer_storage_account "packerStorage" --jenkins_username "jenkins" --jenkins_password "password" --vm_fqdn "devops.westus.cloudapp.azure.com"
```

## Questions/Comments? azdevopspub@microsoft.com