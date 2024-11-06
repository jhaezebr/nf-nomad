#!/bin/bash
source /ops/shared/data-scripts/subroutines/consul-bootstrap.sh
source /ops/shared/data-scripts/subroutines/nomad-bootstrap.sh

set -xe

exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

cat <<-'EOF' > /tmp/server.env
  CLOUD=${cloud_env}
  SERVER_COUNT=${server_count}
  RETRY_JOIN=${retry_join}
  NOMAD_BINARY=${nomad_binary}
  CONSUL_ACL_ENABLED=${consul_acl_enabled}
  NOMAD_ACL_ENABLED=${nomad_acl_enabled}
EOF


sudo bash /ops/shared/scripts/server.sh /tmp/server.env


sed -i "s/CONSUL_TOKEN/${nomad_consul_token_secret}/g" /etc/nomad.d/nomad.hcl

sudo systemctl restart consul
sudo systemctl restart nomad

echo "Finished server setup"

if [[ '${consul_acl_enabled}' == "true" ]]; then
  consul_bootstrap
fi

if [[ '${nomad_acl_enabled}' == "true" ]]; then
  nomad_bootstrap
fi