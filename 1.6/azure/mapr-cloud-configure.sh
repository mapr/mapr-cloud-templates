#!/usr/bin/env bash

msg_err() {
    echo "ERROR: $1"
    exit 1
}

create_node_list() {
    local current_node=$1
    local last_node
    let last_node=current_node+$2-1
    local mapr_nodes="["

    while [ $current_node -le $last_node ]; do
        if [ $current_node -eq $last_node ]; then
            mapr_nodes="$mapr_nodes\"$3$current_node\"]"
        else
            mapr_nodes="$mapr_nodes\"$3$current_node\", "
        fi
        let current_node=$current_node+1
    done

    RESULT=${mapr_nodes}
}

add_nodes_yaml() {
    local current_node=$1
    local last_node
    let last_node=current_node+$2-1
    local mapr_nodes=""

    while [ $current_node -le $last_node ]; do
        echo "    - $3$current_node" >> $4
        let current_node=$current_node+1
    done

    RESULT="${mapr_nodes}"
}

wait_for_connection() {
    local retries=0
    while [ $retries -le 20 ]; do
        sleep 2
        curl --silent -k -I $1 && return
        let retries=$retries+1
        echo "Retry: $retries"
    done
    msg_err "Connection to $1 was not able to be established"
}

if [ -f /opt/mapr/conf/mapr-clusters.conf ]; then
    echo "MapR is already installed; Not running Stanza again."
    exit 0
fi

# TODO: This file should go away and logic should be put in mapr-setup
MEP=$1
CLUSTER_NAME=$2
MAPR_PASSWORD=$3
THREE_DOT_SUBNET_PRIVATE=$4
START_OCTET=$5
NODE_COUNT=$6
SERVICE_TEMPLATE=$7
RESOURCE_GROUP=$8
ADMIN_AUTH_TYPE=$9
MAPR_CORE=${10}
MAPR_USER=${11}
SUBSCRIPTION_ID=${12}
TENANT_ID=${13}

RESULT=""

echo "MEP: $MEP"
echo "CLUSTER_NAME: $CLUSTER_NAME"
echo "MAPR_PASSWORD: <hidden>"
echo "THREE_DOT_SUBNET_PRIVATE: $THREE_DOT_SUBNET_PRIVATE"
echo "START_OCTET: $START_OCTET"
echo "NODE_COUNT: $NODE_COUNT"
echo "SERVICE_TEMPLATE: $SERVICE_TEMPLATE"
echo "RESOURCE_GROUP: $RESOURCE_GROUP"
echo "ADMIN_AUTH_TYPE: $ADMIN_AUTH_TYPE"
echo "MAPR_CORE: $MAPR_CORE"
echo "MAPR_USER: $MAPR_USER"
echo "SUBSCRIPTION_ID: $SUBSCRIPTION_ID"
echo "TENANT_ID: $TENANT_ID"

STANZA_URL="https://raw.githubusercontent.com/mapr/mapr-cloud-templates/master/1.6/azure/mapr-core.yml"
STATUS="SUCCESS"

MAPR_HOME=/opt/mapr/installer
CLI="cd $MAPR_HOME; bin/mapr-installer-cli"

create_node_list $START_OCTET $NODE_COUNT $THREE_DOT_SUBNET_PRIVATE
NODE_LIST=$RESULT
echo "NODE_LIST: $NODE_LIST"

. $MAPR_HOME/build/installer/bin/activate

# TODO: SWF: I don't see REPLACE_THIS in properties.json anymore. Not needed?
#H=$(hostname -f) || msg_err "Could not run hostname"
#sed -i -e "s/REPLACE_THIS/$H/" MAPR_HOME/data/properties.json
service mapr-installer start || msg_err "Could not start mapr-installer service"
wait_for_connection https://localhost:9443 || msg_err "Could not run curl"

echo "Installer state: $?" > /tmp/mapr_installer_state

INPUT=$MAPR_HOME/stanza_input.yml
rm -f $INPUT
touch $INPUT
chown $MAPR_USER:$MAPR_USER $INPUT || msg_err "Could not change owner to $MAPR_USER"

if [ "$SERVICE_TEMPLATE" == "custom-configuration" ]; then
    create_node_list $START_OCTET $NODE_COUNT $THREE_DOT_SUBNET_PRIVATE
    NODE_LIST=$RESULT
    cat >> $INPUT << EOM
environment:
  mapr_core_version: $MAPR_CORE
config:
  ssh_id: $MAPR_USER
  cluster_name: $CLUSTER_NAME
  mep_version: $MEP
  provider:
    id: AZURE
    config:
      resource_group: $RESOURCE_GROUP
      admin_auth_type: $ADMIN_AUTH_TYPE
      subscription_id: $SUBSCRIPTION_ID
      tenant_id: $TENANT_ID
  hosts:
EOM
    add_nodes_yaml $START_OCTET $NODE_COUNT $THREE_DOT_SUBNET_PRIVATE $INPUT

    CMD="$CLI import --no_check_certificate --config -t $INPUT"
    echo "MapR custom configuration selected; Log in to MapR web UI to complete installation."
else
    echo "environment.mapr_core_version=$MAPR_CORE " >> $INPUT
    echo "config.ssh_id=$MAPR_USER " >> $INPUT
    echo "config.ssh_password=$MAPR_PASSWORD " >> $INPUT
    echo "config.mep_version=$MEP " >> $INPUT
    echo "config.cluster_name=$CLUSTER_NAME " >> $INPUT
    echo "config.hosts=$NODE_LIST " >> $INPUT
    echo "config.provider.config.resource_group=$RESOURCE_GROUP " >> $INPUT
    echo "config.provider.config.admin_auth_type=$ADMIN_AUTH_TYPE " >> $INPUT
    echo "config.provider.config.subscription_id=$SUBSCRIPTION_ID " >> $INPUT
    echo "config.provider.config.tenant_id=$TENANT_ID " >> $INPUT
    if [ "$SERVICE_TEMPLATE" != "none" ]; then
        echo "config.services={\"${SERVICE_TEMPLATE}\":{}} " >> $INPUT
    fi

    CMD="$CLI install -f -n -t $STANZA_URL -u $MAPR_USER:$MAPR_PASSWORD@localhost:9443 -o @$INPUT"
    echo "MapR $SERVICE_TEMPLATE selected; Installation starting..."
fi

echo $CMD > /tmp/cmd

sudo -u $MAPR_USER bash -c "$CMD"
RUN_RSLT=$?
rm -f $INPUT
if [ $RUN_RSLT -ne 0 ]; then
    msg_err "Could not run installation: $RUN_RSLT"
fi
