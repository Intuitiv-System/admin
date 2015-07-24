#!/bin/bash
#
# Filename : backup_compression.sh
# Version  : 1.1
# Author   : Olivier Renard
# Contrib  : Mathieu Androz
# Contrib  : 
# Description : Compress *.sql & dirs from rsyncit/${HOST_NAME}/${SITE_NAME} to ${BKP_USER}/${HOST_NAME}/${SITE_NAME}
#  1.1
#   |__ Exclude release files in delete_old() function
#   |__ Remove user and add BKP_USER variable
#   |__ Chown with good user/group : site/mysql/release folders in check_paths() function
# 
#

clear

## Variables ##

HOST_NAME="${1}"
SITE_NAME="${2}"
EMAIL_TO=""
BKP_RETENTION=15
# Owner of backuped files on the backup server
BKP_USER=""

## Do not edit variables below ##

RSYNC_PATH="/home/rsyncit/${HOST_NAME}/${SITE_NAME}"
BKP_PATH="/home/${BKP_USER}/${HOST_NAME}/${SITE_NAME}"
RSYNC_REPORT="/tmp/${HOST_NAME}-${SITE_NAME}-rsync.txt"

## Definition de la date a J pour les tests et J-1 pour la prod
# if [[ -n $(echo ${HOST_NAME} | grep "test") ]]; then
    # Date d'aujourd'hui (tests)
    # BKP_DATE=$(date  "+%Y%m%d")
# else
    # Date d'hier (prod)
    # BKP_DATE=$(date --date="1 day ago" "+%Y%m%d")
# fi

## Pour mettre la date du backup a hier si il est au plus tot minuit et au plus tard 9.00!
if [[ $(date +%k) -ge 0 ]] && [[ $(date +%k) -le 9 ]]; then
    BKP_DATE=$(date --date="1 day ago" +%Y%m%d)
else
    BKP_DATE=$(date +%Y%m%d)
fi

GLOBAL_RETURN=0

#################
#               #
#   Functions   #
#               #
#################

usage() {
    ::
}

log() {
    LOGFILE="/var/log/admin/backup/${HOST_NAME}-${SITE_NAME}.log"
    [[ ! -d $(dirname ${LOGFILE}) ]] && mkdir -p $(dirname ${LOGFILE})
    echo "$(date "+%Y%m%d - %H:%M") :: ${1}" | tee -a ${LOGFILE}
}

test_error() {
    if [[ ${?} != "0" ]] || [[ ${CODE} == "7" ]] || [[ ${CODE} == "9" ]]; then
        case ${CODE} in
            1) PB="Creation de ${BKP_PATH}/release echouee";;
            2) PB="Creation de ${BKP_PATH}/mysql echouee";;
            3) PB="Creation de ${BKP_PATH}/site echouee";;
            4) PB="Renommer 'www' en 'site' echoue";;
            5) PB="Compression de ${FILE_NAME} echouee";;
            6) PB="Renommer 'site' en 'www' echoue";;
            7) PB="Pas de synchro realisee (verifier /etc/cron sur ${HOST_NAME}";;
            8) PB="Suppression anciennes archives";;
            9) PB="Aucun parametres passes au script!";;
            *) PB="Erreur inconnue!";;
        esac
        echo -e "PROBLEME SUR '${BKP_USER}' POUR '${HOST_NAME}/${SITE_NAME}'" \
        "\nPB niveau ${CODE} > ${PB}" | \
        mail -s "[WARNING - TEST] Backup.(2) site ${HOST_NAME}/${SITE_NAME}" "${EMAIL_TO}"
        exit 1
    fi
    GLOBAL_RETURN=$(expr ${GLOBAL_RETURN} + $?)
}

check_paths() {
    if [[ -z ${HOST_NAME} ]] || [[ -z ${SITE_NAME} ]]; then
        CODE=9
        test_error
    fi

    ## Si BKP_RELEASE=0 alors il n'y a pas encore de sauvegardes effectuees pour ${HOST_NAME}/${SITE_NAME}
    BKP_RELEASE=$(ls ${BKP_PATH}/release | wc -l)
    
    if [[ ! -d "${BKP_PATH}/release" ]]; then
        CODE=1
        log "mkdir -p ${BKP_PATH}/release"
        mkdir -p "${BKP_PATH}/release"
        chown ${BKP_USER}:${BKP_USER} "${BKP_PATH}/release"
        test_error
    fi
    if [[ ! -d "${BKP_PATH}/mysql" ]]; then
        CODE=2
        log "mkdir -p ${BKP_PATH}/mysql"
        mkdir -p "${BKP_PATH}/mysql"
        chown ${BKP_USER}:${BKP_USER} "${BKP_PATH}/mysql"
        test_error
    fi
    if [[ ! -d "${BKP_PATH}/site" ]]; then
        CODE=3
        log "mkdir -p ${BKP_PATH}/site"
        mkdir -p "${BKP_PATH}/site"
        chown ${BKP_USER}:${BKP_USER} "${BKP_PATH}/site"
        test_error
    fi
}

