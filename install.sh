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

    read -p "Please enter the path of the desired Disk for your new System: " SYSTEMDISK &&
    echo -e "${red}This will start the installation on "$SYSTEMDISK". ${reset}"
    while true; do
        read -p "Are you sure? [y/n]" YN
        case $YN in
            [Yy]* )  break; echo"done";;
            [Nn]* )  echo "you selected no"; exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}



# greeting
clear
printf "${green}"
printf "############################\n"
printf "Void - ZFS - Installer\n"
printf "############################${reset}\n"

printf "This Script is for ${blue}EFI${reset} Systems.\n"
printf "Logs are at ${blue}$LOGFILE${reset}\n\n"

# check
printf "Run as root? "
rootcheck && ok || failexit
printf "Checking connection. "
networkcheck && ok || failexit
printf "Confirming EFI status. "
eficheck && ok || failexit

printf "Configuring live Environment. "
#source /etc/os-release
#export ID="$ID"
#zgenhostid -f 0x00bab10c
select_drive
