#!/bin/bash
#
# Filename : getVMInfo.sh
# Version  : 1.0
# Author   : mathieu androz
# Contrib  : 
# Description :
#  . Get CPU number, RAM size, distrib
#  . 
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

getCPUNumber() {
    CPUINFO="/proc/cpuinfo"
    CPU_NB="0"
    if [[ -f ${CPUINFO} ]]; then
        CPU_NB=$(grep "processor" ${CPUINFO} | wc -l)
    fi
}

getMEMSize() {
    MEMINFO="/proc/meminfo"
    MEM_SIZE="0"
    if [[ -f ${MEMINFO} ]]; then
        MEM_SIZE=$(grep "MemTotal:" ${MEMINFO} | awk '{print $2" "$3}')
    fi
}

##################
#
#     MAIN
#
##################

createLogrotate

DEST="/home/backupit/"



# Ok, c'est moche, mais ca permet de se retrouver plus facilement dans les logs...
#log "------------------------------"

