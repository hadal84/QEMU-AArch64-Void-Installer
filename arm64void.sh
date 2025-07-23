#!/bin/bash

TARGET_DISK="/dev/vda"

ROOTFS_URL="https://repo-default.voidlinux.org/live/current/void-aarch64-musl-ROOTFS.tar.xz"

EFI_SIZE_MB=512

# error handling
set -euo pipefail

# check for root privileges
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root."
  exit 1
fi

echo "Enter keymap (e.g., us, trq, de): "
read KEYMAP_CONSOLE

echo "Enter timezone (Europe/Istanbul)"
read TIMEZONE

echo "Beginning installation for Void Linux on AArch64"
echo "WARNING: This script will destroy ALL DATA on $TARGET_DISK!"

if ping -c 1 -W 2 google.com &> /dev/null; then
  echo "Networking is available"
else
  echo "Networking doesnt work, configure it and re-run the script."
fi

xbps-install -S

xbps-install -y wget xz git parted

echo "Downloading ROOTFS from: $ROOTFS_URL"
ROOTFS_FILE=$(basename "$ROOTFS_URL")
wget -P /tmp -O "$ROOTFS_FILE" "$ROOTFS_URL"

loadkeys "$KEYMAP_CONSOLE"
echo "Keyboard layout set to $KEYMAP_CONSOLE for live session."

echo "Labeling disk GPT"
parted -s $TARGET_DISK mklabel gpt

echo "Creating efi partition"
parted -s $TARGET_DISK mkpart primary fat32 1MiB 513MiB
parted -s $TARGET_DISK set 1 esp on
parted -s $TARGET_DISK set 1 boot on
mkfs.vfat "${TARGET_DISK}1"

echo "Creating partition for root"
parted -s $TARGET_DISK mkpart primary ext4 513MiB 100%
mkfs.ext4 "${TARGET_DISK}2"

parted "$TARGET_DISK" print

echo "mounting partitions"
mount "${TARGET_DISK}2" /mnt/
mkdir -p /mnt/boot/efi/
mount "${TARGET_DISK}1" /mnt/boot/efi/

tar xvf "/tmp/$ROOTFS_FILE" -C /mnt

echo "installing base system images"
xbps-install -r /mnt -Su xbps
xbps-install -r /mnt -u
xbps-install -r /mnt base-system
xbps-remove -r /mnt -R base-container-full

echo "enter a password for the root user"
read ROOT_PASSWORD

# generate fstab with efi
genfstab -U /mnt >> /mnt/etc/fstab

# chroot territory
echo "now getting into chroot"
sudo xchroot /mnt /bin/bash <<EOF
set -e
echo "root:${ROOT_PASSWORD}" | chpasswd

ln -sf /etc/sv/dhcpcd /var/service/
ln -sf /etc/sv/sshd /var/service/

echo "Installing GRUB for UEFI"
xbps-install -S grub-arm64-efi
grub-install --target=arm64-efi --efi-directory=/boot/efi --bootloader-id="Void"
grub-mkconfig -o /boot/grub/grub.cfg
xbps-reconfigure -fa
EOF
# end of chroot
echo "exited out of chroot"

echo "finalization, unmounting mountpoints."
umount -R /mnt
echo "the script will now put down the machine."
shutdown -r now
