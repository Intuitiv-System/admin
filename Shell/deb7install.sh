#!/bin/bash
#
# Filename : deb7install.sh
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

installPackage() {
    if [[ $(dpkg -l | awk '{print $1" "$2}' | grep " ${1}"$) != "ii ${1}" ]]; then
        log "Installation du package ${1}..."
        apt-get -y -q install "${1}" &> /dev/null
    else
        log "Package ${1} already installed on your system."
    fi
}


#############################
#
# Main
#
#############################


if [[ ! -f "/etc/issue" ]] && [[ $(cat /etc/issue) != "Debian GNU/Linux 7 \n \l" ]]; then
  log "This is not a Debian 7, sorry. Aborted..."
  exit 1
fi

if [[ ! -d "/root/scripts" ]]; then
  log "Please execute firstinstall.sh script before this one. Aborted..."
  exit 1
fi

apt-get update && apt-get upgrade

# Install Apache
apt-get install apache2 php5 php5-gd php5-intl php5-xsl php5-mcrypt php5-memcached php-apc php5-fpm php5-curl curl imagemagick php5-imagick
a2enmod actions headers expires rewrite

# Custom PHP
echo ";
;;;; Custom of php.ini
;
expose_php = Off
date.timezone = \"Europe/Paris\"
max_input_vars = 3000
short_open_tag = Off
" > /etc/php5/fpm/conf.d/custom.ini

# Install FPM
apt-get install libapache2-mod-fastcgi
service apache2 restart

cat >> /etc/apache2/sites-available/vhost.example << EOF
<VirtualHost *:80>
    ServerAdmin webmaster@intuitiv.fr
 
    ServerName  www.oprod.fr
 
    RewriteEngine on
    #RewriteCond %{HTTPS} !on
    #RewriteRule (.*) https://%{HTTP_HOST}%{REQUEST_URI}
 
    #RewriteCond %{HTTP_HOST} ^oprod.fr [OR]
    #RewriteCond %{HTTP_HOST} ^(www\.)?oprod.org [OR]
    #RewriteCond %{HTTP_HOST} ^(www\.)?ville-oprod.(fr|com|org|eu) [OR]
    #RewriteCond %{HTTP_HOST} ^(www\.)?mairie-oprod.(com|org|fr)
    #RewriteRule ^(.*)\$ http://www.oprod.fr\$1 [L,R=301]
 
    DocumentRoot /home/oprod/www/
    <Directory /home/oprod/www/>
      #<IfModule security2_module>
      #   SecRuleEngine Off
      #</IfModule>
        Options -Indexes FollowSymLinks MultiViews
        AllowOverride All
        Order allow,deny
        Allow from all
        #AuthType Basic
        #AuthName "Restricted Area oprod : please login"
        #AuthUserFile /home/oprod/.htpasswd
        #Require valid-user
        #Order deny,allow
        #Deny from env=Blacklist
        #Allow from env=Whitelist
    </Directory>
 
    Redirect 404 /favicon.ico
    <Location /favicon.ico>
        ErrorDocument 404 "No favicon"
    </Location>
 
  # Clear PHP settings of this website
  <FilesMatch ".+\.ph(p[345]?|t|tml)\$">
    SetHandler None
  </FilesMatch>
  <IfModule mod_fastcgi.c>
    <Directory /home/oprod/cgi-bin>
      Order allow,deny
      Allow from all
    </Directory>
    <FilesMatch "\.php[345]?\$">
      SetHandler php5-fcgi
    </FilesMatch>
    Action php5-fcgi /php5-fcgi
    Alias /php5-fcgi /home/oprod/cgi-bin/php5-fcgi-*-80
    FastCgiExternalServer /home/oprod/cgi-bin/php5-fcgi-*-80 -idle-timeout 300 -socket /home/oprod/.socks/oprod.sock -pass-header Authorization
  </IfModule>
 
    # Path of private php.ini
    #PHPINIDir /home/oprod/config
 
    ErrorLog /home/oprod/logs/error.log
    LogLevel warn
    CustomLog /home/oprod/logs/access.log combined
    ServerSignature Off
