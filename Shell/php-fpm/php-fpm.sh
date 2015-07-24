#!/bin/bash

####################################################################
# Script d'installation de PHP-FPM + FastCGI
####################################################################

# Ajout des repos DotDeb
dotdeb_repo() {
	#Recuperation de la cle DotDeb
	wget http://www.dotdeb.org/dotdeb.gpg
	cat dotdeb.gpg | apt-key add -
	aptitude clean > /dev/null
	aptitude update > /dev/null
	if [[ -e dotdeb.gpg ]]; then
		rm dotdeb.gpg
	fi
	echo "Ajout de la cle GPG DotDeb : [OK]"

	#Ajout des repos DotDeb
	SOURCES_LIST="/etc/apt/sources.list.d/dotdeb.list"
        if [ -e "${SOURCES_LIST}" ]; then rm ${SOURCES_LIST}; fi
	echo "#DotDeb packages" >> ${SOURCES_LIST}
	echo "deb http://packages.dotdeb.org squeeze all" >> ${SOURCES_LIST}
	echo "deb-src http://packages.dotdeb.org squeeze all" >> ${SOURCES_LIST}

	echo "Ajout des repositories DotDeb dans le sources.list : [OK]"


	#Fixation des preferences APT pour ne recuperer que les packages PHP upgrades
	PREF_APT="/etc/apt/preferences.d/dotdeb"

cat >> ${PREF_APT} << EOF
Package: libmysqlclient16
Pin : origin *.debian.org
Pin-Priority: 900

Package: mysql-client-5.1
Pin : origin *.debian.org
Pin-Priority: 900

Package: mysql-common
Pin: origin *.debian.org
Pin-Priority: 900

Package: mysql-server
Pin: origin *.debian.org
Pin-Priority: 900

Package: mysql-server-5.1
Pin: origin *.debian.org
Pin-Priority: 900

Package: mysql-server-core-5.1
Pin: origin *.debian.org
Pin-Priority: 900

Package: php5-*
Pin: origin packages.dotdeb.org
Pin-Priority: 500

Package: libapache2-mod-php5*
Pin: origin packages.dotdeb.org
Pin-Priority: 500

EOF
	echo "Creation du fichier de preferences apt : [OK]"
}


# Creation du package fastcgi
# en version 2.4.7
# et installation
fastcgi_install() {
	#Installation des packages pour creation du package
	echo "Installation des packages neccesaires a la creation du nouveau package fastcgi 2.4.7 : [OK]"
	aptitude install -y -q build-essential debhelper cdbs apache2-threaded-dev dpatch libapr1-dev libtool pkg-config

	#Ajout du repo Debian testing
	echo "deb-src http://ftp.fr.debian.org/debian/ testing main contrib non-free" >> /etc/apt/sources.list.d/testing_all.list
	aptitude update > /dev/null

	#Recuperation des sources de fastcgi
	cd /tmp
	apt-get source libapache2-mod-fastcgi

	#Compilation du nouveau package
	cd libapache-mod-fastcgi-2.4.7*
	fakeroot dpkg-buildpackage

	#Installation du nouveau package
	dpkg -i ../libapache2-mod-fastcgi_2.4.7*.deb

	/etc/init.d/apache2 restart

	#Suppression du repo testing dans le sources.list
	#sed -i".bak" '/deb-src http:\/\/ftp.fr.debian.org\/debian\/ testing main contrib non-free/d' /etc/apt/sources.list
    rm /etc/apt/sources.list.d/testing_all.list
	aptitude clean > /dev/null && aptitude update > /dev/null

	echo "Installation du module fastCGI 2.4.7 : [OK]"
}

# Configuration du module FastCGI dans Apache2
fastcgi_conf() {
	#Creation du fichier de conf fastcgi dans apache
	FASTCGI_CONF="/etc/apache2/mods-available/fastcgi.conf"
	if [[ -e ${FASTCGI_CONF} ]]; then
		a2dismod fastcgi && /etc/init.d/apache2 restart
		mv ${FASTCGI_CONF} ${FASTCGI_CONF}.orig
	fi
cat > ${FASTCGI_CONF} << EOF
<IfModule mod_fastcgi.c>
  AddHandler php5-fcgi .php
  Action php5-fcgi /cgi-bin/php5.external
  <Location "/cgi-bin/php5.external">
    Order Deny,Allow
    Deny from All
    Allow from env=REDIRECT_STATUS
  </Location>
</IfModule>
EOF

	a2enmod fastcgi actions
}


# Installation de PHP-fpm
fpm_install() {
	#Installation de PHP-fpm + autres
	aptitude install php5-fpm php5-mcrypt php5-curl php5-gd php5-xsl php5-xmlrpc php-apc php5-suhosin

	echo "Installation de PHP-fpm : [OK]"

	#Backup du fichier de pool conf
	FPM_POOL="/etc/php5/fpm/pool.d"
	mv ${FPM_POOL}/www.conf ${FPM_POOL}/www.conf.dist

	echo "Sauvegarde du fichier de definition de pool de process PHP d'origine : [OK]"
}


