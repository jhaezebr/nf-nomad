#!/bin/bash

set -xe

exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

cat <<-'EOF' > /tmp/client.env
  CLOUD=${cloud_env}
  RETRY_JOIN=${retry_join}
  NOMAD_BINARY=${nomad_binary}
  CONSUL_ACL_ENABLED=${consul_acl_enabled}
  NOMAD_ACL_ENABLED=${nomad_acl_enabled}
EOF

sudo bash /ops/shared/scripts/client.sh /tmp/client.env

CLOUD_ENV="${cloud_env}"

sed -i "s/CONSUL_TOKEN/${nomad_consul_token_secret}/g" /etc/nomad.d/nomad.hcl


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