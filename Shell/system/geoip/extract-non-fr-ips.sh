#!/bin/bash
#
# Filename : extract-non-fr-ips.sh
# Version  : 1.0.3
# Author   : Olivier Renard
# Contrib  : 
# Description : Extract IPs from bruteforcestop mass mails notifiactions
#  . 1.0.3
#   \_ Retrieve and update SVN script-admins ip_to_ban.txt file with subversion
#   \_ Launch vim with paste option to paste multiple bfstop email resume
#  . 1.0.2
#   \_ Update GeoIP.dat after first install
#   \_ Create log directories tree if doesn't exist
#   \_ Create report directories tree if doesn't exist
#   \_ Add geoip-bin package in install command
#  . 1.0.1
#   \_ check function for geoIp installation
#  . 1.0.0
#   \_ first release
#       \_ Open a file where user must paste multi-selection email resume
#       \_ Parse this file and search each lines starting with "http" and retrieve each banned IP
#       \_ Check where each banned IP comes from and keep it if country code is different from "FR" (France)

REPORT_DIR="/root/scripts/shell/geoip/reports"
REPORT_MAIL="mail-report.log"
REPORT_IP="ips.log"

SVN_DIR="/root/svn"
SVN_BAN="${SVN_DIR}/Banned"
SVN_IP_FILE="${SVN_BAN}/ip_to_ban.txt"


log() {
    LOGFILE="/var/log/admin/security/bfs-geoip.log"
    [[ ! -d $(dirname ${LOGFILE}) ]] && mkdir -p $(dirname ${LOGFILE})
    echo "$(date +"%Y-%m-%d %H:%M:%S") :: " ${1} | tee -a ${LOGFILE}
}

updateGeoip() {
    cd /usr/share/GeoIP && \
    wget -q http://geolite.maxmind.com/download/geoip/database/GeoLiteCountry/GeoIP.dat.gz && \
    mv GeoIP.dat GeoIP.old && \
    gunzip GeoIP.dat.gz
}

check_packages() {
    INSTALL_PKGS=""
    # geoip
    if [[ -z $(dpkg -l | grep "^ii  geoip-database") ]]; then
        INSTALL_PKGS="${INSTALL_PKGS} geoip-database libgeoip1"
    fi

    # subversion
    if [[ -z $(dpkg -l | grep -E "^ii  subversion") ]]; then
        INSTALL_PKGS="${INSTALL_PKGS} subversion"
    fi

    if [[ -n ${INSTALL_PKGS} ]]; then
      log "Install ${INSTALL_PKGS}"
      aptitude install -y ${INSTALL_PKGS}
      updateGeoip
    fi
}

get_svn_banned_ip() {
    [[ -z $(dpkg -l | grep -E "^ii[[:blank:]]+subversion") ]] && aptitude install -y subversion
    if [[ ! -d ${SVN_DIR} ]]; then
        log "Checking out SVN banned ip"
        mkdir -p ${SVN_DIR}
        cd ${SVN_DIR}
        svn co https://svn.code.sf.net/p/admin-scripts/code/trunk/Banned
    else
        log "Updating SVN banned ip"
        #cd ${SVN_BAN}
        svn up ${SVN_IP_FILE}
    fi
}

add_svn_banned_ip() {
    NB_IP="$(cat ${REPORT_DIR}/${REPORT_IP} | wc -l) IPs added"
    cat ${REPORT_DIR}/${REPORT_IP} >> ${SVN_IP_FILE}
    cd ${SVN_BAN}
    svn ci -m "${NB_IP}" --username "scriptsadm" --password "lhh28mo;" --no-auth-cache ip_to_ban.txt
    #svn ci ${SVN_IP_BAN}
    log "${NB_IP}"
}

check_packages
#update_geoip_db

get_svn_banned_ip

[[ -f ${REPORT_DIR}/${REPORT_MAIL} ]] && rm ${REPORT_DIR}/${REPORT_MAIL}
vi "+set paste" ${REPORT_DIR}/${REPORT_MAIL}

log "Retrieve IPs from mails selection"
IPS=$(grep -E "^[ ]*http.*$" ${REPORT_DIR}/${REPORT_MAIL} | cut -d"=" -f2)

log "Parse found IPs"
[[ -f ${REPORT_DIR}/${REPORT_IP} ]] && rm ${REPORT_DIR}/${REPORT_IP}
for IP in ${IPS}; do
    IPLOOKUP=$(geoiplookup ${IP})
    if [[ -z $(echo ${IPLOOKUP} | grep "FR") ]]; then
        echo ${IP} >> ${REPORT_DIR}/${REPORT_IP}
    fi
done

add_svn_banned_ip

#cat ${REPORT_DIR}/${REPORT_IP} >> ${LOGFILE}
#echo "Report file : ${REPORT_DIR}/${REPORT_IP}"

# Ok, c'est moche, mais ca permet de se retrouver plus facilement dans les logs...
echo -e "------------------------------" >> ${LOGFILE}