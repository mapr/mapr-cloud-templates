#!/usr/bin/env bash

RESULT=""
MAPR="/opt/mapr"
MAPR_HOME="$MAPR/installer"
PROPERTIES_JSON="$MAPR_HOME/data/properties.json"

MAPR_PASSWORD="$1"

mapr_user_properties_json() {
    local KEY=cluster_admin_id

    if [ ! -f "$1" ]; then
        echo "ERROR: $1 file not found"
        RESULT=""
        return
    fi

    grep -Po '"cluster_admin_id":.*?[^\\]",' $1 > /dev/null
    if [ $? -ne 0 ]; then
        echo "ERROR: Could not find cluster_admin_id in $1"
        RESULT=""
        return
    fi

    RESULT="$(sed -n 's/.*"cluster_admin_id": "\(.*\)",/\1/p' $1)"
}

mapr_owner_properties_json() {
    local output=$(ls -l $1)
    if [ $? -ne 0 ]; then
        echo "ERROR: Could not ls $1: $output"
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
        echo "ERROR: user '$1' does not match user '$2'"
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

    echo "FATAL: Could not find User '$1' or '$2' is in the list of OS users"
    exit 1
}

change_password() {
    echo "$1:$2" | chpasswd
    if [ $? -ne 0 ]; then
        echo "FATAL: Could not change password"
        exit 1
    fi
    echo "Password changed"
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
