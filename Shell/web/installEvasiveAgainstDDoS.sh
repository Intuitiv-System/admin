#!/bin/bash
#
# Filename : installEvasiveAgainstDDoS.sh
# Version  : 1.0
# Author   : mathieu androz
# Contrib  :
# Description :
#  . Install Mod-Evasive sur Debian + configuratio
#

CONFIGFILE="/etc/apache2/conf.d/mod_evasive.conf"
LOGFOLDER="/var/log/apache2/mod_evasive"

usage() {
    ::
}


log() {
    LOGFILE="/var/log/admin/admin.log"
    [[ ! -d $(dirname ${LOGFILE}) ]] && mkdir -p $(dirname ${LOGFILE})
    echo "$(date +%Y%m%d-%H:%M:%s) :: " ${1} | tee -a ${LOGFILE}
}

configure_mod_evasive() {
    echo "#DOSHashTableSize is the size of the hash table that is created for the IP addresses monitored.
DOSHashTableSize 3097
#DOSPageCount is the number of pages allowed to be loaded for the DOSPageInterval setting. In our case, 2 pages per 1 second before the IP gets flagged.
DOSPageCount 2
#DOSSiteCount is the number of objects (ie: images, style sheets, javascripts, SSI, etc) allowed to be accessed in theDOSSiteInterval second. In our case, 100 objects per 1 second.
DOSSiteCount 100
#DOSPageInterval is the number of seconds the intervals are set for DOSPageCount.
DOSPageInterval 1
#DOSSiteInterval is the number of seconds the intervals are set for DOSSiteCount.
DOSSiteInterval 1
#DOSBlockingPeriod is the number of seconds the IP address will recieve the Error 403 (Forbidden) page when they have been flagged.
DOSBlockingPeriod 10
DOSLogDir ${LOGFOLDER}
DOSWhitelist 127.0.0.1" > $1

    chown -R www-data:www-data $1
    echo -e "\nconfig file for mod-evasive for apache is $1"
}

mod_evasive_enabled() {
    if [[ -h "/etc/apache2/mods-enabled/mod-evasive.load" ]]; then
        echo -e "\nmod-evasive is already enabled."
    else
        echo -e "\nbut mod-evasive isn't enabled..."
    fi
}


##################
#
#     MAIN
#
##################

echo "------------------------------------------------------"
echo "-- Mod-evasive against DDoS for Apache installation --"
echo "------------------------------------------------------"

if [[ $(dpkg -l | grep "libapache2-mod-evasive" | awk '{print $1}') = "ii" ]]; then
    echo "mod-evasive for apache is already installed"
    echo "checking for configuration file :"
    echo ". . . . ."
    if [[ -f ${CONFIGFILE} ]]; then
        echo "config file for mod-evasive already exists :"
        echo -e "its content is :\n"
        cat ${CONFIGFILE}
        mod_evasive_enabled
        exit 1
    else
        echo "there is no existing config file at ${CONFIGFILE}"
        exit 1
    fi
else
    echo "installation of mod-evasive for Apache :"
    echo ". . . . . "
    aptitude install libapache2-mod-evasive
    [[ ! -d ${LOGFOLDER} ]] && mkdir -p ${LOGFOLDER}
    echo "configuration of mod-evasive..."
    [[ ! -f ${CONFIGFILE} ]] && configure_mod_evasive ${CONFIGFILE}
    echo "activation of mod-evasive..."
    service apache2 restart 2> /dev/null
    if [[ $? != 0 ]]; then
        /etc/init.d/apache2 restart 2> /dev/null
    fi
fi


# Ok, c'est moche, mais ca permet de se retrouver plus facilement dans les logs...
#log "------------------------------"

exit 0
