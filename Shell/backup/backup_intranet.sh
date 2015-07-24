#!/bin/bash
#
# Filename : backup_intranet.sh
# Version  : 1.0
# Author   : mathieu androz
# Description :
#  . Mount CIFS
#  . Dump MySQL database of the intranet
#  . Rsync the whole intranet's files on CIFS
#  . Rsync the Apache Solr foler on CIFS
#  . Create a simple log file
#


MYSQLUSER="root"
MYSQLPASS=""
MYSQLDB="intranet"

INTRANETPATH="/home/intranet"
BKPPATH="/mnt/backup"
LOGFILE="/var/log/backup/bkpintranet.log"


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
           \n\tcreate 640 root root
           \n}" > ${LOGROTATEDIR}/${LOGROTATEFILE}
    fi
  fi
}

function log() {
  [[ ! -d $(dirname ${LOGFILE}) ]] && mkdir -p $(dirname ${LOGFILE})
  echo "$(date +%Y%m%d-%H:%M:%S) :: " ${1} | tee -a ${LOGFILE}
}



# Mount Windows Share
[[ ! -d "${BKPPATH}" ]] && mkdir -p "${BKPPATH}" && chmod 777 "${BKPPATH}"
if [[ -z $(df -h | grep "srv-strg-lto6") ]]; then
  # /!\ !!! EDIT after username AND password with your access !!! /!\
  # /!\ !!! EDIT after mod=0777 and enter your CIFS path !!! /!\
  mount -t cifs -o username=,password=,rw,iocharset=utf8,file_mode=0777,dir_mode=0777 CIFS_PATH_HERE "${BKPPATH}"
  [[ "${?}" != "0" ]] && log "Can't mount through CIFS and intranet backup fails" && exit 1
fi

# Dump MySQL database
if [[ -d "${BKPPATH}" ]]; then
  mysqldump -u "${MYSQLUSER}" -p""${MYSQLPASS}"" --single-transaction "${MYSQLDB}" > "${BKPPATH}"/"${MYSQLDB}".sql
  if [[ "${?}" != "0" ]]; then
    log "[FAIL] : MySQL dump"
  else
    log "[OK] : MySQL dump"
  fi
else
  log "[FAIL] : "${BKPPATH}" (backup destination folder) does not exit !"
fi

# Sync files from intranet to backup path
if [[ -d "${INTRANETPATH}" ]]; then
  # Copy all the www folder in the Windows network mapping
  [[ ! -d "${BKPPATH}"/www ]] && ( mkdir "${BKPPATH}"/www && chmod 777 "${BKPPATH}"/www )
  rsync -a --delete "${INTRANETPATH}"/www "${BKPPATH}"/www
  if [[ "${?}" != "0" ]]; then
    log "[FAIL] : Sync intranet files"
  else
    log "[OK] : Sync intranet files"
  fi
  # Copy all the apache solr folder in the Windows network mapping
  [[ ! -d "${BKPPATH}"/apache-solr-3.6.2 ]] && ( mkdir "${BKPPATH}"/apache-solr-3.6.2 && chmod 777 "${BKPPATH}"/apache-solr-3.6.2 )
  rsync -a --delete "${INTRANETPATH}"/apache-solr-3.6.2 "${BKPPATH}"/apache-solr-3.6.2
  if [[ "${?}" != "0" ]]; then
    log "[FAIL] : Sync solr files"
  else
    log "[OK] : Sync solr files"
  fi
else
  log "[FAIL] : "${INTRANETPATH}" (intranet folder) does not exist !"
fi

exit 0
