#!/bin/bash
#
# Filename : sendBandwithReports.sh
# Version  : 1.0
# Author   : mathieu androz
# Contrib  :
# Description :
#  . send email with bandwith reports generated with vnstat
#
#


usage() {
    ::
}


log() {
    LOGFILE="/var/log/admin/bandwith.log"
    [[ ! -d $(dirname ${LOGFILE}) ]] && mkdir -p $(dirname ${LOGFILE})
    echo "$(date +%Y%m%d-%H:%M:%s) :: " ${1} | tee -a ${LOGFILE}
}


##################
#
#     MAIN
#
##################

if [[ ! $(dpkg -l | grep "vnstat" | awk '{print $1}') == "ii" ]]; then
	aptitude -y install vnstat &> /dev/null
	vnstat -u -i eth0 --nick "Internet" &> /dev/null
	/etc/init.d/vnstat start &> /dev/null
fi

# Insert into crontab
if [[ -n $(grep $(basename $0) /etc/crontab) ]]; then
	BANDWITHCMD=$(vnstat -m | sed -n ':s;1{N;bs};2,${N;P;D}')
	# Email dest
	DEST="system@intuitiv.fr"
	if [[ -z ${DEST} ]]; then
        echo "Enter a valid email address"
        exit 1
	else
		echo "$BANDWITHCMD" | mail -s "$(echo -e "$(hostname) : Bandwith Report")" $DEST
	fi
else
	echo "
# Send Bandwith Report monthly
00 9	* * 1	root	$(dirname $0)/$(basename $0) &> /dev/null" | tee -a /etc/crontab
fi


# Ok, c'est moche, mais ca permet de se retrouver plus facilement dans les logs...
#log "------------------------------"