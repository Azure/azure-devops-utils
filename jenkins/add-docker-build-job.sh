#!/bin/bash
set -e

if [ "$#" -lt 7 ]; then
    echo ""
    echo "Usage: ./add-docker-build-job.sh <jenkins url>"
    echo "                                 <jenkins user>"
    echo "                                 <jenkins password>"
    echo "                                 <git url>"
    echo "                                 <container registry url>"
    echo "                                 <container registry user name>"
    echo "                                 <container registry password>"
    echo "                                 [opt: credentials id]"
    echo "                                 [opt: credentials description]"
    echo "                                 [opt: job short name]"
    echo "                                 [opt: job display name]"
    echo "                                 [opt: job description]"
    echo "                                 [opt: container repository]"
    exit 1
fi
jenkins_url=${1}
jenkins_user=${2}
jenkins_password=${3}
git_url=${4}
cr_url=${5}
cr_user=${6}
cr_password=${7}
cr_credentials_id=${8}
cr_credentials_description=${9}
job_name=${10}
job_display_name=${11}
job_description=${12}
container_repository_name=${13}

if [ -z "$cr_credentials_id" ]
then
    cr_credentials_id="docker_credentials"
fi
if [ -z "$cr_credentials_description" ]
then
    cr_credentials_description="Docker Container Registry Credentials"
fi
if [ -z "$job_name" ]
then
    job_name="basic-docker-build"
fi
if [ -z "$job_display_name" ]
then
    job_display_name="Basic Docker Build"
fi
if [ -z "$job_description" ]
then
    job_description="A basic pipeline that builds a Docker container. The job expects a Dockerfile at the root of the git repository"
fi
if [ -z "$container_repository_name" ]
then
    container_repository_name="${USER}/myfirstapp"
fi

#download dependencies
base_remote_jenkins_scripts="https://raw.githubusercontent.com/Azure/azure-devops-utils/master"

wget ${base_remote_jenkins_scripts}/jenkins/basic-docker-build-job.xml -O job_template.xml
wget ${base_remote_jenkins_scripts}/jenkins/basic-user-pwd-credentials.xml -O credentials_template.xml
wget ${base_remote_jenkins_scripts}/groovy/basic-docker-build.groovy -O job.groovy

#prepare credentials.xml
cat credentials_template.xml | sed -e "s|{insert-credentials-id}|${cr_credentials_id}|"\
                                   -e "s|{insert-credentials-description}|${cr_credentials_description}|"\
                                   -e "s|{insert-user-name}|${cr_user}|"\
                                   -e "s|{insert-user-password}|${cr_password}|"\
                                    > credentials.xml
rm credentials_template.xml

#prepare job.xml
cat job_template.xml | sed -e "s|{insert-job-display-name}|${job_display_name}|"\
                           -e "s|{insert-job-description}|${job_description}|"\
                           -e "s|{insert-git-url}|${git_url}|"\
                           -e "s|{insert-cr-url}|${cr_url}|"\
                           -e "s|{insert-docker-credentials}|${cr_credentials_id}|"\
                           -e "s|{insert-container-repository}|${container_repository_name}|" > job1.xml
cat job1.xml | sed "/{insert-groovy-script}/r job.groovy" | sed "/{insert-groovy-script}/d" > job.xml
rm job_template.xml
rm job1.xml
rm job.groovy
set +e

function retry_until_successful {
    counter=0
    ${@}
    while [ $? -ne 0 ]; do
        if [[ "$counter" -gt 20 ]]; then
            exit 1
        else
            let counter++
        fi
        sleep 5
        ${@}
    done;
}

#download jenkins cli (wait for Jenkins to be online)
retry_until_successful wget ${jenkins_url}/jnlpJars/jenkins-cli.jar -O jenkins-cli.jar

#install the required plugins
retry_until_successful java -jar jenkins-cli.jar -s ${jenkins_url} install-plugin "credentials" -deploy --username ${jenkins_user} --password ${jenkins_password}
retry_until_successful java -jar jenkins-cli.jar -s ${jenkins_url} install-plugin "workflow-cps" -deploy --username ${jenkins_user} --password ${jenkins_password}
retry_until_successful java -jar jenkins-cli.jar -s ${jenkins_url} install-plugin "workflow-job" -deploy --username ${jenkins_user} --password ${jenkins_password}
retry_until_successful java -jar jenkins-cli.jar -s ${jenkins_url} install-plugin "docker-workflow" -restart --username ${jenkins_user} --password ${jenkins_password}

#wait for instance to be back online
retry_until_successful java -jar jenkins-cli.jar -s ${jenkins_url} version --username ${jenkins_user} --password ${jenkins_password}

#add user/pwd
retry_until_successful cat credentials.xml | java -jar jenkins-cli.jar -s ${jenkins_url} create-credentials-by-xml SystemCredentialsProvider::SystemContextResolver::jenkins "(global)" --username ${jenkins_user} --password ${jenkins_password}
#add job
retry_until_successful cat job.xml | java -jar jenkins-cli.jar -s ${jenkins_url} create-job ${job_name} --username ${jenkins_user} --password ${jenkins_password}

#cleanup
rm credentials.xml
rm job.xml
rm jenkins-cli.jar
