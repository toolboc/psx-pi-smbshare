#!/bin/bash

#
# psx-pi-smbshare automout-usb script
#
# *What it does*
# This script configures raspbian to automount any usb storage to /media/<PartitionLabel>_<sdxy>
# This allows for use of USB & HDD in addition to Micro-SD

# Install pmount
sudo apt-get install -y pmount

# Create udev rule
sudo cat <<'EOF' | sudo tee /etc/udev/rules.d/usbstick.rules
ACTION=="add", KERNEL=="sd[a-z][0-9]", TAG+="systemd", ENV{SYSTEMD_WANTS}="usbstick-handler@%k"
EOF

# Configure systemd
sudo cat <<'EOF' | sudo tee /lib/systemd/system/usbstick-handler@.service
[Unit]
Description=Mount USB sticks
BindsTo=dev-%i.device
After=dev-%i.device

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/automount %I
ExecStop=/usr/bin/pumount /dev/%I
EOF

# Configure mount script
sudo cat <<'EOF' | sudo tee /usr/local/bin/automount
#!/bin/bash

PART=$1
FS_LABEL=`lsblk -o name,label | grep ${PART} | awk '{print $2}'`

if [ -z ${FS_LABEL} ]
then
    /usr/bin/pmount --umask 000 --noatime -w --sync /dev/${PART} /media/${PART}
else
    /usr/bin/pmount --umask 000 --noatime -w --sync /dev/${PART} /media/${FS_LABEL}_${PART}
fi
EOF

# Make script executable
sudo chmod +x /usr/local/bin/automount

# reboot
sudo reboot