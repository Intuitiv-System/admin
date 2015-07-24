#!/bin/bash
# Execute this script with cron (/etc/crontab)
# 0 0 1,15 * * root /path/to/update_geoip_db.sh

log() {
    LOGFILE="/var/log/admin/security/update-geoip.log"
    [[ ! -d $(dirname ${LOGFILE}) ]] && mkdir -p $(dirname ${LOGFILE})
    echo "$(date +"%Y-%m-%d %H:%M:%S") :: " ${1} | tee -a ${LOGFILE}
}

update_geoip_db() {
    ## update, 1st and 15th of each month
    # DATE_D=$(date "+%d")
    # if [[ ${DATE_D} == 1 ]] || [[ ${DATE_D} == 15 ]]; then
        log "Updating GeoIP database"
        cd /usr/share/GeoIP
        wget -q http://geolite.maxmind.com/download/geoip/database/GeoLiteCountry/GeoIP.dat.gz && \
        mv GeoIP.dat GeoIP.old && \
        gunzip GeoIP.dat.gz
        rm GeoIP.old
    # fi
}

update_geoip_db