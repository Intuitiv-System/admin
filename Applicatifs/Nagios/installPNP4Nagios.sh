#!/bin/bash
#
# Filename : instalPNP4Nagios.sh
# Description :
#  . Install PNP4Nagios from sources
#  . And configure PNP4Nagios with Nagios integration
#
#

usage() {
	echo"
Description :
	- Install PNP4Nagios from sources
	- Configure PNP4Nagios with Nagios integration
	- Choose for what Distro you want to deploy PNP4Nagios

Usage :
	$0 {redhat|debian}"
}


# Check requirements
if [[ ${1} == "debian" ]]; then
	[[ $(dpkg -l | grep "  perl ") != "ii" ]] && echo "Installation -> Perl" && aptitude -y -q install perl
	[[ $(dpkg -l | grep -E "  rrdtool ") != "ii" ]] && echo "Installation -> rrdtool" && aptitude -y -q install rrdtool
elif [[ ${1} == "redhat" ]]; then
	echo "Check if perl, rrdtool and httpd are installed... and comment this dummy lines 27 !" && exit 1
  echo "Run on redhat"
else
	usage && exit 1
fi


# Download sources
cd /tmp && wget "http://sourceforge.net/projects/pnp4nagios/files/latest/download" -o /tmp/pnp4nagios.log
FILENAME=$(grep -E "http://downloads.sourceforge.net/project/pnp4nagios/(.*).tar.gz" /tmp/pnp4nagios.log | head -n 1 | awk -F"?" '{print $1}' | sed 's/^.*http:\/\(.*\)$/\1/' | xargs basename)
mv /tmp/download /tmp/${FILENAME}
[[ $? != 0 ]] && echo "ERROR :: rename tar.gz error" && exit 1
FILE="/tmp/${FILENAME}"
tar xzf ${FILE}

FOLDER="$(echo ${FILE} | sed 's/^\(.*\).tar.gz$/\1/')"
if [[ ! -d ${FOLDER} ]]; then
        echo "Can't find extract folder. Aborted..." && exit 1
fi


# Compilation
#test ! -d /opt/pnp4nagios && mkdir -p /opt/pnp4nagios
#cd ${FOLDER} && ./configure --prefix=/opt/pnp4nagios --with-nagios-user=nagios --with-nagios-group=nagios
cd ${FOLDER} && ./configure --with-nagios-user=nagios --with-nagios-group=nagios
if [[ $? != 0 ]]; then
        echo "Compilation problem" && exit 1
fi
make all && make install


# Install web
make install-webconf && make install-config


# Install NPCD Init script call
make install-init

echo "PNP4Nagios successfully installed !"





##############################################################
#
# Nagios4 Configuration for PNP4Nagios
# Path to nagios installation folder = NAGIOS_INSTALLDIR
#
##############################################################

[[ -z ${NAGIOS_INSTALLDIR} ]] && read -p "Enter Nagios installation path : " NAGIOS_INSTALLDIR

if [[ -f ${NAGIOS_INSTALLDIR}/etc/nagios.cfg ]]; then
        cp ${NAGIOS_INSTALLDIR}/etc/nagios.cfg ${NAGIOS_INSTALLDIR}/etc/nagios.cfg.orig
        sed -i 's/process_performance_data/#process_performance_data/g' ${NAGIOS_INSTALLDIR}/etc/nagios.cfg
        echo "
#########################################################
#
# PNP4Nagios Configuration
#
#########################################################
process_performance_data=1

#
# service performance data
#
service_perfdata_file=/usr/local/pnp4nagios/var/service-perfdata
service_perfdata_file_template=DATATYPE::SERVICEPERFDATA\tTIMET::\$TIMET\$\tHOSTNAME::\$HOSTNAME\$\tSERVICEDESC::\$SERVICEDESC\$\tSERVICEPERFDATA::\$SERVICEPERFDATA\$\tSERVICECHECKCOMMAND::\$SERVICECHECKCOMMAND\$\tHOSTSTATE::\$HOSTSTATE$\tHOSTSTATETYPE::\$HOSTSTATETYPE\$\tSERVICESTATE::\$SERVICESTATE\$\tSERVICESTATETYPE::\$SERVICESTATETYPE\$
service_perfdata_file_mode=a
service_perfdata_file_processing_interval=15
service_perfdata_file_processing_command=process-service-perfdata-file

