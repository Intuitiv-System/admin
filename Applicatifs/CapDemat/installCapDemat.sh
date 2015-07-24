#!/bin/bash
#
# Filename : capDematInstaller.sh
# Version  : 1.0
# Author   : mathieu androz
# Contrib  : 
# Description :
#  . Automate installation of CapDemat application
#  . 
#

. /lib/lsb/init-functions

# Capdemat installation informations
TOMCAT_USER="tomcat6"
TOMCAT_GROUP="tomcat6"
TOMCAT_HOME="/var/lib/tomcat6"
CAPDEMAT_HOME="/home/capdemat"
CAPDEMAT_DATA="${CAPDEMAT_HOME}/data"
PROJECTNAME=""
PROJECTDOMAIN=""

# Serveur Infos
EMAIL_HOST="127.0.0.1"
EMAIL_SENDER="test@test.com"
EMAIL_PORT="25"

# URLs Capdemat
CAPDEMAT_ADMIN_URL="https://capdemat.capwebct.fr/attachments/download/851/CapDemat-admin-4.7.2-06012014.zip"
CAPDEMAT_WAR_URL="https://capdemat.capwebct.fr/attachments/download/848/CapDemat-4.7.2-15102013.war"
CAPDEMAT_ASSETS_URL="https://capdemat.capwebct.fr/attachments/download/852/CapDemat-V4.7.2.tar.gz"



( [[ -z "${CAPDEMAT_ADMIN_URL}" ]] || [[ -z "${CAPDEMAT_WAR_URL}" ]] || [[ -z "${CAPDEMAT_ASSETS_URL}" ]] ) && log_failure_msg "CapDemat URLs no defined in the script. Aborted..." && exit 10
( [[ -z "${TOMCAT_USER}" ]] || [[ -z "${TOMCAT_GROUP}" ]] || [[ -z "${TOMCAT_HOME}" ]]) && log_failure_msg "Complete TOMCAT variables at the begin of the script. Aborted..." && exit 11
[[ -z "${CAPDEMAT_HOME}" ]] && log_failure_msg "Complete CAPDEMAT variables at the begin of the script. Aborted..." && exit 12

while [ -z "${EMAIL_HOST}" ]
do
  read -p "Enter Email server IP : " EMAIL_HOST
done
while [ -z "${EMAIL_PORT}" ]
do
  read -p "Enter Email server port : " EMAIL_PORT
done
while [ -z "${EMAIL_SENDER}" ]
do
  read -p "Enter Email sender address : " EMAIL_SENDER
done

echo "
#############################################
#                                           #
#---  Script d'installation de CapDemat  ---#
#                                           #
#############################################
"

while [ -z "${PROJECTNAME}" ] && [ -z "${PROJECTDOMAIN}" ]
do
  read -p "Enter the name of the projet (without spaces) : " PROJECTNAME
  read -p "Enter the FQDN to access to the application : " PROJECTDOMAIN
done


# Modif du sources.list
log_action_msg "sources.list customization"
sed -i 's/^deb\(.*\)main$/\deb\1main contrib non-free/g' /etc/apt/sources.list
sed -i 's/^deb\(.*\)contrib$/deb\1contrib non-free/g' /etc/apt/sources.list
log_success_msg "sources.list customization done"


### Java ###
# Add Oracle JDK
log_action_msg "Install Orcale JDK"
echo "deb http://ppa.launchpad.net/webupd8team/java/ubuntu precise main" > /etc/apt/sources.list.d/webupd8team-java.list
echo "deb-src http://ppa.launchpad.net/webupd8team/java/ubuntu precise main" >> /etc/apt/sources.list.d/webupd8team-java.list
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys EEA14886
apt-get update -q=5
apt-get install -q=5 -y oracle-java7-installer
java -version
echo -e "\nJAVA_HOME=/usr/lib/jvm/java-7-oracle/jre\nexport JAVA_HOME" >> /etc/profile && . /etc/profile
echo -e "\nPATH=$PATH:/usr/lib/jvm/java-7-oracle/jre/bin\nexport PATH" >> /etc/profile && . /etc/profile
log_success_msg "Installation of Oracle JDK done"


### Apache ###
log_action_msg "Install & configure apache2"
apt-get install -q=5 -y apache2 libapache2-mod-jk
log_success_msg "Installation of Apache2 done"


log_action_msg "Configure JK Module"
if [[ -f /etc/apache2/mods-available/jk.conf ]]; then
  mv /etc/apache2/mods-available/jk.conf /etc/apache2/mods-available/jk.conf.orig
