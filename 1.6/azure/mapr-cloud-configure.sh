#!/usr/bin/env bash

MEP=$1
CLUSTER_NAME=$2
CLUSTER_ADMIN_PASSWORD=$3

STANZA_URL="https://raw.githubusercontent.com/mapr/mapr-cloud-templates/master/1.6/common/mapr_core.yml"
SERVICE_TEMPLATE="template-20-drill"
STATUS="SUCCESS"

M_HOME=/opt/mapr/installer
M_USER=mapr
# TODO: Need to get the core version in here
MAPR_CORE=5.2.1
H=$(hostname -f)
# TODO: SWF: I don't see REPLACE_THIS in properties.json anymore. Not needed?
#sed -i -e "s/REPLACE_THIS/$H/" $M_HOME/data/properties.json
service mapr-installer start
sleep 10
curl -k -I https://localhost:9443

echo "Installer state: $?" > /tmp/mapr_installer_state

input=$M_HOME/stanza_input.yml
touch $input
chown $M_USER:$M_USER $input

echo "config.ssh_id=centos " >> $input
# TODO: SWF: Need to handle using a keyfile if possible
echo "ssh_key_file= " >> $input
echo "config.mep_version=${MEP} " > $input
echo "config.cluster_name=${CLUSTER_NAME} " >> $input

CMD="cd $M_HOME; bin/mapr-installer-cli install -v -f -n -t $STANZA_URL -u $M_USER:${CLUSTER_ADMIN_PASSWORD}@localhost:9443 -o @$input"
echo $CMD > /tmp/cmd

sudo -u $M_USER bash -c "$CMD" || STATUS="FAILURE"

SERVICES=$(curl -s -k  "https://$M_USER:${CLUSTER_ADMIN_PASSWORD}@localhost:9443/api/services?name=mapr-webserver&version=$MAPR_CORE")



