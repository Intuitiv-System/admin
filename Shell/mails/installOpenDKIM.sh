#!/bin/bash
#
# Filename : installOpendkim.sh
# Version  : 1.0
# Author   : mathieu androz
# Contrib  :
# Description :
#  . Install Opendkim
#  . Configure Opendkim with Postfix
#


INSTALLFOLDER="/etc/dkim"
CONFIGFILE="/etc/opendkim.conf"
HOST_NAME=""
POSTFIXCONF="/etc/postfix/main.cf"

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
                apt-get -y -q install "${1}" &> /dev/null
                log "Installation du package ${1}"
        fi
}


##################
#
#     MAIN
#
##################

installPackage opendkim

while [ -z ${HOST_NAME} ]
do
        read -p "Enter the hostname you want to sign with DKIM : " HOST_NAME
done

if [[ -d ${INSTALLFOLDER} ]]; then
        echo "${INSTALLFOLDER} already exists. Please check your opendkim config. Aborted..."
        apt-get purge opendkim &> /dev/null
        apt-get autoremove &> /dev/null
        exit 1
else
        mkdir ${INSTALLFOLDER}
fi

if [[ -f ${CONFIGFILE} ]]; then
        cp ${CONFIGFILE} ${CONFIGFILE}.orig
fi

sed -i s/^Domain/^#Domain/g ${CONFIGFILE}
sed -i s/^Keyfile/^#Keyfile/g ${CONFIGFILE}
sed -i s/^Selector/^#Selector/g ${CONFIGFILE}
echo "
Domain                  ${HOST_NAME}
KeyFile                                 ${INSTALLFOLDER}/private.key
Selector                dkim
" >> ${CONFIGFILE}

openssl genrsa -out  ${INSTALLFOLDER}/private.key 1024
openssl rsa -in  ${INSTALLFOLDER}/private.key -pubout -out  ${INSTALLFOLDER}/public.key
chmod 640  ${INSTALLFOLDER}/private.key
chown -R opendkim:root  ${INSTALLFOLDER}

if [[ -f "/etc/default/opendkim" ]]; then
        echo "SOCKET=\"inet:8891:localhost\"" >> /etc/default/opendkim
fi

if [[ -f ${POSTFIXCONF} ]]; then
        cp ${POSTFIXCONF} ${POSTFIXCONF}.orig
fi

echo "
# Filtres DKIM ...
milter_default_action = accept
milter_protocol = 6
smtpd_milters = inet:127.0.0.1:8891
non_smtpd_milters = inet:127.0.0.1:8891
" >> ${POSTFIXCONF}

chown -R opendkim:root  ${INSTALLFOLDER}/private.key

/etc/init.d/postfix restart && /etc/init.d/opendkim restart

KEY=$(sed '1d' ${INSTALLFOLDER}/public.key | sed '$d' | tr -d '\n')

echo "
::: DNS CONFIGURATION :::

1. Create a SPF field like = ${HOST_NAME}       SPF             \"v=spf1 ptr a ~all\"

2. Create a TXT field like = _domainkey.${HOST_NAME}    TXT             \"t=y; o=-;\"

3. Create a DKIM field like = dkim._domainkey.${HOST_NAME}      DKIM    \"v=DKIM1; k=rsa; t=s; p=${KEY}\"

Done !"


# Ok, c'est moche, mais ca permet de se retrouver plus facilement dans les logs...
#log "------------------------------"

exit 0
