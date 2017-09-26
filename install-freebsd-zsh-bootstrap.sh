#!/bin/sh -x

# ZFS RAID Disks
setenv DISK1 /dev/ada1
setenv DISK2 /dev/ada2

# Swap Size
setenv SWAPSIZE 4g

# FTP (no trailing /)
setenv FTP "ftp://ftp6.fr.freebsd.org/pub/FreeBSD/releases/amd64/amd64/10.2-RELEASE"

setenv ROOT_PASSWORD "MonMotDePasse"

# ------- END CONFIGURATION --------

gpart destroy -F ${DISK1}
gpart destroy -F ${DISK2}
gpart create -s gpt ${DISK1}
gpart create -s gpt ${DISK2}

gpart add -t freebsd-boot -l boot -s 512K ${DISK1}
gpart add -t freebsd-boot -l boot -s 512K ${DISK2}
gpart add -t freebsd-swap -l swap -s $SWAPSIZE -a 1m ${DISK1}
gpart add -t freebsd-swap -l swap -s $SWAPSIZE -a 1m ${DISK2}
gpart add -t freebsd-zfs -l disk00 ${DISK1}
gpart add -t freebsd-zfs -l disk01 ${DISK2}

dd if=/dev/zero of=${DISK1}p3 count=560 bs=512
dd if=/dev/zero of=${DISK2}p3 count=560 bs=512
gpart bootcode -b /boot/pmbr -p /boot/gptzfsboot -i 1 ${DISK1}
gpart bootcode -b /boot/pmbr -p /boot/gptzfsboot -i 1 ${DISK2}

zpool create -f -m none -o altroot=/mnt -o cachefile=/tmp/zpool.cache tank mirror gpt/disk00 gpt/disk01
zpool status
zfs create -o mountpoint=/ tank/root
zfs create -o mountpoint=/usr tank/usr
zfs create -o mountpoint=/var tank/var
zfs create -o mountpoint=/tmp tank/tmp
zfs create -o mountpoint=/www tank/www
zfs create -o mountpoint=/usr/home tank/usr/home
zpool set bootfs=tank/root tank
zfs list

cd /mnt && fetch "${FTP}/base.txz"
cd /mnt && fetch "${FTP}/kernel.txz"
cd /mnt && fetch "${FTP}/lib32.txz"
tar --unlink -xpJf /mnt/base.txz -C /mnt
tar --unlink -xpJf /mnt/kernel.txz -C /mnt
tar --unlink -xpJf /mnt/lib32.txz -C /mnt
cat << EOF > /mnt/etc/fstab
ada0p2 none swap sw 0 0
ada1p2 none swap sw 0 0
EOF
cat << EOF > /mnt/etc/rc.conf
keymap="fr.iso.acc.kbd"
ifconfig_em0="DHCP"
fsck_y_enable="YES"
background_fsck="YES"
dumpdev="NO"
zfs_enable="YES"

ntpd_enable="YES"
sshd_enable="YES"
linux_enable="YES"

EOF
cat << EOF > /mnt/boot/loader.conf
zfs_load="YES"
vfs.root.mountfrom="zfs:tank/root"
console=comconsole
EOF

echo "PermitRootLogin yes" >> /mnt/etc/ssh/sshd_config

# Define Root Password
echo "$ROOT_PASSWORD" | pw -R /mnt user mod -n root -h 0

cd /root
zpool export tank
zpool import -o altroot=/mnt -o cachefile=/tmp/zpool.cache tank
cp /tmp/zpool.cache /mnt/boot/zfs/

echo "terminated"