</VirtualHost>
EOF

cat >> /etc/php5/fpm/pool.d/pool.example << _EOF_
[oprod]
 
; Per pool prefix
; It only applies on the following directives:
; - 'slowlog'
; - 'listen' (unixsocket)
; - 'chroot'
; - 'chdir'
; - 'php_values'
; - 'php_admin_values'
; When not set, the global prefix (or /usr) applies instead.
; Note: This directive can also be relative to the global prefix.
; Default Value: none
;prefix = /path/to/pools/\$pool
 
; Unix user/group of processes
; Note: The user is mandatory. If the group is not set, the default user's group
;       will be used.
user = \$pool
group = \$pool
 
listen = /home/\$pool/.socks/\$pool.sock
 
;listen.backlog = 128
 
listen.owner = www-data
listen.group = www-data
;listen.mode = 0660
 
listen.allowed_clients = 127.0.0.1
 
; Specify the nice(2) priority to apply to the pool processes (only if set)
; The value can vary from -19 (highest priority) to 20 (lower priority)
; Default Value: no set
; priority = -19
 
pm = dynamic
 
pm.max_children = 20
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 10
; Note: Used only when pm is set to 'ondemand'
;pm.process_idle_timeout = 10s;
 
; The number of requests each child process should execute before respawning.
; Default Value: 0
;pm.max_requests = 500
 
; This directive may be used to customize the response of a ping request. The
; Default Value: pong
;ping.response = pong
 
; The access log file
; Default: not set
;access.log = log/\$pool.access.log
 
; The access log format.
; Default: "%R - %u %t \"%m %r\" %s"
;access.format = "%R - %u %t \"%m %r%Q%q\" %s %f %{mili}d %{kilo}M %C%%"
 
; The log file for slow requests
; Default Value: not set
;slowlog = log/\$pool.log.slow
;request_slowlog_timeout = 0
 
;request_terminate_timeout = 0
 
; Set open file descriptor rlimit.
; Default Value: system defined value
;rlimit_files = 1024
 
; Set max core size rlimit.
; Possible Values: 'unlimited' or an integer greater or equal to 0
; Default Value: system defined value
;rlimit_core = 0
 
;chroot =
 
; Chdir to this directory at the start.
; Note: relative path can be used.
; Default Value: current directory or / when chroot
chdir = /
 
;catch_workers_output = yes
 
; Pass environment variables like LD_LIBRARY_PATH. All \$VARIABLEs are taken from
; the current environment.
; Default Value: clean env
;env[HOSTNAME] = \$HOSTNAME
;env[PATH] = /usr/local/bin:/usr/bin:/bin
;env[TMP] = /tmp
;env[TMPDIR] = /tmp
;env[TEMP] = /tmp
 
php_admin_value[open_basedir] = /home/\$pool/www:/home/\$pool/tmp:/home/\$pool/sessions:/usr/share/php5:/usr/share/php:/tmp:/home/solr
php_admin_value[session.save_path] = /home/\$pool/sessions
php_admin_value[upload_tmp_dir] = /home/\$pool/tmp
;php_admin_value[sendmail_path] = /usr/sbin/sendmail -t -i -f contact@ovm08.itserver.fr
 
;;; Gestion des erreurs
; Affichage des erreurs
php_flag[display_errors] = off
; Log des erreurs
php_admin_value[error_log] = /home/\$pool/logs/fpm-php.log
php_admin_flag[log_errors] = on
 
;;; Valeurs custom php.ini
php_admin_value[memory_limit] = 256M
php_admin_value[post_max_size] = 30M
php_admin_value[upload_max_filesize] = 30M
 
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
 
; Liste of authorized extensions with php-fpm
security.limit_extensions = .php .php5 .php3 .php4 .html .htm

_EOF_


## Install memcached 
installPackage memcached




## Install MySQL
apt-get install -y mysql-server
service mysql stop
echo "[mysqld]
character-set-server = utf8

innodb_buffer_pool_size = 128M
max_allowed_packet = 32M

#query_cache_size = 32M
#tmp_table_size = 32M
#max_heap_table_size = 32M
#table_cache = 128
open_files_limit = 102400

