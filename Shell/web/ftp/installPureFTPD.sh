#!/bin/bash
#
# Filename : installPureFTPD.sh
# Version  : 2.0
# Author   : mathieu androz
# Contrib  :
# Description :
#  . Install script for Pure-ftpd over MySQL
#  . Add Quota and Bandwidth
#


usage() {
    ::
}

createLogrotate() {
    LOGFILE="/var/log/admin/admin.log"
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

log() {
    createLogrotate
    [[ ! -d $(dirname ${LOGFILE}) ]] && mkdir -p $(dirname ${LOGFILE})
    echo "$(date +%Y%m%d-%H:%M:%S) :: " ${1} | tee -a ${LOGFILE}
}

installPackage() {
    if [[ $(dpkg -l | awk '{print $1" "$2}' | grep " ${1}"$) != "ii ${1}" ]]; then
        log "Installation du package ${1}..."
        apt-get -y -qq install "${1}" &> /dev/null
    fi
}

mysql_cmd() {
    mysql -u root -p"${MYSQLPWD}" -B -N -L -e "${1}"
}

generate_password() {
    [[ -z ${1} ]] && PASS_LEN="17" || PASS_LEN=${1}
    echo $(cat /dev/urandom|tr -dc "a-zA-Z0-9\?"|fold -w ${PASS_LEN}|head -1)
}

testMysqlConnection() {
    while true; do
        read -s -p "Enter MySQL root password : " MYSQLPWD
        MYSQLCMD="/usr/bin/mysql -u root -p${MYSQLPWD} -B -N -L"
        MYSQLTEST=$(${MYSQLCMD} -e "STATUS ;" 2> /dev/null)
        MYSQLTESTERROR=$(echo "${MYSQLTEST}" | head -n 1 | awk '{print $1}')
        if [[ -z ${MYSQLTESTERROR} ]] || [[ ${MYSQLTESTERROR} == "ERROR" ]]; then
            echo -e "Error while connect to MySQL server."
            echo -e "Please check if you're using the good password..."
        else
            break
        fi
    done
}

createDB()
{
    testMysqlConnection
    echo ""
    log "Creation of MySQL '${1}' database..."
    DBEXIST=$(mysql -u root -p"${MYSQLPWD}" -B -N -e "SHOW DATABASES LIKE '${1}' ;" | wc -l)
    if [[ ${DBEXIST} -gt 0 ]]; then
        log "A MySQL database called '${1}' already exists"
    else
        mysql -u root -p"${MYSQLPWD}" -e "CREATE DATABASE ${1} character set utf8 ;"
        log "...done"
    fi
    log "Creation of MySQL '${1}' user..."
    USEREXIST=$(mysql -u root -p"${MYSQLPWD}" -B -N -e "use mysql; SELECT User FROM user;" | grep ${1} | wc -l)
    if [[ ${USEREXIST} -gt 0 ]]; then
        log "A MySQL user called '${1}' already exists"
    else
        #PASS=$(cat /dev/urandom|tr -dc "a-zA-Z0-9\$\?"|fold -w 10|head -1)

        MYSQL_PROJECT_PASS=$(generate_password)

        mysql -u root -p"${MYSQLPWD}" -e "CREATE USER '${1}'@'localhost' identified by '${MYSQL_PROJECT_PASS}' ;"
        log "...done"
        log "Fix MySQL privileges..."
        mysql -u root -p"${MYSQLPWD}" -e "GRANT ALL PRIVILEGES on ${1}.* to '${1}'@'localhost' ;"
        log "...done"
    fi
}

##################
#
#     MAIN
#
##################

# Check if mysql-server is installed
if [[ -z $(dpkg -l | grep -e "^ii  mysql-server ") ]]; then
    echo "MySQL server is not installed on the server. Please install it before. Aborted..." && exit 1
fi

# install pure-ftpd-mysql
installPackage pure-ftpd-mysql

# MySQL creation
createDB pureftpd

##Modification du fichier /etc/pure-ftpd/db/mysql.conf
MYSQLCONFFILE="/etc/pure-ftpd/db/mysql.conf"

[[ -f "${MYSQLCONFFILE}" ]] && mv "${MYSQLCONFFILE}" "${MYSQLCONFFILE}".orig

#Ajout des bonnes requetes:
cat > ${MYSQLCONFFILE} <<EOF

# Config Pure-ftpd MySQL

# MYSQLServer         127.0.0.1
# MYSQLPort           3306
MYSQLSocket         /var/run/mysqld/mysqld.sock
MYSQLUser           pureftpd
MYSQLPassword       $MYSQL_PROJECT_PASS
MYSQLDatabase       pureftpd
MYSQLCrypt          md5

MYSQLGetPW          SELECT Password FROM users WHERE User="\L" AND status="1" AND (ipaccess = "*" OR ipaccess LIKE "\R")
MYSQLGetUID         SELECT Uid FROM users WHERE User="\L" AND status="1" AND (ipaccess = "*" OR ipaccess LIKE "\R")
MYSQLGetGID         SELECT Gid FROM users WHERE User="\L" AND status="1" AND (ipaccess = "*" OR ipaccess LIKE "\R")
MYSQLGetDir         SELECT Dir FROM users WHERE User="\L" AND status="1" AND (ipaccess = "*" OR ipaccess LIKE "\R")
MySQLGetBandwidthUL SELECT ULBandwidth FROM users WHERE User="\L" AND status="1" AND (ipaccess = "*" OR ipaccess LIKE "\R")
MySQLGetBandwidthDL SELECT DLBandwidth FROM users WHERE User="\L" AND status="1" AND (ipaccess = "*" OR ipaccess LIKE "\R")

EOF


# Check if quota are configured on the filesystem
QUOTA=$(grep "quota" /etc/fstab)
if [[ -n "${QUOTA}" ]]; then
    read -p "Do you have configured quotas on your filesystem (y/N) ? " USE_QUOTA
    USE_QUOTA=${USE_QUOTA:-N}
    case ${USE_QUOTA} in
        Y|y|O|o)
            ## Creation de la table users dans la base pureftpd
            mysql -u pureftpd -p${MYSQL_PROJECT_PASS} -D pureftpd -e "CREATE TABLE users (
                User varchar(35) NOT NULL default '',
                status enum('0','1') NOT NULL default '0',
                Password varchar(64) NOT NULL default '',
                Uid varchar(11) NOT NULL default '-1',
                Gid varchar(11) NOT NULL default '-1',
                Dir varchar(128) NOT NULL default '',
                ULBandwidth smallint(5) NOT NULL default '0',
                DLBandwidth smallint(5) NOT NULL default '0',
                comment tinytext NOT NULL,
                ipaccess varchar(15) NOT NULL default '*',
                QuotaSize smallint(5) NOT NULL default '0',
                QuotaFiles int(11) NOT NULL default 0,
                LastModif date NOT NULL DEFAULT '0000-00-00',
                PRIMARY KEY (User),
                UNIQUE KEY User (User));"
            echo >> "MySQLGetQTASZ       SELECT QuotaSize FROM users WHERE User=\"\\L\" AND status=\"1\" AND (ipaccess = \"*\" OR ipaccess LIKE \"\\R\")"
            echo >> "MySQLGetQTAFS       SELECT QuotaFiles FROM users WHERE User=\"\\L\" AND status=\"1\" AND (ipaccess = \"*\" OR ipaccess LIKE \"\\R\")"
        ;;
        
        *) ## Creation de la table users dans la base pureftpd
            mysql -u pureftpd -p${MYSQL_PROJECT_PASS} -D pureftpd -e "CREATE TABLE users (
                User varchar(35) NOT NULL default '',
                status enum('0','1') NOT NULL default '0',
                Password varchar(64) NOT NULL default '',
                Uid varchar(11) NOT NULL default '-1',
                Gid varchar(11) NOT NULL default '-1',
                Dir varchar(128) NOT NULL default '',
                ULBandwidth smallint(5) NOT NULL default '0',
                DLBandwidth smallint(5) NOT NULL default '0',
                comment tinytext NOT NULL,
                ipaccess varchar(15) NOT NULL default '*',
                LastModif date NOT NULL DEFAULT '0000-00-00',
                PRIMARY KEY (User),
                UNIQUE KEY User (User));"
        ;;
    esac
