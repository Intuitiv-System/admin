#!/bin/bash
#
# Filename : bkpDrupalWithRsync.sh
# Version  : 1.0
# Author   : mathieu androz
# Description :
# . Script to backup a Drupal instance with rsync 
# . Perform a dump MySQL of a single database
# . Store the dump in a backup folder
# . Sync web folder in the same backup folder as the dump MySQL
# . Variables at the top this script must be edited
#
#

### TO EDIT ###

# SOURCE : Webfolder path (DocumentRoot)
WEBROOT="/var/www/public_html"

# DESTINATION : Backup destination folder path
BKPDEST="/home/mathieu/rsync"

# MySQL informations
# MySQL user
MYSQLUSER=""
# MySQL password
MYSQLPASS=""
# MySQL database name
MYSQLDB=""

### END EDIT ###


# Logs file (don't edit it)
LOGFILE="/var/log/backup/bkp.log"



function usage() {
	::
}


function createLogrotate() {
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
           \n\tcreate 640 $(id -un) adm
           \n}" > ${LOGROTATEDIR}/${LOGROTATEFILE}
    fi
  fi
}

function log() {
  [[ ! -d $(dirname ${LOGFILE}) ]] && mkdir -p $(dirname ${LOGFILE})
  echo "$(date +%Y%m%d-%H:%M:%S) :: " ${1} | tee -a ${LOGFILE}
}


test $(which rsync) || ( echo "rsync not found..." && exit 1 )

createLogrotate

# Test if destination folder exists
BKPDEST="${BKPDEST%/}"
[[ ! -d "${BKPDEST}" ]] && ( mkdir -p "${BKPDEST}" && chmod 700 "${BKPDEST}" )
# Test WEBROOT variable
WEBROOT="${WEBROOT%/}"
if [[ $(basename "${WEBROOT}") != "public_html" ]]; then
	log "Wrong WEBROOT variable. Must finish by /public_html" && exit 2
elif [[ ! -d "${}" ]]; then
	log "Wrong WEBROOT variable. Path doesn't exist." && exit 2
fi
# Test MySQL access
[[ $(mysql -u "${MYSQLUSER}" -p""${MYSQLPASS}"" "${MYSQLDB}" -N -B -e "show tables; ") ]] || ( log "MySQL informations provided are incorrect. Please check it." && exit 1 )
# Test existing previous dump
[[ -f "${BKPDEST}"/"${MYSQLDB}".sql ]] && mv "${BKPDEST}"/"${MYSQLDB}".sql "${BKPDEST}"/"${MYSQLDB}".sql.old1day

# Proceed backup
# Do MySQL dump
mysqldump -u "${MYSQLUSER}" -p""${MYSQLPASS}"" --single-transaction "${MYSQLDB}" > "${BKPDEST}"/"${MYSQLDB}".sql && \
	log "MySQL dump of ${MYSQLDB} : [OK]" || log "MySQL dump of ${MYSQLDB} : [FAILED]"
# Sync public_html
rsync -rlptD --delete --update "${WEBROOT}" "${BKPDEST}" && \
	log "Rsync of web folder ${WEBROOT} to ${BKPDEST} : [OK]" || log "Rsync of wbe folder ${WEBROOT} to ${BKPDEST} : [FAILED]"

exit 0