fi
echo "<IfModule jkModule>
  JkWorkersFile       \"/etc/libapache2-mod-jk/workers.properties\"
  JkLogLevel           info
  JkLogFile           \"/var/log/apache2/jk.log\" 
  JkLogStampFormat    \"[%a %b %d %H:%M:%S %Y] \" 
  JkOptions           +ForwardKeySize +ForwardURICompat -ForwardDirectories
  JkRequestLogFormat  \"%w %V %T\"
</IfModule>" > /etc/apache2/mods-available/jk.conf
if [[ "$?" -eq 0 ]]; then
  log_success_msg "Configuration of JK Module done."
else
  log_failure_msg "Configuration of JK Module in /etc/apache2/mods-available/jk.conf"
fi

log_action_msg "Configure Worker"
if [[ -f /etc/libapache2-mod-jk/workers.properties ]]; then
  echo "
####### CAPDEMAT WORKER ########
worker.list=cap-demat
worker.cap-demat.port=8009
worker.cap-demat.host=127.0.0.1
worker.cap-demat.type=ajp13
"  >> /etc/libapache2-mod-jk/workers.properties
  log_success_msg "Configuration of Worker done."
else
  log_failure_msg "/etc/libapache2-mod-jk/workers.properties doesn't exist. Please add the worker after the execution of this script !"
fi

log_action_msg "Activate Apache2 modules"
a2enmod ssl
a2enmod jk
a2enmod rewrite
service apache2 restart
if [[ "$?" -eq 0 ]]; then
  log_success_msg "Activation of Apache2 modules done."
else
  log_failure_msg "Activation of Apache2 modules"
fi


### Postgresql ###
log_action_msg "Install PostgreSQL 8.4"
if [[ ! -f /etc/apt/preferences.d/postgresql ]]; then
  echo "Package: postgresql*
Pin : release o=Debian,a=oldstable
Pin-Priority: 900
" >> /etc/apt/preferences.d/postgresql
fi
if [[ ! $(grep "oldstable" /etc/apt/sources.list) ]]; then
  echo "
deb http://ftp.debian.org/debian/ oldstable main contrib non-free
deb http://security.debian.org/ oldstable/updates main contrib non-free
" >> /etc/apt/sources.list
fi
while true;do echo -n .;sleep 1;done &
apt-get update -q=5
kill $!; trap 'kill $!' SIGTERM
while true;do echo -n .;sleep 1;done &
apt-get install -q=5 -y postgresql-8.4 postgresql-client-8.4
kill $!; trap 'kill $!' SIGTERM

log_success_msg "Installation of PostgreSQL 8.4 done."

log_action_msg "Configure PostgreSQL 8.4"
if [[ -d /etc/postgresql/8.4/main ]]; then
  cd /etc/postgresql/8.4/main/
  if [[ -f ./pg_hba.conf ]]; then
    mv ./pg_hba.conf ./pg_hba.conf.orig
  fi
  echo "local   all         capdemat                                 md5" > pg_hba.conf
  echo "
local   all         postgres                                 ident
host    all         capdemat       127.0.0.1/32              md5" >> pg_hba.conf
  
  if [[ -f ./postgresql.conf ]]; then
    sed -i 's/^ssl = true/ssl = false/g' ./postgresql.conf
  fi

  su - postgres -c "createlang plpgsql template1" 
  service postgresql restart
  log_success_msg "Postgresql : Configuration successfull."
  echo ""
  log_action_msg "Postgresql user capdemat creation :"
  while true
  do
    read -s -p "Enter password for capdemat Postgresql user : " CAPDEMAT_PSQL_PWD
    echo ""
    read -s -p "Enter again : " CAPDEMAT_PSQL_PWD2
    if [[ "${CAPDEMAT_PSQL_PWD}" != "${CAPDEMAT_PSQL_PWD2}" ]]; then
      echo "Passwords do not match. Try again..."
    else
      break
    fi
  done
  su - postgres -c "createuser --no-superuser --createdb --no-createrole capdemat"
  su - postgres -c "echo \"ALTER USER capdemat WITH PASSWORD '${CAPDEMAT_PSQL_PWD}' ;\" | psql"
  log_success_msg "Creation of capdemat Postgresql user."
else
  log_failure_msg "Unable to configure Postgresql 8.4"
fi


