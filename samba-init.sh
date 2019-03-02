#!/bin/bash

#restart ps3netsrv++
pkill ps3netsrv++
/usr/local/bin/ps3netsrv++ -d /share

sudo cat <<'EOF' | sudo tee /etc/samba/smb.conf
[global]
workgroup = WORKGROUP
usershare allow guests = yes
map to guest = bad user
allow insecure wide links = yes
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
force user = pi
follow symlinks = yes
wide links = yes
EOF

#if you wish to create a samba user with password you can use the following:
#sudo smbpasswd -a pi
sudo /etc/init.d/samba restart