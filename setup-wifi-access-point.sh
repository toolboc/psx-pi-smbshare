#!/bin/bash

#
# psx-pi-smbshare setup script
#
# *What it does*
# This script will install and configure an external wifi dongle for access to XlinkKai & samba
# This allows for configuring devices without ethernet to have access to these services
# The default SSID name for the wifi network is XlinkKai
#
# Be sure to change the wpa_passphrase to a custom passworkd

# Update packages
sudo apt-get install -y hostapd bridge-utils
sudo systemctl stop hostapd

# Configure hostapd
sudo cat <<'EOF' | sudo tee /etc/default/hostapd
DAEMON_CONF="/etc/hostapd/hostapd.conf"
EOF

sudo cat <<'EOF' | sudo tee /etc/hostapd/hostapd.conf
interface=wlan1
#driver=nl80211
ssid=XlinkKai
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=3
wpa_passphrase=<YOURPASSWORD>
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF

sudo systemctl start hostapd

# Configure dhcpcd

sudo cat <<'EOF' | sudo tee /etc/dhcpcd.conf
interface wlan1
static ip_address=192.168.2.3/24
static domain_name_servers=192.168.2.1 8.8.8.8
static routers=192.168.2.1
nohook wpa_supplicant
EOF

# Configure dnsmasq
sudo cat <<'EOF' | sudo tee -a /etc/dnsmasq.d/custom-dnsmasq.conf

interface=wlan1
dhcp-range=192.168.2.3,192.168.2.100,12h
EOF

# Forward additional ports
sudo iptables -A FORWARD -i wlan1 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i wlan0 -o wlan1 -j ACCEPT

# Restart dnsmasq
sudo systemctl restart dnsmasq