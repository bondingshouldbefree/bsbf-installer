#!/bin/sh
# This script installs the BSBF bonding solution client to conventional Linux
# distributions.
# Author: Chester A. Unal <chester.a.unal@arinc9.com>

usage() {
	echo "Usage: $0 --server-ipv4 <ADDR> --server-port <PORT> --uuid <UUID>"
	exit 1
}

# Parse arguments.
while [ $# -gt 0 ]; do
	case "$1" in
	--server-ipv4)
		[ -z "$2" ] && usage
		server_ipv4="$2"
		shift 2
		;;
	--server-port)
		[ -z "$2" ] && usage
		server_port="$2"
		shift 2
		;;
	--uuid)
		[ -z "$2" ] && usage
		uuid="$2"
		shift 2
		;;
	*)
		usage
		;;
	esac
done

# Show usage if server IPv4 address, server port, and UUID were not provided.
{ [ -z "$server_ipv4" ] || [ -z "$server_port" ] || [ -z "$uuid" ]; } && usage

BSBF_RESOURCES="https://raw.githubusercontent.com/bondingshouldbefree/bsbf-resources/refs/heads/main"

# Install bash, ethtool, fping, jq, and usb-modeswitch.
sudo apt update
sudo apt install bash ethtool fping jq usb-modeswitch

# Install xray and its configuration.
curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh | sudo bash
curl -s $BSBF_RESOURCES/resources-client/xray.json \
  | jq --arg SERVER "$server_ipv4" \
       --argjson PORT "$server_port" \
       --arg UUID "$uuid" '
        .outbounds[0].settings.address = $SERVER
      | .outbounds[0].settings.port = $PORT
      | .outbounds[0].settings.id = $UUID' \
  | sudo tee /usr/local/etc/xray/bsbf-bonding.json > /dev/null

sudo mkdir /etc/nftables
sudo curl $BSBF_RESOURCES/resources-client/bsbf_bonding.nft -o /etc/nftables/bsbf_bonding.nft
sudo curl $BSBF_RESOURCES/resources-client/99-bsbf-bonding.conf -o /etc/systemd/system/xray@.service.d/99-bsbf-bonding.conf

# Install bsbf-mptcp.
sudo curl $BSBF_RESOURCES/bsbf-mptcp/files/usr/sbin/bsbf-mptcp -o /usr/sbin/bsbf-mptcp
sudo chmod +x /usr/sbin/bsbf-mptcp
sudo curl $BSBF_RESOURCES/bsbf-mptcp/files/usr/sbin/bsbf-mptcp-helper -o /usr/sbin/bsbf-mptcp-helper
sudo chmod +x /usr/sbin/bsbf-mptcp-helper
sudo curl $BSBF_RESOURCES/resources-client/bsbf-mptcp.service -o /usr/lib/systemd/system/bsbf-mptcp.service

# Install bsbf-route.
sudo curl $BSBF_RESOURCES/bsbf-route/files/usr/sbin/bsbf-route -o /usr/sbin/bsbf-route
sudo chmod +x /usr/sbin/bsbf-route
sudo curl $BSBF_RESOURCES/resources-client/bsbf-route.service -o /usr/lib/systemd/system/bsbf-route.service

# Install bsbf-tcp-in-udp.
sudo mkdir -p /usr/local/share/tcp-in-udp
sudo curl $BSBF_RESOURCES/bsbf-tcp-in-udp/files/usr/local/share/tcp-in-udp/tcp_in_udp_tc_le.o -o /usr/local/share/tcp-in-udp/tcp_in_udp_tc.o
curl -s $BSBF_RESOURCES/bsbf-tcp-in-udp/files/usr/sbin/bsbf-tcp-in-udp \
  | sed -e "s/^BASE_PORT=.*/BASE_PORT=$server_port/" \
	-e "s/^IPv4=.*/IPv4=\"$server_ipv4\"/" \
  | sudo tee /usr/sbin/bsbf-tcp-in-udp > /dev/null

sudo chmod +x /usr/sbin/bsbf-tcp-in-udp
sudo curl $BSBF_RESOURCES/resources-client/99-bsbf-tcp-in-udp.sh -o /etc/NetworkManager/dispatcher.d/99-bsbf-tcp-in-udp.sh
sudo chmod +x /etc/NetworkManager/dispatcher.d/99-bsbf-tcp-in-udp.sh

# Enable and (re)start systemd services.
sudo systemctl enable bsbf-mptcp bsbf-route xray@bsbf-bonding
sudo systemctl restart bsbf-mptcp bsbf-route xray@bsbf-bonding

# Restart NetworkManager to apply the TCP-in-UDP dispatcher script.
sudo systemctl restart NetworkManager
