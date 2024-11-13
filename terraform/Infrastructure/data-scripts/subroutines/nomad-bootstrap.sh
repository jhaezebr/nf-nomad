nomad_bootstrap () {
    ACL_DIRECTORY="/ops/shared/acl"

    NOMAD_BOOTSTRAP_TOKEN="/tmp/nomad_bootstrap"
    NOMAD_USER_TOKEN="/tmp/nomad_user_token"
    NOMAD_NEXTFLOW_TOKEN="/tmp/nomad_nextflow_token"

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
                exit 0
            fi
        fi
        set -e

        echo "Nomad: ACL bootstrap begin"
        echo "$OUTPUT" | grep -i secret | awk -F '=' '{print $2}' | xargs | awk 'NF' > $NOMAD_BOOTSTRAP_TOKEN
        if [ -s $NOMAD_BOOTSTRAP_TOKEN ]; then
            echo "Nomad: bootstrapped"
            break
        fi
    done

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
    if [ ! -z "$CONSUL_BOOTSTRAP_TOKEN" ] && [ -f "$CONSUL_BOOTSTRAP_TOKEN" ]; then
        consul kv put -token-file=$CONSUL_BOOTSTRAP_TOKEN 'nomad/user_token' "$(cat $NOMAD_USER_TOKEN)"
        consul kv put -token-file=$CONSUL_BOOTSTRAP_TOKEN 'nomad/nextflow_token' "$(cat $NOMAD_NEXTFLOW_TOKEN)"
        consul kv put -token-file=$CONSUL_BOOTSTRAP_TOKEN 'nomad/bootstrap_token' "$(cat $NOMAD_BOOTSTRAP_TOKEN)"
    else
        consul kv put 'nomad/user_token' "$(cat $NOMAD_USER_TOKEN)"
        consul kv put 'nomad/nextflow_token' "$(cat $NOMAD_NEXTFLOW_TOKEN)"
        consul kv put 'nomad/bootstrap_token' "$(cat $NOMAD_BOOTSTRAP_TOKEN)"
    fi

    echo "Nomad: ACL bootstrap end"
}