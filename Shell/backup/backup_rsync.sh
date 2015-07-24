#!/bin/bash
#
# Filename : backup_rsync.sh
# Version  : 1.2
# Author   : Olivier Renard
# Contrib  :
# Description : Rsync websites files and database over SSH
#  . 
#  .
#

BKP_START=$(date "+%s")

#######################
## Variables a editer
#######################

SSH_HOST=""
SSH_USER=""
SSH_PORT=""

BKP_WWW="1"
BKP_SQL="1"

WWW_USER=""
## Definitions optionnelles
WWW_DIR=""
BKP_ADDITIONAL=""

SQL_HOST="localhost"
SQL_USER=""
SQL_PASS=""
SQL_DB=""

EMAIL_DEST=""

#######################
## Variables determinees automatiquement
#######################

PROD_HOSTNAME="$(uname -n | cut -d"." -f1)"
PROD_IP="$(/sbin/ifconfig eth0 | grep 'inet ' | awk '{print $2}' | cut -d: -f2)"

## Trick pour definir un repertoire distant distinct au nom de la DB dans le cas ou une DB seule doit etre sauvegardee (ou en complement de celle d'un site deja sauvegarde)
if [[ ${BKP_WWW} == 0 ]] && [[ ${BKP_SQL} == 1 ]]; then
  SITE_NAME=${SQL_DB}
else
  SITE_NAME=${WWW_USER}
fi
REMOTE_DIR="/home/${SSH_USER}/${PROD_HOSTNAME}/${SITE_NAME}"

BKP_DIR="/home/backup/${WWW_USER}"
BKPED_DIR="/home/${WWW_USER}"

BKP_SIZE=$(du -sh ${BKPED_DIR}/${WWW_DIR} | awk '{print $2 " : " $1}')
if [[ -n ${BKP_ADDITIONAL} ]]; then
    BKP_SIZE_ADD=$(du -sh ${BKPED_DIR}/${BKP_ADDITIONAL} | awk '{print $2 " : " $1}')
fi

LOCAL_SPACE=$(df -h /home/ | sed -e '1d' | awk '{print "\n\t\t- Espace disponible\t: " $4 "/" $2 "\n\t\t- Occupation\t\t\t: " $5}')

## Pour mettre la date du backup a hier si il est au plus tot minuit et au plus tard 9.00!
if [[ $(date +%k) -ge 0 ]] && [[ $(date +%k) -le 9 ]]; then
    BKP_DATE=$(date --date="1 day ago" +%Y%m%d)
else
    BKP_DATE=$(date +%Y%m%d)
fi

##########################################
## !! NEVER EDIT MANUALLY BKP_RELEASE !! #
##########################################
BKP_RELEASE=1

#######################################
## ssh / rsync functions
#######################################
ssh_cmd() {
    ssh -p ${SSH_PORT} ${SSH_USER}@${SSH_HOST} "${1}"
}

rsync_cmd() {
    rsync -arvz --delete --exclude="*sess_*" -e "ssh -p ${SSH_PORT}" "${1}" "${2}"
}

#######################################
## Functions
#######################################
usage() {
    echo "?! SURPRISE !?"
    exit 1
}

log() {
    LOGFILE="/var/log/admin/backup/${SITE_NAME}.log"
    [[ ! -d $(dirname ${LOGFILE}) ]] && mkdir -p $(dirname ${LOGFILE})
    echo "$(date +"%Y-%m-%d %H:%M:%S") :: " ${1} | tee -a ${LOGFILE}
}

test_error() {
    if [[ ${?} != 0 ]] || [[ ${CODE} == 13 ]]; then
        case ${CODE} in
            1) PB="Synchronisation du site";;
            2) PB="Export BDD";;
            3) PB="Synchronisation de la BDD";;
            4) PB="Synchronisation du repertoire additionnel";;
            5) PB="Suppression fichiers locaux";;
            6) PB="Variables non definies";;
            7) PB="Variables SQL non definies";;
            *)exit 2;;
        esac
        echo -e "PROBLEME SUR ${PROD_HOSTNAME} (${PROD_IP}) POUR ${SITE_NAME}" \
        "\nPB niveau ${CODE} > ${PB}\n\nInformations :\n\nOccupation disque : "${LOCAL_SPACE} \
        "\n\nTaille du repertoire a sauvegarder : "${BKP_SIZE} | \
        mail -s "[WARNING] Backup.(1) site ${SITE_NAME}" ${EMAIL_DEST}
        exit 1
    fi
    GLOBAL_RETURN=$(expr ${GLOBAL_RETURN} + $?)
}