### Tomcat6 ###
log_action_msg "Install Tomcat6"
while true;do echo -n .;sleep 1;done &
apt-get install -q=5 -y tomcat6 tomcat6-common ttf-mscorefonts-installer shared-mime-info
kill $!; trap 'kill $!' SIGTERM
service tomcat6 stop
log_success_msg "Installation of Tomcat6 done."

log_action_msg "Configure Tomcat6"
if [[ -f /etc/default/tomcat6 ]]; then
  cp /etc/default/tomcat6 /root/tomcat6_default
  if [[ -n $(grep "^TOMCAT_SECURITY" /etc/default/tomcat6) ]]; then
    sed -i 's/^TOMCAT6_SECURITY=yes/TOMCAT6_SECURITY=no/g' /etc/default/tomcat6
  else
    echo "TOMCAT6_SECURITY=no" >> /etc/default/tomcat6
  fi
  if [[ -n $(grep "^JAVA_HOME=" /etc/default/tomcat6) ]]; then
    sed -i 's/^JAVA_HOME=\(.*\)/#JAVA_HOME=\/1/g' /etc/default/tomcat6
  fi
  echo "JAVA_HOME=/usr/lib/jvm/java-7-oracle/jre" >> /etc/default/tomcat6
  if [[ -n $(grep "^JAVA_OPTS=" /etc/default/tomcat6) ]]; then
    sed -i 's/^JAVA_OPTS=\(.*\)/JAVA_OPTS="-Djava.awt.headless=true -Xms256m -Xmx768m -XX:MaxPermSize=256m -Dfile.encoding=UTF-8 -XX:+UseConcMarkSweepGC"/g' /etc/default/tomcat6
  else
    echo "JAVA_OPTS=\"-Djava.awt.headless=true -Xms256m -Xmx768m -XX:MaxPermSize=256m -Dfile.encoding=UTF-8 -XX:+UseConcMarkSweepGC\"" >> /etc/default/tomcat6
  fi
  sed -i "/Define an AJP 1.3 Connector on port 8009/a<Connector port=\"8009\" protocol=\"AJP\/1.3\" URIEncoding=\"UTF-8\" \/>" /etc/tomcat6/server.xml
  log_success_msg "Configuration of Tomcat6 done."
else
  log_failure_msg "Configuration of Tomcat6."
fi


### Capdemat admin ###
log_action_msg "Install CapDemat Admin"
[[ ! -d "${CAPDEMAT_DATA}" ]] && mkdir -p "${CAPDEMAT_DATA}"
cd /root/
wget --no-check-certificate "${CAPDEMAT_ADMIN_URL}"
CAPDEMAT_ADMIN=$(echo "${CAPDEMAT_ADMIN_URL}" | awk -F"/" '{print $7}')
unzip -d "${CAPDEMAT_DATA}" "${CAPDEMAT_ADMIN}"
if [[ -f ""${CAPDEMAT_DATA}"/conf/spring/local.properties" ]]; then
  mv "${CAPDEMAT_DATA}"/conf/spring/local.properties "${CAPDEMAT_DATA}"/conf/spring/production.properties
  sed -i 's/^mail.sender_host\(.*\)/mail.sender_host='"${EMAIL_HOST}"'/g' "${CAPDEMAT_DATA}"/conf/spring/production.properties
  sed -i 's/^mail.admin_address\(.*\)/mail.admin_address='"${EMAIL_SENDER}"'/g' "${CAPDEMAT_DATA}"/conf/spring/production.properties
  sed -i 's/^mail.sender_port\(.*\)/mail.sender_port='"${EMAIL_PORT}"'/g' "${CAPDEMAT_DATA}"/conf/spring/production.properties
  sed -i 's#^referential.properties.path\(.*\)#referential.properties.path='"${CAPDEMAT_DATA}"'/conf/#g' "${CAPDEMAT_DATA}"/conf/spring/production.properties
  sed -i 's#^assets.properties.path\(.*\)#assets.properties.path='"${CAPDEMAT_DATA}"'/assets/#g' "${CAPDEMAT_DATA}"/conf/spring/production.properties
  sed -i 's#^assets.included_authorities\(.*\)#assets.included_authorities=**#g' "${CAPDEMAT_DATA}"/conf/spring/production.properties
  sed -i 's#^data.properties.path\(.*\)#data.properties.path='"${CAPDEMAT_DATA}"'#g' "${CAPDEMAT_DATA}"/conf/spring/production.properties
else
  log_warning_msg "No ${CAPDEMAT_DATA}/conf/spring/production.properties file found..."
fi


### SSL certificat génération ###
log_action_msg "SSL certificate generation"
[[ ! -d /etc/apache2/ssl ]] && mkdir -p /etc/apache2/ssl
cd /etc/apache2/ssl
openssl genrsa -des3 -out "${PROJECTNAME}".key 2048
openssl req -new -key "${PROJECTNAME}".key -out "${PROJECTNAME}".csr
cp "${PROJECTNAME}".key "${PROJECTNAME}".key.orig
openssl rsa -in "${PROJECTNAME}".key.orig -out "${PROJECTNAME}".key
openssl x509 -req -days 3650 -in "${PROJECTNAME}".csr -signkey "${PROJECTNAME}".key -out "${PROJECTNAME}".crt
chmod 600 "${PROJECTNAME}".key
log_success_msg "SSL autosigned certificate generation done."


### Apache VirtualHosts ###
log_action_msg "Create Virtualhost"
echo "<VirtualHost *:443>
        ServerAdmin admin@intuitiv.fr
        ServerName ${PROJECTDOMAIN}
        SSLEngine on
        SSLCertificateFile /etc/apache2/ssl/${PROJECTNAME}.crt
        SSLCertificateKeyFile /etc/apache2/ssl/${PROJECTNAME}.key
        DocumentRoot /var/www
        <Directory />
                Options Indexes FollowSymLinks MultiViews
                AllowOverride None
                Order allow,deny
                allow from all
        </Directory>
        ErrorLog /var/log/apache2/error-${PROJECTNAME}_ssl.log
        LogLevel warn
        CustomLog /var/log/apache2/access_ssl-${PROJECTNAME}.log combined
        RewriteEngine On
        RewriteRule ^/backoffice(|/)$ https://%{SERVER_NAME}/backoffice/login [NE]
        RewriteRule ^/$ https://%{SERVER_NAME}/frontoffice/home [NE]
        ProxyRequests Off
        <Proxy *>
                Order deny,allow
                Allow from all
        </Proxy>
        #CapDemat
        ProxyPass  / http://127.0.0.1:8080/
        ProxyPassReverse  / http://127.0.0.1:8080/
        RequestHeader set X-Forwarded-Proto https
        ProxyPreserveHost on
</VirtualHost>" > /etc/apache2/sites-available/"${PROJECTNAME}"-ssl

echo "<VirtualHost *:80>
        ServerAdmin admin@intuitiv.fr
        ServerName  ${PROJECTDOMAIN}
        DocumentRoot /var/www
        ErrorLog /var/log/apache2/error-${PROJECTNAME}.log
        LogLevel warn
        CustomLog /var/log/apache2/access-${PROJECTNAME}.log combined
        ProxyRequests Off
        <Proxy *>
                Order deny,allow
                Allow from all
        </Proxy>
        #redirect match
        RewriteEngine On
        RewriteLog /var/log/apache2/rewrite_log-${PROJECTNAME}
        RewriteLogLevel 1
        RewriteRule ^/$ https://%{SERVER_NAME}/frontoffice/home [NE]
        RewriteRule ^/(.*) https://%{SERVER_NAME}/\$1 [NE]
</VirtualHost>" > /etc/apache2/sites-available/"${PROJECTNAME}"

a2ensite "${PROJECTNAME}"
a2ensite "${PROJECTNAME}"-ssl
a2enmod proxy headers proxy_http
service apache2 restart
log_success_msg "Creation of Virtualhosts done."


### Database creation ###
log_action_msg "Database creation"
createdb -U capdemat -O capdemat capdemat_"${PROJECTNAME}"
while [ "$?" -ne 0 ]
do
  log_faillure_msg "Database creation not OK. Please try again..."
  createdb -U capdemat -O capdemat capdemat_"${PROJECTNAME}"
done
psql -U capdemat -W -f "${CAPDEMAT_DATA}"/db/create_schema_pgsql.sql capdemat_"${PROJECTNAME}"
while [ "$?" -ne 0 ]
do
  log_faillure_msg "Database completion not OK. Please try again..."
  psql -U capdemat -W -f "${CAPDEMAT_DATA}"/db/create_schema_pgsql.sql capdemat_"${PROJECTNAME}"
done
log_success_msg "Database creation & completion done."


### Deploiement des Assets ###
log_action_msg "Install CapDemat Assets"
[[ ! -d "${CAPDEMAT_DATA}"/assets ]] && mkdir "${CAPDEMAT_DATA}"/assets
cd /root
wget --no-check-certificate "${CAPDEMAT_ASSETS_URL}"
CAPDEMAT_ASSETS=$(echo "${CAPDEMAT_ASSETS_URL}" | awk -F"/" '{print $7}')
[[ ! -d /root/$(echo "${CAPDEMAT_ASSETS}" | sed 's/.......$//') ]] && mkdir /root/$(echo "${CAPDEMAT_ASSETS}" | sed 's/.......$//')
tar xzf "${CAPDEMAT_ASSETS}" -C /root/$(echo "${CAPDEMAT_ASSETS}" | sed 's/.......$//')
cp -R /root/$(echo "${CAPDEMAT_ASSETS}" | sed 's/.......$//')/Assets/blainville "${CAPDEMAT_DATA}"/assets/"${PROJECTNAME}"
log_success_msg "Installation of CapDemat Assets done."

log_action_msg "Configure CapDemat Assets"
cd "${CAPDEMAT_DATA}"/assets/"${PROJECTNAME}"
cp localAuthority-blainville.xml.tpl localAuthority-"${PROJECTNAME}".xml
sed -i 's/blainville/'"${PROJECTNAME}"'/g' localAuthority-"${PROJECTNAME}".xml
sed -i 's#<property name=\"defaultServerName\(.*\)$#<property name=\"defaultServerName\" value=\"'"${PROJECTDOMAIN}"'\"/>#g' localAuthority-"${PROJECTNAME}".xml
while [ -z "${PGPASSWD}" ]
do
  read -s -p "Enter PostgreSQL capdemat user password : " PGPASSWD
  echo ""
done
sed -i 's#<prop key=\"hibernate.connection.password\(.*\)#<prop key=\"hibernate.connection.password\">'"${PGPASSWD}"'</prop>#g' localAuthority-"${PROJECTNAME}".xml
sed -i 's/_${branch}//g' localAuthority-"${PROJECTNAME}".xml
while [ -z "${CAPDEMAT_EMAIL}" ] || [ -z "${CAPDEMAT_PAYMENT_NAME}" ]
do
  read -p "Enter email address you want to assign in this configuration : " CAPDEMAT_EMAIL
  echo ""
  read -p "Enter Organisation payment name for CapDemat : " CAPDEMAT_PAYMENT_NAME
done
sed -i 's#<property name=\"defaultEmail\(.*\)#<property name=\"defaultEmail\" value=\"'"${CAPDEMAT_EMAIL}"'\"/>#g' localAuthority-"${PROJECTNAME}".xml
sed -i 's#<property name=\"broker\" value=\"Régie démo\(.*\)#<property name=\"broker\" value=\"'"${CAPDEMAT_PAYMENT_NAME}"'\"></property>#g' localAuthority-"${PROJECTNAME}".xml
sed -i 's#<entry key=\"mailSendTo\"\(.*\)#<entry key=\"mailSendTo\" value=\"'"${CAPDEMAT_EMAIL}"'\"/>#g' localAuthority-"${PROJECTNAME}".xml
chown -R "${TOMCAT_USER}":"${TOMCAT_GROUP}" "${CAPDEMAT_DATA}"/assets
log_success_msg "Configuration fo CapDemat Assets done."


### Deploiement du WAR ###
log_action_msg "Deploy CapDemat WAR"
cd /root
[[ -d "${TOMCAT_HOME}"/webapps/ROOT ]] && [[ ! -d /root/ROOT ]] && mv "${TOMCAT_HOME}"/webapps/ROOT /root && mkdir "${TOMCAT_HOME}"/webapps/ROOT
wget --no-check-certificate "${CAPDEMAT_WAR_URL}"
CAPDEMAT_WAR=$(echo "${CAPDEMAT_WAR_URL}" | awk -F"/" '{print $7}')
unzip -d "${TOMCAT_HOME}"/webapps/ROOT "${CAPDEMAT_WAR}"
cp "${CAPDEMAT_DATA}"/conf/spring/production.properties $TOMCAT_HOME/webapps/ROOT/WEB-INF/classes/CapDemat-config.properties
chown -R "${TOMCAT_USER}":"${TOMCAT_GROUP}" "${CAPDEMAT_WAR}"

log_success_msg "Deployment of CapDemat WAR done."

service apache2 restart
service tomcat6 restart

### Report generation ###
echo ""
echo "---------------------------------
        CapDemat Report
---------------------------------

Nom du projet           : ${PROJECTNAME}
URL d'accès front       : https://${PROJECTDOMAIN}/
URL d'accès back        : https://${PROJECTDOMAIN}/backoffice/login
Chemin de l'application : ${CAPDEMAT_DATA}
"