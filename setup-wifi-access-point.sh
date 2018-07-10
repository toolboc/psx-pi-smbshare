#!/bin/bash

#
# psx-pi-smbshare setup-wifi-access-point script
#
# *What it does*
# This script will install and configure an external wifi dongle for access to XlinkKai & samba
# This allows for configuring devices without ethernet to have access to these services
# The default SSID name for the wifi network is XlinkKai
#
# Be sure to change the wpa_passphrase to a custom password

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
#ieee80211n=1
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=3
wpa_passphrase=XlinkKai
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF

# Configure dhcpcd
sudo cat <<'EOF' | sudo tee /etc/dhcpcd.conf
interface wlan1
static ip_address=192.168.3.1/24
nohook wpa_supplicant
EOF

# Configure dnsmasq
sudo cat <<'EOF' | sudo tee -a /etc/dnsmasq.d/custom-dnsmasq.conf

interface=wlan1
bind-dynamic
dhcp-range=192.168.3.2,192.168.3.100,12h
EOF

# Forward additional ports
#sudo iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
sudo iptables -A FORWARD -i wlan0 -o wlan1 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -p ALL -i wlan1 -o wlan0 -j ACCEPT

# Restart services
sudo systemctl stop hostapd
sudo systemctl stop dnsmasq
sudo systemctl start hostapd
sudo systemctl start dnsmasq