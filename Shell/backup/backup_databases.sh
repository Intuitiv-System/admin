#!/bin/bash
#
# Filename : backup_databases.sh
# Version  : 1.1
# Author   : olivier renard && mathieu androz
# Description :
# . MySQL databases backup script function to dbnames in $BKP_DB_FILE
#

#Variables
BKP_PATH="/home/backup"
BKP_DB_FILE="/root/scripts/db2backup.txt"
MYSQLUSER="root"
MYSQLPASS=""

[[ ! -f ${BKP_DB_FILE} ]] && exit 1

#Tant que ligne dans $BKP_DB_FILE faire
while read db_name
do
  #Si dossier $BKP_PATH/$line n'existe pas alors on le cree
  if [ ! -d "${BKP_PATH}/${db_name}" ]; then
    mkdir -p ${BKP_PATH}/${db_name}
  fi
  # backup de la DB $db_name
  mysqldump -u${MYSQLUSER} -p"${MYSQLPASS}" --single-transaction ${db_name} > ${BKP_PATH}/${db_name}/${db_name}.sql
done < ${BKP_DB_FILE}

exit 0
