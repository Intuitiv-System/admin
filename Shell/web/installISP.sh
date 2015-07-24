#!/bin/bash

apt-get install binutils sudo mysql-server
mysql_secure_installation

service mysql stop
echo "[mysqld]
init_connect='SET collation_connection = utf8_general_ci'
init_connect='SET NAMES utf8'
character-set-server = utf8" > /etc/mysql/conf.d/custom_IT.cnf
service mysql start

apt-get install apache2 apache2-doc apache2-utils libapache2-mod-php5 php5 php5-common php5-gd php5-mysql php5-imap phpmyadmin php5-cli php-pear php-auth php5-mcrypt mcrypt php5-imagick imagemagick libruby libapache2-mod-python php5-curl php5-intl php5-ming php5-ps php5-pspell php5-recode php5-snmp php5-sqlite php5-tidy php5-xmlrpc php5-xsl php-apc

a2enmod rewrite ssl actions include auth_digest && service apache2 restart

apt-get install php5-fpm apache2-mpm-itk


a2enmod actions alias && service apache2 restart

# Modif du sources.list
sed -i 's/^deb\(.*\)main$/\deb\1main contrib non-free/g' /etc/apt/sources.list
sed -i 's/^deb\(.*\)contrib$/deb\1contrib non-free/g' /etc/apt/sources.list

apt-get update && \
  apt-get install libapache2-mod-fastcgi && \
  a2enmod fastcgi && \
  service apache2 restart



#### Pure-ftpd ####
apt-get install pure-ftpd-common pure-ftpd-mysql quota quotatool

sed -i 's/^VIRTUALCHROOT=true/^VIRTUALCHROOT=false/g' /etc/default/pure-ftpd-common

service pure-ftpd-mysql restart

### Quota ###

echo "Ajouter ca : usrjquota=quota.user,grpjquota=quota.group,jqfmt=vfsv0 dans /etc/fstab pour l'activation des quota"

read -p "Modifier /etc/fastab puis Entrée"

mount -o remount /
quotacheck -avugm
quotaon -avug

#### Chroot ####
apt-get install build-essential autoconf automake1.9 libtool flex bison debhelper binutils-gold

cd /tmp
wget http://olivier.sessink.nl/jailkit/jailkit-2.17.tar.gz
tar xvfz jailkit-2.17.tar.gz
cd jailkit-2.17
./debian/rules binary

cd ..
dpkg -i jailkit_2.17-1_*.deb
rm -rf jailkit-2.17*

#### Fail2ban ####
apt-get install fail2ban

echo "[postfix-sasl]
enabled  = false
port     = smtp
filter   = postfix-sasl
logpath  = /var/log/mail.log
maxretry = 3" > /etc/fail2ban/jail.local

echo "ignoreregex =" >> /etc/fail2ban/filter.d/postfix-sasl.conf

service fail2ban restart

#### ISPConfig 3 ####
cd /tmp
wget http://www.ispconfig.org/downloads/ISPConfig-3-stable.tar.gz
tar xfz ISPConfig-3-stable.tar.gz
cd ispconfig3_install/install/

echo "#####################################################"

php -q install.php
