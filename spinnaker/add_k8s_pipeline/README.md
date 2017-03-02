# Add Kubernetes Pipeline

Adds a Kubernetes pipeline with three main stages:

1. Deploy to a development environment
1. Wait for manual judgement
1. Deploy to a production environment

The pipeline will be triggered by any new tag pushed to the target repository and will also clean up previous deployments.

## Prerequisites
This must be executed on a machine with a running Spinnaker instance.

## Arguments
| Name | Description |
|---|---|
| --account_name<br/>-an | The Spinnaker account name for your registry |
| --registry<br/>-rg | The Azure Container Registry url, for example 'sample-microsoft.azurecr.io'. |
| --repository<br/>-rp | The repository, for example 'Fabrikam/app1'. Any new tag pushed to this repository will trigger the pipeline. |
| --port<br/>-p | (optional) The port used when creating load balancers for the pipeline. The container deployed by your pipeline is expected to be listening on this port. The default is '8000'. |
| --user_name<br/>-un | (optional) The user name for creating the pipeline. The default is '[anonymous]'. |
| --user_email<br/>-ue | (optional) The user email for creating the pipeline. The default is 'anonymous@Fabrikam.com'. |
| --artifacts_location<br/>-al | (optional) The url for referencing other scripts/artifacts. The default is this github repository. |
| --sas_token<br/>-st | (optional) A sas token needed if the artifacts location is private. |

## Example usage
```bash
./add_k8s_pipeline.sh --acount-name "azure-container-registry" --registry "sample-microsoft.azurecr.io" --repository "Fabrikam/application1"
```

## Questions/Comments? azdevopspub@microsoft.com