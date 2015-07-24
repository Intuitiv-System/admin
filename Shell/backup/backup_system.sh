#!/bin/bash
#
# Filename : backup_system.sh
# Version  : 1.3
# Author   : Olivier Renard
# Contrib  : Mathieu Androz
# Description : Backup system files defined in BKP_DIRS
# 1.3
#   `_ Fix mail
#   `_ Purge old backups
#   `_ Fiw apache2, mysql and fail2ban backups... again !
# 1.2
#   `_ Add Postfix backup
#   `_ Fix BKP_DIR creation
#   `_ Complete email
# 1.1
#   `- Fix apache2, mysql and fail2ban backups
#   `- Add /etc/crontab in the backup
#   `- Check/Install ncftp if not
#   `- Fix compress_all() function
# 1.0
#   `- Backup specifics services on live servers
# TODO
#   `- Change transfert method to rsync over SSH

#######################
## Variables a editer
#######################

FTP_USER=""
FTP_PWD=""
FTP_HOST=""

EMAIL_DEST=""

BKP_DIR="/home/backup/local_system"
BKP_DEST="${BKP_DIR}/local_system"

#######################
## Variables determinees automatiquement
#######################

PROD_HOSTNAME="$(hostname | cut -d"." -f1)"
PROD_IP="$(/sbin/ifconfig eth0 | grep "inet " | awk '{print $2}' | cut -d: -f2)"

FTP_DIR="${PROD_HOSTNAME}/conf_sys"

if [[ $(date +%k) -ge 0 ]] && [[ $(date +%k) -le 9 ]]; then
    DATE_FR=$(date --date="1 day ago" +%Y%m%d)
else
    DATE_FR=$(date +%Y%m%d)
fi

BKP_FILE="${PROD_HOSTNAME}-confs-${DATE_FR}.tar.gz"

#######################################
## Functions for FTP actions
#######################################
open_ftp() {
    ncftp -u ${FTP_USER} -p ${FTP_PWD} ${FTP_HOST}
}

list_ftp() {
    DIR=${1}
    ncftpls -l -u ${FTP_USER} -p ${FTP_PWD} ftp://${FTP_HOST}/${DIR}
}

make_ftp_dir() {
    DIR=${1}
    open_ftp > /dev/null <<EOF
mkdir ${DIR}
bye
EOF
}

#######################################
## Functions
#######################################

usage() {
    ::
}

log() {
    LOGFILE="/var/log/admin/admin.log"
    if [[ ! -d $(dirname ${LOGFILE}) ]]; then
        mkdir $(dirname ${LOGFILE})
    fi
    echo "$(date +"%Y-%m-%d") :: " ${1} | tee -a ${LOGFILE}
}

check_install() {
    if [[ $(dpkg -l | grep "ncftp" | cut -d" " -f1) != "ii" ]]; then
        aptitude -q -y install ncftp &> /dev/null
    fi
}

populate_ftp_tree() {
    [[ ! -d ${BKP_DEST} ]] && mkdir -p ${BKP_DEST}

    FTP_LS=$(list_ftp "${PROD_HOSTNAME}")
    if [[ -z $(echo ${FTP_LS} | grep "${PROD_HOSTNAME}") ]]; then
        make_ftp_dir ${PROD_HOSTNAME}
    fi

    FTP_LS=$(list_ftp "${PROD_HOSTNAME}")
    if [[ -z $(echo ${FTP_LS} | grep "conf_sys") ]]; then
        make_ftp_dir ${FTP_DIR}
    fi
}
backup_success() {
        SUCCESS=${?}
        if [[ ${SUCCESS} -eq 0 ]]; then
                RESULT="DONE"
        else
                RESULT="null"
        fi
}

backup_apache2() {
    [[ -d /etc/apache2 ]] && mkdir ${BKP_DEST}/apache2 && cp -R /etc/apache2/* ${BKP_DEST}/apache2/
    backup_success && log "Copy Apache2 directory : ${RESULT}"
}

backup_mysql() {
    [[ -d /etc/mysql ]] && mkdir ${BKP_DEST}/mysql && cp -R /etc/mysql/* ${BKP_DEST}/mysql/
    backup_success && log "Copy MySQL directory : ${RESULT}"
}

backup_fail2ban() {
    [[ -d /etc/fail2ban ]] && mkdir ${BKP_DEST}/fail2ban && cp -R /etc/fail2ban/* ${BKP_DEST}/fail2ban/
    backup_success && log "Copy Fail2ban directory : ${RESULT}"
}

backup_fw_initd() {
    [[ -f /etc/init.d/firewall ]] && [[ ! -d "${BKP_DEST}/init.d" ]] && mkdir -p "${BKP_DEST}/init.d"
    [[ -f /etc/init.d/firewall ]] && cp /etc/init.d/firewall ${BKP_DEST}/init.d/
    backup_success && log "Copy init.d firewall file : ${RESULT}"
}

backup_crontab() {
    [[ -d /var/spool/cron/crontabs/ ]] && cp -R /var/spool/cron/crontabs/ ${BKP_DEST}/
    [[ -f /etc/crontab ]] && cp /etc/crontab ${BKP_DEST}
    backup_success && log "Copy crontab directory : ${RESULT}"
}

backup_postfix() {
        [[ -d /etc/postfix ]] && mkdir ${BKP_DEST}/postfix && cp -R /etc/postfix/* ${BKP_DEST}/postfix/
        backup_success && log "Copy Postfix directory : ${RESULT}"
}

compress_all() {
    cd ${BKP_DIR}
    tar czf ${BKP_FILE} $(basename ${BKP_DEST})
    backup_success && log "Compress system directoties : ${RESULT}"
}

put_ftp() {
    #for file in ${BKP_DIR}/*.tar.gz; do
    ncftpput -u ${FTP_USER} -p ${FTP_PWD} ${FTP_HOST} ${FTP_DIR}/${FTP_DEST} ${BKP_DIR}/${BKP_FILE}
    log "Send ${BKP_FILE} to FTP : ${?}"
    F=$(tail -n 1 ${LOGFILE})
    FTP_STATUS=${F#${F%?}}
    [[ ${FTP_STATUS} == 0 ]] && log "" && mail_success
    #done
}

local_purge() {
        if [[ -d ${BKP_DEST} ]]; then
                rm -rf ${BKP_DEST}
        fi
        if [[ -f ${BKP_DIR}/${PROD_HOSTNAME}-confs-$(date --date="1 day ago" +%Y%m%d).tar.gz ]]; then
                rm ${BKP_DIR}/${PROD_HOSTNAME}-confs-$(date --date="1 day ago" +%Y%m%d).tar.gz
        fi
}

resume_extract() {
        BKP_DATE=$(date +"%Y-%m-%d")
        BKP_RESUME=$(sed '/^'${BKP_DATE}' ::  Execution of backup_system.sh/,/'${BKP_DATE}' ::$/!d' ${LOGFILE})
}

mail_success() {
    resume_extract
    echo -e "Le resume de la sauvegarde des configurations systemes sur ${PROD_HOSTNAME} (${PROD_IP})" \
    "\n\nListe des dossiers sauvegardes :\n\n$(ls ${BKP_DEST})" \
    "\n\n${BKP_RESUME}" | \
    mail -s "Resume Backup configs ${PROD_HOSTNAME}" ${EMAIL_DEST}
}

##################
#
#     MAIN
#
##################

log ""
log "Execution of backup_system.sh"

local_purge

check_install

populate_ftp_tree

backup_apache2

backup_mysql

backup_fail2ban

backup_fw_initd

backup_crontab

backup_postfix

compress_all

put_ftp

exit 0
