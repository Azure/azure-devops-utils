#!/bin/bash

function print_usage() {
  cat <<EOF
Command
  $0 

Arguments
  --timeout|-t   : Timeout in seconds, defaulted to 120
EOF
}

# Set defaults
timeout=120

while [[ $# > 0 ]]
do
  key="$1"
  shift
  case $key in
    --timeout|-t)
      timeout="$1"
      shift
      ;;
    --help|-help|-h)
      print_usage
      exit 13
      ;;
    *)
      echo "ERROR: Unknown argument '$key'" 1>&2
      exit -1
  esac
done

# NOTE: The following command will start Spinnaker even if it's not running, whereas "sudo restart spinnaker" would fail in that case
sudo service spinnaker restart

# Wait for the following Spinnaker services to be ready:
# Gate - port 8084
# Clouddriver - port 7002
# Front50 - port 8080
# Orca - port 8083
count=0
while !(nc -z localhost 8080) || !(nc -z localhost 8084) || !(nc -z localhost 7002) || !(nc -z localhost 8083); do
  if [ $count -gt $timeout ]; then
    echo "Could not connect to Spinnaker in specified timeout of '$timeout' seconds." 1>&2
    exit 124 # same exit code used by 'timeout' function
  else
    sleep 1
    ((count++))
  fi
done