#!/bin/bash

#
# psx-pi-smbshare automout-usb script
#
# *What it does*
# This script configures raspbian to automount any usb storage to /media/<PartitionLabel>_<sdxy>
# This allows for use of USB & HDD in addition to Micro-SD
# It also creates a new Samba configuration which exposes the last attached USB drive @ //SMBSHARE/${FS_LABEL}_${PART} or //SMBSHARE/${PART} if no FS_LABEL is present

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

# Configure script to run when an automount event is triggered
sudo cat <<'EOF' | sudo tee /usr/local/bin/automount
#!/bin/bash

PART=$1
FS_LABEL=`lsblk -o name,label | grep ${PART} | awk '{print $2}'`

if [ -z ${PART} ]
then
    exit
fi

if [ -z ${FS_LABEL} ]
then
    runuser pi -s /bin/bash -c "/usr/bin/pmount --umask 000 --noatime -w --sync /dev/${PART} /media/${PART}"
    runuser pi -s /bin/bash -c "ln -s /media/${PART} /share/USB"
    shareName=${PART}
else 
    runuser pi -s /bin/bash -c "/usr/bin/pmount --umask 000 --noatime -w --sync /dev/${PART} /media/${FS_LABEL}_${PART}"
    runuser pi -s /bin/bash -c "ln -s /media/${FS_LABEL}_${PART} /share/USB"
    shareName=${FS_LABEL}_${PART}
fi

cat <<EOF | sudo tee /etc/samba/smb.conf
[global]
workgroup = WORKGROUP
usershare allow guests = yes
map to guest = bad user
allow insecure wide links = yes
[share]
Comment = Pi default shared folder
Path = /share
Browseable = yes
Writeable = Yes
only guest = no
create mask = 0777
directory mask = 0777
Public = yes
Guest ok = yes
force user = pi
follow symlinks = yes
wide links = yes
[$shareName]
Comment = USB shared folder
Path = /media/$shareName
Browseable = yes
Writeable = Yes
only guest = no
create mask = 0777
directory mask = 0777
Public = yes
Guest ok = yes
force user = pi
follow symlinks = yes
wide links = yes
EOF

# Make script executable
sudo chmod +x /usr/local/bin/automount

# reboot to take effect
#sudo reboot