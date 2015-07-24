#!/bin/bash
#
# Filename : fpm.sh
# Version  : 1.0
# Author   : mathieu androz
# Contrib  : 
# Description :
#  . 
#  . 
#


LOGFILE="/var/log/admin/admin.log"

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

fpm_poolCreation() {
  # !!! Take the user as parameter $1 !!!
  LIBFPM="/var/lib/php5-fpm"
  [[ ! -d ${LIBFPM} ]] && mkdir -p ${LIBFPM}
  echo "[\"${1}\"]

listen = ${LIBFPM}/\"${1}\".sock
listen.owner = ${1}
listen.group = ${1}
listen.mode =

user = ${1}
group = ${1}

pm = dynamic
pm.max_children = 20
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 10
pm.max_requests = 0

chdir = /

php_admin_value[open_basedir] = /home/\"${1}\"/www:/home/\"${1}\"/tmp:/home/\"${1}\":/usr/share/php5:/usr/share/php:/tmp
php_admin_value[session.save_path] = /home/\"${1}\"/tmp
php_admin_value[upload_tmp_dir] = /home/\"${1}\"/tmp
;php_admin_value[sendmail_path] = \"/usr/sbin/sendmail -t -i -f\"

;;; Gestion des erreurs
; Affichage des erreurs
php_flag[display_errors] = off
; Log des erreurs
php_admin_value[error_log] = /home/\"${1}\"/logs/fpm-php.log
php_admin_flag[log_errors] = on

;;; Valeurs custom php.ini
php_admin_value[memory_limit] = 128M
php_admin_value[post_max_size] = 15M
php_admin_value[upload_max_filesize] = 15M
; SECURITY
php_admin_value[magic_quotes_gpc]=0
php_admin_value[register_globals]=0
php_admin_value[session.auto_start]=0
;php_admin_value[mbstring.http_input]="pass"
;php_admin_value[mbstring.http_output]="pass"
;php_admin_value[mbstring.encoding_translation]=0
php_admin_value[expose_php]=0
php_admin_value[allow_url_fopen]=1
php_admin_value[safe_mode]=0
;php_admin_value[cgi.fix_pathinfo]=1

; Liste des extensions autorisÃ©es avec php-fpm
security.limit_extensions = .php .php5 .html .htm
" > /etc/php5/pool.d/${1}.conf
}


changePHPVersion() {
  # Install on Wheezy PHP53. from Squeeze Dotdeb
  echo "
deb http://ftp.debian.org/debian/ squeeze main contrib non-free
deb http://security.debian.org/ squeeze/updates main contrib non-free
" >> /etc/apt/sources.list

  # Install GnuPG Dotdeb key
  cd /tmp
  wget http://www.dotdeb.org/dotdeb.gpg
  apt-key add dotdeb.gpg

  if [[ -f /etc/apt/preferences.d/preferences ]]; then
    log "/etc/apt/preferences.d/preferences already exists. Check into..."
  else
    echo "Package: php5*
Pin: release a=oldstable
Pin-Priority: 700

Package: libapache2-mod-php5
Pin: release a=oldstable
Pin-Priority: 700

Package: php-pear
Pin: release a=oldstable
Pin-Priority: 700

Package: php-apc
Pin: release a=oldstable
Pin-Priority: 700

Package: *
Pin: release a=stable
Pin-Priority: 600
" > /etc/apt/preferences.d/preferences

  # List all installed PHP packages
  PHP=$(dpkg -l|grep php|grep 5.4.4|awk '{print $2}')
  apt-get update
  apt-get install --reinstall $PHP
  fi
}

fpm_vhostCreation() {
  echo "<VirtualHost *:80>
  ServerName  web1.itdev.lan
  ServerAdmin webmaster@test1.com

  DocumentRoot /home/web1/www/

  # Clear PHP settings of this website
  <FilesMatch \".+\.ph(p[345]?|t|tml)\$\">
    SetHandler None
  </FilesMatch>
  <IfModule mod_fastcgi.c>
    <Directory /home/web1/cgi-bin>
      Options +FollowSymLinks
      AllowOverride All
      Order allow,deny
      Allow from all
    </Directory>
    <FilesMatch \"\.php[345]?\$\">
      SetHandler php5-fcgi
    </FilesMatch>
    Action php5-fcgi /php5-fcgi
    Alias /php5-fcgi /home/web1/cgi-bin/php5-fcgi-*-80-web1.itdev.lan
    FastCgiExternalServer /home/web1/cgi-bin/php5-fcgi-*-80-web1.itdev.lan -idle-timeout 300 -socket /var/lib/php5-fpm/web1.sock -pass-header Authorization
  </IfModule>

  Redirect 404 /favicon.ico
  <Location /favicon.ico>
    ErrorDocument 404 \"No favicon\"
  </Location>

  ErrorLog /home/coralie/logs/error.log
  LogLevel warn
  CustomLog /home/coralie/logs/access.log combined

</VirtualHost>
" > /etc/apache2/sites-available/fpm.vhost.sample
}

upgradeAPC() {
  [[ -f /etc/php5/apache2/conf.d/apc.ini ]] && apt-get remove php-apc
  installPackage php5-dev
  installPackage php-pear
  installPackage libpcre3-dev
  pecl install apc
  service apache2 restart
}


##################
#
#     MAIN
#
##################

createLogrotate

# Install MySQL server
apt-get install binutils mysql-server

service mysql stop
echo "[mysqld]
init_connect='SET collation_connection = utf8_general_ci'
init_connect='SET NAMES utf8'
character-set-server = utf8" > /etc/mysql/conf.d/custom_IT.cnf
service mysql start

mysql_secure_installation

# Modif du sources.list
sed -i 's/^deb\(.*\)main$/\deb\1main contrib non-free/g' /etc/apt/sources.list
sed -i 's/^deb\(.*\)contrib$/deb\1contrib non-free/g' /etc/apt/sources.list
apt-get update

apt-get install apache2 \
  apache2-doc           \
  apache2-utils         \
  libapache2-mod-php5   \
  php5                  \
  php5-common           \
  php5-gd               \
  php5-mysql            \
  php5-imap             \
  phpmyadmin            \
  php5-cli              \
  php-pear              \
  php-auth              \
  php5-mcrypt           \
  mcrypt                \
  php5-imagick          \
  imagemagick           \
  libruby               \
  libapache2-mod-python \
  php5-curl             \
  php5-intl             \
  php5-ming             \
  php5-ps               \
  php5-pspell           \
  php5-recode           \
  php5-snmp             \
  php5-sqlite           \
  php5-tidy             \
  php5-xmlrpc           \
  php5-xsl              \
  php-apc               \
  php5-fpm              \
  libapache2-mod-fastcgi

a2enmod fastcgi         \
  rewrite               \
  actions               \
  include               \
  auth_digest           \
  actions               \
  alias && service apache2 restart


read -p "Do you want to create sample for fpm config file and apache vhost ? [es/no] : " SAMPLE

if [[ $SAMPLE =~ "yes|y|oui" ]]; then
  fpm_vhostCreation && logsuccess "FPM vhost sample creation"
fi




# Ok, c'est moche, mais ca permet de se retrouver plus facilement dans les logs...
#log "------------------------------"

################
# Chroot un user
apt-get install build-essential autoconf automake1.9 libtool debhelper binutils-gold

cd /tmp
wget http://olivier.sessink.nl/jailkit/jailkit-2.17.tar.gz
tar xvfz jailkit-2.17.tar.gz
cd jailkit-2.17
./debian/rules binary

cd ..
dpkg -i jailkit_2.17-1_*.deb
rm -rf jailkit-2.17*

# Creer un home ou un répertoire qui contiendra tous les home chrootés.
# Ici, on crée /home/hosting + nom du user = user1
mkdir -p /home/hosting/user1
chown root:root /home/hosting/user1
jk_init -v -j /home/hosting/user1 apacheutils basicshell extendedshell editors jk_lsh netutils

# Création du user Linux classique = user1
adduser user1

# Création du user dans l'envrionnement chrooté
jk_jailuser -m -j /home/hosting/user1 user1

# Changer le Shell du user
echo "Editer le fichier /home/hosting/user1/etc/passwd et remplacer pour le user1 /usr/sbin/jk_lsh par /bin/bash !"

# Fix Shell bug
echo "export TERM=xterm" >> /home/hosting/user1/home/user1/.bashrc

# Pour ajouter une commande à un environnement de jail existant
# (cela ajoute automatiquement les dépendances !)
# -> en tant que root :
### exemple : jk_cp -j /home/hosting/user1 /usr/bin/curl