check_install() {
    ## Check pour les logiciels si c'est la premiere execution du script
    ## Voir si il ne faut pas installer/reconfigurer Postfix pour l'envoi des emails
    #### dpkg-reconfigure postfix
    if [[ ${BKP_RELEASE} -eq 1 ]]; then
        ## rsync
        [[ -z $(dpkg -l | grep rsync) ]] \
        && echo "Installing rsync, please wait..." \
        && aptitude install -y rsync > /dev/null
    fi
}

check_variables() {
    # Test si les variables sont bien definies
    if [[ -z ${SSH_USER} ]] || [[ -z ${SSH_PORT} ]] || [[ -z ${SSH_HOST} ]] \
    || [[ -z ${WWW_USER} ]] || [[ -z ${EMAIL_DEST} ]] \
    || [[ -z ${BKP_WWW} ]] || [[ -z ${BKP_SQL} ]]; then
        CODE="6"
        test_error ${CODE}
    fi
    # Si backup BDD Alors verifier les variables sql
    if [[ ${BKP_SQL} == 1 ]]; then
        if [[ -z ${SQL_USER} ]] || [[ -z ${SQL_PASS} ]] || [[ -z ${SQL_DB} ]]; then
            CODE="7"
            test_error ${CODE}
        fi
    fi
}

check_folders() {
    ## creation de l'arborescence locale si necessaire
    [[ ! -d "${BKP_DIR}" ]] && mkdir -p "${BKP_DIR}"

    ## creation de l'arborescence distante si necessaire
    log "Checking for remote foleders"
    ssh_cmd "[[ ! -d ${REMOTE_DIR} ]] && mkdir -p ${REMOTE_DIR}"
}

rsync_site() {
    ## Pour exploiter la meme fonction 2 fois si 2 dossiers sont a backup ("WWW_DIR" & "BKP_ADDITIONAL")
    if [[ -z ${1} ]]; then
        local LOCAL_DIR="/home/${WWW_USER}/${WWW_DIR}"
        CODE="1"
    else
        local LOCAL_DIR="/home/${WWW_USER}/${BKP_ADDITIONAL}"
        CODE="4"
    fi
    
    ## rsync local to remote
    log "Starting synchro to remote dir for ${LOCAL_DIR}"
    rsync_cmd "${LOCAL_DIR}" "${SSH_USER}@${SSH_HOST}:${REMOTE_DIR}" >> ${LOGFILE}
    test_error ${CODE}
}

