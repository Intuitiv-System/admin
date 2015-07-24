#!/bin/bash

# Filename : instalNagios4.sh
# Description :
#  . Install Nagios 4 Core depending on the OS
#


usage() {
        echo "
This script installs Nagios4Core and its plugins for Redhat/CentOS and Debian/Ubuntu.
You have to choose :
        - which OS you want to install Nagios
        - where you want to install Nagios

        Usage :: $0 {redhat|debian} {optionnal:install_path}
"
}


common_install() {
        # Download Nagios4Core
        cd /tmp && wget "http://prdownloads.sourceforge.net/sourceforge/nagios/nagios-4.0._.tar.gz"
        tar xzf /tmp/nagios-4.0.8.tar.gz
        cd /tmp && wget "https://www.nagios-plugins.org/download/nagios-plugins-1.4.16.tar.gz"
        tar xzf /tmp/nagios-plugins-2.0.3.tar.gz

        # Creation of nagios user/group
        if [[ $(awk -F":" '{print $1}' /etc/passwd | grep -E "^nagios$" | wc -l) != "1" ]]; then
                useradd --system nagios
        fi
        if [[ $(awk -F":" '{print $1}' /etc/group | grep -E "^nagcmd$" | wc -l) != "1" ]]; then
                groupadd --system nagcmd
                usermod -a -G nagmcd nagios
        fi
}


nagios_compilation() {
# Nagios compilation
        make all
        make install
        make install-init
        make install-config
        make install-commandmode
        make install-webconf

        cp -R contrib/eventhandlers/ ${INSTALLFOLDER}/libexec/
        chown -R nagios:nagios ${INSTALLFOLDER}/libexec/eventhandlers
        ${INSTALLFOLDER}/bin/nagios -v ${INSTALLFOLDER}/etc/nagios.cfg
}


nagios_plugins_compilation() {
        ####
        # Nagios Plugins Installation
        cd /tmp && wget "https://www.nagios-plugins.org/download/nagios-plugins-2.0.3.tar.gz"
        tar xzf /tmp/nagios-plugins-2.0.3.tar.gz
        cd /tmp/nagios-plugins-2.0.3 && ./configure --prefix=${INSTALLFOLDER} --with-nagios-user=nagios --with-nagios-group=nagios
        make
        make install
}


redhat_install() {
        # Install packages needed
        yum install wget httpd php gcc glibc glibc-common gd gd-devel make net-snmp
}


debian_install() {
        # Install packages needed
        aptitude install -y -q build-essential apache2 php5-gd libgd2-xpm libgd2-xpm-dev libapache2-mod-php5

        # Nagios startup
        # If you want that Nagios runs upon system startup :
        #update-rc.d nagios defaults
}


################
#    Main
################

# Default install folder is : /usr/local/nagios
if [[ ${1} == "redhat" ]]; then
    if [[ -n "${2}" ]]; then
        INSTALLFOLDER_="${2}"
        INSTALLFOLDER=${INSTALLFOLDER_%/}
        [[ ! -d ${INSTALLFOLDER} ]] && mkdir -p ${INSTALLFOLDER}
    else
        INSTALLFOLDER="/usr/local/nagios"
    fi
    redhat_install
    common_install
    cd /tmp/nagios-4.0.8/ && ./configure --prefix=${INSTALLFOLDER} --with-command-group=nagcmd
    nagios_compilation
    nagios_plugins_compilation
elif [[ ${1} == "debian" ]]; then
    if [[ -n "${2}" ]]; then
        INSTALLFOLDER="${2}"
        [[ ! -d ${INSTALLFOLDER} ]] && mkdir -p ${INSTALLFOLDER}
    else
        INSTALLFOLDER="/usr/local/nagios"
    fi
    debian_install
    common_install
    cd /tmp/nagios-4.0.8/ && ./configure --prefix=${INSTALLFOLDER} --with-nagios-group=nagios --with-command-group=nagcmd --with-mail=/usr/sbin/sendmail
    nagios_compilation
    nagios_plugins_compilation
else
    usage ; exit 1
fi

# Add a default user for Web Interface Access:
echo "
-------------------------------
"
read -s -p "Setup a password for Web Interface admin user : " NAGIOS_PASS
echo ""
read -s -p "Enter again to confirm : " NAGIOS_PASS2
while [[ ${NAGIOS_PASS} != ${NAGIOS_PASS2} ]]
do
        echo ""
        echo "Passwords don't match, try again..."
        read -s -p "Setup a password for Web Interface admin user : " NAGIOS_PASS
        echo ""
        read -s -p "Enter again to confirm : " NAGIOS_PASS2
done
htpasswd –bc "${INSTALLFOLDER}"/etc/htpasswd.users nagiosadmin ${NAGIOS_PASS}

# Rights fix
chown -R nagios:nagios "${INSTALLFOLDER}"

service nagios start

echo "
You can now access to nagios at : http://$(hostname)/nagios

Web accesses are :
        - username : nagiosadmin
        - password : ${NAGIOS_PASS}

Think to setup Nagios to run on startup if you want.
Help, if you want that Nagios runs upon system startup on Debian(Like) :
    update-rc.d nagios defaults
"

echo "
Fix :
On Debian(Like), if you have the following message when you're running /etc/init.d/nagios start :
        /etc/init.d/nagios: 20: .: Can't open /etc/rc.d/init.d/functions

To fix it, do this :
wget https://raw.github.com/nicolargo/nagiosautoinstall/master/hack4nagiosstart.sh
chmod a+x ./hack4nagiosstart.sh
./hack4nagiosstart.sh
"

exit 0
