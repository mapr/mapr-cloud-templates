#!/usr/bin/env bash

RESULT=""
MAPR="/opt/mapr"
MAPR_HOME="$MAPR/installer"
PROPERTIES_JSON="$MAPR_HOME/data/properties.json"

MAPR_PASSWORD="$1"

msg_err() {
    echo "ERROR: $1"
    exit 1
}

mapr_user_properties_json() {
    local KEY=cluster_admin_id

    if [ ! -f "$1" ]; then
        echo "WARNING: $1 file not found"
        RESULT=""
        return
    fi

    grep -Po '"cluster_admin_id":.*?[^\\]",' $1 > /dev/null
    if [ $? -ne 0 ]; then
        echo "WARNING: Could not find cluster_admin_id in $1"
        RESULT=""
        return
    fi

    RESULT="$(sed -n 's/.*"cluster_admin_id": "\(.*\)",/\1/p' $1)"
}

mapr_owner_properties_json() {
    local output=$(ls -l $1)
    if [ $? -ne 0 ]; then
        echo "WARNING: Could not ls $1: $output"
        RESULT=""
        return
    fi

    output=$(echo $output | awk 'NR==1 {print $3}')
    RESULT="$output"
}

compare_users() {
    if [ "$1" = "$2" ] ; then
        echo "Users match: '$1' = '$2'"
    else
        echo "WARNING: user '$1' does not match user '$2'"
    fi

    id -u $1 > /dev/null
    if [ $? -eq 0 ]; then
        echo "User '$1' exists"
        RESULT="$1"
        return
    fi
    id -u $2 > /dev/null
    if [ $? -eq 0 ]; then
        echo "User '$2' exists"
        RESULT="$2"
        return
    fi

    msg_err "Could not find User '$1' or '$2' is in the list of OS users"
}

change_password() {
    echo "$1:$2" | chpasswd
    [ $? -ne 0 ] && msg_err "Could not change password"
    echo "Password changed"
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

mapr_user_properties_json $PROPERTIES_JSON
echo "MapR user from properties file is: '$RESULT'"
MAPR_USER_PROPERTIES=$RESULT

mapr_owner_properties_json $PROPERTIES_JSON
echo "MapR user from file owner is: '$RESULT'"
MAPR_PROPERTIES_OWNER=$RESULT

compare_users $MAPR_USER_PROPERTIES $MAPR_PROPERTIES_OWNER
echo "MapR user is: $RESULT"
MAPR_USER=$RESULT

change_password $MAPR_USER $MAPR_PASSWORD
passwordless_sudo

#IF THE VPC REQUIRES PROXY SETTINGS ON THE HOST,
#UNCOMMENT AND UPDATE WITH THE PROXY SETTINGS
#export http_proxy=INSERT CORRECT VALUE
#export https_proxy=INSERT CORRECT VALUE
#export no_proxy=169.254.169.254
#echo http_proxy=$http_proxy >> /etc/environment
#echo https_proxy=$https_proxy >> /etc/environment
#echo no_proxy=$no_proxy >> /etc/environment
