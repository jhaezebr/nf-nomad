#!/bin/bash
source /ops/shared/data-scripts/subroutines/consul-bootstrap.sh
source /ops/shared/data-scripts/subroutines/nomad-bootstrap.sh

set -xe

exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
sudo bash /ops/shared/scripts/server.sh "${cloud_env}" "${server_count}" '${retry_join}' "${nomad_binary}"


sed -i "s/CONSUL_TOKEN/${nomad_consul_token_secret}/g" /etc/nomad.d/nomad.hcl

sudo systemctl restart nomad

echo "Finished server setup"


# consul_bootstrap
nomad_bootstrap