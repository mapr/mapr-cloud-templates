#!/usr/bin/env bash

RESULT=""
MAPR="/opt/mapr"
MAPR_HOME="$MAPR/installer"
MAPR_DATA_DIR="$MAPR_HOME/data"
PROPERTIES_JSON="$MAPR_DATA_DIR/properties.json"
MAPR_SUDOERS_FILE="/etc/sudoers.d/mapr_user"

MAPR_PASSWORD="$1"

msg_err() {
    echo "ERROR: $1"
    exit 1
}

mapr_is_image_finalized() {
    echo "Checking Azure image finalization"
    local finalized="$MAPR_DATA_DIR/finalized"
    [ ! -f $finalized ] && msg_err "The Azure image created during the development process was not finalized"
    echo "The Azure image has been properly finalized"
}

mapr_get_properties_json() {
    local KEY=$2

    if [ ! -f "$1" ]; then
        echo "WARNING: $1 file not found"
        RESULT=""
        return
    fi

    grep -Po '"'$KEY'":.*?[^\\]",' $1 > /dev/null
    if [ $? -ne 0 ]; then
        echo "WARNING: Could not find $KEY in $1"
        RESULT=""
        return
    fi

    RESULT="$(sed -n 's/.*"'$KEY'": "\(.*\)",/\1/p' $1)"
}

mapr_owner_properties_json() {
    local output=$(ls -l $1)
    if [ -z "${output}" ]; then
        echo "WARNING: Could not ls $1"
        RESULT=""
        return
    fi

    RESULT="$(echo $output | awk 'NR==1 {print $3}')"
}

mapr_owner_group_properties_json() {
    local output=$(ls -l $1)
    if [ -z "${output}" ]; then
        echo "WARNING: Could not ls $1"
        RESULT=""
        return
    fi

    RESULT="$(echo $output | awk 'NR==1 {print $4}')"
}

compare_users() {
    if [ "$1" = "$2" ] ; then
        echo "Users match: '$1' = '$2'"
    else
        echo "WARNING: user '$1' does not match user '$2'"
    fi

    id -u $1
    if [ $? -eq 0 ]; then
        echo "User '$1' exists"
        RESULT="$1"
        return
    fi
    id -u $2
    if [ $? -eq 0 ]; then
        echo "User '$2' exists"
        RESULT="$2"
        return
    fi

    msg_err "Could not find User '$1' or '$2' is in the list of OS users"
}

compare_groups() {
    if [ "$1" = "$2" ] ; then
        echo "Groups  match: '$1' = '$2'"
    else
        echo "WARNING: group '$1' does not match group '$2'"
    fi

    getent group $1
    if [ $? -eq 0 ]; then
        echo "Group '$1' exists"
        RESULT="$1"
        return
    fi
    getent group $2
    if [ $? -eq 0 ]; then
        echo "Group '$2' exists"
        RESULT="$2"
        return
    fi

    msg_err "Could not find Group '$1' or '$2' is in the list of OS groups"
}

create_user_and_group() {
    groupadd -g 5000 $MAPR_GROUP
    [ $? -ne 0 ] && msg_err "Could not add group $MAPR_GROUP"
    echo "Group $MAPR_GROUP created"
    useradd -g 5000 -m -u 5000 $MAPR_USER
    [ $? -ne 0 ] && msg_err "Could not add user $MAPR_USER"
    echo "User $MAPR_USER created"
}

change_password() {
    echo "$1:$2" | chpasswd --crypt-method SHA512
    [ $? -ne 0 ] && msg_err "Could not change password"
    echo "Password changed"
}

sudoers_add() {
    cat > $MAPR_SUDOERS_FILE << EOM
$MAPR_USER	ALL=(ALL)	NOPASSWD:ALL
Defaults:$MAPR_USER		!requiretty
EOM
    chmod 0440 $MAPR_SUDOERS_FILE
}

passwordless_sudo() {
    local file=""

    if [ -f /etc/sudoers.d/waagent ]; then
        file=/etc/sudoers.d/waagent
    elif [ -f /etc/sudoers.d/90-cloud-init-users ]; then
        file=/etc/sudoers.d/90-cloud-init-users
    fi
    sed -i -e 's/ALL$/NOPASSWD: ALL/' $file ||
        msg_err "Could not set passwordless ssh for OS admin user"
}

[ -n "${HTTP_PROXY}" ] && echo export http_proxy=${HTTP_PROXY} >> $MAPR_HOME/conf/env
[ -n "${HTTPS_PROXY}" ] && echo export https_proxy=${HTTPS_PROXY} >> $MAPR_HOME/conf/env
[ -n "${NO_PROXY}" ] && echo export no_proxy=${NO_PROXY} >> $MAPR_HOME/conf/env
[ -f $MAPR_HOME/conf/env ] && cat $MAPR_HOME/conf/env >> /etc/environment && . $MAPR_HOME/conf/env

# Make sure the image has been finalized, otherwise fail the installation
mapr_is_image_finalized

mapr_get_properties_json $PROPERTIES_JSON cluster_admin_id

echo "MapR user from properties file is: '$RESULT'"
MAPR_USER_PROPERTIES=$RESULT

mapr_owner_properties_json $PROPERTIES_JSON
echo "MapR user from file owner is: '$RESULT'"
MAPR_PROPERTIES_OWNER=$RESULT

mapr_get_properties_json $PROPERTIES_JSON cluster_admin_group
echo "MapR group from properties file is: '$RESULT'"
MAPR_GROUP_PROPERTIES=$RESULT

mapr_owner_group_properties_json $PROPERTIES_JSON
echo "MapR group from file owner is: '$RESULT'"
MAPR_PROPERTIES_GROUP=$RESULT

if [ -z "${MAPR_USER_PROPERTIES}" ] && [ -z "${MAPR_GROUP_PROPERTIES}" ] &&
   [ -z "${MAPR_PROPERTIES_OWNER}" ] && [ -z "{$MAPR_PROPERITIES_GROUP}" ]; then
    echo "A MapR user was not found so this installation will proceed as an unprepped image install."
    IS_PREPPED="false"
    MAPR_USER="mapr"
    MAPR_GROUP="mapr"
    create_user_and_group
    sudoers_add
else
    echo "A MapR user was found so this installation will proceed as a prepped image install."
    IS_PREPPED="true"
    compare_users $MAPR_USER_PROPERTIES $MAPR_PROPERTIES_OWNER
    MAPR_USER=$RESULT
    compare_groups $MAPR_GROUP_PROPERTIES $MAPR_PROPERTIES_GROUP
    MAPR_GROUP=$RESULT
fi

echo "MapR user is: $MAPR_USER"
echo "MapR group is: $MAPR_GROUP"
change_password $MAPR_USER $MAPR_PASSWORD
passwordless_sudo