[mysqld_safe]
open_files_limit = 102400" > /etc/mysql/conf.d/custom.cnf

cat >>/etc/security/limits.conf<<_EOF_
* soft nofile 102400
* hard nofile 102400
* soft nproc 10240
* hard nproc 10240
mysql hard nofile 102400
mysql soft nofile 102400
_EOF_

if [ ! -f /etc/security/limits.d/90-nproc.conf ]
then
  cat >> /etc/security/limits.d/90-nproc.conf<<_EOF_
* soft nofile 102400
* hard nofile 102400
* soft nproc 10240
* hard nproc 10240
root soft nproc unlimited
_EOF_
fi

systemctl start mysql.service
mysql_secure_installation



## Install Pureftpd
/root/scripts/Shell/web/ftp/installPureFTPD.sh

## Install Postfix
apt-get install -y postfix
cp /etc/postfix/main.cf /etc/postfix/main.cf.orig
sed -i -e 's/^relayhost/#relayhost/g' /etc/postfix/main.cf 
echo "
##########
# Mandrill config
##########
relayhost = [smtp.mandrillapp.com]:587
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_use_tls = yes
# Make sure Postfix listens to localhost only
inet_interfaces = 127.0.0.1" >> /etc/postfix/main.cf 
log "Install Pureftpd : OK"



## Install drush
cp /root/scripts/Applicatifs//Drupal/drush-6.5.0.zip /opt 
cd /opt 
unzip drush-6.5.0.zip
cd drush-6.5.0
chmod 755 drush drush.php
ln -s /opt/drush-6.5.0/drush /usr/local/bin/drush
rm /opt/drush-6.5.0.zip
log "Install drush : OK"




## Install Firewall
cp /root/scripts/Banned/firewall.sh /etc/init.d/firewall 
chmod 755 /etc/init.d/firewall
sed -i 's/MONITORING_IP_LIST=("192.168.1.5")/MONITORING_IP_LIST=("80.12.83.108" "37.59.3.119")/g' /etc/init.d/firewall
update-rc.d firewall defaults
log "Install firewall : OK"



## Install Java
cp /root/scripts/Applicatifs/Java/1.7/jdk-7u75-linux-x64.zip.* /opt 
cd /opt 
cat jdk-7u75-linux-x64.zip.00* > jdk-7u75-linux-x64.zip
unzip jdk-7u75-linux-x64.zip
tar xzf jdk-7u75-linux-x64.tar.gz
rm /opt/jdk-7u75-linux-x64.*
echo "
export PATH=\$PATH:/opt/jdk1.7.0_75/bin
export JAVA_HOME=/opt/jdk1.7.0_75" >> /etc/profile && source /etc/profile
ln -s /opt/jdk1.7.0_75/bin/java /usr/local/bin/java
log "Install Java : OK"



## Install NRPE
/root/scripts/Applicatifs/Nagios/installNRPE.sh
log "Install monitoring NPRE : OK"



## Install maintenance
rm /var/www/index.html
mkdir -p /var/www/{www,tmp,.socks,cgi-bin}
chown -R www-data:www-data /var/www/{www,tmp,.socks,cgi-bin}
cp /root/scripts/Shell/Monitoring-Reports/maintenance_apc_memcached.zip /var/www/www/
cd /var/www/www/
unzip maintenance_apc_memcached.zip
rm maintenance_apc_memcached.zip
chown -R www-data:www-data /var/www/www/
cat >> /etc/apache2/sites-available/0-maintenance << _EOF
<VirtualHost *:80>
  ServerAdmin webmaster@intuitiv.fr
 
  DocumentRoot /var/www/www/
 
  <Directory /var/www/www/>
    Options -Indexes FollowSymLinks MultiViews
    AllowOverride None
  </Directory>
 
  <Directory /var/www/www/tools/>
    Options -Indexes FollowSymLinks MultiViews
    AllowOverride All
    Order deny,allow
    Deny from all
    Allow from 80.12.83.108
    #AuthType Basic
    #AuthName "Restricted Area : please login"
    #AuthUserFile /var/www/.htpasswd
    #Require valid-user
  </Directory>
 
  <Directory /var/www/www/apc/>
    Options -Indexes
    AllowOverride All
    Order deny,allow
    Deny from all
    Allow from 80.12.83.108 37.59.3.119
  </Directory>
 
  # Clear PHP settings of this website
  <FilesMatch ".+\.ph(p[345]?|t|tml)\$">
    SetHandler None
  </FilesMatch>
  <IfModule mod_fastcgi.c>
    <Directory /var/www/cgi-bin>
      Order allow,deny
      Allow from all
    </Directory>
    <FilesMatch "\.php[345]?\$">
      SetHandler php5-fcgi
    </FilesMatch>
    Action php5-fcgi /php5-fcgi
    Alias /php5-fcgi /var/www/cgi-bin/php5-fcgi-*-80
    FastCgiExternalServer /var/www/cgi-bin/php5-fcgi-*-80 -idle-timeout 300 -socket /var/run/php5-fpm.sock -pass-header Authorization
  </IfModule>
 
  ServerSignature Off