# Creation de l'environnement d'un VHost
create_vhost_pool() {
	clear
	echo "---------------------------------------------"
	echo "- CREATION DE L'ENVIRONNEMENT POUR UN VHOST -"
	echo "---------------------------------------------"
	read -p "Entrer le nom du home du site : " VHOST

	if [[ ! -d /home/${VHOST} ]]; then
		echo "Creation de l'utilisateur :"
		read -p "Entrer le nom du user UNIX a creer : " VHOST
		adduser --shell /bin/false --disabled-login ${VHOST}
	fi

	POOL_VHOST="/etc/php5/fpm/pool.d/${VHOST}.conf"
	if [[ ! -e ${POOL_VHOST} ]]; then
cat >> ${POOL_VHOST} << EOF
; Nom du pool
[${VHOST}]
; On utilisera une socket
listen = /home/${VHOST}/.socks/${VHOST}.sock

; Permission pour la socket
listen.owner = ${VHOST}
listen.group = ${VHOST}
listen.mode = 0666

; Utilsateur/Groupe des processus
user = ${VHOST}
group = ${VHOST}

; On choisira une gestion dynamique des processus
pm = dynamic

pm.max_children = 20
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 10

slowlog = /var/log/php5-fpm/${VHOST}.log.slow

; Quelques directives de configuration de PHP
php_admin_value[open_basedir]=/home/${VHOST}/www
php_admin_value[session.save_path]=/home/${VHOST}/tmp
php_admin_value[upload_tmp_dir]=/home/${VHOST}/tmp

;;; Gestion des erreurs
; Affichage des erreurs
php_flag[display_errors] = off
; Log des erreurs
php_admin_value[error_log] = /home/${VHOST}/logs/fpm-php.log
php_admin_flag[log_errors] = on

;;; Valeurs custom php.ini
;php_admin_value[memory_limit] = 32M
;php_admin_value[post_max_size] = 8M
;php_admin_value[upload_max_filesize] = 8M
; SECURITY
php_admin_value[magic_quotes_gpc]=0
php_admin_value[register_globals]=0
php_admin_value[session.auto_start]=0
;php_admin_value[mbstring.http_input]="pass"
;php_admin_value[mbstring.http_output]="pass"
php_admin_value[mbstring.encoding_translation]=0
php_admin_value[expose_php]=0
php_admin_value[allow_url_fopen]=1
php_admin_value[safe_mode]=0
php_admin_value[cgi.fix_pathinfo]=1

; Liste des extensions autorisÃ©es avec php-fpm
;security.limit_extensions = .php .php5 .html .htm



EOF
	echo "Creation du pool FPM ${VHOST} : [OK]"

	else
		echo "Le pool de process ${VHOST} existe deja."
		echo "La creation de l'environnement pour ${VHOST} se termine sans modification."
		exit 3
	fi

	#Creation des repertoires de l'environnement
	if [[ ! -d /home/${VHOST}/.socks ]]; then
		mkdir /home/${VHOST}/.socks
		echo "Creation de /home/${VHOST}/.socks"
	fi
	if [[ ! -d /home/${VHOST}/cgi-bin ]]; then
		mkdir /home/${VHOST}/cgi-bin
		echo "Creation de /home/${VHOST}/cgi-bin"
	fi
	if [[ ! -d /home/${VHOST}/tmp ]]; then
		mkdir /home/${VHOST}/tmp
		echo "Creation de /home/${VHOST}/tmp"
	fi
	if [[ ! -d /home/${VHOST}/logs ]]; then
		mkdir /home/${VHOST}/logs
		echo "Creation de /home/${VHOST}/logs"
	fi
        if [[ ! -d /home/${VHOST}/www ]]; then
                mkdir /home/${VHOST}/www
                echo "Creation de /home/${VHOST}/www"
        fi

	chown -R ${VHOST}:${VHOST} /home/${VHOST}/.socks
	chown -R ${VHOST}:${VHOST} /home/${VHOST}/cgi-bin
	chown -R ${VHOST}:${VHOST} /home/${VHOST}/tmp
	chown -R ${VHOST}:${VHOST} /home/${VHOST}/logs
	chown -R ${VHOST}:${VHOST} /home/${VHOST}/www

	#Creation du irtualHost dans Apache
	VHOST_APACHE="/etc/apache2/sites-available/${VHOST}"
	if [[ ! -e ${VHOST_APACHE} ]]; then
cat >> ${VHOST_APACHE} << EOF
<VirtualHost *:80>
	ServerAdmin contact@intuitiv.fr
	ServerName

	DocumentRoot /home/${VHOST}/www
	Options None

	# Fast CGI + FPM
	# La valeur de idle.timeout est modifiable,
	# elle correspond au timeout de FastCGI pour ce vhost
	FastCgiExternalServer /home/${VHOST}/cgi-bin/php5.external -socket /home/${VHOST}/.socks/${VHOST}.sock
	Alias /cgi-bin/ /home/${VHOST}/cgi-bin/

	<Directory /home/${VHOST}/www>
		Options -Indexes SymLinksIfOwnerMatch
		AllowOverride All
		Order allow,deny
		Allow from all
	</Directory>

	Redirect 404 /favicon.ico
	<Location /favicon.ico>
    	ErrorDocument 404 "No favicon"
	</Location>

	# Log
	ErrorLog /home/${VHOST}/logs/error.log
	LogLevel warn
	CustomLog /home/${VHOST}/logs/access.log combined
</VirtualHost>
EOF
	echo "Creation du VirtualHost ${VHOST} dans /etc/apache2/sites-available/"
	a2ensite ${VHOST} && /etc/init.d/apache2 reload

	else
		echo "Le VirtualHost dans Apache ${VHOST} existe deja ! : [WARN]"
	fi

}




#################
#     Main
#################

# Ajout des repos DotDeb
#dotdeb_repo

# Creation du package fastcgi en version 2.4.7 et installation
#fastcgi_install

# Configuration du module FastCGI dans Apache2
#fastcgi_conf

# Installation de php-fpm + configuration initiale
fpm_install

# Creation de l'environnement d'un VHost
create_vhost_pool

exit 0