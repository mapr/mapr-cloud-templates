#!/usr/bin/env bash

admin_user=$1
admin_pw=$2
subnet=$3
listen_ip=$4
address_space=$5
domain=$(hostname -d)

echo "OPENVPN USER: $admin_user"
echo "OPENVPN PASSWORD: <hidden>"
echo "OPENVPN SUBNET: $subnet"
echo "OPENVPN LISTENIP: $listen_ip"
echo "OPENVPN ADDRESS SPACE: $address_space"
echo "OPENVPN DOMAIN: $domain"

/usr/local/openvpn_as/scripts/sacli -k vpn.client.tls_version_min -v 1.2 ConfigPut
/usr/local/openvpn_as/scripts/sacli -k vpn.client.tls_version_min_strict -v true ConfigPut
/usr/local/openvpn_as/scripts/sacli -k vpn.server.tls_version_min -v 1.2 ConfigPut
/usr/local/openvpn_as/scripts/sacli -k vpn.daemon.0.client.network -v $subnet ConfigPut
/usr/local/openvpn_as/scripts/sacli -k vpn.daemon.0.client.netmask_bits -v 24 ConfigPut
/usr/local/openvpn_as/scripts/sacli -k vpn.client.routing.reroute_dns -v true ConfigPut
/usr/local/openvpn_as/scripts/sacli -k vpn.server.dhcp_option.domain -v $domain ConfigPut
/usr/local/openvpn_as/scripts/sacli -k vpn.server.routing.private_network.0 -v $address_space ConfigPut
/usr/local/openvpn_as/scripts/sacli -k host.name -v $listen_ip ConfigPut
/usr/local/openvpn_as/scripts/sacli start
/usr/local/openvpn_as/scripts/sacli --user router --key prop_autologin --value true UserPropPut
/usr/local/openvpn_as/scripts/sacli --user $admin_user --key prop_superuser --value true UserPropPut
