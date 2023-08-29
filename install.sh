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


# greeting
clear
printf "${green}"
printf "############################\n"
printf "Void - ZFS - Installer\n"
printf "############################${reset}\n"

printf "This Script is for ${blue}EFI${reset} Systems.\n"
printf "Logs are at ${blue}$LOGFILE${reset}\n\n"

# checks
printf "Run as root? "
rootcheck && ok || failexit
printf "Checking connection. "
networkcheck && ok || failexit
printf "Confirming EFI status. "
eficheck && ok || failexit


