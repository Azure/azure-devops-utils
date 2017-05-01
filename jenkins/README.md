## Jenkins groovy script to build and push a Docker container
> [basic-docker-build.groovy](basic-docker-build.groovy)

Sample Jenkins pipeline that clones a git repository, builds the docker container defined in the Docker file and pushes that container to a private container registry.
The Jenkins Job that uses this groovy script must have these parameters defined:

| Jenkins job parameters  | Description                                                                                                 |
|-------------------------|-------------------------------------------------------------------------------------------------------------|
| git_repo                | A public git repository that has a Dockerfile                                                               |
| docker_repository       | The container repository                                                                                    |
| registry_url            | The Docker private container registry url                                                                   |
| registry_credentials_id | The Jenkins credentials id that stores the user name and password for the Docker private container registry |

## Add a Docker Build job in an existing Jenkins instance
> [add-docker-build-job.sh](add-docker-build-job.sh)

Bash script that adds a Docker Build job in an existing Jenkins instance. The created job will use the [basic-docker-build.groovy](basic-docker-build.groovy) script.

## Disable security for a Jenkins instance
> [unsecure-jenkins-instance.sh](unsecure-jenkins-instance.sh)

Bash script that disables the security of a Jenkins instance.

If you accidentally set up security realm / authorization in such a way that you may no longer able to reconfigure Jenkins you can use this script to disable security.

***Don't make your instance publicly available when running this script! Anyone can access your unsecure Jenkins instance!***
For more informations see the [Jenkins documentation](https://jenkins.io/doc/book/operating/security/#disabling-security)

## Install Jenkins
> [install_jenkins.sh](install_jenkins.sh)
Bash script that installs Jenkins on a Linux VM and exposes it to the public through port 80 (login and cli are disabled).

##  Install Jenkins plugins
> [run-cli-command.sh](run-cli-command.sh)
Bash script that runs a Jenkins cli command.

## Questions/Comments? azdevopspub@microsoft.com