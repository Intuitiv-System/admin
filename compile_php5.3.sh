#!/bin/bash
#
# Filename : .sh
# Version  : 1.0
# Author   : mathieu androz
# Contrib  : 
# Description :
#  . 
#  . 
#


LOGFILE="/var/log/admin/admin.log"
HOSTINGBASE="/home/hosting"

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

####################################
## MAIN
####################################

read -p "Enter path where you want to install PHP 5.3 : " PHPPATH

apt-get install build-essential \
  mysql-client \
  libmysql++-dev \
  libxml2-dev  \
  libcurl4-openssl-dev \
  libpng12-dev \
  libicu-dev \
  libmcrypt-dev \
  libxslt1-dev \
  autoconf \
  autoconf2.13 \
  libbz2-dev \
  libjpeg-dev \
  libcurl4-openssl-dev \
  libxpm-dev \
  libfreetype6-dev \
  libt1-dev \
  libgmp-dev \
  libpspell-dev \
  libltdl-dev

ln -s /usr/lib/x86_64-linux-gnu/libXpm.a /usr/lib/libXpm.a


CONFIG_OPTS="--prefix="${PHPPATH}" \
  --with-config-file-path="${PHPPATH}"/etc \
  --with-layout=GNU \
  --with-config-file-scan-dir=${PHPPATH}/etc/conf.d
"

WITH_OPTS="--with-gd \
  --with-png-dir=/usr \
  --with-mysqli=/usr/bin/mysql_config \
  --with-openssl \
  --with-zlib \
  --with-curl \
  --with-gettext \
  --with-mcrypt \
  --with-mhash \
  --with-mysql \
  --with-jpeg-dir=/usr \
  --with-regex=system \
  --with-gnu-ld \
  --with-libxml-dir \
  --with-xsl \
  --with-xmlrpc \
  --with-iconv \
  --with-pdo-mysql \
  --with-xpm-dir=/usr \
  --with-t1lib \
  --with-pcre-regex \
  --with-freetype-dir=/usr \
  --with-pspell \
  --with-bz2 \
  --with-gmp
  "


FPM_OPTS="--enable-fpm \
--with-fpm-user=www-data \
--with-fpm-group=www-data
"


ENABLE_OPTS="--disable-ipv6 \
  --enable-intl \
  --enable-wddx \
  --enable-sigchild \
  --enable-short-tags \
  --disable-rpath \
  --enable-libgcc \
  --enable-bcmath \
  --enable-calendar \
  --enable-ftp \
  --enable-exif \
  --enable-sysvsem \
  --enable-sysvshm \
  --enable-sysvmsg \
  --enable-zip \
  --enable-inline-optimization \
  --enable-soap \
  --enable-mbstring \
  --enable-mbregex \
  --enable-shared=yes \
  --enable-static=yes \
  --enable-sockets \
  --enable-pdo
"


cd /tmp
wget http://fr2.php.net/get/php-5.3.28.tar.gz/from/this/mirror -O php-5.3.28.tar.gz
tar xzf php-5.3.28.tar.gz

cd php-5.3.28
./configure $CONFIG_OPTS $WITH_OPTS $ENABLE_OPTS $FPM_OPTS

make && make install


# pool.d folder
if [[ -d /etc/php5/fpm/pool.d ]] && [[ -d "${PHPPATH}" ]]; then
  ln -s /etc/php5/fpm/pool.d "${PHPPATH}"/etc/pool.d
  log_success_msg "Creation of pool.d folder as a symlink of /etc/php5/fpm/pool.d"
elif [[ -d "${PHPPATH}"/etc ]]; then
  mkdir -p "${PHPPATH}"/etc/pool.d && log_success_msg "Creation of pool.d folder"
else
  log_failure_msg "No pool.d folder has been found or created. Please inspect !"
fi

[[ ! -d "${PHPPATH}"/etc/conf.d ]] && mkdir "${PHPPATH}"/etc/conf.d

[[ ! -f "${PHPPATH}"/etc/php-fpm.conf ]] && cp "${PHPPATH}"/etc/php-fpm.conf.default "${PHPPATH}"/etc/php-fpm.conf && log_success_msg "Creation of php-fpm.conf file"
echo "include=\"${PHPPATH}\"/etc/pool.d/*.conf" >> "${PHPPATH}"/etc/php-fpm.conf

