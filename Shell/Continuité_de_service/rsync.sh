#!/bin/sh

if [ 0 -eq $# ]; then
    echo "Usage: $0 <directory>"
    exit 0
fi

if [ -f /tmp/backup.lock ]; then
    echo "Backup already in progress..."
    exit 1
else
    touch /tmp/backup.lock
    for dir in $*; do
        rsync -e 'ssh -p 6622' -avrog --delete root@172.31.0.132:$dir/ /$dir
    done
fi
rm -f /tmp/backup.lock
exit 0
