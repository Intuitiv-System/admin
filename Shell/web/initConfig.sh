#!/bin/bash
#
# Filename : initConfig.sh
# Version  : 1.0
# Author   : mathieu androz
# Contrib  : 
# Description :
#  . 
#  . 
#

LOGFILE="/var/log/admin/admin.log"

usage() {
    ::
}

createLogrotate() {
    LOGROTATEDIR="/etc/logrotate.d"
    LOGROTATEFILE="admin"
    if [[ -d ${LOGROTATEDIR} ]]; then
        if [[ ! -f ${LOGROTATEDIR}/${LOGROTATEFILE} ]]; then
            touch ${LOGROTATEDIR}/${LOGROTATEFILE}
            chmod 644 ${LOGROTATEDIR}/${LOGROTATEFILE}
            echo -e "${LOGFILE} {\
                \n\tweekly \
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
    [[ ! -d $(dirname ${LOGFILE}) ]] && mkdir -p $(dirname ${LOGFILE})
    echo "$(date +%Y%m%d-%H:%M:%S) :: " ${1} | tee -a ${LOGFILE}
}


installPackage() {
    if [[ $(dpkg -l | awk '{print $1" "$2}' | grep " ${1}"$) != "ii ${1}" ]]; then
        log "Installation du package ${1}..."
        apt-get -y -q install "${1}" &> /dev/null
    fi
}

phpComposant() {
    if [[ $(dpkg -l | awk '{print $1" "$2}' | grep " ${1}"$) != "ii ${1}" ]]; then
        echo ""
    fi
}

phpConfig() {
    # Configuration & Securisation
    PHPCONFD="/etc/php5/conf.d"
    if [[ -d ${PHPCONFD} ]] && [[ ! -f ${PHPCONFD}/custom_it.ini ]]; then
        echo -e "; Custom PHP installation :
            \n;Disable PHP exposure
            \nexpose_php = Off
            \n\n;disable_functions = symlink,shell_exec,exec,proc_close,proc_open,popen,system,dl,passthru,escapeshellarg,escapeshellcmd,curl_exec,curl_multi_exec,phpinfo
            \n\n;TimeZone
            \ndate.timezone = \"Europe/Paris\"
            \n\n;Errors
            \ndisplay_errors = Off
            \n\n;Secure
            \nopen_basedir = \"/var/www:/tmp:/opt/phpmyadmin:/usr/lib/php5:/usr/share/php5:/var/lib/php5\"
            \n" > ${PHPCONFD}/custom_it.ini
    fi
}

##################
#
#     MAIN
#
##################

createLogrotate


# Ok, c'est moche, mais ca permet de se retrouver plus facilement dans les logs...
#log "------------------------------"