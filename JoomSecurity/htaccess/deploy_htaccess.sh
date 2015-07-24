#!/bin/bash
##
# Description : Secure Joomla folders which are often used to hack severs
# Author : Olivier Renard <orenard@intuitiv.fr> <olivier.renard.eu@gmail.com>
# Version : 1.0

JOOM_SECU_DIR="/root/joomla_security"
# List of home directories websites, separated by a pipe
# Example :
#  Website 1 directory : /home/site1
#  Website 2 directory : /home/toto
#  Website 2 directory : /home/plip
#  JOOM_SITES_PROD="site1|toto|plip"
JOOM_SITES_PROD=""

[[ -z ${JOOM_SITES_PROD} ]] && echo "You must define sites to protect" && exit 1

function pause {
  read -p "$*"
}

function preparation {
  [[ ! -d /root/joomla_security ]] && mkdir /root/joomla_security
  cd /root/joomla_security
  mkdir images tmp
  wget --no-check-certificate --user=scriptsadm --password="lhh28mo;" https://svn.code.sf.net/p/admin-scripts/code/trunk/JoomSeurity/htaccess/images/.htaccess -O /root/joomla_security/images/.htaccess
  wget --no-check-certificate --user=scriptsadm --password="lhh28mo;" https://svn.code.sf.net/p/admin-scripts/code/trunk/JoomSeurity/htaccess/tmp/.htaccess -O /root/joomla_security/tmp/.htaccess
}

function copy_htaccess {
  # 2 params needed
  #  - $1 : src folder
  #  - $2 : dest folder

  # check if there is already a htaccess file in dest folder
  if [[ ! -f ${2}/.htaccess ]]; then
    #echo -n "Copying .htaccess in ${2} : "
    cp ${1}/.htaccess ${2}/.htaccess && echo "[OK]" || "[FAIL]"
  else
    COMPARE_IMG_HT=$(diff ${1}/.htaccess ${2}/.htaccess)
    if [[ ! -z ${COMPARE_IMG_HT} ]]; then
      echo "A different .htaccess already exists in ${2}"
      pause "Press any key to open vim and verify manually it's content"
      vim ${2}/.htaccess
    #else
      #echo "[SKIP] .htaccess file in ${2} already exists and is identical."
    fi
  fi
}

if [[ ! -d ${JOOM_SECU_DIR} ]]; then
  wget --no-check-certificate --user=scriptsadm --password="lhh28mo;" https://svn.code.sf.net/p/admin-scripts/code/trunk/JoomSeurity/htaccess_preparation.sh
  chmod 700 htaccess_preparation.sh
  ./htaccess_preparation.sh
fi

preparation

for SITE in /home/*/www; do
  # If website are Joomla! && in ${JOOM_SITES_PROD}
  if [[ -f ${SITE}/configuration.php ]] && \
   [[ ! -z $(cat ${SITE}/configuration.php | grep -i "joomla") ]] && \
   [[ ! -z $(echo ${SITE} | egrep ${JOOM_SITES_PROD}) ]]; then
    #echo ${SITE}
    JOOM_USER=$(ls -l ${SITE}/.. | egrep "www$" | cut -d" " -f3)
    JOOM_GROUP=$(ls -l ${SITE}/.. | egrep "www$" | cut -d" " -f4)

    # copy .htaccess files
    copy_htaccess ${JOOM_SECU_DIR}/images ${SITE}/images
    copy_htaccess ${JOOM_SECU_DIR}/tmp ${SITE}/tmp

    # on change le user/group sur les fichiers .htaccess
    chown ${JOOM_USER}:${JOOM_GROUP} ${SITE}/images/.htaccess ${SITE}/tmp/.htaccess
    chmod 644 ${SITE}/images/.htaccess ${SITE}/tmp/.htaccess

    echo
  fi
done
