# Await Restart Spinnaker

Restarts Spinnaker and waits for several known services to be ready before returning.

## Prerequisites
This must be executed on a machine with an existing Spinnaker instance.

## Arguments
| Name | Description |
|---|---|
| --timeout<br/>-t | (optional) The time to wait in seconds, defaulted to 120. |

## Example usage
```bash
./await_restart_spinnaker.sh --timeout 120
```

## Questions/Comments? azdevopspub@microsoft.com