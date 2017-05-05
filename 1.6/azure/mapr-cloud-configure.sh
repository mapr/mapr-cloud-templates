#!/usr/bin/env bash

# TODO: File should go away and logic should be put in mapr-setup
MEP=$1
CLUSTER_NAME=$2
MAPR_PASSWORD=$3
THREE_DOT_SUBNET_PRIVATE=$4
START_OCTET=$5
NODE_COUNT=$6
SERVICE_TEMPLATE=$7

RESULT=""

echo "MEP: $MEP"
echo "CLUSTER_NAME: $CLUSTER_NAME"
echo "MAPR_PASSWORD: <hidden>"
echo "THREE_DOT_SUBNET_PRIVATE: $THREE_DOT_SUBNET_PRIVATE"
echo "START_OCTET: $START_OCTET"
echo "NODE_COUNT: $NODE_COUNT"
echo "SERVICE_TEMPLATE: $SERVICE_TEMPLATE"

STANZA_URL="https://raw.githubusercontent.com/mapr/mapr-cloud-templates/master/1.6/azure/mapr-core.yml"
SERVICE_TEMPLATE="template-20-drill"
STATUS="SUCCESS"

M_HOME=/opt/mapr/installer
MAPR_USER=mapr

# TODO: Need to get the core version in here
MAPR_CORE=5.2.1
H=$(hostname -f)

function create_node_list() {
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

    RESULT=$mapr_nodes
}

create_node_list $START_OCTET $NODE_COUNT $THREE_DOT_SUBNET_PRIVATE
NODE_LIST=$RESULT
echo "NODE_LIST: $NODE_LIST"

. $M_HOME/build/installer/bin/activate

# TODO: SWF: I don't see REPLACE_THIS in properties.json anymore. Not needed?
#sed -i -e "s/REPLACE_THIS/$H/" $M_HOME/data/properties.json
service mapr-installer start
sleep 10
curl -k -I https://localhost:9443

echo "Installer state: $?" > /tmp/mapr_installer_state

input=$M_HOME/stanza_input.yml
rm -f $input
touch $input
chown $M_USER:$M_USER $input

# TODO: get SSH user name
echo "config.ssh_id=centos " >> $input
# TODO: SWF: Need to handle using a keyfile if possible
echo "config.ssh_key_file= " >> $input
# TODO: SWF: Pass in an admin user name and create a public/private key to access
echo "config.ssh_id=$MAPR_USER " >> $input
echo "config.ssh_password=$MAPR_PASSWORD " >> $input
echo "config.mep_version=$MEP " >> $input
echo "config.cluster_name=$CLUSTER_NAME " >> $input
# TODO: SWF need to find the IPs based on subnet and installer's private IP
echo "config.hosts=$NODE_LIST " >> $input
echo "config.services={\"${SERVICE_TEMPLATE}\":{}} " >> $input

CMD="cd $M_HOME; bin/mapr-installer-cli install -f -n -t $STANZA_URL -u $MAPR_USER:$MAPR_PASSWORD@localhost:9443 -o @$input"
echo $CMD > /tmp/cmd

sudo -u $M_USER bash -c "$CMD" || STATUS="FAILURE"
