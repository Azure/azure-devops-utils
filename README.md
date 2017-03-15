# Azure DevOps Utilities
This repository contains utility scripts to run/configure DevOp systems in Azure. These scripts can be used individually, but are also leveraged in several 'Getting Started' solutions:
* [Jenkins Quickstart Templates](https://azure.microsoft.com/resources/templates/?term=Jenkins)
* [Spinnaker Quickstart Templates](https://azure.microsoft.com/resources/templates/?term=Spinnaker)

## Contents
* Common
  * [create-service-principal.sh](bash/create-service-principal.sh): Creates Azure Service Principal credentials.
* Jenkins
  * [add-docker-build-job.sh](jenkins/add-docker-build-job.sh): Adds a Docker Build job in an existing Jenkins instance.
  * [unsecure-jenkins-instance.sh](jenkins/unsecure-jenkins-instance.sh): Disables the security of a Jenkins instance.
  * [Jenkins-Windows-Init-Script.ps1](powershell/Jenkins-Windows-Init-Script.ps1): Sample script on how to setup your Windows Azure Jenkins Agent to communicate through JNLP with the Jenkins master.
  * [Migrate-Image-From-Classic.ps1](powershell/Migrate-Image-From-Classic.ps1): Migrates an image from the classic image model to the new Azure Resource Manager model.
* Spinnaker
  * [add_k8s_pipeline.sh](spinnaker/add_k8s_pipeline/): Adds a Kubernetes pipeline with three main stages:
    1. Deploy to a development environment
    1. Wait for manual judgement
    1. Deploy to a production environment
  * [await_restart_service.sh](spinnaker/await_restart_service/): Restarts a Spinnaker service and waits for the service to be open for requests.
  * [configure_k8s.sh](spinnaker/configure_k8s/): Automatically configure a spinnaker instance to target a Kubernetes cluster and Azure Container Registry.
  * [copy_kube_config.sh](spinnaker/copy_kube_config/): Programatically copies a kubeconfig file from an Azure Container Service Kubernetes cluster to a Spinnaker machine.
  * [install_spinnaker.sh](spinnaker/install_spinnaker/): Install Spinnaker and automatically configure it to use Azure Storage (azs) as its persistent storage.

## Questions/Comments? azdevopspub@microsoft.com

_This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments._