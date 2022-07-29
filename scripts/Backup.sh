#!/usr/bin/sh
#

set -euo pipefail
#I can remove the remaining error checking now
printf "Checking if backups is a mountpoint\n"
sudo mountpoint -q /backup
printf "Success\n"

DATE=$(date '+%Y-%m-%d-%H-%M')

rootName="/.snapshots/root-$DATE"
homeName="/.snapshots/home-$DATE"

printf "Taking snapshots of home and root with timestamp $DATE\n"
sudo btrfs subvolume snapshot -r /home "$homeName"
if [ $? -ne 0 ]; then
    printf "Snapshot of home failed. Please correct errors and try again\n"
    exit -1
fi
sudo btrfs subvolume snapshot -r / "$rootName"
if [ $? -ne 0 ]; then
    printf "Snapshot of root failed. Please correct errors and try again\n"
    exit -1
fi
printf "Success\n"

printf "Trying to find last snapshot for incremental backup\n"
if [ -L /.snapshots/root-last ]; then
    parentRoot="-p /.snapshots/root-last"
    printf "Found snapshot of root\n"
else
    parentRoot=''
    printf "No snapshot found of root, sending full backup\n"
fi

if [ -L /.snapshots/home-last ]; then
    parentHome="-p /.snapshots/home-last"
    printf "Found snapshot of home\n"
else
    parentHome=''
    printf "No snapshot found of home, sending full backup\n"
fi
#This should cause an error
if [ ! -d /backup/.snapshots ]; then
    printf "Directory /backup/.snapshots not found. Creating new folder\n"
    sudo mkdir /backup/.snapshots
fi

printf "\nSending backups to external drive\n"
printf "Sending root\n"
sudo btrfs send $parentRoot "$rootName" | pv | sudo btrfs receive /backup/.snapshots
if [ $? -ne 0 ]; then
    printf "Failed to send root, please fix errors and complete backup manually"
    exit -1
fi
printf "Root succeeded, writing updated information to root-last\n"
sudo rm -f /.snapshots/root-last
sudo ln -sf "$rootName" /.snapshots/root-last
printf "Sending home\n"
sudo btrfs send $parentHome "$homeName" | pv | sudo btrfs receive /backup/.snapshots
if [ $? -ne 0 ]; then
    printf "Failed to send home, please fix errors and complete backup manually\n"
    exit -1
fi
printf "Home succeeded, writing updated information to home-last\n"
sudo rm -f /.snapshots/home-last
sudo ln -sf "$homeName" /.snapshots/home-last

printf "All snapshots succeeded.\n Backing up efi directory using rsync\n"
DEST=/backup/rsync/efi
mkdir -p /backup/rsync/efi/latest
rsync -avh --progress --delete /efi "$DEST/latest"
if [ $? -ne 0 ]; then
    printf "Syncing /efi failed, exiting"
    exit -1
fi
mkdir "$DEST/$DATE"
cp -al "$DEST/latest/" "$DEST/$DATE"
printf "Backup of /efi finished.\n"
printf "Backing up ISO files. Only the latest copy is kept\n"
mkdir -p /backup/rsync/ISO
rsync -avh --progress --delete "$HOME/ISO" /backup/rsync/ISO
if [ $? -ne 0 ]; then
    printf "Failed to backup ISO files. Exiting"
    exit -1
fi
printf "Backing up of ISO files finished.\n"

#printf "Backing up Movies\n"
#mkdir -p /backup/rsync/Movies
#rsync -avh --progress --delete "$HOME/Movies" /backup/rsync/Movies
#printf "Finished Backup of Movies\n"

printf "All backups finished\n"
