#!/bin/bash
#
# Filename : phpmyadminManagement.sh
# Version  : 2.0
# Author   : mathieu androz
# Contrib  :
# Description :
#  . Automate PhpMyAdmin installation from sources
#  . Automate PhpMyAdmin update from sources
#


PMAINPLACE=""
PMAFILE="/tmp/pma.txt"
BLOWFISH=""


usage() {
    echo "
Command line options :

Required :
    -i      Install phpmyadmin from sources
    -u      Update already installed phpmyadmin version

Optionnal, with argument :
    -w      Webuser owner for PhpMyAdmin
    -p      Path of PhpMyAdmin folder (i.e /opt/phpmyadmin)
    -b      Blowfish passphrase
    -h      Print Help

Usage : $0 [-w webuser] [-p /path/of/phpmyadmin] [-b passphrase] {-i|-u}
"
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
                \n\tcreate 640 root root \
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
    else
        log "Package ${1} already installed on your system."
    fi
}


askPmafolder() {
    while [ "${PMAINPLACE}" = "" ] || ! [ -d "${PMAINPLACE}" ]
    do
        read -p "Enter the path of your present phpmyadmin folder (i.e /opt/phpmyadmin) : " PMAINPLACE
        if [[ $(echo ${PMAINPLACE: -1}) = "/" ]]; then
            PMAINPLACE=$(echo "${PMAINPLACE%?}")
        fi
        echo ""
    done
}


askBlowfish() {
    BLOWFISH=""
    while [ "${BLOWFISH}" = "" ]
    do
        read -p "Enter your blowfish passphrase : " BLOWFISH
        echo "Your blowfish passphrase is : ${BLOWFISH}"
    done
}


generateBlowfish() {
    [[ -z ${1} ]] && PASS_LEN="35" || PASS_LEN=${1}
    echo $(cat /dev/urandom|tr -dc "a-zA-Z0-9\$\?\!\-\_"|fold -w ${PASS_LEN}|head -1)
}


beginning() {
    installPackage zip
    test -z "${BLOWFISH}" && BLOWFISH=$(generateBlowfish 40)
    INSTALLPATH=$(dirname ${PMAINPLACE})
    INSERT="
/* Custom Configuration */
\$cfg['Servers'][\$i]['hide_db'] = '(information_schema|phpmyadmin|mysql)';
\$cfg['ShowServerInfo'] = false;
\$cfg['ShowPhpInfo'] = false;
\$cfg['ShowChgPassword'] = false;
\$cfg['ShowCreateDb'] = false;
\$cfg['SuggestDBName'] = false;
\$cfg['ThemeManager'] = false;
\$cfg['blowfish_secret'] = '\"${BLOWFISH}\"';
\$cfg['ThemeDefault'] = 'pmahomme';
\$cfg['SuhosinDisableWarning'] = true;
\$cfg['PmaNoRelation_DisableWarning'] = true;
?>"
    # Download latest PMA version
    wget --user-agent="Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/27.0.1453.110 Safari/537.36" \
        http://sourceforge.net/projects/phpmyadmin/files/latest/download -O ${PMAFILE} &> /dev/null
    # Recover last PMA version URL link
    PMALINK=$(grep "/phpmyadmin/phpMyAdmin" ${PMAFILE} | head -n 1 | cut -d = -f 4 | cut -d ? -f 1)
    if [[ ${PMALINK} =~ ^http ]] && [[ ${PMALINK} =~ zip$ ]]; then
        # Last PMA version ?
        PMALATEST=$(echo ${PMALINK} |  awk -F"/" '{print $7}')
    else
        log "bad link discovered : ${PMALINK}"
        purgeAll && exit 1
    fi
}


purgeAll() {
    log "Suppression of install files"
    rm ${PMAFILE}
    [[ -f ${INSTALLPATH}/phpMyAdmin-${PMALATEST}-all-languages.zip ]] && rm ${INSTALLPATH}/phpMyAdmin-${PMALATEST}-all-languages.zip
}


##################
#
#     MAIN
#
##################

[[ $(id -u) != 0 ]] && echo 'You must be root !' && exit 1

