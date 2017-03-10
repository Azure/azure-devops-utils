#!/bin/bash

function print_usage() {
  cat <<EOF
Command
  $0 

Arguments
  --service|-s [Required]: Spinnaker service to restart
  --host|-h              : The host configured for the service, defaulted to localhost.
  --port|-p              : The port used by the service, if different than the default.
  --timeout|-t           : Timeout in seconds, defaulted to 120
EOF
}

function throw_if_empty() {
  local name="$1"
  local value="$2"
  if [ -z "$value" ]; then
    echo "Parameter '$name' cannot be empty." 1>&2
    print_usage
    exit -1
  fi
}

# Set defaults
host="localhost"
timeout=120

while [[ $# > 0 ]]
do
  key="$1"
  shift
  case $key in
    --service|-s)
      service="$1"
      shift
      ;;
    --host|-h)
      host="$1"
      shift
      ;;
    --port|-p)
      port="$1"
      shift
      ;;
    --timeout|-t)
      timeout="$1"
      shift
      ;;
    --help|-help|-h)
      print_usage
      exit 13
      ;;
    *)
      echo "ERROR: Unknown argument '$key' to script '$0'" 1>&2
      exit -1
  esac
done

throw_if_empty --service $service

if [ -z "$port" ]; then
  case $service in
    clouddriver)
      port=7002
      ;;
    echo)
      port=8089
      ;;
    deck)
      port=9000
      ;;
    fiat)
      port=7003
      ;;
    front50)
      port=8080
      ;;
    gate)
      port=8084
      ;;
    igor)
      port=8088
      ;;
    orca)
      port=8083
      ;;
    rosco)
      port=8087
      ;;
    *)
      echo "A default port for service '$service' is not known and must be specified."
      exit -1
  esac
fi

sudo service $service restart

count=0
while !(nc -z $host $port); do
  if [ $count -gt $timeout ]; then
    echo "Could not connect to Spinnaker service '$service' at '$host:$port' in specified timeout of '$timeout' seconds." 1>&2
    exit 124 # same exit code used by 'timeout' function
  else
    sleep 1
    ((count++))
  fi
done