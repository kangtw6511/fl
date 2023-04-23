#!/bin/bash

# Set timezone
ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime

# Sync system time with network time server
ntpdate pool.ntp.org

# Install required packages
emerge --sync
emerge -av sys-kernel/gentoo-sources sys-kernel/genkernel-next sys-boot/grub:2 net-misc/netifrc app-admin/sudo

# Configure network settings
echo 'config_enp0s3="dhcp"' >> /etc/conf.d/net
cd /etc/init.d
ln -s net.lo net.enp0s3
rc-update add net.enp0s3 default

# Partition the disk
gdisk /dev/sda << EOF
o
Y
n
1

+128M
EF00
n
2

+4G
8200
n
3


w
Y
EOF

# Create file systems
mkfs.ext2 /dev/sda1
mkfs.vfat -F 32 /dev/sda1
mkswap /dev/sda2
swapon /dev/sda2
mkfs.ext4 /dev/sda3
mkfs.xfs /dev/sda3

# Mount partitions
mkdir -p /mnt/funtoo
mount /dev/sda3 /mnt/funtoo
mkdir /mnt/funtoo/boot
mount /dev/sda1 /mnt/funtoo/boot
mkdir /mnt/funtoo/var
mount /dev/sdb1 /mnt/funtoo/var

# Install Funtoo Linux
cd /mnt/funtoo
wget https://build.funtoo.org/1.4-release-std/x86-64bit/generic_64/stage3-latest.tar.xz
tar xvf stage3-latest.tar.xz --xattrs-include='*.*' --numeric-owner
mount -t proc proc /mnt/funtoo/proc
mount --rbind /sys /mnt/funtoo/sys
mount --make-rslave /mnt/funtoo/sys
mount --rbind /dev /mnt/funtoo/dev
mount --make-rslave /mnt/funtoo/dev
chroot /mnt/funtoo /bin/bash -c "source /etc/profile && \
                                export PS1=\"(chroot) \${PS1}\" && \
                                emerge-webrsync && \
                                emerge -avuDN @world && \
                                echo 'Asia/Seoul' > /etc/timezone && \
                                emerge --config sys-libs/timezone-data && \
                                locale-gen && \
                                eselect locale set 11 && \
                                eselect keymap set 2 && \
                                echo 'hostname=\"myhost\"' > /etc/conf.d/hostname && \
                                echo '127.0.0.1 myhost localhost' > /etc/hosts && \
                                emerge -av sys-boot/grub:2 && \
                                grub-install /dev/sda && \
                                grub-mkconfig -o /boot/grub/grub.cfg

# Install and configure bootloader
emerge --ask --verbose sys-boot/grub
grub-install /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg