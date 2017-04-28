## Create Service Principal [Deprecated]

It is now recommended to use [version 2.0](https://docs.microsoft.com/cli/azure/install-azure-cli) of the Azure CLI:
```bash
az login
az account set --subscription <Subscription ID>
az ad sp create-for-rbac
```
By default, the last command creates a Service Principal with the 'Contributor' role scoped to the current subscription. Pass the '--help' parameter for more info if you want to change the defaults.

See [here](https://docs.microsoft.com/cli/azure/create-an-azure-service-principal-azure-cli?toc=%2fazure%2fazure-resource-manager%2ftoc.json) for more information

If you still want to use [version 1.0](https://docs.microsoft.com/azure/cli-install-nodejs) of the Azure CLI, then use this script. It prompts for user input to be able to authenticate on Azure and to pick the desired subscription (this step can be skipped by providing the subscription id as a script argument).

## Questions/Comments? azdevopspub@microsoft.com