else
    mysql -u pureftpd -p${MYSQL_PROJECT_PASS} -D pureftpd -e "CREATE TABLE users (
        User varchar(35) NOT NULL default '',
        status enum('0','1') NOT NULL default '0',
        Password varchar(64) NOT NULL default '',
        Uid varchar(11) NOT NULL default '-1',
        Gid varchar(11) NOT NULL default '-1',
        Dir varchar(128) NOT NULL default '',
        ULBandwidth smallint(5) NOT NULL default '0',
        DLBandwidth smallint(5) NOT NULL default '0',
        comment tinytext NOT NULL,
        ipaccess varchar(15) NOT NULL default '*',
        LastModif date NOT NULL DEFAULT '0000-00-00',
        PRIMARY KEY (User),
        UNIQUE KEY User (User));"
fi

## Options de configuration de PureFTPD
echo yes > /etc/pure-ftpd/conf/ChrootEveryone

## Options de configuration de PureFTPD : On autorise le user www-data
echo 1000 > /etc/pure-ftpd/conf/MinUID

## Options de configuration de PureFTPD : On met un umask sur les dossier et les fichiers uploadés
echo "113 002" > /etc/pure-ftpd/conf/Umask

## Options de configuration de PureFTPD : On change le minUID de connexion
## UID 33 = www-data (apache user)
echo 33 > /etc/pure-ftpd/conf/MinUID

## Redemarrage du serveur FTP
service pure-ftpd-mysql restart


echo -e "\n------------------------------------------------
           Resume Informations
------------------------------------------------\n

MySQL User       :   pureftpd
MySQL Password   :   ${MYSQL_PROJECT_PASS}
MySQL DBName     :   pureftpd

" | tee /root/info_pureftpd.log

chmod 600 /root/info_pureftpd.log

# Ok, c'est moche, mais ca permet de se retrouver plus facilement dans les logs...
#log "------------------------------"

exit 0
