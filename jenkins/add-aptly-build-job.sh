#!/bin/bash

function print_usage() {
  cat <<EOF
Command
  $0
Arguments
  --git_url|-g             : Git URL for the build job
  --repository_name|-rn    : Aptly repository name used to store debian packages
  --job_short_name|-jsn    : Desired Jenkins job short name
  --job_display_name|-jdn  : Desired Jenkins job display name
  --job_description|-jd    : Desired Jenkins job description
  --artifacts_location|-al : Url used to reference other scripts/artifacts.
  --sas_token|-st          : A sas token needed if the artifacts location is private.
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

#set defaults
job_short_name="hello-karyon-rxnetty"
job_display_name="Sample Aptly Job"
job_description="A basic pipeline that builds a debian package and pushes it to an Aptly repository hosted on the Jenkins VM."
repository_name="hello-karyon-rxnetty"
artifacts_location="https://raw.githubusercontent.com/Azure/azure-devops-utils/master/"
git_url="https://github.com/azure-devops/hello-karyon-rxnetty.git"

while [[ $# > 0 ]]
do
  key="$1"
  shift
  case $key in
    --git_url|-g)
      git_url="$1";;
    --repository_name|-rn)
      repository_name="$1";;
    --job_short_name|-jsn)
      job_short_name="$1";;
    --job_display_name|-jdn)
      job_display_name="$1";;
    --job_description|-jd)
      job_description="$1";;
    --artifacts_location|-al)
      artifacts_location="$1";;
    --sas_token|-st)
      artifacts_location_sas_token="$1";;
    --help|-help|-h)
      print_usage
      exit 13;;
    *)
      echo "ERROR: Unknown argument '$key' to script '$0'" 1>&2
      exit -1
  esac
  shift
done

throw_if_empty git_url $git_url
throw_if_empty repository_name $repository_name

#download dependencies
job_xml=$(curl -s ${artifacts_location}/jenkins/basic-aptly-build-job.xml${artifacts_location_sas_token})

#prepare job.xml
job_xml=${job_xml//'{insert-job-display-name}'/${job_display_name}}
job_xml=${job_xml//'{insert-job-description}'/${job_description}}
job_xml=${job_xml//'{insert-git-url}'/${git_url}}
job_xml=${job_xml//'{insert-repository-name}'/${repository_name}}

echo "${job_xml}" > job.xml

echo "Installing git..." 
sudo DEBIAN_FRONTEND=noninteractive apt-get install git -y

echo "Installing Java 8..." 
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y openjdk-8-jdk

gradle_version="3.5"
echo "Installing Gradlew ${gradle_version}..." 
wget -nv https://services.gradle.org/distributions/gradle-${gradle_version}-bin.zip
sudo unzip gradle-${gradle_version}-bin.zip -d /opt/gradle
sudo ln -s /opt/gradle/gradle-${gradle_version}/bin/gradle /usr/bin/gradle

run_util_script "jenkins/run-cli-command.sh" -c "install-plugin git -restart"

echo "Waiting for Jenkins to be back online..."
run_util_script "jenkins/run-cli-command.sh" -c "version"

echo "Adding basic vmss job..."
run_util_script "jenkins/run-cli-command.sh" -cif "job.xml" -c "create-job ${job_short_name}"

#cleanup
rm job.xml
rm jenkins-cli.jar