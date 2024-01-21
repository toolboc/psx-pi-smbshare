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

# Make sure we're not root otherwise the paths will be wrong
if [ $USER = "root" ]; then
  echo "Do not run this script as root or with sudo"
  exit 1
fi

if whiptail --yesno "Would you like to enable ps3netsrv for PS3 support? (SMB is enabled either way for PS2 support etc.)" 8 55; then
  PS3NETSRV=true
else
  PS3NETSRV=false
fi

if whiptail --yesno "Would you like to enable XLink Kai?" 8 55; then
  XLINKKAI=true
else
  XLINKKAI=false
fi

if whiptail --yesno "Would you like to enable wifi access point for a direct wifi connection?" 8 55; then
  WIFIACCESSPOINT=true
else
  WIFIACCESSPOINT=false
fi

if whiptail --yesno "Would you like to share wifi over ethernet, for devices without wifi? (Ethernet will no longer work for providing the pi an internet connection)" 9 55; then
  ETHROUTE=true
else
  ETHROUTE=false
fi

# Update packages
sudo apt-get -y update
sudo apt-get -y upgrade

# Ensure basic tools are present
sudo apt-get -y install screen wget git curl coreutils iptables hostapd

# Install and configure Samba
sudo apt-get install -y samba samba-common-bin
wget https://raw.githubusercontent.com/georgewoodall82/psx-pi-smbshare-updated/master/samba-init.sh -O /home/${USER}/samba-init.sh
sed -i "s/userplaceholder/${USER}/g" /home/${USER}/samba-init.sh
chmod 755 /home/${USER}/samba-init.sh
sudo cp /home/${USER}/samba-init.sh /usr/local/bin
sudo mkdir -m 1777 /share

# Install ps3netsrv if PS3NETSRV is true
if [ "$PS3NETSRV" = true ]; then
  sudo rm /usr/local/bin/ps3netsrv++
  sudo apt-get install -y git gcc
  git clone https://github.com/dirkvdb/ps3netsrv--.git
  cd ps3netsrv--
  git submodule update --init
  make CXX=g++
  sudo cp ps3netsrv++ /usr/local/bin
fi

if [ "$ETHROUTE" = true ]; then
  # Install wifi-to-eth route settings
  sudo apt-get install -y dnsmasq
  wget https://raw.githubusercontent.com/georgewoodall82/psx-pi-smbshare-updated/master/wifi-to-eth-route.sh -O /home/${USER}/wifi-to-eth-route.sh
else
  touch /home/${USER}/wifi-to-eth-route.sh
chmod 755 /home/${USER}/wifi-to-eth-route.sh

if [ "$WIFIACCESSPOINT" = true ]; then
  # Install setup-wifi-access-point settings
  sudo apt-get install -y hostapd bridge-utils
  wget https://raw.githubusercontent.com/georgewoodall82/psx-pi-smbshare-updated/master/setup-wifi-access-point.sh -O /home/${USER}/setup-wifi-access-point.sh
else
  touch /home/${USER}/setup-wifi-access-point.sh
fi
chmod 755 /home/${USER}/setup-wifi-access-point.sh

# Install XLink Kai if XLINKKAI is true
if [ "$XLINKKAI" = true ]; then

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
else
touch /home/${USER}/launchkai.sh

#End of XLink Kai install
fi
chmod 755 /home/${USER}/launchkai.sh

# Install USB automount settings
wget https://raw.githubusercontent.com/georgewoodall82/psx-pi-smbshare-updated/master/automount-usb.sh -O /home/${USER}/automount-usb.sh
chmod 755 /home/${USER}/automount-usb.sh
/home/${USER}/automount-usb.sh

# Set samba-init + ps3netsrv, wifi-to-eth-route, setup-wifi-access-point, and XLink Kai to run on startup
{ echo -e "@reboot sudo bash /usr/local/bin/samba-init.sh\n@reboot sudo bash /home/${USER}/wifi-to-eth-route.sh && sudo bash /home/${USER}/setup-wifi-access-point.sh\n@reboot bash /home/${USER}/launchkai.sh"; } | crontab -u ${USER} -

# Not a bad idea to reboot
sudo reboot
