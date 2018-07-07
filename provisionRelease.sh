#!/bin/bash

#
# psx-pi-smbshare provision script for releases
#
# *What it does*
# prepares a psx-pi-smbshare image candidate for first time use
# It will remove all bash history on the device and flush configuration files 

rm /var/log/firstboot.log
rm /etc/wpa_supplicant/wpa_supplicant.conf
cat /dev/null > ~/.bash_history && history -c && exit