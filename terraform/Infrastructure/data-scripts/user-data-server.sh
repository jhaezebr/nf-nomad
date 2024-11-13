#!/bin/bash
set -xe

# logging to /var/log/user-data.log on VM
exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# variables
SERVER_COUNT=${server_count}
RETRY_JOIN=${retry_join}
CONSUL_ACL_ENABLED=${consul_acl_enabled}
NOMAD_ACL_ENABLED=${nomad_acl_enabled}
NOMAD_CONSUL_TOKEN_SECRET=${nomad_consul_token_secret}
NOMAD_CONSUL_TOKEN_ID=${nomad_consul_token_id}

# Wait for network
sleep 15

DOCKER_BRIDGE_IP_ADDRESS=(`ifconfig docker0 2>/dev/null|awk '/inet addr:/ {print $2}'|sed 's/addr://'`)

# Get IP from metadata service
IP_ADDRESS=$(curl -s -H Metadata:true --noproxy "*" http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0?api-version=2021-12-13 | jq -r '.["privateIpAddress"]')


##################
#      CONSUL    #
##################
cat <<-EOF > /etc/consul.d/consul.hcl
  data_dir = "/opt/consul/data"
  bind_addr = "0.0.0.0"
  client_addr = "0.0.0.0"
  advertise_addr = "$IP_ADDRESS"
  bootstrap_expect = $SERVER_COUNT
  acl {
    enabled = $CONSUL_ACL_ENABLED
    default_policy = "deny"
    down_policy = "extend-cache"
  }
  log_level = "INFO"
  server = true
  ui = true
  retry_join = ["$RETRY_JOIN"]
  service {
      name = "consul"
  }
  connect {
    enabled = true
  }
  ports {
    grpc = 8502
    dns  = 8600
  }
EOF

cat <<-'EOF' > /etc/systemd/system/consul.service
  [Unit]
  Description=Consul Agent
  Requires=network-online.target
  After=network-online.target
  [Service]
  Restart=on-failure
  Environment=CONSUL_ALLOW_PRIVILEGED_PORTS=true
  ExecStart=/usr/local/bin/consul agent -config-dir="/etc/consul.d"
  ExecReload=/bin/kill -HUP $MAINPID
  KillSignal=SIGTERM
  User=root
  Group=root
  [Install]
  WantedBy=multi-user.target
EOF

sudo systemctl enable consul.service
sudo systemctl start consul.service
sleep 10
export CONSUL_HTTP_ADDR=$IP_ADDRESS:8500
export CONSUL_RPC_ADDR=$IP_ADDRESS:8400


##################
#      VAULT     #
##################
cat <<-EOF > /etc/vault.d/vault.hcl
  ui = true
  backend "consul" {
    path          = "vault/"
    address       = "$IP_ADDRESS:8500"
    cluster_addr  = "https://$IP_ADDRESS:8201"
    redirect_addr = "http://$IP_ADDRESS:8200"
  }
  listener "tcp" {
    address         = "0.0.0.0:8200"
    cluster_address = "$IP_ADDRESS:8201"
    tls_disable     = 1
  }
EOF

cat <<-'EOF' > /etc/systemd/system/vault.service
  [Unit]
  Description=Vault Agent
  Requires=network-online.target
  After=network-online.target
  Wants=consul.service
  After=consul.service
  [Service]
  Restart=on-failure
  Environment=GOMAXPROCS=nproc
  ExecStart=/usr/local/bin/vault server -config="/etc/vault.d/vault.hcl"
  ExecReload=/bin/kill -HUP $MAINPID
  KillSignal=SIGTERM
  User=root
  Group=root
  [Install]
  WantedBy=multi-user.target
EOF

sudo systemctl enable vault.service
sudo systemctl start vault.service



##################
#      NOMAD     #
##################
cat <<-EOF > /etc/nomad.d/nomad.hcl
data_dir  = "/opt/nomad/data"
bind_addr = "0.0.0.0"

# Enable the server
server {
  enabled          = true
  bootstrap_expect = $SERVER_COUNT
}

consul {
  address = "127.0.0.1:8500"
  token = "$NOMAD_CONSUL_TOKEN_SECRET"
}

acl {
  enabled = $NOMAD_ACL_ENABLED
}

vault {
  enabled          = false
  address          = "http://active.vault.service.consul:8200"
  task_token_ttl   = "1h"
  create_from_role = "nomad-cluster"
  token            = ""
}
EOF

