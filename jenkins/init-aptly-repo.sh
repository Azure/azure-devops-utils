#!/bin/bash

function print_usage() {
  cat <<EOF
Command
  $0 

Arguments
  --vm_fqdn|-vf         [Required]: FQDN for the Jenkins instance hosting the Aptly repository
  --repository_name|-rn           : Repository name for hosting debian packages, defaulted to 'hello-karyon-rxnetty'
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

# Set defaults
repository_name="hello-karyon-rxnetty"

while [[ $# > 0 ]]
do
  key="$1"
  shift
  case $key in
    --vm_fqdn|-vf)
      vm_fqdn="$1";;
    --repository_name|-rn)
      repository_name="$1";;
    --help|-help|-h)
      print_usage
      exit 13;;
    *)
      echo "ERROR: Unknown argument '$key' to script '$0'" 1>&2
      exit -1
  esac
  shift
done

throw_if_empty vm_fqdn $vm_fqdn
throw_if_empty repository_name $repository_name

# Install aptly
echo "deb http://repo.aptly.info/ squeeze main" | sudo tee -a "/etc/apt/sources.list" > /dev/null
sudo apt-key adv --keyserver keys.gnupg.net --recv-keys 9E3E53F19C7DE460
sudo DEBIAN_FRONTEND=noninteractive apt-get update --yes
sudo DEBIAN_FRONTEND=noninteractive apt-get install aptly --yes

# Create default aptly repository
sudo su -c "aptly repo create $repository_name" jenkins
sudo su -c "aptly publish repo -architectures=\"amd64\" -component=main -distribution=trusty -skip-signing=true $repository_name" jenkins

# Serve aptly on port 9999
aptly_nginx_config=$(cat <<EOF
server {
  listen 9999;
  root /var/lib/jenkins/.aptly/public;
  server_name {vm_fqdn};
  location / {
    autoindex on;
  }
}
EOF
)
aptly_nginx_config=${aptly_nginx_config//'{vm_fqdn}'/${vm_fqdn}}

echo "${aptly_nginx_config}" | sudo tee -a /etc/nginx/sites-enabled/default > /dev/null

#restart nginx
sudo service nginx restart