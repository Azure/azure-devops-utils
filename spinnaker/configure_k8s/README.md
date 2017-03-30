# Configure Spinnaker for Kubernetes

Automatically configure a spinnaker instance to target a Kubernetes cluster and Azure Container Registry. This script will restart clouddriver and igor so that config changes take effect. The only remaining step is copy the kubeconfig file from your Kubernetes master vm to the Spinnaker VM.

## Prerequisites
This must be executed on a machine with an existing Spinnaker instance.

## Arguments
| Name | Description |
|---|---|
| --registry<br/>-rg | The Azure Container Registry url, for example 'sample-microsoft.azurecr.io'. |
| --app_id<br/>-ai | The Service Principal app id used to access your registry. |
| --app_key<br/>-ak | The Service Principal app key used to access your registry. |
| --repository<br/>-rp | (optional) The docker repository if targeting a repo from 'index.docker.io'. If targeting an Azure Container Registry, the repository does _not_ need to be explicitly specified. |
| --artifacts_location<br/>-al | (optional) The url for referencing other scripts/artifacts. The default is this github repository. |
| --sas_token<br/>-st | (optional) A sas token needed if the artifacts location is private. |

## Example usage
```bash
./configure_k8s.sh --registry "sample-microsoft.azurecr.io" --app_id "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" --app-key "password"
```

## Questions/Comments? azdevopspub@microsoft.com