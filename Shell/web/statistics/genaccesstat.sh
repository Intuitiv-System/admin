#!/bin/bash
#
# Filename : genstat.sh
# Version  : 1.0
# Author   : mathieu androz
# Contrib  : 
# Description :
#  . Install Goaccess Apache stats analyzer
#  . Generate HTML reports from access.log files
#


LOGFILE="/var/log/admin/admin.log"

# include
. /lib/lsb/init-functions


usage() {
    ::
}

createLogrotate() {
    LOGROTATEDIR="/etc/logrotate.d"
    LOGROTATEFILE="admin"
    if [[ -d ${LOGROTATEDIR} ]]; then
        if [[ ! -f ${LOGROTATEDIR}/${LOGROTATEFILE} ]]; then
            touch ${LOGROTATEDIR}/${LOGROTATEFILE}
            chmod 644 ${LOGROTATEDIR}/${LOGROTATEFILE}
            echo -e "${LOGFILE} {\n\tweekly \
                \n\tmissingok \
                \n\trotate 52 \
                \n\tcompress \
                \n\tdelaycompress \
                \n\tnotifempty \
                \n\tcreate 640 root root
                \n}" > ${LOGROTATEDIR}/${LOGROTATEFILE}
        fi
    fi
}

log() {
    [[ ! -d $(dirname ${LOGFILE}) ]] && mkdir -p $(dirname ${LOGFILE})
    echo "$(date +%Y%m%d-%H:%M:%S) :: " ${1} | tee -a ${LOGFILE}
}

installPackage() {
    if [[ $(dpkg -l | awk '{print $1" "$2}' | grep " ${1}"$) != "ii ${1}" ]]; then
        log "Installation du package ${1}..."
        apt-get -y -q install "${1}" &> /dev/null
    else
        log "Package ${1} already installed on your system."
    fi
}


##################
#
#     MAIN
#
##################

GEOFOLDER="usr/share/GeoIP"
GOACCESS_VERSION="0.8.5"

installPackage libgeoip-dev
installPackage libncursesw5-dev
installPackage libglib2.0-dev
installPackage pkg-config

if [[ -z "${GOACCESS_VERSION}" ]]; then
  cd /tmp
  wget http://goaccess.io
  GOACCESS_VERSION=$(grep "Latest stable release" index.html | awk -F">" '{print $3}' | awk '{print $1}')
  if [[ -z "${GOACCESS_VERSION}" ]]; then
    log "Can't get Goaccess Last Version. Aborted..."
    exit 1
  fi
  rm download
fi

[[ ! -d "${GEOFOLDER}" ]] && mkdir -p "${GEOFOLDER}"
cd "${GEOFOLDER}"
wget -q http://geolite.maxmind.com/download/geoip/database/GeoLiteCountry/GeoIP.dat.gz
[[ -f GeoIP.dat ]] && mv GeoIP.dat GeoIP.old
gunzip GeoIP.dat.gz 
rm GeoIP.old

cd /opt/ && wget http://tar.goaccess.io/goaccess-"${GOACCESS_VERSION}".tar.gz
[[ -f goaccess-"${GOACCESS_VERSION}".tar.gz ]] && tar xzf goaccess-"${GOACCESS_VERSION}".tar.gz
./configure --enable-geoip --enable-utf8
make && make install

###################
#
# A FINIR !!!
# Il faut gérer en param les fichiers access.log à analyser et la destiation des résultats !
#
###################

#/usr/local/bin/goaccess --output-format=json -a --date-format="%d/%b/%Y" --log-format='%h %^[%d:%^] "%r" %s %b "%R" "%u"' -f "${ACCESSFILE}" > FILE

exit 0