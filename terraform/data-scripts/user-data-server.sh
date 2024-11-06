#!/bin/bash
source /ops/shared/data-scripts/subroutines/consul-bootstrap.sh
source /ops/shared/data-scripts/subroutines/nomad-bootstrap.sh

set -xe

exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
sudo bash /ops/shared/scripts/server.sh "${cloud_env}" "${server_count}" '${retry_join}' "${nomad_binary}"


sed -i "s/CONSUL_TOKEN/${nomad_consul_token_secret}/g" /etc/nomad.d/nomad.hcl
sed -i "s/NOMAD_ACL_ENABLED/${nomad_acl_enabled}/g" /etc/nomad.d/nomad.hcl

sed -i "s/CONSUL_ACL_ENABLED/${consul_acl_enabled}/g" /etc/consul.d/consul.hcl

sudo systemctl restart consul
sudo systemctl restart nomad

echo "Finished server setup"

if [[ '${consul_acl_enabled}' == "true" ]]; then
  consul_bootstrap
fi

if [[ '${nomad_acl_enabled}' == "true" ]]; then
  nomad_bootstrap
fi