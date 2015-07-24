#!/bin/bash

###################
# Install MySQL 5.5 under Debian Squeeze
###################


# This script uses DotDeb packages to install
# MySQL server 5.5 on Debian Squeeze with aptitude commands


# Download mysql5.5 package
cd /tmp
wget "http://www.mysql.com/get/Downloads/MySQL-5.5/mysql-5.5.28-debian6.0-x86_64.deb/from/http://cdn.mysql.com/"


# Edit sources.list
#SOURCES=/etc/apt/sources.list
SOURCES=/etc/apt/sources.list.d/dotdeb.org.list

if [[ -f ${SOURCES} ]]; then
	echo "" >> ${SOURCES}
	echo "# DotDeb links" >> ${SOURCES}
	echo "deb http://packages.dotdeb.org squeeze all" >> ${SOURCES}
	echo "deb-src http://packages.dotdeb.org squeeze all" >> ${SOURCES}
fi


# MySQL 5.5 package installation
gpg --keyserver keys.gnupg.net --recv-key 89DF5277
gpg -a --export 89DF5277 | apt-key add -

aptitude update

aptitude install -q -y  mysql-server-5.5

sleep 2


# Securisation of MySQL installation
/usr/bin/mysql_secure_installation

sleep 2


# Stop mysql service
if [[ $(pidof mysqld) != "" ]]; then
	/etc/init.d/mysql stop
fi


# Edit my.cnf
MYCNF=/etc/mysql/my.cnf
MYCONFD=/etc/mysql/conf.d

if [[ ! -f ${MYCONFD}/lowercase.cnf ]] && [[ -z $(grep "lower_case_table_names" ${MYCNF}) ]]; then
  echo -e "[mysqldump]
lower_case_table_names=1" > ${MYCONFD}/lowercase.cnf
fi
if [[ ! -f ${MYCONFD}/utf8.cnf ]] && [[ -z $(grep "character-set-server=utf8" ${MYCNF}) ]]; then
  echo "[client]
default-character-set=utf8

[mysqld]
init_connect='SET collation_connection = utf8_general_ci'
init_connect='SET NAMES utf8'
default-character-set=utf8
character-set-server = utf8
collation-server = utf8_general_ci

[mysql]
default-character-set=utf8" > ${MYCONFD}/utf8.cnf

## Pas joli!
#if [[ ! -f ${MYCNF}.local ]]; then
	#cp ${MYCNF} ${MYCNF}.local
	#sed -i "/[mysqldump]/i\#Disable case sensitivity\nlower_case_table_names=1\n\n#Default cahracter set as UTF8\ncharacter-set-server=utf8\n" ${MYCNF}
#fi


# Start mysql service
if [[ $(pidof mysqld) -eq "" ]]; then
	/etc/init.d/mysql start
fi


exit 0