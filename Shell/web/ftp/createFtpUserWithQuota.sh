#!/bin/bash
#
# Filename : createFtpUser.sh
# Version  : 2.0
# Author   : Mathieu ANDROZ
#
# Description :
#  . Create a Pureftpd user in a MySQL database
#  . Allow Quota size and Bandwidth rate
#


. /lib/lsb/init-functions

[[ $(id -u) -eq "0" ]] || ( echo "This script have to run as root. Aborted..." && exit 2 )


FTP_SQL_FILE="/etc/pure-ftpd/db/mysql.conf"

[[ ! -f "${FTP_SQL_FILE}" ]] && echo "${FTP_SQL_FILE} doesn't exist. Aborted..." && exit 10

FTP_SQL_USER=$(cat ${FTP_SQL_FILE}  | grep -E "^MYSQLUser"     | awk '{print $2}')
FTP_SQL_PASS=$(cat ${FTP_SQL_FILE}  | grep -E "^MYSQLPassword" | awk '{print $2}')
FTP_SQL_DB=$(cat ${FTP_SQL_FILE}    | grep -E "^MYSQLDatabase" | awk '{print $2}')
FTP_SQL_CRYPT=$(cat ${FTP_SQL_FILE} | grep -E "^MYSQLCrypt"    | awk '{print $2}')

generate_password() {
    [[ -z ${1} ]] && PASS_LEN="15" || PASS_LEN=${1}
    echo $(cat /dev/urandom|tr -dc "a-zA-Z0-9\?"|fold -w ${PASS_LEN}|head -1)
}

QUOTA_PRESENT=$(grep -E "^MySQLGetQTASZ" "${FTP_SQL_FILE}")

if [[ -f "${FTP_SQL_FILE}" ]] && [[ -n "${FTP_SQL_USER}" ]] && [[ -n "${FTP_SQL_PASS}" ]] && [[ -n "${FTP_SQL_DB}" ]] && [[ -n "${FTP_SQL_CRYPT}" ]] ; then
    PASSFILE="/etc/passwd"
    GROUPFILE="/etc/group"
    int='^[0-9]+$'          # To test if FTP_QUOTA and FTP_BW is an integer

    while [[ -z "${FTP_USER}" ]] || \
        [[ -z "${FTP_USER_OWNER}" ]] || \
        [[ -z "${FTP_GROUP_OWNER}" ]] || \
        [[ -z "${FTP_HOME}" ]] || \
        ( [[ -n "${FTP_BW}" ]] && ! [[ "${FTP_BW}" =~ $int ]] )
    do
        echo ""
        read -p "Enter FTP username : "                      FTP_USER
        read -p "Enter FTP Unix user owner : "               FTP_USER_OWNER
        read -p "Enter FTP Unix group owner : "              FTP_GROUP_OWNER
        read -p "Enter FTP home : "                          FTP_HOME
        read -p "Enter FTP Bandwidth in kB/s (default=0) : " FTP_BW

        # Check if FTP user already exists
        SQL="USE ${FTP_SQL_DB}; SELECT count(*) from users WHERE User = '${FTP_USER}';"
        [[ $(mysql -N -s -u "${FTP_SQL_USER}" -p"${FTP_SQL_PASS}" -e "${SQL}") -gt 0 ]] && FTP_USER="" && log_failure_msg "FTP username already exists." && continue

        # Check if Unix user, group and home are existing
        FTP_UID=$(grep -E "^${FTP_USER_OWNER}:" ${PASSFILE} | awk -F":" '{print $3}')
        FTP_GID=$(grep -E "^${FTP_GROUP_OWNER}:" ${GROUPFILE} | awk -F":" '{print $3}')
        [[ -z "${FTP_UID}" ]]       && FTP_USER="" && log_failure_msg "User owner does not exist."
        [[ -z "${FTP_GID}" ]]       && FTP_USER="" && log_failure_msg "User group does not exist."
        [[ ! -d "${FTP_HOME}" ]]    && FTP_USER="" && log_failure_msg "Home does not exist."

        # Set FTP_Bandwidth to 0 by default
        [[ -z ${FTP_BW} ]] && FTP_BW="0"
    done

    if [[ -z "${QUOTA_PRESENT}" ]]; then
        while ( [[ -n "${FTP_QUOTA}" ]] && ! [[ "${FTP_QUOTA}" =~ $int ]] )
        do
            read -p "Enter FTP quota in MB (default=10000) : "   FTP_QUOTA
        done
    fi

    FTP_PASS=$(generate_password "15")
    [[ -z ${FTP_QUOTA} ]] && FTP_QUOTA="10000"
    FTP_ACCOUNT="/root/ftp_account_${FTP_USER}.inf"
    
    echo ""
    echo "FTP username          : ${FTP_USER}"                     | tee -a ${FTP_ACCOUNT}
    echo "FTP password          : ${FTP_PASS}"                     | tee -a ${FTP_ACCOUNT}
    echo "FTP user owner - UID  : ${FTP_USER_OWNER} - ${FTP_UID}"  | tee -a ${FTP_ACCOUNT}
    echo "FTP group owner - GID : ${FTP_GROUP_OWNER} - ${FTP_GID}" | tee -a ${FTP_ACCOUNT}
    echo "FTP home              : ${FTP_HOME}"                     | tee -a ${FTP_ACCOUNT}
    echo "FTP Bandwidth         : ${FTP_BW}"                       | tee -a ${FTP_ACCOUNT}
    [[ -z "${QUOTA_PRESENT}" ]] && \
    echo "FTP quota size        : ${FTP_QUOTA}"                    | tee -a ${FTP_ACCOUNT}
    echo "----------------------------------------------------"    | tee -a ${FTP_ACCOUNT}
    chmod 600 ${FTP_ACCOUNT}

    ## Request to add new FTP user in Pure-FTPD database
    if [[ -z "${QUOTA_PRESENT}" ]]; then
        SQL_REQ="USE ${FTP_SQL_DB}; INSERT INTO users \
            (User, status, Password, Uid, Gid, Dir, ULBandwidth, DLBandwidth, comment, ipaccess, LastModif) \
            VALUES ('${FTP_USER}', '1', ${FTP_SQL_CRYPT}( '${FTP_PASS}' ), '${FTP_UID}', '${FTP_GID}', '${FTP_HOME}', '${FTP_BW}', '${FTP_BW}', '', '*', now());"
    else
        SQL_REQ="USE ${FTP_SQL_DB}; INSERT INTO users \
            (User, status, Password, Uid, Gid, Dir, ULBandwidth, DLBandwidth, comment, ipaccess, QuotaSize, QuotaFiles, LastModif) \
            VALUES ('${FTP_USER}', '1', ${FTP_SQL_CRYPT}( '${FTP_PASS}' ), '${FTP_UID}', '${FTP_GID}', '${FTP_HOME}', '${FTP_BW}', '${FTP_BW}', '', '*', '${FTP_QUOTA}', '0', now());"
    fi
    mysql -u "${FTP_SQL_USER}" -p"${FTP_SQL_PASS}" -e "${SQL_REQ}"
    if [[ "$?" -ne 0 ]]; then
        log_failure_msg "FTP user creation fails because of MySQL query error :
        ${SQL_RQ}"
        log_action_msg "FTP account removed."
        [[ -f "${FTP_ACCOUNT}" ]] && rm "${FTP_ACCOUNT}"
    fi
else
    log_failure_msg "Fail to create new FTP user ${FTP_USER} because of bad informations in Pure-ftpd DB config file :
${FTP_SQL_FILE}.

Aborted...
"
    exit 2
fi

exit 0
