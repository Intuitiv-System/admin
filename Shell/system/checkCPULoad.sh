#!/bin/bash
#
# Filename : checkCPULoad.sh
# Version  : 1.1
# Author   : mathieu androz
# Contrib  : 
# Description :
# 1.1
#   `_ Add email alert
# 1.0
#   `_ check CPU usage for each CPU separately
#   `_ if CPU usage exceed MAXLOAD value, ACTION is executed
#


usage() {
    ::
}


log() {
    LOGFILE="/var/log/admin/admin.log"
    [[ ! -d $(dirname ${LOGFILE}) ]] && mkdir -p $(dirname ${LOGFILE})
    echo "$(date +%Y%m%d-%H:%M:%S) :: " ${1} | tee -a ${LOGFILE}
}


installPackage() {
    if [[ ! -f /tmp/sysstat ]] || [[ $(dpkg -l | grep "${1}" | awk '{print $1}') != "ii" ]]; then
            apt-get -y -q install "${1}" &> /dev/null
            log "Installation du package ${1}"
            touch /tmp/sysstat
    fi
}



##################
#
#     MAIN
#
##################

installPackage sysstat

CPUNB=$(grep -E "^processor" /proc/cpuinfo | wc -l)
MAX=$(( ${CPUNB} - 1 ))


##### Edit these values #####
MAXLOAD="92"
ACTION="/etc/init.d/apache2 restart"
EMAILADDR=""
#############################


cpunum=0
while [ ${cpunum} -le ${MAX} ]
do
    STATFILE="/tmp/cpu_load.log"
    mpstat -P ${cpunum} 1 8 > ${STATFILE}
    AVGLOAD=$(tail -n 1 ${STATFILE} | awk '{print $10}')
    REALLOAD=$(( 100 - ${AVGLOAD} ))
    if [[ ${REALLOAD} -gt ${MAXLOAD} ]]; then
        $(${ACTION})
        sed -i "1i\La commande suivante a ete executee sur $(hostname) :\n\n${ACTION}\n\n" ${STATFILE}
        [[ -n ${EMAILADDR} ]] && cat ${STATFILE} | mail -s "Action on $(hostname)" ${EMAILADDR}
    fi
    [[ -f ${STATFILE} ]] && rm ${STATFILE}
    cpunum=$(( ${cpunum} + 1 ))
done

exit 0


# Ok, c'est moche, mais ca permet de se retrouver plus facilement dans les logs...
#log "------------------------------"