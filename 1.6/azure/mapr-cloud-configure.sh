#!/usr/bin/env bash

INSTALL_PACKAGES="mapr-installer-definitions mapr-installer"
RESULT=""
INTERNAL_ONLY="mapr-core-internal"
INTERNAL="${INTERNAL_ONLY}-"
MAPR="/opt/mapr"
MAPR_HOME="$MAPR/installer"
PROPERTIES_JSON="$MAPR_HOME/data/properties.json"
STANZA_URL="https://raw.githubusercontent.com/mapr/mapr-cloud-templates/master/1.6/azure/mapr-core.yml"
STATUS="SUCCESS"
CLI="cd $MAPR_HOME; bin/mapr-installer-cli"

msg_err() {
    echo "ERROR: $1"
    exit 1
}

find_installed_core_version() {
    if [ -z $1 ]; then
        RESULT=""
        return
    fi

    local ver=$1
    local mapr_major_version=${ver%%.*}
    ver=${ver#*.}

    local mapr_minor_version=${ver%%.*}
    ver=${ver#*.}

    local mapr_triple_version=${ver%%.*}
    local mapr_version="${mapr_major_version}.${mapr_minor_version}.${mapr_triple_version}"

    RESULT="$mapr_version"
}

compare_versions() {
    if [ "$1" = "$2" ] ; then
        echo "Versions match: $1 = $2"
        RESULT="$1"
    elif [ "$1" \> "$2" ] ; then
        echo "ERROR version '$1' is greater than version '$2'"
        RESULT="$1"
    else
        echo "ERROR version '$1' is less than version '$2'"
        RESULT="$2"
    fi
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
    RESULT="$mapr_nodes"
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
    RESULT="$mapr_nodes"
}

wait_for_connection() {
    local retries=0
    while [ $retries -le 20 ]; do
        sleep 2
        curl --silent -k -I $1 && return
        let retries=$retries+1
        echo "Waiting for successful connection: $retries"
    done
    msg_err "Connection to $1 was not able to be established"
}

check_os() {
    if [ -f /etc/redhat-release ]; then
        RESULT=redhat
    elif grep -q -s SUSE /etc/os-release ; then
        RESULT=suse
    elif grep -q -s DISTRIB_ID=Ubuntu /etc/lsb-release; then
        RESULT=ubuntu
    else
        msg_err "Unsupported operating system"
    fi
}

build_version() {
    RESULT=$(cat $MAPR/MapRBuildVersion)
    if [ $? -ne 0 ]; then
        echo "ERROR: Could not find $MAPR/MapRBuildVersion"
        RESULT=""
    fi
}

package_version_redhat() {
    echo "Checking MapR packager version RedHat"
    RESULT=$(rpm -qa | grep $INTERNAL)
    if [ $? -ne 0 ]; then
        echo "WARNING: Could not find rpm package starting with $INTERNAL"
        RESULT=""
    else
        RESULT="${RESULT/$INTERNAL/}"
    fi
    echo "$RESULT"

}

package_version_ubuntu() {
    echo "Checking MapR packager version Ubuntu"
    RESULT=$(dpkg-query --show --showformat='${Version}' $INTERNAL_ONLY)
    if [ $? -ne 0 ]; then
        echo "WARNING: Could not find deb package starting with $INTERNAL"
        RESULT=""
    else
        RESULT="${RESULT/$INTERNAL/}"
    fi
}

package_version_suse() {
    echo "Checking MapR packager version Suse"
    RESULT=$(rpm -qa | grep $INTERNAL)
    if [ $? -ne 0 ]; then
        echo "WARNING: Could not find rpm starting with $INTERNAL"
        RESULT=""
    else
        RESULT="${RESULT/$INTERNAL/}"
    fi
}

if [ -f /opt/mapr/conf/mapr-clusters.conf ]; then
    echo "MapR is already installed; Not running Stanza again."
    exit 0
fi

MEP=$1
CLUSTER_NAME=$2
MAPR_PASSWORD=$3
THREE_DOT_SUBNET_PRIVATE=$4
START_OCTET=$5
NODE_COUNT=$6
SERVICE_TEMPLATE=$7
RESOURCE_GROUP=$8
ADMIN_AUTH_TYPE=$9
SUBSCRIPTION_ID=${10}
TENANT_ID=${11}
LICENSE_TYPE=${12}

# Auto detect the MAPR_USER and change the MAPR_PASSWORD
. ./mapr-init.sh $MAPR_PASSWORD

check_os
OS=$RESULT

build_version
BUILD_FILE_VERSION=$RESULT
package_version_$OS
PACKAGE_VERSION=$RESULT

find_installed_core_version $BUILD_FILE_VERSION
echo "Build file version: '$RESULT'"
BUILD_FILE_VERSION=$RESULT

find_installed_core_version $PACKAGE_VERSION
echo "Package version: '$RESULT'"
PACKAGE_VERSION=$RESULT

compare_versions $BUILD_FILE_VERSION $PACKAGE_VERSION
echo "Final MapR Core version: '$RESULT'"
MAPR_CORE=$RESULT

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
echo "LICENSE_TYPE: $LICENSE_TYPE"

create_node_list $START_OCTET $NODE_COUNT $THREE_DOT_SUBNET_PRIVATE
NODE_LIST=$RESULT
echo "NODE_LIST: $NODE_LIST"

. $MAPR_HOME/build/installer/bin/activate

/opt/mapr/installer/bin/mapr-setup.sh -y upgrade
service mapr-installer start || echo "Could not start mapr-installer service"
wait_for_connection https://localhost:9443 || msg_err "Could not run curl"

INPUT=$MAPR_HOME/conf/stanza_input.yml
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

    CMD="$CLI import --no_check_certificate --config -t $INPUT -u $MAPR_USER:$MAPR_PASSWORD@localhost:9443"
    echo "MapR custom configuration selected; Log in to MapR web UI to complete installation."
else
    echo "environment.mapr_core_version=$MAPR_CORE " >> $INPUT
    echo "config.ssh_id=$MAPR_USER " >> $INPUT
    echo "config.mep_version=$MEP " >> $INPUT
    echo "config.cluster_name=$CLUSTER_NAME " >> $INPUT
    echo "config.cluster_admin_id=$MAPR_USER " >> $INPUT
    echo "config.hosts=$NODE_LIST " >> $INPUT
    echo "config.license_type=$LICENSE_TYPE " >> $INPUT
    echo "config.provider.config.resource_group=$RESOURCE_GROUP " >> $INPUT
    echo "config.provider.config.admin_auth_type=$ADMIN_AUTH_TYPE " >> $INPUT
    echo "config.provider.config.subscription_id=$SUBSCRIPTION_ID " >> $INPUT
    echo "config.provider.config.tenant_id=$TENANT_ID " >> $INPUT
    if [ "$SERVICE_TEMPLATE" != "none" ]; then
        echo "config.services={\"${SERVICE_TEMPLATE}\":{}} " >> $INPUT
    fi

    CMD="$CLI install -f -n -t $STANZA_URL -u $MAPR_USER:$MAPR_PASSWORD@localhost:9443 -o @$INPUT"
    CMD="$CMD -o config.ssh_password=$MAPR_PASSWORD"
    CMD="$CMD -o config.cluster_admin_password=$MAPR_PASSWORD"
    CMD="$CMD -o config.db_admin_password=$MAPR_PASSWORD"
    echo "MapR $SERVICE_TEMPLATE selected; Installation starting..."
fi

chmod 0440 $INPUT
sudo -u $MAPR_USER bash -c "$CMD"
RUN_RSLT=$?
if [ $RUN_RSLT -ne 0 ]; then
    msg_err "Could not run installation: $RUN_RSLT"
fi