cat <<-'EOF' > /etc/systemd/system/nomad.service
  [Unit]
  Description=Nomad
  Documentation=https://nomadproject.io/docs/
  Wants=network-online.target
  After=network-online.target
  StartLimitIntervalSec=10
  StartLimitBurst=3
  Wants=consul.service
  After=consul.service
  Wants=vault.service
  After=vault.service
  [Service]
  ExecReload=/bin/kill -HUP $MAINPID
  ExecStart=/usr/local/bin/nomad agent -config /etc/nomad.d
  KillMode=process
  KillSignal=SIGINT
  LimitNOFILE=infinity
  LimitNPROC=infinity
  Restart=on-failure
  RestartSec=2
  TasksMax=infinity
  [Install]
  WantedBy=multi-user.target
EOF

sudo systemctl enable nomad.service
sudo systemctl start nomad.service
sleep 10
export NOMAD_ADDR=http://$IP_ADDRESS:4646


###################
# CONSUL TEMPLATE #
###################

cat <<-EOF > /etc/consul-template.d/consul-template.hcl
  vault {
    address      = "http://active.vault.service.consul:8200"
    token        = ""
    grace        = "1s"
    unwrap_token = false
    renew_token  = true
  }
  syslog {
    enabled  = true
    facility = "LOCAL5"
  }
  acl = {
    enabled = true
    default_policy = "deny"
    enable_token_persistence = true
  }
EOF

cat <<-'EOF' > /etc/systemd/system/consul-template.service
  [Unit]
  Description=Consul Template Agent
  Requires=network-online.target
  After=network-online.target
  [Service]
  Restart=on-failure
  ExecStart=/usr/local/bin/consul-template -config="/etc/consul-template.d/consul-template.hcl"
  ExecReload=/bin/kill -HUP $MAINPID
  KillSignal=SIGTERM
  User=root
  Group=root
  [Install]
  WantedBy=multi-user.target
EOF


###########
#   ETC   #
###########
# Add hostname to /etc/hosts

echo "127.0.0.1 $(hostname)" | sudo tee --append /etc/hosts

# Add Docker bridge network IP to /etc/resolv.conf (at the top)

echo "nameserver $DOCKER_BRIDGE_IP_ADDRESS" | sudo tee /etc/resolv.conf.new
cat /etc/resolv.conf | sudo tee --append /etc/resolv.conf.new
sudo mv /etc/resolv.conf.new /etc/resolv.conf

export JAVA_HOME=$(readlink -f /usr/bin/javac | sed "s:/bin/javac::")

HOME_DIR=ubuntu
# Set env vars for tool CLIs
echo "export CONSUL_RPC_ADDR=$IP_ADDRESS:8400" | sudo tee --append /home/$HOME_DIR/.bashrc
echo "export CONSUL_HTTP_ADDR=$IP_ADDRESS:8500" | sudo tee --append /home/$HOME_DIR/.bashrc
echo "export VAULT_ADDR=http://$IP_ADDRESS:8200" | sudo tee --append /home/$HOME_DIR/.bashrc
echo "export NOMAD_ADDR=http://$IP_ADDRESS:4646" | sudo tee --append /home/$HOME_DIR/.bashrc
echo "export JAVA_HOME=$JAVA_HOME"  | sudo tee --append /home/$HOME_DIR/.bashrc


ACL_DIRECTORY="/ops/shared/acl"
CONSUL_BOOTSTRAP_TOKEN="/tmp/consul_bootstrap"

if [[ "$CONSUL_ACL_ENABLED" == "true" ]]; then
  #consul_bootstrap

  NEEDS_BOOTSTRAPPING="false"

  # Wait until leader has been elected and bootstrap consul ACLs
  for i in {1..9}; do
      # capture stdout and stderr
      set +e
      sleep 5
      OUTPUT=$(consul acl bootstrap 2>&1)
      if [ $? -ne 0 ]; then
          echo "Consul: acl bootstrap: $OUTPUT"
          if [[ "$OUTPUT" = *"No cluster leader"* ]]; then
              echo "Consul: no cluster leader"
              continue
          else
              echo "Consul: already bootstrapped"
              break
          fi
      fi
      set -e

      echo "Consul: ACL bootstrap begin"
      echo "$OUTPUT" | grep -i secretid | awk '{print $2}' > $CONSUL_BOOTSTRAP_TOKEN
      if [ -s $CONSUL_BOOTSTRAP_TOKEN ]; then
          echo "Consul: bootstrapped"
          NEEDS_BOOTSTRAPPING="true"
          break
      fi
  done

  if [[ "$NEEDS_BOOTSTRAPPING" == "true" ]]; then

    consul acl policy create \
        -name 'nomad-auto-join' \
        -rules="@$ACL_DIRECTORY/consul-acl-nomad-auto-join.hcl" \
        -token-file=$CONSUL_BOOTSTRAP_TOKEN

    consul acl role create \
        -name "nomad-auto-join" \
        -description "Role with policies necessary for nomad servers and clients to auto-join via Consul." \
        -policy-name "nomad-auto-join" \
        -token-file=$CONSUL_BOOTSTRAP_TOKEN

    consul acl token create \
        -accessor=$NOMAD_CONSUL_TOKEN_ID \
        -secret=$NOMAD_CONSUL_TOKEN_SECRET \
        -description "Nomad server/client auto-join token" \
        -role-name nomad-auto-join -token-file=$CONSUL_BOOTSTRAP_TOKEN
        
    consul kv put \
        -token-file=$CONSUL_BOOTSTRAP_TOKEN \
        'consul/bootstrap_token' "$(cat $CONSUL_BOOTSTRAP_TOKEN)"

  fi
  echo "Consul: ACL bootstrap end"