backup_db() {
    ## Dump de la base de donnee
    CODE="2"
    log "Database dump"
    mysqldump -h${SQL_HOST} -u${SQL_USER} -p${SQL_PASS} --single-transaction ${SQL_DB} \
        > ${BKP_DIR}/${SQL_DB}.sql
    test_error ${CODE}

    ## rsync du dump de la base de donnee
    CODE="3"
    local LOCAL_DIR="${BKP_DIR}/${SQL_DB}.sql"
    log "Sarting synchro to remote dir for ${LOCAL_DIR}"
    rsync_cmd "${LOCAL_DIR}" "${SSH_USER}@${SSH_HOST}:${REMOTE_DIR}" >> ${LOGFILE}
    test_error ${CODE}

    ## suppression de la base de donnee
    CODE="5"
    log "Delete local files"
    rm ${BKP_DIR}/*
    test_error ${CODE}
}

## Fonction qui permet de definir la valeur par defaut a saisir pour l'execution du script de compression sur le serveur de sauvegarde
prepare_crontab() {
    LAST_CRON=$(ssh_cmd "~/.scripts/get_last_crontab.sh")
    read -p "A quelle heure executer le script de compression sur itbackup [${LAST_CRON}] : " CRON_TIME
    [[ -z ${CRON_TIME} ]] && CRON_TIME=${LAST_CRON}
    ssh_cmd "echo '${CRON_TIME} * * * root /root/scripts/backups/backup_compress_site.sh \"${PROD_HOSTNAME}\" \"${SITE_NAME}\" &> /dev/null' >> /tmp/backup_add_crontab.txt"
}

## Fonction permettant de recuperer les activites rsync logguees lors de chaque execution du script
rsync_activity() {
    LAST_LINE=$(grep -n "^-----------------------.*" ${LOGFILE} | tail -n 1 | cut -d":" -f1)
    if [[ -n ${LAST_LINE} ]]; then
        ACTIVITIES=$(awk 'NR > '${LAST_LINE} ${LOGFILE})
    else
        ACTIVITIES=$(cat ${LOGFILE})
    fi
    echo "${ACTIVITIES}" > ${BKP_DIR}/${BKP_DATE}-rsync_activity.txt
    rsync_cmd "${BKP_DIR}/${BKP_DATE}-rsync_activity.txt" "${SSH_USER}@${SSH_HOST}:${REMOTE_DIR}" >> ${LOGFILE}
    rm ${BKP_DIR}/${BKP_DATE}-rsync_activity.txt
}

## Envoi via rsync sur le serveur de sauvegarde des informations relatives au serveur en production (infos sys + infos rsync)
rsync_success() {
    rsync_activity
    if [[ ${BKP_WWW} == "0" ]] && [[ ${BKP_SQL} == "1" ]]; then
        MAIL_BODY="La synchro \"BDD\""
    elif [[ ${BKP_WWW} == "1" ]] && [[ ${BKP_SQL} == "0" ]]; then
        MAIL_BODY="La synchro \"site\""
    else
        MAIL_BODY="Les synchros \"site\" et \"BDD\""
    fi
    MAIL_BODY="${MAIL_BODY} de ${SITE_NAME} sur ${PROD_HOSTNAME} (${PROD_IP}) sont [OK]"
    MAIL_BODY="${MAIL_BODY}\n\nInformations Production :"
    MAIL_BODY="${MAIL_BODY}\n\n\tOccupation disque : ${LOCAL_SPACE}"
    if [[ -z ${BKP_ADDITIONAL} ]]; then
        MAIL_BODY="${MAIL_BODY}\n\n\tTaille du repertoire a sauvegarder :\n\t\t${BKP_SIZE}"
    else
        MAIL_BODY="${MAIL_BODY}\n\n\tTaille des repertoires a sauvegarder : "
        MAIL_BODY="${MAIL_BODY}\n\t\t${BKP_SIZE}"
        MAIL_BODY="${MAIL_BODY}\n\t\t${BKP_SIZE_ADD}"
    fi
    MAIL_BODY="${MAIL_BODY}\n\n\tDuree de la synchronisation : $(expr ${BKP_END} - ${BKP_START}) sec(s)"
    MAIL_BODY="${MAIL_BODY}\n\n------------------------------------------------------------\n\n"
    echo "${MAIL_BODY}" > "${BKP_DIR}/${BKP_DATE}-rsync_status.txt"
    rsync_cmd "${BKP_DIR}/${BKP_DATE}-rsync_status.txt" "${SSH_USER}@${SSH_HOST}:${REMOTE_DIR}" >> ${LOGFILE}
    rm ${BKP_DIR}/${BKP_DATE}-rsync_status.txt
}

########################
## MAIN
########################

check_variables

check_install

check_folders

if [[ ${BKP_WWW} == 1 ]]; then
    rsync_site
    [[ ! -z ${BKP_ADDITIONAL} ]] && rsync_site "ADD"
fi

if [[ ${BKP_SQL} == 1 ]]; then
    backup_db
fi

[[ ${BKP_RELEASE} == 1 ]] \
    && prepare_crontab \
    && sed -i 's/^\(BKP_RELEASE=\)./\10/g' "$(dirname $0)/$(basename $0)" \
    && test_error ${CODE}


[[ ${GLOBAL_RETURN} -eq 0 ]] && BKP_END=$(date "+%s") && rsync_success

# Ok, c'est moche, mais ca permet d'exploiter facilement les logs
echo -e "------------------------------" >> ${LOGFILE}