#!/bin/bash
#
# Filename : createFtpUsersh
# Version  : 1.0
# Author   : Mathieu ANDROZ
#
# Description :
#  . Create a Pureftpd user in a MySQL database


FTP_SQL_FILE="/etc/pure-ftpd/db/mysql.conf"
FTP_SQL_USER=$(cat ${FTP_SQL_FILE} | grep -E "^MYSQLUser" | awk '{print $2}')
FTP_SQL_PASS=$(cat ${FTP_SQL_FILE} | grep -E "^MYSQLPassword" | awk '{print $2}')
FTP_SQL_DB=$(cat ${FTP_SQL_FILE} | grep -E "^MYSQLDatabase" | awk '{print $2}')
FTP_SQL_CRYPT=$(cat ${FTP_SQL_FILE} | grep -E "^MYSQLCrypt" | awk '{print $2}')


generate_password() {
    [[ -z ${1} ]] && PASS_LEN="10" || PASS_LEN=${1}
    echo $(cat /dev/urandom|tr -dc "a-zA-Z0-9\$\?"|fold -w ${PASS_LEN}|head -1)
}


if [[ -f "${FTP_SQL_FILE}" ]] && [[ -n "${FTP_SQL_USER}" ]] && [[ -n "${FTP_SQL_PASS}" ]] && [[ -n "${FTP_SQL_DB}" ]] && [[ -n "${FTP_SQL_CRYPT}" ]] ; then
    read -p "Enter FTP username : "         FTP_USER
    read -p "Enter FTP Unix user owner : "  FTP_USER_OWNER
    read -p "Enter FTP Unix group owner : " FTP_GROUP_OWNER
    read -p "Enter FTP home : "             FTP_HOME

    PASSFILE="/etc/passwd"
    GROUPFILE="/etc/group"
    if [[ -n "${FTP_USER}" ]] && [[ -n "${FTP_USER_OWNER}" ]] && [[ -n "${FTP_GROUP_OWNER}" ]] && [[ -n "${FTP_HOME}" ]]; then
        FTP_UID=$(grep -E "^${FTP_USER_OWNER}:" ${PASSFILE} | awk -F":" '{print $3}')
        FTP_GID=$(grep -E "^${FTP_GROUP_OWNER}:" ${GROUPFILE} | awk -F":" '{print $3}')
        FTP_PASS=$(generate_password "12")

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
        echo "Answer to all requests. Aborted..."
        exit 2
    fi
else
    echo "Fail to create new FTP user ${FTP_USER}. Aborted..."
    exit 2
fi

exit 0
