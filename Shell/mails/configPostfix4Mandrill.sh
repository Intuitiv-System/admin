#!/bin/bash
#
# Filename : configPostfix4Mandrill.sh
# Version  : 1.0
# Author   : mathieu androz
# Contrib  : 
# Description :
#  . Install postfix & sasl
#  . configure postfix to work with Mandrill plateform
#

POSTFIX="/etc/postfix"

usage() {
    ::
}


log() {
    LOGFILE="/var/log/admin/admin.log"
    [[ ! -d $(dirname ${LOGFILE}) ]] && mkdir -p $(dirname ${LOGFILE})
    echo "$(date +%Y%m%d-%H:%M:%s) :: " ${1} | tee -a ${LOGFILE}
}

installPackage() {
    if [[ $(dpkg -l | grep "${1}" | awk '{print $1}') != "ii" ]]; then
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

installPackage postfix
installPackage libsasl2-2
installPackage ca-certificates
installPackage libsasl2-modules

# Test if Mandrill is already configured on Postfix
#if [[ $(grep -E "^relayhost[")]]

#1
SASL="${POSTFIX}/sasl_passwd"
test -f ${SASL} && mv ${SASL} ${SASL}.B4mandrill
echo -e "[smtp.mandrillapp.com]:587\t" > ${SASL}
read -p "Enter Mandrill USERNAME:API_KEY on the same line - Press Enter" VIDE
vi ${SASL}
chown root:root ${SASL} && chmod go-rwx ${SASL}
postmap ${SASL}

#2
MAIN="${POSTFIX}/main.cf"
test -f ${MAIN} && cp ${MAIN} ${MAIN}.B4mandrill
echo "--- Configuration of Postfix main.cf ---"
read -p "Select \"Internet websites\" - Press Enter" VIDE
dpkg-reconfigure postfix
sed -i -e '/relayhost/s/^/#/g' ${MAIN}
echo "
# Custom against SPAMS
smtpd_error_sleep_time = 2s
smtpd_soft_error_limit = 10
smtpd_hard_error_limit = 20

##########
# Mandrill config
##########
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_use_tls = yes
" >> ${MAIN}


# Ok, c'est moche, mais ca permet de se retrouver plus facilement dans les logs...
#log "------------------------------"