#!/bin/bash
#
# Filename : migrate_backups.sh
# Version  : 1.0
# Author   : Olivier Renard
# Contrib  : 
# Description : Change backup script for enabled virtualhosts
#  . check which virtualhosts are enabled and copy the new backup script with the right name
#  . retrieve values from future old backup scripts and edit future new backup script
#  . 
#

clear

BKP_FILE_ORIG="/root/scripts/backup/backup_web.sh"
BKP_DIR="/home/backup"
BKP_OLD_SCRIPTS="${BKP_DIR}/old_scripts/$(date +%Y%m%d)"

LOG_DIR="/var/log/admin"
LOG_FILE="${LOG_DIR}/backup_migration.log"

usage() {
    ::
}

prepare_logs() {
    [[ ! -d ${LOG_DIR} ]] && mkdir -p ${LOG_DIR}
}

log() {
    [[ ${?} -gt 1 ]] && STATE="KO" || STATE="OK"
    echo $(date "+%Y-%m-%d %H:%M")" :: ${STATE} > ${1}" | tee -a ${LOG_FILE}
}

copy_backup_script() {
    # Renommer le nouveau script avec le nom du user UNIX du futur ancien script
    BKP_NAME=$(echo ${BKP_OLD_SCRIPT} | cut -d'/' -f4 | cut -d'_' -f1)
    LOOP=0
    for BKP_SCRIPT in /home/backup/*_backup.sh; do
        BKP_NAME=$(echo ${BKP_SCRIPT} | cut -d"/" -f4 | cut -d"_" -f1)
        for ENABLED_SITE in /etc/apache2/sites-enabled/*; do
            ENABLED_SITE=$(echo ${ENABLED_SITE} | cut -d"/" -f5 | cut -d"-" -f1)
            if [[ "${ENABLED_SITE}" =~ .*"${BKP_NAME}".* ]]; then
                BKP_NEW_SCRIPT="${BKP_DIR}/backup_${ENABLED_SITE}.sh"
                [[ ! -f ${BKP_NEW_SCRIPT} ]] && cp ${BKP_FILE_ORIG} ${BKP_NEW_SCRIPT}
                chmod 700 ${BKP_NEW_SCRIPT}

                update_script_details ${BKP_NEW_SCRIPT}

                update_crontab ${BKP_NEW_SCRIPT} ${LOOP}

                LOOP=$(expr ${LOOP} + 1)
            fi
        done
        [[ ! -d ${BKP_OLD_SCRIPTS} ]] && mkdir ${BKP_OLD_SCRIPTS}
        [[ -f ${BKP_SCRIPT} ]] && mv ${BKP_SCRIPT} ${BKP_OLD_SCRIPTS}

    done
}

update_script_details() {
        BKP_NEW_SCRIPT=${1}
        BKP_NAME=$(echo ${BKP_NEW_SCRIPT} | cut -d"/" -f4 | cut -d"_" -f2 | cut -d"." -f1)
        FTP_USER=$(grep -E "^FTPUSER=" /home/backup/${BKP_NAME}_backup.sh | cut -d'"' -f2)
        FTP_PWD=$(grep -E "^FTPPWD=" /home/backup/${BKP_NAME}_backup.sh | cut -d'"' -f2)
        FTP_HOST=$(grep -E "^FTPHOST=" /home/backup/${BKP_NAME}_backup.sh | cut -d'"' -f2)
        BKP_WWW=$(grep -E "^ACTIVATE_SITE=" /home/backup/${BKP_NAME}_backup.sh | cut -d'"' -f2)
        BKP_SQL=$(grep -E "^ACTIVATE_MYSQL=" /home/backup/${BKP_NAME}_backup.sh | cut -d'"' -f2)
        WWW_DIR=$(grep -E "^BACKUPED_DIR=" /home/backup/${BKP_NAME}_backup.sh | cut -d'"' -f2 | cut -d"/" -f4)
        WWW_USER=$(grep -E "^SITE_NAME=" /home/backup/${BKP_NAME}_backup.sh | cut -d'"' -f2)
        BKP_ADDITIONNAL=$(grep -E "^BACKUPED_MODULES=" /home/backup/${BKP_NAME}_backup.sh | cut -d'"' -f2 | cut -d"/" -f4)
        SQL_USER=$(grep -E "^MYSQLUSER=" /home/backup/${BKP_NAME}_backup.sh | cut -d'"' -f2)
        SQL_PASS=$(grep -E "^MYSQLPWD=" /home/backup/${BKP_NAME}_backup.sh | cut -d'"' -f2)
        SQL_DB=$(grep -E "^MYSQLDBNAME=" /home/backup/${BKP_NAME}_backup.sh | cut -d'"' -f2)
        SQL_HOST=$(grep -E "^MYSQLHOST=" /home/backup/${BKP_NAME}_backup.sh | cut -d'"' -f2)
        EMAIL_DEST=$(grep -E "^EMAIL=" /home/backup/${BKP_NAME}_backup.sh | cut -d'"' -f2)

        sed -i -e 's/^\(FTP_USER\).*/\1="'${FTP_USER}'"/g' \
               -e 's/^\(FTP_PWD\).*/\1="'${FTP_PWD}'"/g' \
               -e 's/^\(FTP_HOST\).*/\1="'${FTP_HOST}'"/g' \
               -e 's/^\(BKP_WWW\).*/\1="'${BKP_WWW}'"/g' \
               -e 's/^\(BKP_SQL\).*/\1="'${BKP_SQL}'"/g' \
               -e 's/^\(WWW_USER\).*/\1="'${WWW_USER}'"/g' \
               -e 's/^\(SQL_USER\).*/\1="'${SQL_USER}'"/g' \
               -e 's/^\(SQL_PASS\).*/\1="'${SQL_PASS}'"/g' \
               -e 's/^\(SQL_DB\).*/\1="'${SQL_DB}'"/g' \
               -e 's/^\(SQL_HOST\).*/\1="'${SQL_HOST}'"/g' \
               -e 's/^\(EMAIL_DEST\).*/\1="'${EMAIL_DEST}'"/g' ${BKP_NEW_SCRIPT}
               #-e 's/^\(WWW_DIR\).*/\1="'${WWW_DIR}'"/g' \
        [[ ! -z ${WWW_DIR} ]] && sed -i -e 's/^\(WWW_DIR\).*/\1="'${WWW_DIR}'"/g' ${BKP_NEW_SCRIPT}
        [[ ! -z ${BKP_ADDITIONNAL} ]] && sed -i -e 's/^\(BKP_ADDITIONNAL\).*/\1="'${BKP_ADDITIONNAL}'"/g' ${BKP_NEW_SCRIPT}
}

update_crontab() {
    # As many backup scripts are launched by crontab per user method, we must edit it by hands
    # However, the must be disabled with crontab -e and added in /etc/crontab
    BKP_NAME=$(echo ${1} | cut -d"/" -f4 | cut -d"_" -f2 | cut -d"." -f1)
    LOOP=${2}
    CRON_FILE="/etc/crontab"
    [[ ${LOOP} -eq 0 ]] && echo "# Backup execution" >> ${CRON_FILE}

    cat /var/spool/cron/crontabs/root | grep -E "^#[0-9]+.*backup_${BKP_NAME}.*" | \
    sed 's/^#\(.*\)/\1/g' | sed 's#\(.*\)\( /home.*\)#\1 root\2#g' >> ${CRON_FILE}
}

######## MAIN ########
prepare_logs

copy_backup_script

# Edit root's crontab in order to comment all lines concerned by backup scripts
crontab -e

exit 0