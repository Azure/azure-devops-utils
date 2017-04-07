#!/bin/bash

function print_usage() {
  cat <<EOF
Command
  $0
Arguments
  --jenkins_url|-j          [Required]: Jenkins URL
  --jenkins_user_name|-ju   [Required]: Jenkins user name
  --plugins|-p              [Required]: Comma separated list of plugins to install
  --jenkins_password|-jp              : Jenkins password. If not specified and the user name is "admin", the initialAdminPassword will be used
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

#set defaults
artifacts_location="https://raw.githubusercontent.com/Azure/azure-devops-utils/master/"


while [[ $# > 0 ]]
do
  key="$1"
  shift
  case $key in
    --jenkins_url|-j)
      jenkins_url="$1"
      shift
      ;;
    --jenkins_user_name|-ju)
      jenkins_user_name="$1"
      shift
      ;;
    --jenkins_password|-jp)
      jenkins_password="$1"
      shift
      ;;
    --plugins|-p)
      plugins="$1"
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

throw_if_empty --jenkins_url $jenkins_url
throw_if_empty --jenkins_user_name $jenkins_user_name
throw_if_empty --plugins $plugins

if [ "$jenkins_user_name" != "admin" ]; then
  throw_if_empty --jenkins_password $jenkins_password
fi

function retry_until_successful {
    counter=0
    "${@}"
    while [ $? -ne 0 ]; do
        if [[ "$counter" -gt 20 ]]; then
            exit 1
        else
            let counter++
        fi
        sleep 5
        "${@}"
    done;
}

#download jenkins cli (wait for Jenkins to be online)
retry_until_successful wget ${jenkins_url}/jnlpJars/jenkins-cli.jar -O jenkins-cli.jar

if [ -z "$jenkins_password" ]; then
  # NOTE: Intentionally setting this after the first retry_until_successful to ensure the initialAdminPassword file exists
  jenkins_password=`sudo cat /var/lib/jenkins/secrets/initialAdminPassword`
fi

#install the required plugins
pluginsArray=(${plugins//,/ })
for plugin_name in "${pluginsArray[@]}"; do
  retry_until_successful java -jar jenkins-cli.jar -s ${jenkins_url} install-plugin "${plugin_name}" -deploy --username "${jenkins_user_name}" --password "${jenkins_password}"
done