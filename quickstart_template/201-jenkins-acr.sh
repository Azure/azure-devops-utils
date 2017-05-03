#!/bin/bash
function print_usage() {
  cat <<EOF
https://github.com/Azure/azure-quickstart-templates/tree/master/201-jenkins-acr
Command
  $0
Arguments
  --vm_user_name|-u        [Required] : VM user name
  --git_url|-g             [Required] : Git URL with a Dockerfile in it's root
  --registry|-r            [Required] : Registry url targeted by the pipeline
  --registry_user_name|-ru [Required] : Registry user name
  --registry_password|-rp  [Required] : Registry password
  --repository|-rr         [Required] : Repository targeted by the pipeline
  --jenkins_fqdn|-jf       [Required] : Jenkins FQDN
  --artifacts_location|-al            : Url used to reference other scripts/artifacts.
  --sas_token|-st                     : A sas token needed if the artifacts location is private.
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

function run_util_script() {
  local script_path="$1"
  shift
  curl --silent "${artifacts_location}${script_path}${artifacts_location_sas_token}" | sudo bash -s -- "$@"
  local return_value=$?
  if [ $return_value -ne 0 ]; then
    >&2 echo "Failed while executing script '$script_path'."
    exit $return_value
  fi
}

#defaults
artifacts_location="https://raw.githubusercontent.com/Azure/azure-devops-utils/master/"
while [[ $# > 0 ]]
do
  key="$1"
  shift
  case $key in
    --vm_user_name|-u)
      vm_user_name="$1"
      shift
      ;;
    --git_url|-g)
      git_url="$1"
      shift
      ;;
    --registry|-r)
      registry="$1"
      shift
      ;;
    --registry_user_name|-ru)
      registry_user_name="$1"
      shift
      ;;
    --registry_password|-rp)
      registry_password="$1"
      shift
      ;;
    --repository|-rr)
      repository="$1"
      shift
      ;;
    --jenkins_fqdn|-jf)
      jenkins_fqdn="$1"
      shift
      ;;
    --artifacts_location|-al)
      artifacts_location="$1"
      shift
      ;;
    --sas_token|-st)
      artifacts_location_sas_token="$1"
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

throw_if_empty --vm_user_name $vm_user_name
throw_if_empty --git_url $git_url
throw_if_empty --registry $registry
throw_if_empty --registry_user_name $registry_user_name
throw_if_empty --registry_password $registry_password
throw_if_empty --jenkins_fqdn $jenkins_fqdn

if [ -z "$repository" ]; then
  repository="${vm_user_name}/myfirstapp"
fi

#install jenkins
run_util_script "jenkins/install_jenkins.sh" -jf "${jenkins_fqdn}" -al "${artifacts_location}" -st "${artifacts_location_sas_token}"

#install git
sudo apt-get install git --yes

#install docker if not already installed
if !(command -v docker >/dev/null); then
  sudo curl -sSL https://get.docker.com/ | sh
fi

#make sure jenkins has access to docker cli
sudo gpasswd -a jenkins docker
skill -KILL -u jenkins
sudo service jenkins restart

echo "Including the pipeline"
run_util_script "jenkins/add-docker-build-job.sh" -j "http://localhost:8080/" -ju "admin" -g "${git_url}" -r "${registry}" -ru "${registry_user_name}"  -rp "${registry_password}" -rr "$repository" -sps "* * * * *" -al "$artifacts_location" -st "$artifacts_location_sas_token"
