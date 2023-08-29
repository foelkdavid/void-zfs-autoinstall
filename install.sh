#!/bin/bash

# Adding colors for output:
red="\e[0;91m"
green="\e[0;92m"
blue="\e[0;94m"
yellow="\e[0;93m"
bold="\e[1m"
reset="\e[0m"

# --
LOGFILE="void-zfs-autoinstall.log"



# convenience:
fail() { echo -e "${red}[FAILED]${reset}"; }

failexit() {
    fail
    exit
}
ok() { echo -e "${green}[OK]${reset}"; }

skipped() { echo -e "${yellow}[SKIPPED]${reset}"; }

# checks if command is run as root / sudo
rootcheck() { [ $(id -u) -eq 0 ] && return 0 || return 1; }

# naive connectivity check
networkcheck() { ping -c 3 www.kernel.org > $LOGFILE && return 0 || return 1; }

eficheck() { dmesg | grep -i efivars >> $LOGFILE && return 0 || return 1; }

select_drive(){
    echo "Starting disk Partitioning"
    echo -e "Found disks: (>1G)"
    echo -e "${bold}"
    lsblk -dp | grep G | awk '{print $1, $4}' &&
    echo -e "${reset}"

    read -p "Please enter the path of the desired Disk for your new System: " BOOT_DISK &&
    echo -e "${red}This will start the installation on "$BOOT_DISK". ${reset}"
    while true; do
        read -p "Are you sure? [y/n]" YN
        case $YN in
            [Yy]* )  break; echo"done";;
            [Nn]* )  echo "you selected no"; exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

define_disk_variables(){
  export BOOT_PART="1"

  if [[ $BOOT_DISK == "/dev/nvme"* ]]; then
    export BOOT_DEVICE="${BOOT_DISK}p${BOOT_PART}"
  else
    export BOOT_DEVICE="${BOOT_DISK}${BOOT_PART}"
  fi

  export POOL_DISK=$BOOT_DISK
  export POOL_PART="2"

  if [[ $POOL_DISK == "/dev/nvme"* ]]; then
    export POOL_DEVICE="${POOL_DISK}p${POOL_PART}"
  else
    export POOL_DEVICE="${POOL_DISK}${POOL_PART}"
  fi
}

wipe_partitions() {
  wipefs -a "$POOL_DISK"
  wipefs -a "$BOOT_DISK"

  sgdisk --zap-all "$POOL_DISK"
  sgdisk --zap-all "$BOOT_DISK"
}

create_partitions() {
  sgdisk -n "${BOOT_PART}:1m:+512m" -t "${BOOT_PART}:ef00" "$BOOT_DISK"
  sgdisk -n "${POOL_PART}:0:-10m" -t "${POOL_PART}:bf00" "$POOL_DISK"


  zpool create -f -o ashift=12 \
   -O compression=lz4 \
   -O acltype=posixacl \
   -O xattr=sa \
   -O relatime=on \
   -O encryption=aes-256-gcm \
   -O keyformat=passphrase \
   -o autotrim=on \
   -o compatibility=openzfs-2.1-linux \
   -m none zroot "$POOL_DEVICE"
}

create_initfs() {
  zfs create -o mountpoint=none zroot/ROOT
  zfs create -o mountpoint=/ -o canmount=noauto zroot/ROOT/${ID}
  zfs create -o mountpoint=/home zroot/home
  zpool set bootfs=zroot/ROOT/${ID} zroot
}

verify_and_update() {
  zpool export zroot
  zpool import -N -R /mnt zroot
  zfs load-key -L prompt zroot

  zfs mount zroot/ROOT/${ID}
  zfs mount zroot/home

  mount | grep mnt

  udevadm trigger
}

install_void(){
  XBPS_ARCH=x86_64 xbps-install \
    -S -R https://mirrors.servercentral.com/voidlinux/current \
    -r /mnt base-system


  cp /etc/hostid /mnt/etc
  mkdir /mnt/etc/zfs


  xchroot /mnt /bin/bash -- << EOCHROOT

  echo 'KEYMAP="de"' >> /etc/rc.conf
  echo 'HARDWARECLOCK="UTC"' >> /etc/rc.conf
  ln -sf /usr/share/zoneinfo/Europe/Vienna /etc/localtime

  echo 'en_US.UTF-8 UTF-8' >> /etc/default/libc-locales
  echo 'de_AT.UTF-8 UTF-8' >> /etc/default/libc-locales

  xbps-reconfigure -f glibc-locales
  passwd

  echo 'nofsck="yes"' >> /etc/dracut.conf.d/zol.conf
  echo 'add_dracutmodules+=" zfs "' >> /etc/dracut.conf.d/zol.conf
  echo 'omit_dracutmodules+=" btrfs "' >> /etc/dracut.conf.d/zol.conf
  #echo 'install_items+=" /etc/zfs/zroot.key "' >> /etc/dracut.conf.d/zol.conf
  
  xbps-install -S zfs

  zfs set org.zfsbootmenu:commandline="quiet loglevel=4" zroot/ROOT
  #zfs set org.zfsbootmenu:keysource="zroot/ROOT/${ID}" zroot

  mkfs.vfat -F32 "$BOOT_DEVICE"

  echo '$( blkid | grep "$BOOT_DEVICE" | cut -d ' ' -f 2 ) /boot/efi vfat defaults 0 0' >> /etc/fstab

  mkdir -p /boot/efi
  mount /boot/efi

  xbps-install -S curl

  mkdir -p /boot/efi/EFI/ZBM
  curl -o /boot/efi/EFI/ZBM/VMLINUZ.EFI -L https://get.zfsbootmenu.org/efi
  cp /boot/efi/EFI/ZBM/VMLINUZ.EFI /boot/efi/EFI/ZBM/VMLINUZ-BACKUP.EFI

  xbps-install efibootmgr

  efibootmgr -c -d "$BOOT_DISK" -p "$BOOT_PART" \
    -L "ZFSBootMenu (Backup)" \
    -l \\EFI\\ZBM\\VMLINUZ-BACKUP.EFI

  efibootmgr -c -d "$BOOT_DISK" -p "$BOOT_PART" \
    -L "ZFSBootMenu" \
    -l \\EFI\\ZBM\\VMLINUZ.EFI

EOCHROOT

umount -n -R /mnt
zpool export zroot
reboot

}


# greeting
clear
printf "${green}"
printf "############################\n"
printf "Void - ZFS - Installer\n"
printf "############################${reset}\n"

printf "This Script is for ${blue}EFI${reset} Systems.\n"
printf "Logs are at ${blue}$LOGFILE${reset}\n\n"

#cv check
printf "Run as root? "
rootcheck && ok || failexit
printf "Checking connection. "
networkcheck && ok || failexit
printf "Confirming EFI status. "
eficheck && ok || failexit

printf "Configuring live Environment. "
source /etc/os-release
export ID="$ID"
zgenhostid -f 0x00bab10c
select_drive
define_disk_variables
echo $BOOT_DEVICE

wipe_partitions
create_partitions
create_initfs
verify_and_update
install_void