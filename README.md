# azure-devops-utils
Utilities of Azure Devops to run/configure systems in Azure

## [Create Service Principal](bash/create-service-principal.sh)
> [bash/create-service-principal.sh](bash/create-service-principal.sh)

Creates Azure Service Principal credentials.

Requires that the [Azure CLI](https://docs.microsoft.com/en-us/azure/xplat-cli-install) is pre-installed.

The script prompts for user input to be able to authenticate on Azure and to pick the desired subscription (this step can be skipped by providing the subscription id as a script argument).

For doing this in Windows without a bash shell, refer to instructions [here](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-authenticate-service-principal-cli)

Another alternative using PowerShell can be found [here](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-authenticate-service-principal)

## [Jenkins Azure Agent initialization script](powershell/Jenkins-Windows-Init-Script.ps1)
> [powershell/Jenkins-Windows-Init-Script.ps1](powershell/Jenkins-Windows-Init-Script.ps1)

Sample script on how to setup your Windows Azure Jenkins Agent to communicate through JNLP with the Jenkins master.
Before deploying using this initialization script remember to update this line with your credentials (you can get api token by clicking on your username --> configure --> show api token):
```powershell
$credentials="username:apitoken"
```
More information about the Azure VM Agents plugin can be found [here](https://wiki.jenkins-ci.org/display/JENKINS/Azure+VM+Agents+Plugin).

## [Azure Classic VM Image migration](powershell/Migrate-Image-From-Classic.ps1)
> [powershell/Migrate-Image-From-Classic.ps1](powershell/Migrate-Image-From-Classic.ps1)

Migrates an image from the classic image model to the new Azure Resource Manager model.

| Argument             | Description                                                                                       |
|----------------------|---------------------------------------------------------------------------------------------------|
| ImageName            | Original image name                                                                               |
| TargetStorageAccount | Target account to copy to                                                                         |
| TargetResourceGroup  | Resource group of the target storage account                                                      |
| TargetContainer      | Target container to put the VHD                                                                   |
| TargetVirtualPath    | Virtual path to put the blob in. If not specified, defaults to the virtual path of the source URI |
| TargetBlobName       | Blob name to copy to.  If not specified, defaults to the blob name of the source URI              |


## [Jenkins groovy scripts](groovy/)
> [groovy/basic-docker-build.groovy](groovy/basic-docker-build.groovy)

Sample Jenkins pipeline that clones a git repository, builds the docker image defined in the Docker file and pushes that image to a private container registry.
The Jenkins Job that uses this groovy script must have these parameters defined:

| Jenkins job parameters  | Description                                                                                                 |
|-------------------------|-------------------------------------------------------------------------------------------------------------|
| git_repo                | A public git repository that has a Dockerfile                                                               |
| docker_tag_prefix       | The image tag prefix (the tag will be in this format: "<prefix>:build_number")                              |
| registry_url            | The Docker private container registry url                                                                   |
| registry_credentials_id | The Jenkins credentials id that stores the user name and password for the Docker private container registry |
