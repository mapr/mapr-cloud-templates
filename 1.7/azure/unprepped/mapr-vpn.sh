#!/usr/bin/env bash

admin_user=$1
admin_pw=$2
subnet=$3
listen_fqdn=$4
address_space=$5

echo "OPENVPN USER: $admin_user"
echo "OPENVPN PASSWORD: <hidden>"
echo "OPENVPN SUBNET: $subnet"
echo "OPENVPN LISTEN FQDN: $listen_fqdn"
echo "OPENVPN ADDRESS SPACE: $address_space"

# if OpenVPN is already installed don't do it again
service --status-all 2>&1 | grep openvpnas > /dev/null
if [ $? -eq 0 ]; then
    echo "OpenVPN is already installed so it will not be reinstalled"
    exit 0
fi
echo "OpenVPN is not installed; installing ..."

./install_openvpn_access_server.sh $admin_pw
last_exit=$?
if [ $last_exit -ne 0 ]; then
    >&2 echo "OpenVPN Error from install_openvpn_access_server: $last_exit"
    exit $last_exit
fi
echo "OpenVPN successfully installed"

./mapr-vpn-configure.sh $admin_user $admin_pw $subnet $listen_fqdn $address_space
last_exit=$?
if [ $last_exit -ne 0 ]; then
    >&2 echo "OpenVPN Error from mapr-vpn-configure: $last_exit"
    exit $last_exit
fi
echo "OpenVPN successfully configured"
echo "OpenVPN setup complete"
