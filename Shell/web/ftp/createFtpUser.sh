#!/bin/bash
#
# Filename : createFtpUser.sh
# Version  : 2.0
# Author   : mathieu androz
#
# Description :
#  . Create a Pureftpd user in a MySQL database (simple mode)
#

. /lib/lsb/init-functions

FTP_SQL_FILE="/etc/pure-ftpd/db/mysql.conf"
FTP_SQL_USER=$(cat ${FTP_SQL_FILE} | grep -E "^MYSQLUser" | awk '{print $2}')
FTP_SQL_PASS=$(cat ${FTP_SQL_FILE} | grep -E "^MYSQLPassword" | awk '{print $2}')
FTP_SQL_DB=$(cat ${FTP_SQL_FILE} | grep -E "^MYSQLDatabase" | awk '{print $2}')
FTP_SQL_CRYPT=$(cat ${FTP_SQL_FILE} | grep -E "^MYSQLCrypt" | awk '{print $2}')


generate_password() {
    [[ -z ${1} ]] && PASS_LEN="10" || PASS_LEN=${1}
    echo $(cat /dev/urandom|tr -dc "a-zA-Z0-9\?"|fold -w ${PASS_LEN}|head -1)
}


if [[ -f "${FTP_SQL_FILE}" ]] && [[ -n "${FTP_SQL_USER}" ]] && [[ -n "${FTP_SQL_PASS}" ]] && [[ -n "${FTP_SQL_DB}" ]] && [[ -n "${FTP_SQL_CRYPT}" ]] ; then

    # test the users table description
    SQL="SELECT count(COLUMN_NAME) from information_schema.columns where table_schema = '${FTP_SQL_DB}' AND table_name = 'users';"
    [[ $(mysql -N -s -u "${FTP_SQL_USER}" -p"${FTP_SQL_PASS}" -e "${SQL}") -ne "5" ]] && log_failure_msg "This script can't be used because of too many fields in 'users' table. Exiting" && exit 1

    PASSFILE="/etc/passwd"
    GROUPFILE="/etc/group"

    while [[ -z "${FTP_USER}" ]] || \
        [[ -z "${FTP_USER_OWNER}" ]] || \
        [[ -z "${FTP_GROUP_OWNER}" ]] || \
        [[ -z "${FTP_HOME}" ]]
    do
        read -p "Enter FTP username : "         FTP_USER
        read -p "Enter FTP Unix user owner : "  FTP_USER_OWNER
        read -p "Enter FTP Unix group owner : " FTP_GROUP_OWNER
        read -p "Enter FTP home : "             FTP_HOME
    
        # Check if FTP user already exists
        SQL="USE ${FTP_SQL_DB}; SELECT count(*) from users WHERE User = '${FTP_USER}';"
        [[ $(mysql -N -s -u "${FTP_SQL_USER}" -p"${FTP_SQL_PASS}" -e "${SQL}") -gt 0 ]] && FTP_USER="" && log_failure_msg "FTP username already exists." && continue

        # Check if Unix user, group and home are existing
        FTP_UID=$(grep -E "^${FTP_USER_OWNER}:" ${PASSFILE} | awk -F":" '{print $3}')
        FTP_GID=$(grep -E "^${FTP_GROUP_OWNER}:" ${GROUPFILE} | awk -F":" '{print $3}')
        [[ -z "${FTP_UID}" ]]       && FTP_USER="" && log_failure_msg "User owner does not exist."
        [[ -z "${FTP_GID}" ]]       && FTP_USER="" && log_failure_msg "User group does not exist."
        [[ ! -d "${FTP_HOME}" ]]    && FTP_USER="" && log_failure_msg "Home does not exist."
    done

        FTP_PASS=$(generate_password "15")

        FTP_ACCOUNT="/root/ftp_account_${FTP_USER}.inf"
        echo ""
        echo "FTP username          : ${FTP_USER}"                      | tee -a ${FTP_ACCOUNT}
        echo "FTP password          : ${FTP_PASS}"                      | tee -a ${FTP_ACCOUNT}
        echo "FTP user owner - UID  : ${FTP_USER_OWNER} - ${FTP_UID}"   | tee -a ${FTP_ACCOUNT}
        echo "FTP group owner - GID : ${FTP_GROUP_OWNER} - ${FTP_GID}"  | tee -a ${FTP_ACCOUNT}
        echo "FTP home              : ${FTP_HOME}"                      | tee -a ${FTP_ACCOUNT}
        echo "----------------------------------------------------"     | tee -a ${FTP_ACCOUNT}
        chmod 600 ${FTP_ACCOUNT}

        ## Request to add new FTP user in Pure-FTPD database
        SQL_REQ="USE ${FTP_SQL_DB}; INSERT INTO users VALUES ('${FTP_USER}', ${FTP_SQL_CRYPT}( '${FTP_PASS}' ), '${FTP_UID}', '${FTP_GID}', '${FTP_HOME}');"
        mysql -u ${FTP_SQL_USER} -p"${FTP_SQL_PASS}" -e "${SQL_REQ}"
    else
        log_failure_msg "Answer to all requests. Aborted..."
        exit 2
    fi
else
    log_failure_msg "Fail to create new FTP user ${FTP_USER}. Aborted..."
    exit 2
fi

exit 0
