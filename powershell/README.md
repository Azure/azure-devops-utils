## Jenkins Azure Agent initialization script
> [Jenkins-Windows-Init-Script.ps1](Jenkins-Windows-Init-Script.ps1)

Sample script on how to setup your Windows Azure Jenkins Agent to communicate through JNLP with the Jenkins master.
Before deploying using this initialization script remember to update this line with your credentials (you can get api token by clicking on your username --> configure --> show api token):
```powershell
$credentials="username:apitoken"
```
More information about the Azure VM Agents plugin can be found [here](https://wiki.jenkins-ci.org/display/JENKINS/Azure+VM+Agents+Plugin).

## Azure Classic VM Image migration
> [Migrate-Image-From-Classic.ps1](Migrate-Image-From-Classic.ps1)

Migrates an image from the classic image model to the new Azure Resource Manager model.

| Argument             | Description                                                                                       |
|----------------------|---------------------------------------------------------------------------------------------------|
| ImageName            | Original image name                                                                               |
| TargetStorageAccount | Target account to copy to                                                                         |
| TargetResourceGroup  | Resource group of the target storage account                                                      |
| TargetContainer      | Target container to put the VHD                                                                   |
| TargetVirtualPath    | Virtual path to put the blob in. If not specified, defaults to the virtual path of the source URI |
| TargetBlobName       | Blob name to copy to.  If not specified, defaults to the blob name of the source URI              |

## Questions/Comments? azdevopspub@microsoft.com