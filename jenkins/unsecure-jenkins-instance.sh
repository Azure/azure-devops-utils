#!/bin/bash

sudo echo "1" > /var/lib/jenkins/jenkins.install.InstallUtil.lastExecVersion

unsecure_config_xml=$(sed -zr \
    -e "s|<useSecurity>.*</useSecurity>|<useSecurity>false</useSecurity>|"\
    -e "s|<authorizationStrategy.*</authorizationStrategy>||"\
    -e "s|<securityRealm.*</securityRealm>||"\
  /var/lib/jenkins/config.xml)

echo "${unsecure_config_xml}" > /var/lib/jenkins/config.xml

sudo service jenkins restart