#
# host performance data starting with Nagios 3.0
#
host_perfdata_file=/usr/local/pnp4nagios/var/host-perfdata
host_perfdata_file_template=DATATYPE::HOSTPERFDATA\tTIMET::\$TIMET\$\tHOSTNAME::\$HOSTNAME\$\tHOSTPERFDATA::\$HOSTPERFDATA\$\tHOSTCHECKCOMMAND::\$HOSTCHECKCOMMAND\$\tHOSTSTATE::\$HOSTSTATE\$\tHOSTSTATETYPE::\$HOSTSTATETYPE\$
host_perfdata_file_mode=a
host_perfdata_file_processing_interval=15
host_perfdata_file_processing_command=process-host-perfdata-file
" >> ${NAGIOS_INSTALLDIR}/etc/nagios.cfg

else
        echo "${NAGIOS_INSTALLDIR}/etc/nagios.cfg doesn't exist. PNP4Nagios configuration in Nagios4 aborted." && exit 1
fi




if [[ -f ${NAGIOS_INSTALLDIR}/etc/objects/commands.cfg ]]; then
        cp ${NAGIOS_INSTALLDIR}/etc/objects/commands.cfg ${NAGIOS_INSTALLDIR}/etc/objects/commands.cfg.orig
        echo "
###############################################################
#
# PNP4Nagios Configuration
#
###############################################################
define command{
       command_name    process-service-perfdata-file
       command_line    /bin/mv /usr/local/pnp4nagios/var/service-perfdata /usr/local/pnp4nagios/var/spool/service-perfdata.\$TIMET\$
}

define command{
       command_name    process-host-perfdata-file
       command_line    /bin/mv /usr/local/pnp4nagios/var/host-perfdata /usr/local/pnp4nagios/var/spool/host-perfdata.\$TIMET\$
}
" >> ${NAGIOS_INSTALLDIR}/etc/objects/commands.cfg

else
        echo "${NAGIOS_INSTALLDIR}/etc/objects/commands.cfg doesn't exist. PNP4Nagios configuration in Nagios4 aborted." && exit 1
fi


echo "
To start NPCD, launch this :
/usr/local/pnp4nagios/bin/npcd -d -f /usr/local/pnp4nagios/etc/npcd.cfg"


read -p "Do you want to integrate PNP4Nagios to Nagios ? [Y/n] :" INTEGRATE_PNP
INTEGRATE_PNP=${INTEGRATE_PNP:-Y}
case ${INTEGRATE_PNP} in
  Y|y|O|o*)
    # Copy of JS in Nagios installation
    cp /tmp/${FOLDER}/contrib/ssi/status-header.ssi ${NAGIOS_INSTALLDIR}/share/ssi/
    chown nagios:nagios ${NAGIOS_INSTALLDIR}/share/ssi/status-header.ssi

    # Template modifications
    [[ -f ${NAGIOS_INSTALLDIR}/etc/objects/templates.cfg ]] && cp ${NAGIOS_INSTALLDIR}/etc/objects/templates.cfg ${NAGIOS_INSTALLDIR}/etc/objects/templates.cfg.orig
    sed -i "/^define host/a \        action_url             \/pnp4nagios\/index.php\/graph?host=\$HOSTNAME\$&srv=_HOST_' class='tips' rel='\/pnp4nagios\/index.php\/popup?host=\$HOSTNAME\$&srv=_HOST_" ${NAGIOS_INSTALLDIR}/etc/objects/templates.cfg
    sed -i "/^define service/a \        action_url             \/pnp4nagios\/index.php\/graph?host=\$HOSTNAME\$&srv=\$SERVICEDESC\$' class='tips' rel='\/pnp4nagios\/index.php\/popup?host=\$HOSTNAME\$&srv=\$SERVICEDESC\$" ${NAGIOS_INSTALLDIR}/etc/objects/templates.cfg

    # Restart Nagios
    service nagios restart
    [[ $? != 0 ]] && echo "Check /var/log/syslog to find out why nagios doesn't start."
  ;;
  *) log "Integration of PNP4Nagios in Nagios : [CANCEL]" ;;
esac


exit 0
