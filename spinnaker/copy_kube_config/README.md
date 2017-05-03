# Copy kubeconfig file

Programatically copies a kubeconfig file from an Azure Container Service Kubernetes cluster to a Spinnaker machine.

>**Note:** This script is only intended for use when copying the kubeconfig programatically with a Service Principal (aka when you do not have access to the ssh private key). If you want to do this manually, you can simply use 'scp'.

## Prerequisites
This must be executed on a machine with an existing Spinnaker instance. The 'az' cli must be installed and you must already be logged in with the correct subscription set.

## Arguments
| Name | Description |
|---|---|
| --user_name<br/>-un | The admin user name for the Kubernetes cluster. |
| --resource_group<br/>-rg | The resource group containing the Kubernetes cluster. |
| --master_fqdn<br/>-mf | The FQDN for the master VMs in the Kubernetes cluster. |

## Example usage
```bash
./copy_kube_config.sh --user_name "adminuser" --resource_group "resourcegroup" --master_fqdn "samplemgmt.westus.cloudapp.azure.com"
```

## Questions/Comments? azdevopspub@microsoft.com