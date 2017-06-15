# Azure DevOps Utilities
This repository contains utility scripts to run/configure DevOp systems in Azure. These scripts can be used individually, but are also leveraged in several 'Getting Started' solutions:
* [Jenkins Quickstart Templates](https://azure.microsoft.com/resources/templates/?term=Jenkins)
* [Spinnaker Quickstart Templates](https://azure.microsoft.com/resources/templates/?term=Spinnaker)

## Contents
* Common
  * [create-service-principal.sh](bash/create-service-principal.sh): Creates Azure Service Principal credentials.
  * [deploy-dev-ops.sh](deploy-dev-ops/): Deploys a DevOps pipeline targeting either a Kubernetes cluster or VM Scale Sets.
* Jenkins
  * [basic-docker-build.groovy](jenkins/basic-docker-build.groovy): Sample Jenkins pipeline that clones a git repository, builds the docker container defined in the Docker file and pushes that container to a private container registry.
  * [add-docker-build-job.sh](jenkins/add-docker-build-job.sh): Adds a Docker Build job in an existing Jenkins instance.
  * [add-aptly-build-job.sh](jenkins/add-aptly-build-job.sh): Adds a sample Build job in an existing Jenkins instance that pushes a debian package to an Aptly repository.
  * [init-aptly-repo.sh](jenkins/init-aptly-repo.sh): Initializes an Aptly repository on an existing Jenkins instance.
  * [unsecure-jenkins-instance.sh](jenkins/unsecure-jenkins-instance.sh): Disables the security of a Jenkins instance.
  * [Jenkins-Windows-Init-Script.ps1](powershell/Jenkins-Windows-Init-Script.ps1): Sample script on how to setup your Windows Azure Jenkins Agent to communicate through JNLP with the Jenkins master.
  * [Migrate-Image-From-Classic.ps1](powershell/Migrate-Image-From-Classic.ps1): Migrates an image from the classic image model to the new Azure Resource Manager model.
  * [install_jenkins.sh](jenkins/install_jenkins.sh): Bash script that installs Jenkins on a Linux VM and exposes it to the public through port 80 (login and cli are disabled).
  * [run-cli-command.sh](jenkins/run-cli-command.sh): Script that runs a Jenkins CLI command.
* Spinnaker
  * [add_k8s_pipeline.sh](spinnaker/add_k8s_pipeline/): Adds a Kubernetes pipeline with three main stages:
    1. Deploy to a development environment
    1. Wait for manual judgement
    1. Deploy to a production environment
  * [copy_kube_config.sh](spinnaker/copy_kube_config/): Programatically copies a kubeconfig file from an Azure Container Service Kubernetes cluster to a Spinnaker machine.
  * [install_halyard.sh](spinnaker/install_halyard/): Install Halyard and automatically configure Spinnaker to use Azure Storage (azs) as its persistent storage.

## Questions/Comments? azdevopspub@microsoft.com

_This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments._