#!/bin/bash
#
# Filename : alfrescoPurge.sh
# Version  : 1.0
# Author   : mathieu androz
# Contrib  : 
# Description :
#  . Purge deleted files saved in contentstore.deleted folder
#  . 
#


usage() {
    ::
}


log() {
    LOGFILE="/var/log/admin/admin.log"
    [[ ! -d $(dirname ${LOGFILE}) ]] && mkdir -p $(dirname ${LOGFILE})
    echo "$(date +%Y%m%d-%H:%M:%s) :: " ${1} | tee -a ${LOGFILE}
}


##################
#
#     MAIN
#
##################

ALFRESCO_ALFDATA=""
DAYS_TO_KEEP=""

if [[ -z ${ALFRESCO_ALFDATA} ]] || [[ ! -d ${ALFRESCO_ALFDATA} ]]; then
	echo "Please fix the variable ALFRESCO_ALFDATA in this script before execute it."
	echo "Bye"
	exit 1
elif [[ -z ${DAYS_TO_KEEP} ]]; then
	echo "Please fix teh variable DAYS_TO_KEEP in this script before execute it."
	echo "Bye"
	exit 2
elif [[ -d ${ALFRESCO_ALFDATA}/contentstore.deleted ]]; then
	find ${ALFRESCO_ALFDATA}/contentstore.deleted -mtime  +${DAYS_TO_KEEP} -name '*bin' | xargs rm
	find ${ALFRESCO_ALFDATA}/contentstore.deleted -type d -empty | xargs rmdir
	echo "contentstore.deleted well purged !"
else
	echo "Hmmm, it seems you have a problem..."
	echo "You have to investigate !"
	exit 3
fi

exit 0

# Ok, c'est moche, mais ca permet de se retrouver plus facilement dans les logs...
#log "------------------------------"