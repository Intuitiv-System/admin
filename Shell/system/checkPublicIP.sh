#!/bin/bash
#
# Filename : checkPublicIP.sh
# Version  : 1.0
# Author   : mathieu androz
# Contrib  :
# Description :
#  . Get public IP
#  . Send an email if IP has changed
#


usage() {
    echo "
Description :
    - Get the public IP
    - Send an email if public IP has changed
Usage :
    Run checkPublicIP.sh in a cron job like :
    */5 * * * *     root    /root/scripts/checkPublicIP.sh 2> /dev/null"
}


log() {
    LOGFILE="/var/log/admin/admin.log"
    [[ ! -d $(dirname ${LOGFILE}) ]] && mkdir -p $(dirname ${LOGFILE})
    echo "$(date +%Y%m%d-%H:%M:%s) :: " ${1} | tee -a ${LOGFILE}
}

mail_ip(){
    echo -e "L'ancienne IP etait : $(cat ${IPFILE})\nLa nouvelle adresse IP de la box est : ${1}" | mail -s "Box IP changed" ${2}
}


##################
#
#     MAIN
#
##################

IPFILE="/tmp/publicip"
IP=$(wget http://ipecho.net/plain -O - -q ; echo)


if [[ ! -f ${IPFILE} ]]; then
    echo ${IP} > ${IPFILE}
    mail_ip ${IP} "system@intuitiv.fr"
else
    if [[ ${IP} != $(cat ${IPFILE}) ]]; then
        mail_ip ${IP} "system@intuitiv.fr"
        echo ${IP} > ${IPFILE}
    fi
fi

exit 0

# Ok, c'est moche, mais ca permet de se retrouver plus facilement dans les logs...
#log "------------------------------"
#!/bin/bash
#
# Filename : checkPublicIP.sh
# Version  : 1.0
# Author   : mathieu androz
# Contrib  :
# Description :
#  . Get public IP
#  . Send an email if IP has changed
#


usage() {
    echo "
Description :
    - Get the public IP
    - Send an email if public IP has changed
Usage :
    Run checkPublicIP.sh in a cron job like :
    */5 * * * *     root    /root/scripts/checkPublicIP.sh 2> /dev/null"
}


log() {
    LOGFILE="/var/log/admin/admin.log"
    [[ ! -d $(dirname ${LOGFILE}) ]] && mkdir -p $(dirname ${LOGFILE})
    echo "$(date +%Y%m%d-%H:%M:%s) :: " ${1} | tee -a ${LOGFILE}
}

mail_ip(){
    echo -e "L'ancienne IP etait : $(cat ${IPFILE})\nLa nouvelle adresse IP de la box est : ${1}" | mail -s "Box IP changed" ${2}
}


##################
#
#     MAIN
#
##################

IPFILE="/tmp/publicip"
IP=$(wget http://ipecho.net/plain -O - -q ; echo)


if [[ ! -f ${IPFILE} ]]; then
    echo ${IP} > ${IPFILE}
    mail_ip ${IP} "system@intuitiv.fr"
else
    if [[ ${IP} != $(cat ${IPFILE}) ]]; then
        mail_ip ${IP} "system@intuitiv.fr"
        echo ${IP} > ${IPFILE}
    fi
fi

exit 0

# Ok, c'est moche, mais ca permet de se retrouver plus facilement dans les logs...
#log "------------------------------"
