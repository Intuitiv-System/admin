#!/bin/bash
#
# Filename : installNRPE.sh
# Version  : 1.1
# Author   : mathieu androz
# Contrib  : 
# Description :
#  . Nagios NRPE installation on a host to monitor
#  . Configure NRPE
#  . Add memory script to check memory (check_memory.sh)
#


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

#Installation of package : nagios-nrpe-server
apt-get install -y nagios-nrpe-server

# Configuration
NRPECONF="/etc/nagios/nrpe.cfg"
NRPECUSTOMCONF="/etc/nagios/nrpe.d/custom_IT.cfg"
if [[ -f ${NRPECONF} ]]; then
	cp ${NRPECONF} ${NRPECONF}.orig
	sed -i "s/^server_port/#server_port/g" ${NRPECONF}
	sed -i "s/^allowed_host/#allowed_hosts/g" ${NRPECONF}
	sed -i "s/^dont_blame/#dont_blame/g" ${NRPECONF}
	sed -i "s/^command\[/#command\[/g" ${NRPECONF}
fi

if [[ ! -f ${NRPECUSTOMCONF} ]]; then
	echo "# Port d'écoute du serveur Nagios
server_port=5666
 
# Adresse IP du serveur Nagios
#allowed_hosts=192.168.1.5
#Ou pour une machine de l'extérieur
allowed_hosts=80.12.83.108,85.170.199.32,89.2.157.7,37.59.3.119
 
#On autorise le passage d'arguments
dont_blame_nrpe=1
 
command[check_users]=/usr/lib/nagios/plugins/check_users -w 5 -c 10
command[check_load]=/usr/lib/nagios/plugins/check_load -w 15,10,5 -c 30,25,20
command[check_slash]=/usr/lib/nagios/plugins/check_disk -w 20% -c 10% -p /
command[check_home]=/usr/lib/nagios/plugins/check_disk -w 20% -c 10% -p /home
command[check_var]=/usr/lib/nagios/plugins/check_disk -w 20% -c 10% -p /var
command[check_zombie_procs]=/usr/lib/nagios/plugins/check_procs -w 5 -c 10 -s Z
command[check_total_procs]=/usr/lib/nagios/plugins/check_procs -w 150 -c 200
command[check_all_disks]=/usr/lib/nagios/plugins/check_disk -w 20% -c 10%
command[check_procs]=/usr/lib/nagios/plugins/check_procs -w 250 -c 400
command[check_swap]=/usr/lib/nagios/plugins/check_swap -w 20% -c 10%
" > ${NRPECUSTOMCONF}
fi

# Creation of check_memory script
CHECK_MEMORY="/usr/lib/nagios/plugins/check_memory"
if [[ ! -f ${CHECK_MEMORY} ]]; then
	cd /tmp
	wget "https://raw.githubusercontent.com/lazzio/admin/master/Applicatifs/Nagios/nagios_check/check_memory.txt"
	mv /tmp/check_memory.txt ${CHECK_MEMORY}
	perl -pi.orig -e 's#\r\n#\n#g' ${CHECK_MEMORY}
	chmod 755 ${CHECK_MEMORY}
  echo "command[check_memory]=${CHECK_MEMORY} -w 70 -c 90" >> ${NRPECUSTOMCONF}
fi

##Creation of check_opcache script
CHECK_OPCACHE="/var/www/html/www/tools/"
if [[ ! -d ${CHECK_OPCACHE} ]]
then
  mkdir -p ${CHECK_OPCACHE}
fi
  cd /tmp
  wget "https://github.com/lazzio/admin/blob/master/Applicatifs/Nagios/nagios_check/check_opcache.php"
  mv /tmp/check_opcache.php ${CHECK_OPCACHE}
  perl -pi.orig -e 's#\r\n#\n#g' ${CHECK_OPCACHE}
  chmod 755 ${CHECK_OPCACHE}/check_opcache.php
  
 # Creation of Postfix mailq check script
CHECK_MAILQ="/usr/lib/nagios/plugins/check_postfix_queue"
if [[ $(dpkg -l | grep "postfix " | awk '{print $1}') == "ii" ]]; then
	cd /tmp
	wget "https://raw.githubusercontent.com/lazzio/admin/master/Applicatifs/Nagios/nagios_check/check_postfix_queue.txt"
	mv /tmp/check_postfix_queue.txt ${CHECK_MAILQ}
	perl -pi.orig -e 's#\r\n#\n#g' ${CHECK_MAILQ}
	chmod 755 ${CHECK_MAILQ}
	echo "command[check_queue]=${CHECK_MAILQ} -w 20 -c 40" >> ${NRPECUSTOMCONF}
fi

# Creation of Apache connections number check script
CHECK_APACHE="/usr/lib/nagios/plugins/check_apache_connections"
if [[ $(dpkg -l | grep "apache2 " | awk '{print $1}') == "ii" ]]; then
  cd /tmp
  wget "https://raw.githubusercontent.com/lazzio/admin/master/Applicatifs/Nagios/nagios_check/check_apache_connections.txt"
  mv /tmp/check_apache_connections.txt ${CHECK_APACHE}
  perl -pi.orig -e 's#\r\n#\n#g' ${CHECK_APACHE}
  chmod 755 ${CHECK_APACHE}
  echo "command[check_apache_connections]=${CHECK_APACHE} -w 250 -c 300" >> ${NRPECUSTOMCONF}
fi

# Creation of JStat check script
CHECK_JSTAT="/usr/lib/nagios/plugins/check_jstat"
if [[ -n $(which java) ]]; then
  cd /tmp
  wget "https://raw.githubusercontent.com/lazzio/admin/master/Applicatifs/Nagios/nagios_check/check_jstat.txt"
  mv /tmp/check_jstat.txt ${CHECK_JSTAT}
  perl -pi.orig -e 's#\r\n#\n#g' ${CHECK_JSTAT}
  chmod 755 ${CHECK_JSTAT}
  echo "#command[check_jstat]=${CHECK_JSTAT} -p -w 85 -c 90" >> ${NRPECUSTOMCONF}
fi


echo "#command[check_tcp_solr]=/usr/lib/nagios/plugins/check_tcp -H localhost -4 --port 8983" >> ${NRPECUSTOMCONF}

service nagios-nrpe-server restart



# Ok, c'est moche, mais ca permet de se retrouver plus facilement dans les logs...
#log "------------------------------"

exit 0
