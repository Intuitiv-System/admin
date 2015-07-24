#!/bin/bash
#
# Filename : installModSecurity.sh
# Version  : 1.0
# Author   : mathieu androz
# Description :
# . Install & configure mod_security module for Apache 2.2
# . Update module's rules by the latest OWASP modsecurity rules
#   https://github.com/SpiderLabs/owasp-modsecurity-crs/tree/master/activated_rules
#


# OWASP modsecurity rules GIT url
OWASPGIT="https://github.com/SpiderLabs/owasp-modsecurity-crs"

# Logs file (don't edit it)
LOGFILE="/var/log/backup/bkp.log"


function usage() {
  ::
}

function createLogrotate() {
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
           \n\tcreate 640 $(id -un) adm
           \n}" > ${LOGROTATEDIR}/${LOGROTATEFILE}
    fi
  fi
}

function log() {
  [[ ! -d $(dirname ${LOGFILE}) ]] && mkdir -p $(dirname ${LOGFILE})
  echo "$(date +%Y%m%d-%H:%M:%S) :: " ${1} | tee -a ${LOGFILE}
}


test $(which git) || ( echo "git not found..." && exit 1 )

createLogrotate

if [[ $(dpkg -l | grep "libapache2-modsecurity" | awk '{print $1}') != "ii " ]]; then
  apt-get install -y libapache2-modsecurity > /dev/null
fi

cp /etc/modsecurity/modsecurity.conf{-recommended,}

if [[ -f /etc/modsecurity/modsecurity.conf ]]; then
  sed -i 's#^SecRuleEngine\(.*\)$#SecRuleEngine On#g' /etc/modsecurity/modsecurity.conf
  # Fix upload max file size at 32M
  sed -i 's#^SecRequestBodyLimit\(.*\)$#SecRequestBodyLimit 32768000#g' /etc/modsecurity/modsecurity.conf
  sed -i 's#^SecRequestBodyInMemoryLimit\(.*\)$#SecRequestBodyInMemoryLimit 32768000#g' /etc/modsecurity/modsecurity.conf
  sed -i 's#^SecResponseBodyAccess\(.*\)$#SecResponseBodyAccess Off#g' /etc/modsecurity/modsecurity.conf
fi

# Get OWASP modsecurity's rules
cd /tmp
git clone "${OWASPGIT}"
[[ -d /usr/share/modsecurity-crs ]] && \
  ( mv /usr/share/modsecurity-crs /usr/share/modsecurity-crs.bak && mv /tmp/owasp-modsecurity-crs /usr/share/modsecurity-crs )
( [[ -f /usr/share/modsecurity-crs/modsecurity_crs_10_setup.conf.example ]] && [[ ! -f /usr/share/modsecurity-crs/modsecurity_crs_10_setup.conf ]] ) && \
  mv /usr/share/modsecurity-crs/modsecurity_crs_10_setup.conf.example /usr/share/modsecurity-crs/modsecurity_crs_10_setup.conf
ln -s /usr/share/modsecurity-crs/base_rules/*.conf /usr/share/modsecurity-crs/activated_rules/

a2enmod mod-security
service apache2 restart



exit 0
