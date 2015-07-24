#!/bin/bash

cd /home/backup
mv old_scripts/$(date +%Y%m%d)/* .
rm backup_*.sh
[[ -f /tmp/test-crontab ]] && rm /tmp/test-crontab
echo "Edit /etc/crontab in order to comment lines which refers to backup scripts"