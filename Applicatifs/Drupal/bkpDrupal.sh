#!/bin/bash
#
# Filename : backup_intranet.sh
# Version  : 1.0
# Author   : mathieu androz
# Description :
#  . backup option :
#    |__ use drush command to perform a full backup (files + db)
#  . restore :
#    |__ use drush command to perform a full restoration (files + db)
#



# Web user
WEBUSER="www-data"
# Website name
WEBNAME=""

# Logs file
LOGFILE="/var/log/backup/bkp${WEBNAME}.log"



function usage() {
  echo "
  Backup option :
    Create a tar.gz containing all files and a database dump

    Usage :: $0 backup {project documentroot path} {backup destination path}

  Restore option :
    Restore all the web folder, import database in an existing schema and configure the settings file

    Usage :: $0 restore {backup filename} {project documentroot path|restore destination} [mysql_username] [mysql_password] [mysql_database]
    "
    exit 2
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
           \n\tcreate 640 root root
           \n}" > ${LOGROTATEDIR}/${LOGROTATEFILE}
    fi
  fi
}

function log() {
  [[ ! -d $(dirname ${LOGFILE}) ]] && mkdir -p $(dirname ${LOGFILE})
  echo "$(date +%Y%m%d-%H:%M:%S) :: " ${1} | tee -a ${LOGFILE}
}


test $(which drush) || echo "drush not found. Aborted..." && exit 1
[[ -z "${WEBNAME}" ]] || echo "The website name variable is not specified. Please edit the script and the var WEBNAME." && exit 1

createLogrotate

case "${1}" in 
  backup)
    BKPFILE="${WEBNAME}_$(date +%Y%m%d).tar.gz"
    if [[ "$#" -ne 3 ]]; then
      log "Missing argument" && usage 
    else
      # Get documentroot path
      DOCROOT="${2}"
      [[ ! -d "${DOCROOT}" ]] && log "mentionned DocumentRoot doesn't exist. Aborted..." && exit 1
      # Get backup destination path
      BKPPATH="${3}"
      # Create backup destination folder
      [[ ! -d "${BKPPATH}" ]] && mkdir -p "${BKPPATH}" && chmod 700 "${BKPPATH}"
      # Do backup using drush command
      if [[ ! -f "${BKPPATH}"/"${BKPFILE}" ]]; then
        cd "${DOCROOT}"
        drush ard --destination="${BKPPATH}"/"${BKPFILE}" && log "backup succeeded"
      else
        log "A backup with the same name already exists in ""${BKPPATH}""/""${BKPFILE}"" "
        exit 0
      fi
    fi
  ;;

  restore)
    if [[ "$#" -ne 6 ]]; then
      log "Missing argument" && usage
    else
      BKPPATHFILE="${2}"
      [[ ! -f "${BKPPATHFILE}" ]] && log "backup archive to restore doesn't exist. Aborted..." && exit 1
      DESTPATH="${3}"
      [[ ! -d $(dirname "${DESTPATH}") ]] && log "destination parent folder where to restore doesn't exist. Aborted..." && exit 1
      # Test this MySQL account
      MYSQLUSER="${4}"
      MYSQLPASS="${5}"
      MYSQLDB="${6}"
      [[ $(mysql -u "${MYSQLUSER}" -p""${MYSQLPASS}"" "${MYSQLDB}" -N -B -e "show tables; ") ]] || ( log "MySQL informations provided are incorrect. Please check it." && exit 1 )
      #Backup the current instance
      mv "${DESTPATH}" "${DESTPATH}".bkp
      cd "${DESTPATH}".bkp && mysqldump -u "${MYSQLUSER}" -p""${MYSQLPASS}"" --single-transaction "${MYSQLDB}" > "${MYSQLDB}"_done_by_restorescript.sql.bkp
      # Drop all tables in the database to restore the dump
      mysql -u "${MYSQLUSER}" -p""${MYSQLPASS}"" "${MYSQLDB}" -e "SHOW TABLES" | grep -v "Tables_in_${MYSQLDB}" | while read tabname; do mysql -u "${MYSQLUSER}" -p""${MYSQLPASS}"" "${MYSQLDB}" -e "DROP TABLE $tabname"; done && log "Purge of the database ${MYSQLDB} done with success" || (log "Problem with the purge of database ${MYSQLDB}" && exit 1)
      # Restoration process
      cd $(dirname "${BKPPATHFILE}")
      drush arr $(basename "${BKPPATHFILE}") --destination="${DESTPATH}" --db-url=mysql://"${MYSQLUSER}":"${MYSQLPASS}"@localhost/"${MYSQLDB}" && log "Restore succeeded"
      echo ""
      log "!!! IMPORTANT !!! : A current backup has been done with the restore process. This backup is the folder ${DESTPATH}.bkp which contains a database dump called ${MYSQLDB}_done_by_restorescript.sql.bkp.
If you need to use this backup, please delete the ${MYSQLDB}_done_by_restorescript.sql.bkp file after restoration succeeded.
If your restore process with this script is a success, please delete this whole folder ${DESTPATH}.bkp.
Finally, check the owner:group permissions of ${DESTPATH} and its content and fix them with a chown -R if needed."

      exit 0
    fi
  ;;
  
  *)
    log "Wrong first argument. Please retry." && usage
  ;;
esac

exit 0
