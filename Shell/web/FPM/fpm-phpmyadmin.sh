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

installPackage() {
    if [[ $(dpkg -l | awk '{print $1" "$2}' | grep " ${1}"$) != "ii ${1}" ]]; then
        log "Installation du package ${1}..."
        apt-get -y -q install "${1}" &> /dev/null
    else
        log "Package ${1} already installed on your system."
    fi
}


##################
#
#     MAIN
#
##################

createLogrotate

# Créer un user/group phpmyadmin :
addgroup --system --gid 999 phpmyadmin
adduser --system --home /opt/phpmyadmin --uid 999 --gid 999 --shell /bin/sh phpmyadmin

if [[ -f "/etc/apache2/conf.d/phpmyadmin.conf" ]]; then
  mv /etc/apache2/conf.d/phpmyadmin.conf /root/
fi

if [[ $(grep -E "^Listen 8888" /etc/apache2/ports.conf | wc -l) != "1" ]]; then
  sed "\Listen 80/aListen 8888" /etc/apache2/ports.conf
fi

if [[ ! -f "/etc/apache2/sites-available/phpmyadmin" ]]; then
cat >> /etc/apache2/sites-available/phpmyadmin << END
<VirtualHost *:8888>

  DocumentRoot /opt/phpmyadmin/www/

  <Directory /opt/phpmyadmin/www/>
          Options FollowSymLinks
          DirectoryIndex index.php

    Order deny,allow
    Deny from env=Blacklist
    Allow from env=Whitelist

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
  <FilesMatch ".+\.ph(p[345]?|t|tml)$">
    SetHandler None
  </FilesMatch>
  <IfModule mod_fastcgi.c>
    <Directory /opt/phpmyadmin/cgi-bin>
      Order allow,deny
      Allow from all
    </Directory>
    <FilesMatch "\.php[345]?$">
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
END
  a2ensite phpmyadmin && apache2ctl graceful && ps aux | grep apache2
fi

if [[ ! -f "/etc/logrotate.d/phpmyadmin" ]]; then
  echo "/opt/phpmyadmin/logs/*.log {
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
"
fi

exit 0