# If no args, print usage
[[ $# -eq 0 ]] && usage && exit 1

createLogrotate

while getopts ":hw:p:b:ui" option
do
    case "$option" in
        h)
            usage && exit 1
        ;;
        w)
            if [[ $(echo ${OPTARG} | cut -c 1) = "-" ]]; then
                echo "Bad argument for the parameter : $option"
                echo "Aborted..."
                exit 1
            else
                WEBUSER=${OPTARG}
            fi
        ;;
        p)  
            if [[ $(echo ${OPTARG} | cut -c 1) = "-" ]]; then
                echo "Bad argument for the parameter : $option"
                echo "Aborted..."
                exit 1
            else
                PMAINPLACE=${OPTARG}
            fi
        ;;
        b)  
            if [[ $(echo ${OPTARG} | cut -c 1) = "-" ]]; then
                echo "Bad argument for the parameter : $option"
                echo "Aborted..."
                exit 1
            else
                BLOWFISH=${OPTARG}
            fi
        ;;
        u)  
            
            beginning
            if [[ -f ${PMAINPLACE}/README ]]; then
                # PMA version already installed on the server ?
                PMAACTUALVERSION=$(cat ${PMAINPLACE}/README | grep -E '^Version' | cut -d " " -f 2)
                log "Actual version : ${PMAACTUALVERSION}"
                log "New version found : ${PMALATEST}"
                # If actual is older than the new one, deploy the new version of PhpMyAdmin
                if echo "${PMALATEST} ${PMAACTUALVERSION}" | awk '{exit !( $1 > $2)}'; then
                    cd ${INSTALLPATH} && wget "${PMALINK}" &> /dev/null
                    unzip ${INSTALLPATH}/phpMyAdmin-${PMALATEST}-all-languages.zip &> /dev/null
                    # Backup actual version in tar.gz with today's date
                    tar czf $(basename ${PMAINPLACE})_$(date +%Y%m%d).tar.gz $(basename ${PMAINPLACE}) &> /dev/null && rm -rf ${PMAINPLACE}
                    mv ${INSTALLPATH}/phpMyAdmin-${PMALATEST}-all-languages ${PMAINPLACE}
                    [[ ! -f ${PMAINPLACE}/config.inc.php ]] && cp ${PMAINPLACE}/config.sample.inc.php ${PMAINPLACE}/config.inc.php
                    sed -i '/^$/d' ${PMAINPLACE}/config.inc.php
                    sed -i '$d' ${PMAINPLACE}/config.inc.php
                    echo "${INSERT}" >> ${PMAINPLACE}/config.inc.php && log "Configuration of config.inc.php file"
                    test -z ${WEBUSER} && WEBUSER="www-data"
                    chown -R ${WEBUSER}:${WEBUSER} ${PMAINPLACE}
                else
                    log "No new PhpMyAdmin version yet..." && exit 1
                fi
            else
                log "Unable to get the actual version of PhpMyAdmin" && exit 1
            fi
            purgeAll
        ;;
        i)  
            test -z "${PMAINPLACE}" && askPmafolder
            test -d "${PMAINPLACE}" && log "This folder already exists. Aborted..." && exit 1
            beginning
            cd ${INSTALLPATH} && wget "${PMALINK}" &> /dev/null
            unzip ${INSTALLPATH}/phpMyAdmin-${PMALATEST}-all-languages.zip &> /dev/null
            mv ${INSTALLPATH}/phpMyAdmin-${PMALATEST}-all-languages ${PMAINPLACE}
            [[ ! -f ${PMAINPLACE}/config.inc.php ]] && cp ${PMAINPLACE}/config.sample.inc.php ${PMAINPLACE}/config.inc.php
            sed -i '/^$/d' ${PMAINPLACE}/config.inc.php
            sed -i '$d' ${PMAINPLACE}/config.inc.php
            echo "${INSERT}" >> ${PMAINPLACE}/config.inc.php && log "Configuration of config.inc.php file"
            test -z ${WEBUSER} && WEBUSER="www-data"
            chown -R ${WEBUSER}:${WEBUSER} ${PMAINPLACE}
            purgeAll
        ;;
        :)  
            echo "Option ${OPTARG} requieres an argument. Aborted..." && exit 1
        ;;
        \?) 
            echo "${OPTARG}: INVALID OPTION. Aborted..." && exit 1
        ;;
    esac
done


exit 0

# Ok, c'est moche, mais ca permet de se retrouver plus facilement dans les logs...
#log "------------------------------"
