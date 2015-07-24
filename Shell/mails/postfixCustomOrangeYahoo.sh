#!/bin/bash
#
# Filename : postfixCustomOrangeYahoo.sh
# Version  : 1.0
# Author   : mathieu androz
# Contrib  :
# Description :
#  1.0
#   `_
#   `_
#




POSTFIXPATH="/etc/postfix"
POSTFIXMAIN="${POSTFIXPATH}/main.cf"
POSTFIXMASTER="${POSTFIXPATH}/master.cf"
POSTFIXTRANSPORT="${POSTFIXPATH}/transport"


usage() {
    ::
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

againstSpam() {
        if [[ -f ${POSTFIXMAIN} ]]; then
                log "Check Spam protection..."
                if [[ $(grep -E "^smtpd_error_sleep_time" ${POSTFIXMAIN}) == "" ]]; then
                        echo "
# Custom against SPAMS
smtpd_error_sleep_time = 2s
smtpd_soft_error_limit = 10
smtpd_hard_error_limit = 20
anvil_rate_time_unit = 60s
# Nombre maximal de requêtes de livraison de messages que tout client est autorisé à faire à ce service par unité de temps
smtpd_client_message_rate_limit = 100
# Nombre maximal d'adresses de destination qu'un client est autorisé à envoyer à ce service par unité de temps
smtpd_client_recipient_rate_limit = 100
# Nombre maximum de tentatives de connexion qu'un client est autorisé à faire à ce service par unité de temps
#smtpd_client_connection_rate_limit =
# contrôle le nombre de destinataires qu'un agent de livraison de Postfix inclura dans chaque copie dun message
default_destination_recipient_limit = 25

                        " >> ${POSTFIXMAIN}
                        log "A part of config was added in ${POSTFIXMAIN} to reduce spams."
                else
                        log "Postfix is already limited against spams."
                fi
        else
                log "${POSTFIXMAIN} doens't exist."
                exit 1
        fi

}

orange() {
        log "Check Wanadoo/Orange config..."
        if [[ -f ${POSTFIXTRANSPORT} ]]; then
                CHECK1=$(grep -E "^(wanadoo|orange)" ${POSTFIXTRANSPORT})
                CHZCK2=$(grep )
}


##################
#
#     MAIN
#
##################



# Ok, c'est moche, mais ca permet de se retrouver plus facilement dans les logs...
#log "------------------------------"
