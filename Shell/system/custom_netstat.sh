#!/bin/bash
#
# Filename : custom_netstat.sh
# Version  : 1.1
# Author   : Olivier RENARD
#
# Return IPs connected to host on HTTP & HTTPS ports
#
# . Print/send by mail all IPs retrived with netstat and filters by grep, awk and cut

clear

usage() {
    echo "USAGE : ${0} [--panic]
    OPTION :
        --panic, -p     Send all IPs connected trough HTTP(S) ports by mail to ${MAIL}
        -h              Print this short help"
}


MAIL=""
HOST=$(hostname | cut -d"." -f1)

CMD=$(netstat -anp | egrep ":(80|443)" | awk -F" " '{print $5}' | cut -d":" -f1)

if [[ -n ${1} ]]; then
    if [[ ${1} == "--panic" ]] || [[ ${1} == "-p" ]]; then
        while [[ -z ${MAIL} ]]
        do
            read -p "Enter your email address : " MAIL
        done
        echo "${CMD}" | mail -s "[SYSTEM PANIC] 04-03:(80|443) IPs list" ${MAIL}
    else
        usage
    fi
else
    echo "${CMD}"
fi