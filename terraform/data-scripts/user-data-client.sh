#!/bin/bash

set -xe

exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
sudo bash /ops/shared/scripts/client.sh "${cloud_env}" '${retry_join}' "${nomad_binary}"

CLOUD_ENV="${cloud_env}"

sed -i "s/CONSUL_TOKEN/${nomad_consul_token_secret}/g" /etc/nomad.d/nomad.hcl
sed -i "s/NOMAD_ACL_ENABLED/${nomad_acl_enabled}/g" /etc/nomad.d/nomad.hcl

sed -i "s/CONSUL_ACL_ENABLED/${consul_acl_enabled}/g" /etc/consul.d/consul.hcl


case $CLOUD_ENV in
  azure)
    echo "CLOUD_ENV: azure"
    ;;
  *)
    echo "CLOUD_ENV: not set"
    ;;
esac

sudo systemctl restart consul
sudo systemctl restart nomad

echo "Finished client setup"