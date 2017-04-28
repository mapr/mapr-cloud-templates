#!/usr/bin/env bash

MEP=$1
CLUSTER_NAME=$2
CLUSTER_ADMIN_PASSWORD=$3
CLOUD_PROVIDER=$4

STANZA_URL=
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

echo "config.mep_version=${MEP} " > $input
echo "config.cluster_name=${CLUSTER_NAME} " >> $input
echo "config.clusterAdminPassword=${CLUSTER_ADMIN_PASSWORD} " >> $input
echo "config.ssh_id=centos " >> $input
echo "config.provider.config.id=${CLOUD_PROVIDER} " >> $input




