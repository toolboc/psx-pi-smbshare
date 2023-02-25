#!/bin/bash

#
# psx-pi-smbshare setup script
#
# *What it does*
# This script will install and configure an smb share at /share
# It will also compile ps3netsrv from source to allow operability with PS3/Multiman
# It also configures the pi ethernet port to act as dhcp server for connected devices and allows those connections to route through wifi on wlan0
# Finally, XLink Kai is installed for online play.
#
# *More about the network configuration*
# This configuration provides an ethernet connected PS2 or PS3 a low-latency connection to the smb share running on the raspberry pi
# The configuration also allows for outbound access from the PS2 or PS3 if wifi is configured on the pi
# This setup should work fine out the box with OPL and multiman
# Per default configuration, the smbserver is accessible on 192.168.2.1


USER=`whoami`
# Update packages
sudo apt-get -y update
sudo apt-get -y upgrade

# Ensure basic tools are present
sudo apt-get -y install screen wget git curl coreutils

# Install and configure Samba
sudo apt-get install -y samba samba-common-bin
wget https://raw.githubusercontent.com/toolboc/psx-pi-smbshare/master/samba-init.sh -O /home/${USER}/samba-init.sh
chmod 755 /home/${USER}/samba-init.sh
sudo cp /home/${USER}/samba-init.sh /usr/local/bin
sudo mkdir -m 1777 /share

# Install ps3netsrv
sudo rm /usr/local/bin/ps3netsrv++
sudo apt-get install -y git gcc
git clone https://github.com/dirkvdb/ps3netsrv--.git
cd ps3netsrv--
git submodule update --init
make CXX=g++
sudo cp ps3netsrv++ /usr/local/bin

# Install wifi-to-eth route settings
sudo apt-get install -y dnsmasq
wget https://raw.githubusercontent.com/toolboc/psx-pi-smbshare/master/wifi-to-eth-route.sh -O /home/${USER}/wifi-to-eth-route.sh
chmod 755 /home/${USER}/wifi-to-eth-route.sh

# Install setup-wifi-access-point settings
sudo apt-get install -y hostapd bridge-utils
wget https://raw.githubusercontent.com/toolboc/psx-pi-smbshare/master/setup-wifi-access-point.sh -O /home/${USER}/setup-wifi-access-point.sh
chmod 755 /home/${USER}/setup-wifi-access-point.sh

# Remove old XLink Kai Repo if present
sudo rm -rf /etc/apt/sources.list.d/teamxlink.list

# Set up teamxlink repository and install XLink Kai

sudo apt-get install -y ca-certificates curl gnupg
sudo mkdir -m 0755 -p /etc/apt/keyrings
sudo rm /etc/apt/keyrings/teamxlink.gpg
curl -fsSL https://dist.teamxlink.co.uk/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/teamxlink.gpg
sudo chmod a+r /etc/apt/keyrings/teamxlink.gpg
echo  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/teamxlink.gpg] https://dist.teamxlink.co.uk/linux/debian/static/deb/release/ /" | sudo tee /etc/apt/sources.list.d/teamxlink.list > /dev/null
sudo apt-get update
sudo apt-get install -y xlinkkai

# Write XLink Kai launch script
cat <<'EOF' > /home/${USER}/launchkai.sh
echo "Checking for XLink Kai updates"
sudo apt-get install xlinkkai -y
echo "Launching XLink Kai"
while true; do
    screen -dmS kai kaiengine
    sleep 5
done
EOF

chmod 755 /home/${USER}/launchkai.sh

# Install USB automount settings
wget https://raw.githubusercontent.com/toolboc/psx-pi-smbshare/master/automount-usb.sh -O /home/${USER}/automount-usb.sh
chmod 755 /home/${USER}/automount-usb.sh
sudo /home/${USER}/automount-usb.sh

# Set samba-init + ps3netsrv, wifi-to-eth-route, setup-wifi-access-point, and XLink Kai to run on startup
{ echo -e "@reboot sudo bash /usr/local/bin/samba-init.sh\n@reboot sudo bash /home/${USER}/wifi-to-eth-route.sh && sudo bash /home/${USER}/setup-wifi-access-point.sh\n@reboot bash /home/${USER}/launchkai.sh"; } | crontab -u pi -

# Start services
sudo /usr/local/bin/samba-init.sh
sudo /home/${USER}/wifi-to-eth-route.sh
sudo /home/${USER}/setup-wifi-access-point.sh
ps3netsrv++ -d /share/
screen -dmS kailauncher /home/${USER}/launchkai.sh

# Not a bad idea to reboot
sudo reboot
