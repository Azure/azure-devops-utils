#!/bin/bash

wget -q -O - https://pkg.jenkins.io/debian/jenkins-ci.org.key | sudo apt-key add -
sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
sudo apt-get update --yes
sudo apt-get install jenkins --yes
sudo apt-get install jenkins --yes # sometime the first apt-get install jenkins command fails, so we try it twice