</VirtualHost>
_EOF
a2ensite 0-maintenance
a2dissite 000-default
service apache2 reload
log "Install maintenance mode + tools : OK"




## install backupit
adduser backupit
cp /root/scripts/Shell/backup/dumpalldb /home/backupit/
chown backupit:backupit /home/backupit/dumpalldb
read -s -p "Enter MySQL root password : " ROOT_MYSQL
sed -i 's/DBPASS=""/DBPASS="'${ROOT_MYSQL}'"/g' /home/backupit/dumpalldb
installPackage sudo
echo "backupit ALL=NOPASSWD: /usr/bin/rsync" >> /etc/sudoers
mkdir /home/backupit/.ssh && chown backupit:backupit /home/backupit/.ssh && chmod 700 /home/backupit/.ssh
log "Install backupit : OK"



echo "
# example purge session files
#00 12 * * * root  find /home/plip/sessions/* -type f -mtime +15 -exec rm {} \;" >> /etc/crontab

## Secure Apache
APACHE_SECURITY="/etc/apache2/conf.d/security"
sed -i 's/^ServerTokens/#ServerTokens/g' ${APACHE_SECURITY}
sed -i 's/^ServerSignature/#ServerSignature/g' ${APACHE_SECURITY}
echo "
ServerTokens Prod
ServerSignature Off

<DirectoryMatch \"/\\.svn\">
  Order allow,deny
  Deny from all
  Satisfy all
</DirectoryMatch>

<DirectoryMatch \"/\\.git\">
  Order allow,deny
  Deny from all
  Satisfy all
</DirectoryMatch>

<Files ~ \"^\\.git\">
  Order allow,deny
  Deny from all
  Satisfy all
</Files>

" >> ${APACHE_SECURITY}
log "Secure Apache2 : OK"



## Configure APC
[[ ! -d "/mnt/apc" ]] && mkdir /mnt/apc && chmod 777 /mnt/apc
echo "tmpfs     /mnt/apc      tmpfs     size=128M     0        0" >> /etc/fstab && mount /mnt/apc
if [[ -f "/etc/php5/fpm/conf.d/20-apc.ini" ]]; then
  APC=/etc/php5/fpm/conf.d/20-apc.ini
  echo "apc.enabled = 1
apc.shm_size = 128M
apc.ttl = 7200
apc.user_ttl = 7200
apc.num_files_hint = 10000
apc.max_file_size = 2M
apc.stat = 1
apc.write_lock = 1
apc.mmap_file_mask=/mnt/apc/apc.XXXXXX" >> ${APC}
service php5-fpm restart
fi
log "COnfiguration of APC : OK"



