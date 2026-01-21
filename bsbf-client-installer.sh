#!/bin/sh
# This script installs the BSBF bonding solution client to conventional Linux
# distributions.
# Author: Chester A. Unal <chester.a.unal@arinc9.com>

# Install sing-box and its configuration.
curl -fsSL https://sing-box.app/install.sh | sh
sudo curl https://raw.githubusercontent.com/bondingshouldbefree/bsbf-openwrt-imagebuilder-config-generator/refs/heads/main/config/sing-box.json -o /etc/sing-box/bsbf-bonding.json

# Install ethtool, fping, and usb-modeswitch.
sudo apt update
sudo apt install ethtool fping usb-modeswitch

BSBF_FEED="https://raw.githubusercontent.com/bondingshouldbefree/bsbf-client-scripts/refs/heads/main"

# Install bsbf-mptcp-helper.
sudo curl $BSBF_FEED/bsbf-mptcp-helper/files/usr/sbin/bsbf-mptcp-backup -o /usr/sbin/bsbf-mptcp-backup
sudo chmod +x /usr/sbin/bsbf-mptcp-backup
sudo curl $BSBF_FEED/bsbf-mptcp-helper/files/usr/sbin/bsbf-mptcp-helper -o /usr/sbin/bsbf-mptcp-helper
sudo chmod +x /usr/sbin/bsbf-mptcp-helper

# Install bsbf-route.
sudo curl $BSBF_FEED/bsbf-route/files/usr/sbin/bsbf-route -o /usr/sbin/bsbf-route
sudo chmod +x /usr/sbin/bsbf-route

# Install bsbf-tcp-in-udp.
sudo mkdir -p /usr/local/share/tcp-in-udp
sudo curl $BSBF_FEED/bsbf-tcp-in-udp/files/usr/local/share/tcp-in-udp/tcp_in_udp_tc_le.o -o /usr/local/share/tcp-in-udp/tcp_in_udp_tc.o
sudo curl $BSBF_FEED/bsbf-tcp-in-udp/files/usr/sbin/bsbf-tcp-in-udp -o /usr/sbin/bsbf-tcp-in-udp
sudo chmod +x /usr/sbin/bsbf-tcp-in-udp
sudo cp dispatcher.d/99-bsbf-tcp-in-udp.sh /etc/NetworkManager/dispatcher.d/
sudo chmod +x /etc/NetworkManager/dispatcher.d/99-bsbf-tcp-in-udp.sh

# Install systemd services.
sudo cp systemd/bsbf-mptcp-backup.service /usr/lib/systemd/system/
sudo cp systemd/bsbf-route.service /usr/lib/systemd/system/

# Enable and (re)start systemd services.
sudo systemctl enable bsbf-mptcp-backup bsbf-route sing-box@bsbf-bonding
sudo systemctl restart bsbf-mptcp-backup bsbf-route sing-box@bsbf-bonding

# Restart NetworkManager to apply the TCP-in-UDP dispatcher script.
sudo systemctl restart NetworkManager
