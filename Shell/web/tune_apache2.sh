#!/bin/bash
#
# Filename : tune_apache2.sh
# Version  : 1.1
# Author   : mathieu androz
# Description :
#  .Tuning of Apache2 prefork configuration
#   in the file /etc/apache2/apache2.conf
#
#


APACHECONF="/etc/apache2/apache2.conf"
TOTALMEM=$(free -m | sed -n 2p | awk '{print $2}')
ALLOWEDMEM=$(expr ${TOTALMEM} / 2)


usage() {
    ::
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
    elif [[ ${DISTRIB} = "Debian" ]]; then
        if [[ $(whoami) != "root" ]]; then
            echo "Login as root and execute this command : ${DIR}/${FILE}" && su -
            exit 0
        fi
    else
        echo "You're running on ${DISTRIB}.\nThis script is adapted for Debian-Like OS.\nBye"
        exit 1
    fi
}

avgMemApacheUsed() {
    TOTALMEMUSED=$(ps aux | grep 'apache2' | grep -v 'grep' | awk '{SUM+=$6}END{print SUM/1024}' | cut -d'.' -f1)
    NBAPACHEPROCESS=$(ps aux | grep 'apache2' | grep -v 'grep' | awk '{print $6}' | wc -l | tr -d ' ')
    AVGMEMAPACHEUSED=$(expr ${TOTALMEMUSED} / ${NBAPACHEPROCESS})
}


maxMemApacheUsed() {
    MAXMEMUSED=$(ps aux | grep 'apache2' | grep -v 'grep' | awk '{print $6/1024}' | cut -d'.' -f1 | sort | tail -n 1)
    echo "Maximum Memory used by a single Apache2 process is : ${MAXMEMUSED}"
}


# Number of theorical max Apache process allowed
# consistent to the total server RAM
maxAllowedClients() {
    MAXALLOWEDCLIENTS=$(expr ${ALLOWEDMEM} / ${AVGMEMAPACHEUSED})
}


# Check
MPMPREFORK=$(dpkg -l | grep apache2-mpm-prefork | wc -l)
#[[ ${MPMPREFORK} -nq 1 ]] && echo "Apache2 is not installed" && exit 1

# Recover actual MPM informations
ACTUALCONF=$(sed '/^<IfModule mpm_prefork_module>/,/^<\/IfModule>/!d' ${APACHECONF})





##################
#
# MAIN
#
###################

[[ ! -f ${APACHECONF} ]] && echo "The file ${APACHECONF} doesn't exist" && exit 1

CheckDistrib
echo "Actual Configuration of MPM Prefork is :"
echo "${ACTUALCONF}"

avgMemApacheUsed
echo ""
echo "Average of consummed Memory by Apache is : ${AVGMEMAPACHEUSED} Mo"
echo "Number of actual Apache2 childs : ${NBAPACHEPROCESS}"

maxAllowedClients
echo "Maximum Memory proposed for Apache2 : ${ALLOWEDMEM} Mo"
echo "Maximum number of Apache process allowed on the server : ${MAXALLOWEDCLIENTS}"

maxMemApacheUsed
echo ""
echo -e "A proposal of Apache2 MPM-prefork configuration can be :
    StartServers          5
    MinSpareServers       5
    MaxSpareServers       10
    MaxClients            ${MAXALLOWEDCLIENTS}
    MaxRequestsPerChild   1000
"

exit 0