## install phpmyadmin
apt-get install phpmyadmin
addgroup --system --gid 990 phpmyadmin
adduser --system --home /opt/phpmyadmin --uid 990 --gid 990 --shell /bin/sh phpmyadmin
mkdir -p /opt/phpmyadmin/{tmp,cgi-bin,.socks,sessions,logs}
echo "
Go to https://www.phpmyadmin.net/downloads/
"
read -p "Paste link to tar.gz of the PhpMyAdmin version you want to install : " PMALINK
cd /opt && wget "${PMALINK}"
tar xzf phpMyAdmin-4*
rm phpMyAdmin*tar.gz
mv phpMyAdmin* /opt/phpmyadmin/www
cp /opt/phpmyadmin/www/config.sample.inc.php /opt/phpmyadmin/www/config.inc.php
sed '$d' /opt/phpmyadmin/www/config.inc.php
echo "
/* Custom Configuration */
\$cfg['Servers'][\$i]['hide_db'] = '(information_schema|performance_schema|phpmyadmin|mysql)';
\$cfg['ShowServerInfo'] = false;
\$cfg['ShowPhpInfo'] = false;
\$cfg['ShowChgPassword'] = false;
\$cfg['ShowCreateDb'] = false;
\$cfg['SuggestDBName'] = false;
\$cfg['ThemeManager'] = false;
\$cfg['blowfish_secret'] = 'UFKGgyfKYFDflfDFyfOUG8D8Oteè-dubièdbkdè';
\$cfg['ThemeDefault'] = 'pmahomme';
\$cfg['SuhosinDisableWarning'] = true;
\$cfg['PmaNoRelation_DisableWarning'] = true;
?>
" >> /opt/phpmyadmin/www/config.inc.php
chown -R phpmyadmin:phpmyadmin /opt/phpmyadmin/

#Deplacement du fichier de config phpmaydmin d'apache
mv /etc/apache2/conf.d/phpmyadmin.conf /root/phpmyadmin.conf
#On dit a Apache d'ecouter aussi le port 8888 en plus du 80 et 443
PORTS="/etc/apache2/ports.conf"
LIGNE=$(awk '$0 == "Listen 80" {print NR}' ${PORTS})
sed -i "${LIGNE}a\Listen 8888" ${PORTS}

if [[ ! -f "/etc/apache2/sites-available/phpmyadmin" ]]; then
cat >> /etc/apache2/sites-available/phpmyadmin << _EOF_
<VirtualHost *:8888>
 
  DocumentRoot /opt/phpmyadmin/www/
 
  <Directory /opt/phpmyadmin/www/>
          Options FollowSymLinks
          DirectoryIndex index.php
 
    #Order deny,allow
    #Deny from env=Blacklist
    #Allow from env=Whitelist
 
          <IfModule mod_php5.c>
                  AddType application/x-httpd-php .php
 
                  php_flag magic_quotes_gpc Off
                  php_flag track_vars On
                  php_flag register_globals Off
                  php_admin_flag allow_url_fopen Off
                  php_value include_path .
                  php_admin_value upload_tmp_dir /var/lib/phpmyadmin/tmp
                  php_admin_value open_basedir /usr/share/phpmyadmin/:/etc/phpmyadmin/:/var/lib/phpmyadmin/
          </IfModule>
 
  </Directory>
 
  # Authorize for setup
  <Directory /opt/phpmyadmin/www/setup>
    <IfModule mod_authn_file.c>
      AuthType Basic
      AuthName "phpMyAdmin Setup"
      AuthUserFile /etc/phpmyadmin/htpasswd.setup
    </IfModule>
    Require valid-user
  </Directory>
 
  # Disallow web access to directories that don't need it
  <Directory /opt/phpmyadmin/www/libraries>
    Order Deny,Allow
    Deny from All
  </Directory>
  <Directory /opt/phpmyadmin/phpmyadmin/www/setup/lib>
    Order Deny,Allow
    Deny from All
  </Directory>
 
  # Clear PHP settings of this website
  <FilesMatch ".+\.ph(p[345]?|t|tml)\$">
    SetHandler None
  </FilesMatch>
  <IfModule mod_fastcgi.c>
    <Directory /opt/phpmyadmin/cgi-bin>
      Order allow,deny
      Allow from all
    </Directory>
    <FilesMatch "\.php[345]?\$">
      SetHandler php5-fcgi
    </FilesMatch>
    Action php5-fcgi /php5-fcgi
    Alias /php5-fcgi /opt/phpmyadmin/cgi-bin/php5-fcgi-*-80
    FastCgiExternalServer /opt/phpmyadmin/cgi-bin/php5-fcgi-*-80 -idle-timeout 300 -socket /opt/phpmyadmin/.socks/phpmyadmin.sock -pass-header Authorization
  </IfModule>
 
  ErrorLog /opt/phpmyadmin/logs/error.log
  LogLevel warn
  CustomLog /opt/phpmyadmin/logs/access.log combined
  ServerSignature Off
 