# php.ini
[[ ! -f "${PHPPATH}"/etc/php.ini ]] && cp /tmp/php-5.3.28/php.ini-production "${PHPPATH}"/etc/php.ini && log_success_msg "php.ini file location : "${PHPPATH}"/etc/php.ini"

# Modif listen = /var/run/php-53-fpm.sock
[[ -n $(grep -E "^listen" "${PHPPATH}"/etc/php-fpm.conf) ]] && sed -i s/^listen/\;listen/g "${PHPPATH}"/etc/php-fpm.conf

# init.d
PHPINITD="/etc/init.d/php53-fpm"

[[ ! -f "${PHPINITD}" ]] && \
echo "#! /bin/sh
### BEGIN INIT INFO
# Provides:          php53-fpm
# Required-Start:    \$all
# Required-Stop:     \$all
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: starts php53-fpm
# Description:       starts the PHP FastCGI Process Manager daemon
### END INIT INFO
php_fpm_BIN=\"${PHPPATH}\"/sbin/php-fpm
php_fpm_CONF=\"${PHPPATH}\"/etc/php-fpm.conf
php_fpm_PID=\"${PHPPATH}\"/var/run/php-fpm.pid
php_opts=\"--fpm-config \$php_fpm_CONF\"
wait_for_pid () {
        try=0
        while test \$try -lt 35 ; do
                case \"\$1\" in
                        'created')
                        if [ -f \"\$2\" ] ; then
                                try=''
                                break
                        fi
                        ;;
                        'removed')
                        if [ ! -f \"\$2\" ] ; then
                                try=''
                                break
                        fi
                        ;;
                esac
                echo -n .
                try=\$(expr \$try + 1)
                sleep 1
        done
}
case \"\$1\" in
        start)
                echo -n \"Starting php-fpm \"
                \$php_fpm_BIN \$php_opts
                if [ \"\$?\" != 0 ] ; then
                        echo \" failed\"
                        exit 1
                fi
                wait_for_pid created \$php_fpm_PID
                if [ -n \"\$try\" ] ; then
                        echo \" failed\"
                        exit 1
                else
                        echo \" done\"
                fi
        ;;
        stop)
                echo -n \"Gracefully shutting down php-fpm \"
                if [ ! -r \$php_fpm_PID ] ; then
                        echo \"warning, no pid file found - php-fpm is not running ?\"
                        exit 1
                fi
                kill -QUIT \$(cat \$php_fpm_PID)
                wait_for_pid removed \$php_fpm_PID
                if [ -n \"$try\" ] ; then
                        echo \" failed. Use force-exit\"
                        exit 1
                else
                        echo \" done\"
                       echo \" done\"
                fi
        ;;
        force-quit)
                echo -n \"Terminating php-fpm \"
                if [ ! -r \$php_fpm_PID ] ; then
                        echo \"warning, no pid file found - php-fpm is not running ?\"
                        exit 1
                fi
                kill -TERM \$(cat $php_fpm_PID)
                wait_for_pid removed \$php_fpm_PID
                if [ -n \"\$try\" ] ; then
                        echo \" failed\"
                        exit 1
                else
                        echo \" done\"
                fi
        ;;
        restart)
                \$0 stop
                \$0 start
        ;;
        reload)
                echo -n \"Reload service php-fpm \"
                if [ ! -r \$php_fpm_PID ] ; then
                        echo \"warning, no pid file found - php-fpm is not running ?\"
                        exit 1
                fi
                kill -USR2 \$(cat \$php_fpm_PID)
                echo \" done\"
        ;;
        *)
                echo \"Usage: \$0 {start|stop|force-quit|restart|reload}\"
                exit 1
        ;;
esac
" > "${PHPINITD}"
chmod 755 "${PHPINITD}"

# Add APC to PHP
installPackage php-pear
installPackage autoconf
cd "${PHPPATH}"/bin
./pecl download apc
tar xzf APC-*.tgz
cd APC-*/
../phpizet
./configure --with-php-config="${PHPPATH}"/bin/php-config
make && make install

echo "extension=apc.so

apc.enabled = 1
apc.shm_size = 128M
apc.ttl = 7200
apc.user_ttl = 7200
apc.num_files_hint = 3000
apc.max_file_size = 2M
apc.stat = 1
apc.write_lock = 1
" > "${PHPPATH}"/etc/conf.d/apc.ini && echo "Think to restart FPM !"