# Await Restart Spinnaker Service

Restarts a Spinnaker service and waits for the service to be open for requests.

## Prerequisites
This must be executed on a machine with an existing Spinnaker instance.

## Arguments
| Name | Description |
|---|---|
| --service<br/>-s | The Spinnaker service to restart. |
| --host<br/>-h | (optional) The host used by the service, default to localhost. |
| --port<br/>-p | (optional) The port used by the service, if different than the default. |
| --timeout<br/>-t | (optional) The time to wait in seconds, defaulted to 120. |

## Example usage
```bash
./await_restart_service.sh --service clouddriver
```

## Questions/Comments? azdevopspub@microsoft.com