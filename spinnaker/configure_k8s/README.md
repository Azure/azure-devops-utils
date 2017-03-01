# Configure Spinnaker for Kubernetes

Automatically configure a spinnaker instance to target a Kubernetes cluster and to use an Azure storage account for Spinnaker's persistent storage. This script will restart spinnaker after it is done so that config changes take effect. The only remaining step is copy the kubeconfig file from your Kubernetes master vm to the Spinnaker VM.

## Prerequisites
This must be executed on a machine with an existing Spinnaker instance.

## Arguments
| Name | Description |
|---|---|
| --storage_account_name<br/>-san | The storage account name used for Spinnaker's persistent storage service (front50). |
| --storage_account_key<br/>-sak | The storage account key used for Spinnaker's persistent storage service (front50). |
| --registry<br/>-rg | The Azure Container Registry url, for example 'sample-microsoft.azurecr.io'. |
| --client_id<br/>-ci | The Service Principal client id used to access your registry. |
| --client_key<br/>-ck | The Service Principal client key used to access your registry. |
| --repository<br/>-rp | (optional) The docker repository if targeting a repo from 'index.docker.io'. If targeting an Azure Container Registry, the repository does _not_ need to be explicitly specified. |
| --artifacts_location<br/>-al | (optional) The url for referencing other scripts/artifacts. The default is this github repository. |
| --sas_token<br/>-st | (optional) A sas token needed if the artifacts location is private. |

## Example usage
```bash
./configure_k8s.sh --storage_account_name "sample" --storage_account_key "password" --registry "sample-microsoft.azurecr.io" --client_id "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" --client-key "password"
```

## Questions/Comments? azdevopspub@microsoft.com