#!/usr/bin/env bash

admin_user=$1
admin_pw=$2
subnet=$3
listen_ip=$4

echo "OPENVPN USER: $1"
echo "OPENVPN SUBNET: $3"
echo "OPENVPN LISTENIP: $4"

/usr/local/openvpn_as/scripts/sacli -k vpn.client.tls_version_min -v 1.2 ConfigPut
/usr/local/openvpn_as/scripts/sacli -k vpn.client.tls_version_min_strict -v true ConfigPut
/usr/local/openvpn_as/scripts/sacli -k vpn.server.tls_version_min -v 1.2 ConfigPut
/usr/local/openvpn_as/scripts/sacli -k vpn.daemon.0.client.network -v $subnet ConfigPut
/usr/local/openvpn_as/scripts/sacli -k vpn.daemon.0.client.netmask_bits -v 24 ConfigPut
/usr/local/openvpn_as/scripts/sacli -k host.name -v $listen_ip ConfigPut
/usr/local/openvpn_as/scripts/sacli --user router --key prop_autologin --value true UserPropPut
/usr/local/openvpn_as/scripts/sacli --user $admin_user --key prop_superuser --value true UserPropPut
/usr/local/openvpn_as/scripts/sacli start
