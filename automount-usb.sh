#!/bin/bash

#
# psx-pi-smbshare automout-usb script
#
# *What it does*
# This script configures raspbian to automount any usb storage to /media/sd<xy>
# This allows for use of USB & HDD in addition to Micro-SD
# It also creates a new Samba configuration which exposes the last attached USB drive @ //SMBSHARE/<PARTITION>

# Update packages
sudo apt-get update

# Install NTFS Read/Write Support
sudo apt-get install -y ntfs-3g 

# Install pmount with ExFAT support
sudo apt-get install -y exfat-fuse exfat-utils autoconf intltool libtool libtool-bin libglib2.0-dev libblkid-dev
cd ~
git clone https://github.com/stigi/pmount-exfat.git
cd pmount-exfat
./autogen.sh
make
sudo make install prefix=usr
sudo sed -i 's/not_physically_logged_allow = no/not_physically_logged_allow = yes/' /etc/pmount.conf

# Create udev rule
sudo cat <<'EOF' | sudo tee /etc/udev/rules.d/usbstick.rules
ACTION=="add", KERNEL=="sd[a-z][0-9]", TAG+="systemd", ENV{SYSTEMD_WANTS}="usbstick-handler@%k"
ENV{DEVTYPE}=="usb_device", ACTION=="remove", SUBSYSTEM=="usb", RUN+="/bin/systemctl --no-block start usbstick-cleanup@%k.service"
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
ExecStart=/usr/local/bin/automount.sh %I
ExecStop=/usr/bin/pumount /dev/%I
EOF

sudo cat <<'EOF' | sudo tee /lib/systemd/system/usbstick-cleanup@.service
[Unit]
Description=Cleanup USB sticks
BindsTo=dev-%i.device

[Service]
Type=simple
ExecStart=/usr/local/bin/samba-init.sh && /usr/bin/pumount /dev/%I
EOF

# Configure script to run when an automount event is triggered
sudo cat <<'EOF' | sudo tee /usr/local/bin/automount.sh
#!/bin/bash

PART=$1
FS_LABEL=`lsblk -o name,label | grep ${PART} | awk '{print $2}'`

if [ -z ${PART} ]
then
    exit
fi

runuser pi -s /bin/bash -c "/usr/bin/pmount --umask 000 --noatime -w --sync /dev/${PART} /media/${PART}"

#create a new smb share for the mounted drive
cat <<EOS | sudo tee /etc/samba/smb.conf
[global]
workgroup = WORKGROUP
usershare allow guests = yes
map to guest = bad user
allow insecure wide links = yes
[share]
Comment = Pi default shared folder
Path = /media/$PART
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
EOS

#if you wish to create a samba user with password you can use the following:
#sudo smbpasswd -a pi
sudo /etc/init.d/samba restart
EOF

# Make script executable
sudo chmod +x /usr/local/bin/automount.sh

# Reload udev rules and triggers
sudo udevadm control --reload-rules && udevadm trigger