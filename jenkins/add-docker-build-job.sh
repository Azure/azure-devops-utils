#!/bin/bash

function print_usage() {
  cat <<EOF
Command
  $0
Arguments
  --jenkins_url|-j          [Required]: Jenkins URL
  --jenkins_username|-ju    [Required]: Jenkins user name
  --jenkins_password|-jp              : Jenkins password. If not specified and the user name is "admin", the initialAdminPassword will be used
  --git_url|-g              [Required]: Git URL with a Dockerfile in it's root
  --registry|-r             [Required]: Registry url targeted by the pipeline
  --registry_user_name|-ru  [Required]: Registry user name
  --registry_password|-rp   [Required]: Registry password
  --repository|-rr                    : Repository targeted by the pipeline
  --credentials_id|-ci                : Desired Jenkins credentials id
  --credentials_desc|-cd              : Desired Jenkins credentials description
  --job_short_name|-jsn               : Desired Jenkins job short name
  --job_display_name|-jdn             : Desired Jenkins job display name
  --job_description|-jd               : Desired Jenkins job description
  --scm_poll_schedule|-sps            : cron style schedule for SCM polling
  --scm_poll_ignore_commit_hooks|spi  : Ignore changes notified by SCM post-commit hooks. (Will be ignore if the poll schedule is not defined)
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

#set defaults
credentials_id="docker_credentials"
credentials_desc="Docker Container Registry Credentials"
job_short_name="basic-docker-build"
job_display_name="Basic Docker Build"
job_description="A basic pipeline that builds a Docker container. The job expects a Dockerfile at the root of the git repository"
repository="${USER}/myfirstapp"
scm_poll_schedule=""
scm_poll_ignore_commit_hooks="0"
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
    --jenkins_username|-ju)
      jenkins_username="$1"
      shift
      ;;
    --jenkins_password|-jp)
      jenkins_password="$1"
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
    --credentials_id|-ci)
      credentials_id="$1"
      shift
      ;;
    --credentials_desc|-cd)
      credentials_desc="$1"
      shift
      ;;
    --job_short_name|-jsn)
      job_short_name="$1"
      shift
      ;;
    --job_display_name|-jdn)
      job_display_name="$1"
      shift
      ;;
    --job_description|-jd)
      job_description="$1"
      shift
      ;;
   --scm_poll_schedule|-sps)
      scm_poll_schedule="$1"
      shift
      ;;
  --scm_poll_ignore_commit_hooks|-spi)
      scm_poll_ignore_commit_hooks="$1"
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

throw_if_empty --jenkins_url $jenkins_url
throw_if_empty --jenkins_username $jenkins_username
if [ "$jenkins_username" != "admin" ]; then
  throw_if_empty --jenkins_password $jenkins_password
fi
throw_if_empty --git_url $git_url
throw_if_empty --registry $registry
throw_if_empty --registry_user_name $registry_user_name
throw_if_empty --registry_password $registry_password

#download dependencies
job_xml=$(curl -s ${artifacts_location}/jenkins/basic-docker-build-job.xml${artifacts_location_sas_token})
credentials_xml=$(curl -s ${artifacts_location}/jenkins/basic-user-pwd-credentials.xml${artifacts_location_sas_token})

#prepare credentials.xml
credentials_xml=${credentials_xml//'{insert-credentials-id}'/${credentials_id}}
credentials_xml=${credentials_xml//'{insert-credentials-description}'/${credentials_desc}}
credentials_xml=${credentials_xml//'{insert-user-name}'/${registry_user_name}}
credentials_xml=${credentials_xml//'{insert-user-password}'/${registry_password}}

#prepare job.xml
job_xml=${job_xml//'{insert-job-display-name}'/${job_display_name}}
job_xml=${job_xml//'{insert-job-description}'/${job_description}}
job_xml=${job_xml//'{insert-git-url}'/${git_url}}
job_xml=${job_xml//'{insert-registry}'/${registry}}
job_xml=${job_xml//'{insert-docker-credentials}'/${credentials_id}}
job_xml=${job_xml//'{insert-container-repository}'/${repository}}


if [ -n "${scm_poll_schedule}" ]
then
  scm_poll_ignore_commit_hooks_bool="false"
  if [[ "${scm_poll_ignore_commit_hooks}" == "1" ]]
  then
    scm_poll_ignore_commit_hooks_bool="true"
  fi
  triggers_xml_node=$(cat <<EOF
<triggers>
  <hudson.triggers.SCMTrigger>
  <spec>${scm_poll_schedule}</spec>
  <ignorePostCommitHooks>${scm_poll_ignore_commit_hooks_bool}</ignorePostCommitHooks>
  </hudson.triggers.SCMTrigger>
</triggers>
EOF
)
  job_xml=${job_xml//'<triggers/>'/${triggers_xml_node}}
fi

job_xml=${job_xml//'{insert-groovy-script}'/"$(curl -s ${artifacts_location}/jenkins/basic-docker-build.groovy${artifacts_location_sas_token})"}
echo "${job_xml}" > job.xml

#install the required plugins
run_util_script "jenkins/run-cli-command.sh" -j "$jenkins_url" -ju "$jenkins_username" -jp "$jenkins_password" -c "install-plugin credentials -deploy"
plugins=(docker-workflow git)
for plugin in "${plugins[@]}"; do
  run_util_script "jenkins/run-cli-command.sh" -j "$jenkins_url" -ju "$jenkins_username" -jp "$jenkins_password" -c "install-plugin $plugin -restart"
done

#wait for instance to be back online
run_util_script "jenkins/run-cli-command.sh" -j "$jenkins_url" -ju "$jenkins_username" -jp "$jenkins_password" -c "version"

#add user/pwd
echo "${credentials_xml}" > credentials.xml
run_util_script "jenkins/run-cli-command.sh" -j "$jenkins_url" -ju "$jenkins_username" -jp "$jenkins_password" -c 'create-credentials-by-xml SystemCredentialsProvider::SystemContextResolver::jenkins (global)' -cif "credentials.xml"

#add job
run_util_script "jenkins/run-cli-command.sh" -j "$jenkins_url" -ju "$jenkins_username" -jp "$jenkins_password" -c "create-job ${job_short_name}" -cif "job.xml"

#cleanup
rm credentials.xml
rm job.xml
rm jenkins-cli.jar