#!/usr/bin/env bash

# TODO: File should go away and logic should be put in mapr-setup
MEP=$1
CLUSTER_NAME=$2
CLUSTER_ADMIN_PASSWORD=$3

STANZA_URL="https://raw.githubusercontent.com/mapr/mapr-cloud-templates/master/1.6/azure/mapr-core.yml"
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
rm -f $input
touch $input
chown $M_USER:$M_USER $input

# TODO: get SSH user name
echo "config.ssh_id=centos " >> $input
# TODO: SWF: Need to handle using a keyfile if possible
echo "config.ssh_key_file= " >> $input
# TODO: SWF: Pass in an admin user name and create a public/private key to access
echo "config.ssh_id=centos " >> $input
echo "config.ssh_password=UsingCloud4MapR " >> $input
echo "config.mep_version=${MEP} " >> $input
echo "config.cluster_name=${CLUSTER_NAME} " >> $input
# TODO: SWF need to find the IPs based on subnet and installer's private IP
echo "config.hosts=[\"28.1.8.4\", \"28.1.8.5\"] " >> $input

CMD="cd $M_HOME; bin/mapr-installer-cli install -v -f -n -t $STANZA_URL -u $M_USER:${CLUSTER_ADMIN_PASSWORD}@localhost:9443 -o @$input"
echo $CMD > /tmp/cmd

sudo -u $M_USER bash -c "$CMD" || STATUS="FAILURE"

SERVICES=$(curl -s -k  "https://$M_USER:${CLUSTER_ADMIN_PASSWORD}@localhost:9443/api/services?name=mapr-webserver&version=$MAPR_CORE")