define_variables() {
    FILE_NAME=$(echo "${FILE_PATH}" | cut -d"/" -f6)
    
    ## Si Fichier && Fichier != *.txt
    if [[ -f "${FILE_PATH}" ]] && [[ -n $(echo "${FILE_NAME}" | grep -vE "*.txt") ]]; then
        BKP_TYPE="DB"
        BKP_SUB_DIR="mysql"

    ## Ou Si Dossier
    elif [[ -d "${FILE_PATH}" ]]; then
        if [[ ${FILE_NAME} == "www" ]]; then
            BKP_TYPE="site"
        else
            BKP_TYPE=${FILE_NAME}
        fi
        BKP_SUB_DIR="site"

    fi
    
    ## Si premier backup
    [[ "${BKP_RELEASE}" == 0 ]] && BKP_SUB_DIR="release"
}

test_rsync_files() {
    CODE="7"
    if [[ -z $(ls -l ${RSYNC_PATH} | grep ".txt") ]]; then
        test_error
    fi
}

compress_datas() {
    if [[ -n "${BKP_TYPE}" ]]; then
        #log "File to backup found"
        cd "${RSYNC_PATH}"
        if [[ -d ${FILE_NAME} ]]; then
            if [[ "${FILE_NAME}" == "www" ]] || \
               [[ -n $(echo ${FILE_NAME} | grep "alfresco") ]] || \
               [[ -n $(echo ${FILE_NAME} | grep "liferay") ]]; then
                CODE=4
                FILE_ORIG=${FILE_NAME}
                log "Rename '${FILE_NAME}' to 'site'"
                mv "${FILE_NAME}" "site"
                FILE_NAME="site"
                test_error
            fi
        fi
        CODE=5
        log "Comrpession of '${FILE_NAME}' to ${BKP_PATH}/${BKP_SUB_DIR}/${BKP_DATE}-${SITE_NAME}-${BKP_TYPE}.tar.gz"
        tar czf ${BKP_PATH}/${BKP_SUB_DIR}/${BKP_DATE}-${SITE_NAME}-${BKP_TYPE}.tar.gz ${FILE_NAME}
        test_error
        
        chown ${BKP_USER}:${BKP_USER} ${BKP_PATH}/${BKP_SUB_DIR}/${BKP_DATE}-${SITE_NAME}-${BKP_TYPE}.tar.gz

        if [[ -d "${FILE_NAME}" ]] && [[ "${FILE_NAME}" == "site" ]]; then
            CODE=6
            log "Rename 'site' to 'www'"
            mv "${FILE_NAME}" "${FILE_ORIG}"
            FILE_NAME="www"
            test_error
        fi
        
    fi
}

rename_sites() {
    SITE_NAME_ALT=""
    if [[ ${SITE_NAME} == "vernaison" ]]; then
        SITE_NAME_ALT="vernaison-demat"
    fi
}

mail_success() {
    rename_sites
    
    [[ -n ${SITE_NAME_ALT} ]] && MAIL_SUBJECT=${SITE_NAME_ALT} || MAIL_SUBJECT=${SITE_NAME}
    MAIL_SUBJECT="[OK - TEST] Backup report : ${HOST_NAME}/${MAIL_SUBJECT}"

    echo -e "La compression des donnees de ${HOST_NAME}/${SITE_NAME} est [OK]" > ${RSYNC_REPORT} && \
    sed -i 's/-*\\n\\n$/\\tDuree de la compression : '$(expr ${BKP_END} - ${BKP_START})' sec(s)\\n\\n&/g' \
        ${RSYNC_PATH}/${BKP_DATE}-rsync_status.txt
    echo -e $(cat ${RSYNC_PATH}/${BKP_DATE}-rsync_status.txt) >> ${RSYNC_REPORT}

    if [[ ${BKP_RELEASE} == 0 ]]; then
        MAIL_SUBJECT=${MAIL_SUBJECT}" - RELEASE"
    else
        cat ${RSYNC_PATH}/${BKP_DATE}-rsync_activity.txt >> ${RSYNC_REPORT}
    fi
    
    cat ${RSYNC_REPORT} | mail -s "${MAIL_SUBJECT}" "${EMAIL_TO}"
}

delete_old() {
    log "Deleting ${BKP_RETENTION} days old files"
    CODE=8
    find ${BKP_PATH} -type f -not -path "*/release/*" -mtime +${BKP_RETENTION} -exec rm {} \;
    test_error
}

################
#              #
#     Main     #
#              #
################

BKP_START=$(date +%s)

check_paths

for FILE_PATH in "${RSYNC_PATH}"/*; do
    define_variables

    compress_datas
done

delete_old

BKP_END=$(date +%s)

[[ "${GLOBAL_RETURN}" == 0 ]] && mail_success

log "Deleting txt and sql files"
rm ${RSYNC_PATH}/*.txt ${RSYNC_REPORT} ${RSYNC_PATH}/*.sql

log "------------------------------"