## Add a Docker Build job in an existing Jenkins instance
> [add-docker-build-job.sh](add-docker-build-job.sh)

Bash script that adds a Docker Build job in an existing Jenkins instance. The created job will use the [basic-docker-build.groovy](basic-docker-build.groovy) script.

## Disable security for a Jenkins instance
> [unsecure-jenkins-instance.sh](unsecure-jenkins-instance.sh)

Bash script that disables the security of a Jenkins instance.

If you accidentally set up security realm / authorization in such a way that you may no longer able to reconfigure Jenkins you can use this script to disable security.

***Don't make your instance publicly available when running this script! Anyone can access your unsecure Jenkins instance!***
For more informations see the [Jenkins documentation](https://jenkins.io/doc/book/operating/security/#disabling-security)

## Questions/Comments? azdevopspub@microsoft.com