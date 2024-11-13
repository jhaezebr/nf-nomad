#!/bin/bash

set -xe

# setup logging
exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# variables
RETRY_JOIN=${retry_join}
NOMAD_BINARY=${nomad_binary}
CONSUL_ACL_ENABLED=${consul_acl_enabled}
NOMAD_ACL_ENABLED=${nomad_acl_enabled}
NOMAD_CONSUL_TOKEN_SECRET=${nomad_consul_token_secret}

# Wait for network
sleep 15

DOCKER_BRIDGE_IP_ADDRESS=(`ifconfig docker0 2>/dev/null|awk '/inet addr:/ {print $2}'|sed 's/addr://'`)

# Get IP from metadata service
IP_ADDRESS=$(curl -s -H Metadata:true --noproxy "*" http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0?api-version=2021-12-13 | jq -r '.["privateIpAddress"]')


##################
#      CONSUL    #
##################
cat <<-EOF > /etc/consul.d/consul.hcl
  ui = true
  log_level = "INFO"
  data_dir = "/opt/consul/data"
  bind_addr = "0.0.0.0"
  client_addr = "0.0.0.0"
  advertise_addr = "$IP_ADDRESS"
  retry_join = ["$RETRY_JOIN"]
  acl {
    enabled = $CONSUL_ACL_ENABLED
    default_policy = "deny"
    down_policy = "extend-cache"
  }
  connect {
    enabled = true
  }
  ports {
    grpc = 8502
    dns = 8600
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


##################
#      NOMAD     #
##################
cat <<-EOF > /etc/nomad.d/nomad.hcl
  data_dir  = "/opt/nomad/data"
  bind_addr = "0.0.0.0"
  datacenter = "dc1"
  client {
    enabled = true
    options {
      "driver.raw_exec.enable"    = "1"
      "docker.privileged.enabled" = "true"
    }
  }
  acl {
    enabled = $NOMAD_ACL_ENABLED
  }
  consul {
    address = "127.0.0.1:8500"
    token = "$NOMAD_CONSUL_TOKEN_SECRET"
  }
  vault {
    enabled = true
    address = "http://active.vault.service.consul:8200"
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

# Set env vars for tool CLIs
HOME_DIR=ubuntu
echo "export VAULT_ADDR=http://$IP_ADDRESS:8200" | sudo tee --append /home/$HOME_DIR/.bashrc
echo "export NOMAD_ADDR=http://$IP_ADDRESS:4646" | sudo tee --append /home/$HOME_DIR/.bashrc
echo "export JAVA_HOME=$JAVA_HOME"  | sudo tee --append /home/$HOME_DIR/.bashrc


echo "Finished client setup"