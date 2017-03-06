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

## Questions/Comments? azdevopspub@microsoft.com