</VirtualHost>
_EOF_
fi

if [[ ! -f "/etc/php5/fpm/pool.d/phpmyadmin.conf" ]]; then
cat >> /etc/php5/fpm/pool.d/phpmyadmin.conf << __EOF__
[phpmyadmin]

;prefix = /path/to/pools/\$pool

user = \$pool
group = \$pool

listen = /opt/\$pool/.socks/\$pool.sock
;listen.backlog = 128
listen.owner = www-data
listen.group = www-data
listen.mode = 0660
listen.allowed_clients = 127.0.0.1

; priority = -19
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3

;pm.process_idle_timeout = 10s;
;pm.max_requests = 500

;ping.response = pong

;access.log = log/\$pool.access.log

; The access log format.
;access.format = "%R - %u %t \"%m %r%Q%q\" %s %f %{mili}d %{kilo}M %C%%"

;slowlog = log/\$pool.log.slow

;request_slowlog_timeout = 0
;request_terminate_timeout = 0
;rlimit_files = 1024
;rlimit_core = 0
;chroot =
chdir = /

; Pass environment variables like LD_LIBRARY_PATH. All \$VARIABLEs are taken from
; the current environment.
; Default Value: clean env
;env[HOSTNAME] = \$HOSTNAME
;env[PATH] = /usr/local/bin:/usr/bin:/bin
;env[TMP] = /tmp
;env[TMPDIR] = /tmp
;env[TEMP] = /tmp

; Default Value: nothing is defined by default except the values in php.ini and
;                specified at startup with the -d argument
;php_admin_value[sendmail_path] = /usr/sbin/sendmail -t -i -f www@my.domain.com

php_admin_value[open_basedir] = /opt/phpmyadmin/:/etc/phpmyadmin/
php_admin_value[session.save_path] = /opt/phpmyadmin/tmp
php_admin_value[upload_tmp_dir] = /opt/phpmyadmin/tmp
;php_admin_value[sendmail_path] = /usr/sbin/sendmail -t -i -f contact@ovm09.itserver.fr

;;; Gestion des erreurs
; Affichage des erreurs
php_flag[display_errors] = off
; Log des erreurs
php_admin_value[error_log] = /var/log/apache2/fpm-php-phpmyadmin.log
php_admin_flag[log_errors] = on

;;; Valeurs custom php.ini
php_admin_value[memory_limit] = 256M
php_admin_value[post_max_size] = 30M
php_admin_value[upload_max_filesize] = 30M
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
__EOF__
fi

a2ensite phpmyadmin && service apache2 restart && service php5-fpm restart

if [[ ! -f "/etc/logrotate.d/phpmyadmin" ]]; then
cat >> /etc/logrotate.d/phpmyadmin << __EOF
/opt/phpmyadmin/logs/*.log {
        weekly
        missingok
        rotate 52
        compress
        delaycompress
        notifempty
        create 640 phpmyadmin adm
        sharedscripts
        postrotate
                /etc/init.d/apache2 reload > /dev/null
        endscript
        prerotate
                if [ -d /etc/logrotate.d/httpd-prerotate ]; then \
                        run-parts /etc/logrotate.d/httpd-prerotate; \
                fi; \
        endscript
}
__EOF
fi
log "Install of phpmyadmin : OK"

## Install mod_security
/root/scripts/Shell/web/Security/installModSecurity.sh
service apache2 restart
log "Install of mod_security : OK"


### end 
echo "
##############################################
Think to :
  - Configure postfix with sasl_passwd file for Mandrill
  - Create Solr service + home
  - install fail2ban
"
