#!/usr/bin/sh
#This script saves the most important data to google drive.
#Everyting is encrypted using my yubikey.

#First synchronize all truly important folders to the ~/gdrive directory.
#I am no backing up config files as they are stored on github anyways, neither am I backing up system data as that can easily be replaced.
set -euo pipefail

mkdir -p "$HOME"/gdrive-backup-unencrypted/{archives,data}

rsync -ah --progress --delete "$HOME/Documents" "$HOME/gdrive-backup-unencrypted/data"
echo "Synchronized data"
fullBackup=0
if [ ! -f "$HOME/gdrive-backup-unencrypted/counter" ]; then
    echo "Could not find counter file, a full backup will be created"
    fullBackup=1
else
    if [ $(cat "$HOME/gdrive-backup-unencrypted/counter") -gt 7 ]; then
        echo "Reached limit for incremental backup, creating full backup"
        fullBackup=1
    else
        if [ ! -f "$HOME/gdrive-backup-unencrypted/incremental.snar" ]; then
            echo "incremental.snar does not exist, doing full backup"
            fullBackup=1
        fi
    fi
fi

if [ $fullBackup -eq 1 ]; then
    rm -f "$HOME/gdrive-backup-unencrypted/incremental.snar"
    echo 0 >"$HOME/gdrive-backup-unencrypted/counter"
fi
DATE=$(date '+%Y-%m-%d-%H-%M')
echo "Timestamp = $DATE"

cd "$HOME/gdrive-backup-unencrypted"
COUNTER=$(($(cat counter) + 1))
echo "Creating archive and encrypting to myself"
tar -cg incremental.snar -f - data | gpg -er 41BA008ED4859A28DFB838D0B94070CB29B3F0FB | pv >"archives/$DATE.$COUNTER.tar.xz.gpg"

echo "Incrementing counter"
echo "$COUNTER" >counter
echo "Finished archiving."
echo "Synchronizing created archive to drive folder"
if [ ! -d "$HOME/gdrive/Backup" ]; then
    echo "Error,gdrive/Backup not found. Please set it up and synchronize manually"
    exit 1
fi

cp "archives/$DATE.$COUNTER.tar.xz.gpg" "$HOME/gdrive/Backup"
cd "$HOME/gdrive"
drive push Backup
echo "Finished"
