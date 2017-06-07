#!/usr/bin/env bash

admin_user=$1
admin_pw=$2
subnet=$3
listen_fqdn=$4

echo "OPENVPN USER: $admin_user"
echo "OPENVPN PASSWORD: <hidden>"
echo "OPENVPN SUBNET: $subnet"
echo "OPENVPN LISTEN FQDN: $listen_fqdn"

./install_openvpn_access_server.sh $admin_pw
last_exit=$?
if [ $last_exit -ne 0 ]; then
    >&2 echo "Error from install_openvpn_access_server: $last_exit"
    exit $last_exit
fi

./mapr-vpn-configure.sh $admin_user $admin_pw $subnet $listen_fqdn
last_exit=$?
if [ $last_exit -ne 0 ]; then
    >&2 echo "Error from mapr-vpn-configure: $last_exit"
    exit $last_exit
fi

echo "VPN setup sucessfully"
