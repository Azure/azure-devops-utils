#!/bin/bash
if [ "$#" -lt 6 ]; then
    echo "Usage: ./install-jenkins-and-docker-build-pipeline.sh <VM user name>"
    echo "                                                      <git url>"
    echo "                                                      <container registry url>"
    echo "                                                      <container registry user name>"
    echo "                                                      <container registry password>"
    echo "                                                      <include Docker Build pipeline>"
    exit 1
fi
vm_user=${1}
git_url=${2}
cr_url=${3}
cr_user=${4}
cr_password=${5}
include_pipeline=${6}

#install jenkins
wget -q -O - https://pkg.jenkins.io/debian/jenkins-ci.org.key | sudo apt-key add -
sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
curl -fsSL https://apt.dockerproject.org/gpg | sudo apt-key add -
sudo add-apt-repository \
       "deb https://apt.dockerproject.org/repo/ \
       ubuntu-$(lsb_release -cs) \
       main"
sudo apt-get update --yes
sudo apt-get install jenkins --yes
sudo apt-get install jenkins --yes # sometime the first apt-get install jenkins command fails, so we try it twice
sudo apt-get install git --yes
sudo apt-get -y install docker-engine --yes
sudo gpasswd -a jenkins docker
sudo service docker restart
skill -KILL -u jenkins
sudo service jenkins restart

echo ${include_pipeline}
if [[ "${include_pipeline}" != "1" ]]
then
    echo "skipping the pipeline inclusion"
    exit 0
fi
echo "including the pipeline"
#download dependencies
base_remote_jenkins_scripts="https://raw.githubusercontent.com/Azure/azure-devops-utils/master/jenkins"
add_docker_build_job_script_name="add-docker-build-job.sh"

wget "${base_remote_jenkins_scripts}/${add_docker_build_job_script_name}" -O ${add_docker_build_job_script_name}
sudo chmod +x ${add_docker_build_job_script_name}

#get password and call build creation script
admin_password=`sudo cat /var/lib/jenkins/secrets/initialAdminPassword`

./${add_docker_build_job_script_name} "http://localhost:8080/" "admin" "${admin_password}" "${git_url}" "${cr_url}" "${cr_user}" "${cr_password}" "" "" "" "" "" "${vm_user}/myfirstapp"