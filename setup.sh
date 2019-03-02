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
wget https://raw.githubusercontent.com/toolboc/psx-pi-smbshare/master/samba-init.sh -O /home/pi/samba-init.sh
chmod 755 /home/pi/samba-init.sh
sudo cp /home/pi/samba-init.sh /usr/local/bin
sudo mkdir -m 1777 /share

# Install ps3netsrv
sudo apt-get install -y git gcc
git clone https://github.com/dirkvdb/ps3netsrv--.git
cd ps3netsrv--
git submodule update --init
make CXX=g++
sudo cp ps3netsrv++ /usr/local/bin


# Install wifi-to-eth route settings
sudo apt-get install -y dnsmasq
wget https://raw.githubusercontent.com/toolboc/psx-pi-smbshare/master/wifi-to-eth-route.sh -O /home/pi/wifi-to-eth-route.sh
chmod 755 /home/pi/wifi-to-eth-route.sh

# Install setup-wifi-access-point settings
sudo apt-get install -y hostapd bridge-utils
wget https://raw.githubusercontent.com/toolboc/psx-pi-smbshare/master/setup-wifi-access-point.sh -O /home/pi/setup-wifi-access-point.sh
chmod 755 /home/pi/setup-wifi-access-point.sh

# Install Xlink Kai
wget https://cdn.teamxlink.co.uk/binary/kaiEngine-7.4.33-rev759.headless.ARM.tar.gz
tar -xzvf kaiEngine-7.4.33-rev759.headless.ARM.tar.gz
sudo cp kaiEngine-7.4.33/kaiengine_arm /usr/local/bin
sudo mkdir /root/.xlink

cat <<'EOF' > /home/pi/launchkai.sh
while true; do
    /usr/local/bin/kaiengine_arm
    sleep 1
done
EOF

chmod 755 /home/pi/launchkai.sh

# Install USB automount settings
wget https://raw.githubusercontent.com/toolboc/psx-pi-smbshare/master/automount-usb.sh -O /home/pi/automount-usb.sh
chmod 755 /home/pi/automount-usb.sh
sudo /home/pi/automount-usb.sh

# Set samba-init + ps3netsrv, wifi-to-eth-route, setup-wifi-access-point, and Xlink Kai to run on startup
{ echo -e "@reboot sudo bash /usr/local/bin/samba-init.sh\n@reboot sudo bash /home/pi/wifi-to-eth-route.sh && sudo bash /home/pi/setup-wifi-access-point.sh\n@reboot sudo bash /home/pi/launchkai.sh"; } | crontab -u pi -

# Start services
sudo /usr/local/bin/samba-init.sh
sudo /home/pi/wifi-to-eth-route.sh
sudo /home/pi/setup-wifi-access-point.sh
ps3netsrv++ -d /share/
sudo kaiengine_arm

# Not a bad idea to reboot
sudo reboot
