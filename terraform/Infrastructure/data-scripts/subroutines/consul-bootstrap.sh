consul_bootstrap () {
    nomad_consul_token_id=$1
    nomad_consul_token_secret=$2

    ACL_DIRECTORY="/ops/shared/acl"
    CONSUL_BOOTSTRAP_TOKEN="/tmp/consul_bootstrap"

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
                exit 0
            fi

        fi
        set -e

        echo "Consul: ACL bootstrap begin"
        echo "$OUTPUT" | grep -i secretid | awk '{print $2}' > $CONSUL_BOOTSTRAP_TOKEN
        if [ -s $CONSUL_BOOTSTRAP_TOKEN ]; then
            echo "Consul: bootstrapped"
            break
        fi
    done


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
        -accessor=${nomad_consul_token_id} \
        -secret=${nomad_consul_token_secret} \
        -description "Nomad server/client auto-join token" \
        -role-name nomad-auto-join -token-file=$CONSUL_BOOTSTRAP_TOKEN
        
    consul kv put \
        -token-file=$CONSUL_BOOTSTRAP_TOKEN \
        'consul/bootstrap_token' "$(cat $CONSUL_BOOTSTRAP_TOKEN)"


    echo "Consul: ACL bootstrap end"
}