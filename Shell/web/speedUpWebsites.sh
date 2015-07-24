#!/bin/bash
#
# Filename : speedUpWebsites.sh
# Version  : 1.0
# Author   : mathieu androz
# Contrib  :
# Description :
#  . Install Mod_cache sur Debian + configuration
#  . Install Mod_expires sur Debian + configuration



usage() {
    echo "
    Usage :
    . Install Mod-Evasive sur Debian + configuration
    . Install Mod_expires sur Debian + configuration
    "
    exit 1
}


log() {
    LOGFILE="/var/log/admin/admin.log"
    [[ ! -d $(dirname ${LOGFILE}) ]] && mkdir -p $(dirname ${LOGFILE})
    echo "$(date +%Y%m%d-%H:%M:%s) :: " ${1} | tee -a ${LOGFILE}
}

installPackage() {
        if [[ $(dpkg -l | grep "${1}" | awk '{print $1}') != "ii" ]]; then
                apt-get -y -q install "${1}" &> /dev/null
                log "Installation du package ${1}"
        fi
}


##################
#
#     MAIN
#
##################

APACHEDIR="/etc/apache2"

echo "--------------------------"
echo "-- Mod cache for Apache --"
echo "--------------------------"

if [[ ! -h ${APACHEDIR}/mod-enabled/cache.load ]] ; then
    a2enmod cache
fi

if [[ ! -h ${APACHEDIR}/mod-enabled/disk_cache.load ]] ; then
    a2enmod disk_cache
    # Insert to line 20 in disk_cache.conf
    sed -i '20iCacheEnable disk /' ${APACHEDIR}/mod-enabled/disk_cache.conf
fi

if [[ ! -h ${APACHEDIR}/mod-enabled/mem_cache.load ]] ; then
    a2enmod mem_cache
fi

echo "--------------------------"
echo "-- Mod expires for Apache --"
echo "--------------------------"

if [[ ! -h ${APACHEDIR}/mod-enabled/expires.load ]] ; then
    a2enmod expires
fi

echo "Add these lines in each virtualhosts :

ExpiresActive On
ExpiresDefault \"access plus 1 month\"
"

service apache2 restart


# Ok, c'est moche, mais ca permet de se retrouver plus facilement dans les logs...
#log "------------------------------"

exit 0
