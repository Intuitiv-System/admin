#!/bin/bash
#
# Filename : PhpDotdebInstaller.sh
# Version  : 1.0
# Author   : mathieu androz
# Contrib  : 
# Description :
#  . Install PHP5 DotDeb packages on Debian Squeeze
#  . without upgrade MySQL or any other packages
#


usage() {
    ::
}


log() {
    LOGFILE="/var/log/admin/admin.log"
    [[ ! -d $(dirname ${LOGFILE}) ]] && mkdir -p $(dirname ${LOGFILE})
    echo "$(date +%Y%m%d-%H:%M:%s) :: " ${1} | tee -a ${LOGFILE}
}


##################
#
#     MAIN
#
##################
if [[ ! -f /etc/debian_version ]] || [[ $(cat /etc/debian_version | cut -d"." -f1) != "6" ]]; then
	echo "You're not running Debian Squeeze, sorry."
else
	if [[ ! -f /etc/apt/sources.list.d/dotdeb.list ]]; then
		echo "#DotDeb packages
deb http://packages.dotdeb.org squeeze all
deb-src http://packages.dotdeb.org squeeze all" > /etc/apt/sources.list.d/dotdeb.list
	fi
	if [[ ! -f /etc/apt/preferences.d/dotdeb ]]; then
		echo "Package: libmysqlclient16
Pin : origin *.debian.org
Pin-Priority: 900

Package: mysql-client-5.1
Pin : origin *.debian.org
Pin-Priority: 900

Package: mysql-common
Pin: origin *.debian.org
Pin-Priority: 900

Package: mysql-server
Pin: origin *.debian.org
Pin-Priority: 900

Package: mysql-server-5.1
Pin: origin *.debian.org
Pin-Priority: 900

Package: mysql-server-core-5.1
Pin: origin *.debian.org
Pin-Priority: 900

Package: php5-*
Pin: origin packages.dotdeb.org
Pin-Priority: 500

Package: libapache2-mod-php5*
Pin: origin packages.dotdeb.org
Pin-Priority: 500

Package: *
Pin: origin packages.dotdeb.org
Pin-Priority: 500" > /etc/apt/preferences.d/dotdeb
	fi
	# Get the Dotdeb GPG Key
	wget http://www.dotdeb.org/dotdeb.gpg
	# Install Dotdeb GPG Key
	cat dotdeb.gpg | apt-key add -
	aptitude clean
	aptitude update
	aptitude safe-upgrade
fi


# Ok, c'est moche, mais ca permet de se retrouver plus facilement dans les logs...
#log "------------------------------"

exit 0