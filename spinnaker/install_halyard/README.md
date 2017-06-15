# Install Spinnaker

Install Halyard and automatically configure Spinnaker to use Azure Storage (azs) as its persistent storage.

## Prerequisites
This must be executed on a linux VM. You must run 'hal deploy apply' to finish deployment of Spinnaker.

## Arguments
| Name | Description |
|---|---|
| --storage_account_name<br/>-san | The storage account name used for Spinnaker's persistent storage service (front50). |
| --storage_account_key<br/>-sak | The storage account key used for Spinnaker's persistent storage service (front50). |
| --username<br/>-u | User for which to install Halyard. |

## Example usage
```bash
./install_spinnaker.sh --storage_account_name "sample" --storage_account_key "password"
```

## Questions/Comments? azdevopspub@microsoft.com