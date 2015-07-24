#!/bin/bash
#
# Filename : createChroot.sh
# Version  : 1.0
# Author   : mathieu androz
# Contrib  : 
# Description :
#  . 
#  . 
#


LOGFILE="/var/log/admin/admin.log"
HOSTINGBASE="/home/hosting"

# include
. /lib/lsb/init-functions


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
    [[ ! -d $(dirname ${LOGFILE}) ]] && mkdir -p $(dirname ${LOGFILE})
    echo "$(date +%Y%m%d-%H:%M:%S) :: " ${1} | tee -a ${LOGFILE}
}

logsuccess() {
    [[ ! -d $(dirname ${LOGFILE}) ]] && mkdir -p $(dirname ${LOGFILE})
    echo "$(date +%Y%m%d-%H:%M:%S) :: $(log_success_msg)" ${1} | tee -a ${LOGFILE}    
}

logwarn() {
    [[ ! -d $(dirname ${LOGFILE}) ]] && mkdir -p $(dirname ${LOGFILE})
    echo "$(date +%Y%m%d-%H:%M:%S) :: $(log_warn_msg)" ${1} | tee -a ${LOGFILE}    
}

logfailure() {
    [[ ! -d $(dirname ${LOGFILE}) ]] && mkdir -p $(dirname ${LOGFILE})
    echo "$(date +%Y%m%d-%H:%M:%S) :: $(slog_failure_msg)" ${1} | tee -a ${LOGFILE}    
}

installPackage() {
    if [[ $(dpkg -l | awk '{print $1" "$2}' | grep " ${1}"$) != "ii ${1}" ]]; then
        log "Installation du package ${1}..."
        apt-get -y -q install "${1}" &> /dev/null
    else
        log "Package ${1} already installed on your system."
    fi
}


##################
#
#     MAIN
#
##################

[[ ! -d ${HOSTINGBASE} ]] && echo "Please fix HOSTINGBASE variable" && exit 1

createLogrotate

installPackage build-essential 
installPackage autoconf
installPackage automake1.9
installPackage libtool
installPackage debhelper
installPackage binutils-gold

if [[ -z $(which jk_init) ]]; then
    cd /tmp
    wget http://olivier.sessink.nl/jailkit/jailkit-2.17.tar.gz
    tar xvfz jailkit-2.17.tar.gz
    cd jailkit-2.17
    ./debian/rules binary
    if [[ -f /tmp/jailkit_2.17-1_amd64.deb ]]; then
        dpkg -i /tmp/jailkit_2.17-1_amd64.deb
    else
        log "Installation of jailkit failed" && exit 1
    fi
    logsuccess "Installation of jailkit 2.17"
fi

read -p "Enter user name to create : " USERNAME

# Creer un home ou un répertoire qui contiendra tous les home chrootés distinctement.
# Ici, on crée /home/hosting + nom du user = user1
if [[ ! -d  "${HOSTINGBASE}"/"${USERNAME}" ]]; then
    mkdir -p "${HOSTINGBASE}"/"${USERNAME}"
    chown root:root "${HOSTINGBASE}"/"${USERNAME}"
    jk_init -v -j "${HOSTINGBASE}"/"${USERNAME}" apacheutils basicshell extendedshell editors jk_lsh netutils

    # Création du user Linux classique = user1
    [[ $(grep -E "^${USERNAME}$" /etc/passwd | wc -l) = 0 ]] && adduser "${USERNAME}"

    # Création du user dans l'envrionnement chrooté
    # usage :  jk_jailuser -m /path/chroot username
    jk_jailuser -m -j "${HOSTINGBASE}"/"${USERNAME}" "${USERNAME}"

    sed -i 's#/usr/bin/jk_lsh$#/bin/bash#g' "${HOSTINGBASE}"/"${USERNAME}"/etc/passwd

    # Fix Shell bug
    echo -e "#Fix Shell bug\nexport TERM=xterm" >> "${HOSTINGBASE}"/"${USERNAME}"/home/"${USERNAME}"/.bashrc
    source "${HOSTINGBASE}"/"${USERNAME}"/home/"${USERNAME}"/.bashrc


# Ok, c'est moche, mais ca permet de se retrouver plus facilement dans les logs...
#log "------------------------------"

