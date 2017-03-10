# Install Spinnaker

Install Spinnaker and automatically configure it to use Azure Storage (azs) as its persistent storage.

## Prerequisites
This must be executed on a linux VM.

## Arguments
| Name | Description |
|---|---|
| --storage_account_name<br/>-san | The storage account name used for Spinnaker's persistent storage service (front50). |
| --storage_account_key<br/>-sak | The storage account key used for Spinnaker's persistent storage service (front50). |
| --artifacts_location<br/>-al | (optional) The url for referencing other scripts/artifacts. The default is this github repository. |
| --sas_token<br/>-st | (optional) A sas token needed if the artifacts location is private. |

## Example usage
```bash
./install_spinnaker.sh --storage_account_name "sample" --storage_account_key "password"
```

## Questions/Comments? azdevopspub@microsoft.com