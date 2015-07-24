#!/bin/bash
#
# Filename : pnpn_emailer.sh
# Version  : 1.0
# Author   : sanjay@intuitinnovations.com
# Contrib  : mathieu androz
# Description :
#  . This script does a simple task of creating PDF files via PNP url and emails it out
#  . 
#


usage() {
    ::
}


log() {
    LOGFILE="/var/log/admin/admin.log"
    if [[ ! -d $(dirname ${LOGFILE}) ]]; then
        mkdir $(dirname ${LOGFILE})
    fi
    echo "$(date +%Y%m%d) :: " ${1} | tee -a ${LOGFILE}
}


##################
#
#     MAIN
#
##################

# This script does a simple task of creating PDF files via PNP url and emails it out
# This script must be executed as root
# This script may contain sensitive information such as usernames and passwords, so ensure only root has access to it
# YOU MUST SPECIFY THE VARIABLES BELOW
# Script by sanjay@intuitinnovations.com
# v.1.1
# change log
#

# Usage.. pnp_emailer.sh <hostname> <service_name>, e.g. ./php_emailer.sh Astervox1 CPU_Load ---note--- (case sensitive)

# Exemple d'adresse :
# http://monitor.intuitiv.lan/pnp4nagios/pdf?host=om04-srv03.itserver.fr&srv=Current+Load&start=&end=

########################################################################################################################
# SETTINGS
########################################################################################################################

# Website Info: Change below

# CONSTANTS
nagiosurl=https://monitoring.intuitiv.lan     # e.g. https://192.168.1.1/nagios or http://nagios.intuit.my:8080/nagios
accessuser=                            # Your username to access the nagios website
accesspassword=                        # Your password to access the nagios website
usessl=1                                      # 1-yes or 2-no
deleteattachment=1                            # 1-yes or 2-no option to delete the generated PDF file, default yes

# CONSTANTS - EMAIL
emailfrom=icinga@
naturalname="Icinga Report"
sendto=
smtpserver=localhost
smtpport=25

########################################################################################################################

# Schedule it, create CRON jobs with the following example lines
# /usr/bin/pnp_emailer.sh SERVERNAME SERVICENAME &> /dev/null

# Don't change anything below this

# VARIABLES - WEB
#hostnameurl=$1
#svrnameurl=$2

####
# List of all hosts
###
for hostnameurl in  'server1' \
                    'server2' \
                    'server3' \
                    'server4'
do
        HERE=$(dirname $0)
        # Preparation of the filename
        filedate=`date +"%m-%d-%y"`
        filename=${hostnameurl}-${filedate}.pdf

        # Prepare PDF filename
        #if [ "$1" == "" ]; then
        #    echo "No hostname specified"
        #    exit
        #fi

        #if [ "$2" == "" ]; then
        #    echo "No service specified"
        #    exit
        #fi

        if [ "$usessl" == "1" ]; then
            clear
            cd ${HERE}
            echo Starting
            echo Using SSL options
            #wget --no-check-certificate --http-user=$accessuser --http-password=$accesspassword "$nagiosurl/pnp4nagios/pdf?host=$hostnameurl&srv=$svrnameurl&display=service&view=4&source=1&end=&start=" -O $filename
            wget --no-check-certificate --http-user=$accessuser --http-password=$accesspassword "$nagiosurl/pnp4nagios/pdf?host=$hostnameurl&view=2" -O $filename
        fi

        if [ "$usessl" == "2" ]; then
            clear
            cd ${HERE}
            echo Starting
            echo Using standard HTML options
            #wget --http-user=$accessuser --http-password=$accesspassword "$nagiosurl/pnp4nagios/pdf?host=$hostnameurl&srv=$svrnameurl&end=&start=" -O $filename
            # Graph One Week - all services for a host
            wget --http-user=$accessuser --http-password=$accesspassword "$nagiosurl/pnp4nagios/pdf?host=$hostnameurl&view=2" -O $filename
        fi

        # Now email that file
        /usr/bin/sendEmail -f $emailfrom -u "Icinga PDF Report Emailer -Reporting $hostnameurl" -a "$HERE/$filename" -t $sendto -m "Icinga PDF Report for $hostnameurl"


        if [ "$deleteattachment" == "1" ]; then
            clear
            echo Removing Generated Report
            rm $HERE/$filename
        fi
done

exit 0