fi


if [[ "$NOMAD_ACL_ENABLED" == "true" ]]; then
  #nomad_bootstrap

  NOMAD_BOOTSTRAP_TOKEN="/tmp/nomad_bootstrap"
  NOMAD_USER_TOKEN="/tmp/nomad_user_token"
  NOMAD_NEXTFLOW_TOKEN="/tmp/nomad_nextflow_token"
  NEEDS_BOOTSTRAPPING="false"

  # Wait for nomad servers to come up and bootstrap nomad ACL
  for i in {1..12}; do
      # capture stdout and stderr
      set +e
      sleep 5
      OUTPUT=$(nomad acl bootstrap 2>&1)
      if [ $? -ne 0 ]; then
          echo "Nomad: acl bootstrap: $OUTPUT"
          if [[ "$OUTPUT" = *"No cluster leader"* ]]; then
              echo "Nomad: no cluster leader"
              continue
          else
              echo "Nomad: already bootstrapped"
              break
          fi
      fi
      set -e

      echo "Nomad: ACL bootstrap begin"
      echo "$OUTPUT" | grep -i secret | awk -F '=' '{print $2}' | xargs | awk 'NF' > $NOMAD_BOOTSTRAP_TOKEN
      if [ -s $NOMAD_BOOTSTRAP_TOKEN ]; then
          echo "Nomad: bootstrapped"
          NEEDS_BOOTSTRAPPING="true"
          break
      fi
  done

  if [[ "$NEEDS_BOOTSTRAPPING" == "true" ]]; then
    # USER TOKEN
    nomad acl policy apply \
        -token "$(cat $NOMAD_BOOTSTRAP_TOKEN)" \
        -description "Policy to allow reading of agents and nodes and listing and submitting jobs in all namespaces." \
        node-read-job-submit $ACL_DIRECTORY/nomad-acl-user.hcl

    nomad acl token create \
        -token "$(cat $NOMAD_BOOTSTRAP_TOKEN)" \
        -name "read-token" \
        -policy node-read-job-submit \
        | grep -i secret | awk -F "=" '{print $2}' | xargs > $NOMAD_USER_TOKEN


    # NEXTFLOW TOKEN
    nomad acl policy apply \
        -token "$(cat $NOMAD_BOOTSTRAP_TOKEN)" \
        -description "Policy to allow submitting jobs into the nextflow namespace." \
        nextflow-submit $ACL_DIRECTORY/nomad-acl-nextflow.hcl

    nomad acl token create \
        -token "$(cat $NOMAD_BOOTSTRAP_TOKEN)" \
        -name "read-token" \
        -policy nextflow-submit \
        | grep -i secret | awk -F "=" '{print $2}' | xargs > $NOMAD_NEXTFLOW_TOKEN


    # Write user token to kv
    if [[ "$CONSUL_ACL_ENABLED" == "true" ]] && [ -f "$CONSUL_BOOTSTRAP_TOKEN" ]; then
        consul kv put -token-file=$CONSUL_BOOTSTRAP_TOKEN 'nomad/user_token' "$(cat $NOMAD_USER_TOKEN)"
        consul kv put -token-file=$CONSUL_BOOTSTRAP_TOKEN 'nomad/nextflow_token' "$(cat $NOMAD_NEXTFLOW_TOKEN)"
        consul kv put -token-file=$CONSUL_BOOTSTRAP_TOKEN 'nomad/bootstrap_token' "$(cat $NOMAD_BOOTSTRAP_TOKEN)"
    else
        consul kv put 'nomad/user_token' "$(cat $NOMAD_USER_TOKEN)"
        consul kv put 'nomad/nextflow_token' "$(cat $NOMAD_NEXTFLOW_TOKEN)"
        consul kv put 'nomad/bootstrap_token' "$(cat $NOMAD_BOOTSTRAP_TOKEN)"
    fi
  fi

  echo "Nomad: ACL bootstrap end"

fi

echo "Finished server setup"