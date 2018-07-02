#!/bin/bash

#
# psx-pi-smbshare setup script
#
# *What it does*
# This script will install and configure an smb share at /share
# It will also compile ps3netsrv from source to allow operability with PS3/Multiman
# Finally, it configures the pi ethernet port to act as dhcp server for connected devices and allows those connections to route through wifi on wlan0
#
# *More about the network configuration*
# This configuration provides an ethernet connected PS2 or PS3 a low-latency connection to the smb share running on the raspberry pi
# The configuration also allows for outbound access from the PS2 or PS3 if wifi is configured on the pi
# This setup should work fine out the box with OPL and multiman
# Per default configuration, the smbserver is accessible on 192.168.2.1


# Update packages
sudo apt-get -y update
sudo apt-get -y upgrade

# Install and configure Samba
sudo apt-get install -y samba samba-common-bin

sudo mkdir -m 1777 /share

sudo cat <<'EOF' | sudo tee /etc/samba/smb.conf
[global]
workgroup = WORKGROUP
usershare allow guests = yes
map to guest = bad user
[share]
Comment = Pi shared folder
Path = /share
Browseable = yes
Writeable = Yes
only guest = no
create mask = 0777
directory mask = 0777
Public = yes
Guest ok = yes
EOF

#if you wish to create a samba user with password you can use the following:
#sudo smbpasswd -a pi
sudo /etc/init.d/samba restart

# Install ps3netsrv
sudo apt-get install -y git gcc
git clone https://github.com/dirkvdb/ps3netsrv--.git
cd ps3netsrv--
git submodule update --init
make CXX=g++
sudo cp ps3netsrv++ /usr/local/bin


# Install wifi-to-eth route settings
sudo apt-get install -y dnsmasq
cd ~
wget https://raw.githubusercontent.com/arpitjindal97/raspbian-recipes/master/wifi-to-eth-route.sh -O ~/wifi-to-eth-route.sh
chmod 755 wifi-to-eth-route.sh

# Set wifi-to-eth-route and ps3netsrv to run on startup
{ echo -e "@reboot sudo bash /home/pi/wifi-to-eth-route.sh\n@reboot /usr/local/bin/ps3netsrv++ -d /share/"; } | crontab -u pi -

# Start services
sudo /home/pi/wifi-to-eth-route.sh
ps3netsrv++ -d /share/