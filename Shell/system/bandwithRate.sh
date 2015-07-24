#!/bin/bash
#
# Filename : bandwithRate.sh
# Version  : 1.0
# Author   : mathieu androz
# Contrib  : 
# Description :
#  . install vnstat
#  . configure vnstat
#  . 

HOST=$(hostname)
DATE=$(date +%m-%Y)
MONTH=$(date +%m)
YEAR=$(date +%Y)
VNSTATMONTH=$(vnstat -s | sed -n '2, 4 p')

usage() {
    ::
}


log() {
    LOGFILE="/var/log/admin/admin.log"
    if [[ ! -d $(dirname ${LOGFILE}) ]]; then
        mkdir $(dirname ${LOGFILE})
    fi
    echo "$(date +%Y%m%d) :: " ${1} | tee -a ${LOGFILE}
}


##################
#
#     MAIN
#
##################

if [[ $(dpkg -l | grep "vnstat" | awk '{print $1}') == "ii" ]]; then
	echo -e "\n => vnstat is already installed\n"
else
	echo " -> :: Installation ::"
	aptitude -y install vnstat > /dev/null
	echo " -> :: Configuration :: Creation of the db file for eth0"
	vnstat -u -i eth0 --nick "Internet"
	/etc/init.d/vnstat start
fi

#
echo -e "Statistiques Bande passante pour le mois de ${MONTH} ${YEAR} :\n\n
${VNSTATMONTH}" | mail -s "Bandwith ${DATE} ${HOST}" system@intuitiv.fr

exit 0