#!/bin/bash

# Make sure the internet connection is active by running ping -c 3 google.com.
ping -c 3 google.com || (echo "Internet connection not detected, exiting." && exit)

# Set variables for partitioning
DISK="/dev/sda"
BOOT_SIZE="512M"
ROOT_SIZE="20G"

# Partition the disk using parted
parted --script "${DISK}" \
    mklabel gpt \
    mkpart primary fat32 1M "${BOOT_SIZE}" \
    set 1 esp on \
    mkpart primary ext4 "${BOOT_SIZE}" "${ROOT_SIZE}" \
    mkpart primary ext4 "${ROOT_SIZE}" 100%

# Format partitions
mkfs.fat -F 32 "${DISK}1"
mkfs.ext4 "${DISK}2"
mkfs.ext4 "${DISK}3"

# Mount partitions
mount "${DISK}2" /mnt/gentoo
mkdir /mnt/gentoo/boot
mount "${DISK}1" /mnt/gentoo/boot

# Download and extract the Funtoo stage3 tarball
STAGE3_URL="https://build.funtoo.org/1.4-release-std/x86-64bit/generic_64/stage3-latest.tar.xz"
wget "${STAGE3_URL}" -O /mnt/gentoo/stage3.tar.xz
tar xpf /mnt/gentoo/stage3.tar.xz -C /mnt/gentoo --xattrs-include='*.*' --numeric-owner

# Download and extract the Funtoo portage tree
PORTAGE_URL="https://build.funtoo.org/1.4-release-std/x86-64bit/generic_64/portage-latest.tar.xz"
wget "${PORTAGE_URL}" -O /mnt/gentoo/portage.tar.xz
tar xpf /mnt/gentoo/portage.tar.xz -C /mnt/gentoo/usr --xattrs-include='*.*' --numeric-owner

# Set up the fstab
echo "${DISK}2    /        ext4    defaults    0 1" > /mnt/gentoo/etc/fstab
echo "${DISK}1    /boot/efi    vfat    defaults    0 2" >> /mnt/gentoo/etc/fstab
echo "tmpfs    /tmp    tmpfs    defaults,nosuid,nodev    0 0" >> /mnt/gentoo/etc/fstab
echo "tmpfs    /var/tmp/portage    tmpfs    size=4G,noatime    0 0" >> /mnt/gentoo/etc/fstab

# Set up the Funtoo specific configuration files
echo "hostname=\"funtoo\"" > /mnt/gentoo/etc/conf.d/hostname
echo "127.0.0.1    localhost    funtoo" > /mnt/gentoo/etc/hosts

# Set up the timezone
TIMEZONE="Asia/Seoul"
ln -sf /usr/share/zoneinfo/${TIMEZONE} /mnt/gentoo/etc/localtime
echo "${TIMEZONE}" > /mnt/gentoo/etc/timezone

# Set up the locale
echo "en_US ISO-8859-1
en_US.UTF-8 UTF-8
ko_KR.UTF-8 UTF-8" > /mnt/gentoo/etc/locale.gen
chroot /mnt/gentoo locale-gen

# Set the root password
chroot /mnt/gentoo passwd

# Configure the network
echo "config_eth0=\"dhcp\"" > /mnt/gentoo/etc/conf.d/net
ln -sf /etc/init.d/net.lo /mnt/gentoo/etc/init.d/net.eth0
rc-update add net.eth0 default

# Install Korean input method and fonts
chroot /mnt/gentoo emerge -q app-i18n/ibus-hangul media-fonts/nanum

# Set up IBus for Korean input
echo 'GTK_IM_MODULE="ibus"' >> /mnt/gentoo/etc/portage/make.conf
echo 'QT_IM_MODULE="ibus"' >> /mnt/gentoo/etc/portage/make.conf
echo 'XMODIFIERS="@im=ibus"' >> /mnt/gentoo/etc/environment
echo 'export XMODIFIERS' >> /mnt/gentoo/etc/env.d/90xinput

# Set up locale settings for Korean
echo 'LANG="ko_KR.UTF-8"' > /mnt/gentoo/etc/env.d/02locale
echo 'LC_COLLATE="C"' >> /mnt/gentoo/etc/env.d/02locale
echo 'LC_CTYPE="ko_KR.UTF-8"' >> /mnt/gentoo/etc/env.d/02locale

# Set up console font and keymap for Korean
echo 'FONT="lat0-16.psfu.gz"' > /mnt/gentoo/etc/env.d/01console
echo 'KEYMAP="ko"' >> /mnt/gentoo/etc/env.d/01console

#Unmount partitions and reboot
umount -R /mnt/gentoo
reboot