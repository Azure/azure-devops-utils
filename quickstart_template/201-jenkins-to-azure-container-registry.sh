#!/bin/bash
function print_usage() {
  cat <<EOF
https://github.com/Azure/azure-quickstart-templates/tree/master/201-jenkins-to-azure-container-registry
Command
  $0
Arguments
  --include_docker_build_pipeline|-i    : Include a docker build pipeline (off by default). If enabled, then the rest of the arguments are required
  --vm_user_name|-u                     : VM user name
  --git_url|-g                          : Git URL with a Dockerfile in it's root
  --registry|-r                         : Registry url targeted by the pipeline
  --registry_user_name|-ru              : Registry user name
  --registry_password|-rp               : Registry password
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

#defaults
include_docker_build_pipeline="0"
base_remote_jenkins_scripts="https://raw.githubusercontent.com/Azure/azure-devops-utils/master"

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
    --include_docker_build_pipeline|-i)
      include_docker_build_pipeline="$1"
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

if [[ "${include_docker_build_pipeline}" == "1" ]]
then
    throw_if_empty --vm_user_name $vm_user_name
    throw_if_empty --git_url $git_url
    throw_if_empty --registry $registry
    throw_if_empty --registry_user_name $registry_user_name
    throw_if_empty --registry_password $registry_password
fi

#install jenkins
wget -q -O - https://pkg.jenkins.io/debian/jenkins-ci.org.key | sudo apt-key add -
sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
sudo apt-get update --yes
sudo apt-get install jenkins --yes
sudo apt-get install jenkins --yes # sometime the first apt-get install jenkins command fails, so we try it twice
sudo apt-get install git --yes

#install docker
sudo curl -sSL https://get.docker.com/ | sh

#make sure jenkins has access to docker cli
sudo gpasswd -a jenkins docker
skill -KILL -u jenkins
sudo service jenkins restart

if [[ "${include_docker_build_pipeline}" == "1" ]]
then
    echo "Including the pipeline"

    #get password and call build creation script
    admin_password=`sudo cat /var/lib/jenkins/secrets/initialAdminPassword`

    curl --silent "${base_remote_jenkins_scripts}/jenkins/add-docker-build-job.sh" | sudo bash -s -- -j "http://localhost:8080/" -ju "admin" -jp "${admin_password}" -g "${git_url}" -r "${registry}" -ru "${registry_user_name}"  -rp "${registry_password}" -rr "${vm_user_name}/myfirstapp"
fi
