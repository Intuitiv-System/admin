#!/bin/bash

#####################################################################
##								    #
##	Script pour ajouter les ip banned de iptables dans          #
##	le hosts.deny de FreePBX				    #
##								    #
#####################################################################


#HOSTS_DENY="/etc/hosts.deny"
HOSTS_DENY="/root/hosts.d"
BANNED_FILE="/tmp/banned.txt"

[[ -f "${HOSTS_DENY}" ]] && cp "${HOSTS_DENY}" /root/hosts.deny

BANNED_IPS=$(iptables -L -n | sed -e '1,/Chain fail2ban-ASTERISK/d' -e '/Chain fpbx-rtp/,$d' | grep REJECT | sort | uniq | awk '{print $4}' | sed -e '/80.12.83.108/d')

echo "${BANNED_IPS}" > "${BANNED_FILE}"

# Format IPs for hosts.deny
sed -i 's/^/ALL: /' "${BANNED_FILE}"

# Get only banned IPs from hosts.deny file
ALREADY_BANNED="/root/1.txt"
grep -e '^ALL:' "${HOSTS_DENY}" > "${ALREADY_BANNED}"

DIFF=$(diff "${BANNED_FILE}" "${ALREADY_BANNED}")

#IP2ADD=$(grep -e '^< ALL:' "${DIFF}" | awk '{print $2 $3}')
#Formatage de la sortie de la commande diff pour le fichier hosts.deny
IP2ADD=$(diff "${BANNED_FILE}" "${ALREADY_BANNED}" | grep -e '^< ALL: ' | awk '{print $2 " " $3}')

echo "${IP2ADD}" >> ${HOSTS_DENY}
