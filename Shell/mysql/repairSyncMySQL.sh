#!/bin/bash
#
# Filename : repairSyncMySQL.sh
# Version  : 1.0
# Author   :
# Contrib  :
# Description :
#  . Prepare a dump with all informations needed to rebuild a replication slave
#  .
#


MYSQLHOST="localhost"
MYSQLPORT="3306"
MYSQLROOT="root"
MYSQLPWD="mysql"
MYSQLSTATUS="/tmp/global_status.txt"
MYSQLVARIABLES="/tmp/global_variables.txt"
MYSQLFILE="/root/mysqlDbDump_$(date +%Y%m%d).sql"


ROUGE="\E[1;31m"
NORMAL="\E[0;39m"
JAUNE="\E[1;33m"


usage() {
    ::
}


log() {
    LOGFILE="/var/log/admin/admin.log"
    [[ ! -d $(dirname ${LOGFILE}) ]] && mkdir -p $(dirname ${LOGFILE})
    echo "$(date +%Y%m%d-%H:%M:%s) :: " ${1} | tee -a ${LOGFILE}
}


cleanTmpFiles() {
    [[ -f ${MYSQLSTATUS} ]] && rm ${MYSQLSTATUS}
    [[ -f ${MYSQLVARIABLES} ]] && rm ${MYSQLVARIABLES}
}


CheckDistrib()
{
    # On what linux distribution you are
    DISTRIB=$(awk '{print $1}' /etc/issue)
    DIR=$(pwd)
    FILE=$(basename $0)
    if [[ ${DISTRIB} = "Ubuntu" ]]; then
        if [[ $(whoami) != "root" ]]; then
            echo "Login as root and execute this command : ${DIR}/${FILE}" && sudo su -
            exit 0
        fi
            [[ -z ${MYSQLPWD} ]] && read -s -p "Enter root MySQL password : " MYSQLPWD
            MYSQLCMD="/usr/bin/mysql -u ${MYSQLROOT} -P ${MYSQLPORT} --host=${MYSQLHOST} -p${MYSQLPWD} -B -N -L"
    elif [[ ${DISTRIB} = "Debian" ]]; then
        if [[ $(whoami) != "root" ]]; then
            echo "Login as root and execute this command : ${DIR}/${FILE}" && su -
            exit 0
        fi
            [[ -z ${MYSQLPWD} ]] && read -s -p "Enter root MySQL password : " MYSQLPWD
            MYSQLCMD="/usr/bin/mysql -u ${MYSQLROOT} -P ${MYSQLPORT} --host=${MYSQLHOST} -p${MYSQLPWD} -B -N -L"
    else
        echo "You're running on ${DISTRIB}.\nThis script is adapted for Debian-Like OS.\nBye"
        [[ -z ${MYSQLPWD} ]] && read -s -p "Enter root MySQL password : " MYSQLPWD
        MYSQLCMD="/usr/bin/mysql -u ${MYSQLROOT} -P ${MYSQLPORT} --host=${MYSQLHOST} -p${MYSQLPWD} -B -N -L"
    fi
}

testMysqlConnection() {
    CheckDistrib
    MYSQLTEST=$(${MYSQLCMD} -e "STATUS ;" 2> /dev/null)
    MYSQLTESTERROR=$(echo "${MYSQLTEST}" | head -n 1 | awk '{print $1}')
    if [[ -z ${MYSQLTESTERROR} ]] || [[ ${MYSQLTESTERROR} == "ERROR" ]]; then
        echo "Error while connect to MySQL server."
        echo "Please check if you're using the good password for example..."
        exit 1
    fi
}

##################
#
#     MAIN
#
##################

testMysqlConnection

# Get Master position and log file
MASTERLOGFILE=$(${MYSQLCMD} -e "SHOW MASTER STATUS ;" |awk '{print $1}')
MASTERPOSITION=$(${MYSQLCMD} -e "SHOW MASTER STATUS ;" | awk '{print $2}')

clear

### IMPORTANT MESSAGE !
echo -e "${ROUGE}#######################################

         !!! IMPORTANT !!!

--- MASTER SERVER SIDE ---

You have to open a second Shell,
connect to MySQL as root
and put a write lock with :

 FLUSH TABLES WITH READ LOCK ;

After, ensure to unlock with :

 UNLOCK TABLES ;

${JAUNE}--- SLAVE SERVER SIDE ---

In order to resync the slave server,
you have to copy the generated file on teh slave server
and execute the following command line :

 mysql -u root -p < dump_file.sql

${ROUGE}#######################################${NORMAL}"

# DB list names
echo ""
read -p "Enter the list of databases you want to dump (separated by a space) : " DBLIST
echo ""
read -p "Enter MASTER_HOST IP address : " MASTER_HOST
read -p "Enter MASTER SERVER PORT number : " MASTER_PORT
read -p "Enter MASTER replication username : " MASTER_USER
read -s -p "Enter MASTER replication user password : " MASTER_PASSWORD
echo ""

echo "-- STOP MYSQL SLAVE SERVER
STOP SLAVE ;

" > ${MYSQLFILE}

# Make a mysqldump
mysqldump -u root -p"${MYSQLPWD}" --add-drop-database --databases ${DBLIST} --single-transaction >> ${MYSQLFILE}

echo "
-- SET MASTER INFORMATIONS on SLAVE
CHANGE MASTER TO MASTER_HOST='${MASTER_HOST}',
MASTER_PORT=${MASTER_PORT},
MASTER_USER='${MASTER_USER}',
MASTER_PASSWORD='${MASTER_PASSWORD}',
MASTER_LOG_FILE='${MASTERLOGFILE}',
MASTER_LOG_POS=${MASTERPOSITION} ;

-- RESTART MYSQL SLAVE SERVER
START SLAVE ;" >> ${MYSQLFILE}

echo ""
echo "Dump file to import on the slave server is here : ${MYSQLFILE}"
echo ""

exit 0

# Ok, c'est moche, mais ca permet de se retrouver plus facilement dans les logs...
#log "------------------------------"
