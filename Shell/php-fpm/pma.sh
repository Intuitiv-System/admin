#!/bin/bash


##################################################
# Script de configuration de PhpMyAdmin
# dans un environnement avec PHP-fpm + FastCGI
##################################################

# Variables a editer
HOME_PMA="/opt/phpmyadmin"
USER_PMA="phpmyadmin"
PORT="8888"




# Installation de phpmyadmin
if [[ $(dpkg --list | grep phpmyadmin | awk '{print $1}') != "ii" ]]; then
	aptitude install -y dbconfig-common ttf-dejavu-core > /dev/null
	# Recuperation du package upgradé de phpmyadmin
	cd /tmp && wget "http://sourceforge.net/projects/admin-scripts/files/Shell/php-fpm/phpmyadmin_3.4.11.1-1_all.deb"
	dpkg -i /tmp/phpmyadmin_3.4.11.1-1_all.deb
	echo "Installation de PhpMyAdmin : [OK]"
elif [[ $(dpkg --list | grep phpmyadmin | awk -F":" '{print $2}' | cut -c 1-6) != "3.4.11" ]]; then
	# Recuperation du package upgradé de phpmyadmin
	cd /tmp && wget "http://sourceforge.net/projects/admin-scripts/files/Shell/php-fpm/phpmyadmin_3.4.11.1-1_all.deb"
	dpkg -i /tmp/phpmyadmin_3.4.11.1-1_all.deb
	echo "Upgrade de PhpMyAdmin : [OK]"
else
	echo "Phpmyadmin est deja a la bonne version."
fi


# Creation d'un user pour phpmyadmin
# On place le home du user dans /opt/phpmyadmin
if [[ -z $(grep ${USER_PMA} /etc/passwd) ]]; then
	adduser --system --home ${HOME_PMA} --shell /bin/false ${USER_PMA}
	addgroup --system ${USER_PMA}
	usermod -g ${USER_PMA} ${USER_PMA}
else
	echo "Un utilisateur ${USER_PMA} existe deja..."
	echo "Script abort... exit"
	exit 1
fi

# Copie des fichiers phpmyadmin dans le home
if [[ ! -d ${HOME_PMA}/www ]]; then
  mkdir ${HOME_PMA}/www
fi
cp -R /usr/share/phpmyadmin/* ${HOME_PMA}/www


# Creation de l'environnement pour php-fpm
if [[ ! -d ${HOME_PMA}/www/cgi-bin ]]; then
	mkdir ${HOME_PMA}/www/cgi-bin
fi
if [[ ! -d ${HOME_PMA}/www/tmp ]]; then
	mkdir ${HOME_PMA}/www/tmp
fi
if [[ ! -d ${HOME_PMA}/.socks ]]; then
	mkdir ${HOME_PMA}/.socks
fi
if [[ ! -d ${HOME_PMA}/logs ]]; then
	mkdir ${HOME_PMA}/logs
fi


# On fixe les droits
chown -R ${USER_PMA}:${USER_PMA} ${HOME_PMA}
find ${HOME_PMA}/www -type f -exec chmod 644 {} \;


# Creation du pool FPM pour phpmyadmin
if [[ ! -f /etc/php5/fpm/pool.d/phpmyadmin.conf ]]; then
cat >> /etc/php5/fpm/pool.d/phpmyadmin.conf << EOF
; Nom du pool
[pma]
; On utilisera une socket
listen = ${HOME_PMA}/.socks/pma.sock

; Permission pour la socket
listen.owner = ${USER_PMA}
listen.group = ${USER_PMA}
listen.mode = 0666

; Utilsateur/Groupe des processus
user = ${USER_PMA}
group = ${USER_PMA}
;chroot =
; On choisira une gestion dynamique des processus
pm = dynamic

pm.max_children = 20
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 10

slowlog = ${HOME_PMA}/logs/slow.log

; Quelques directives de configuration de PHP
php_admin_value[open_basedir]=${HOME_PMA}/www
php_admin_value[session.save_path]=${HOME_PMA}/www/tmp
php_admin_value[upload_tmp_dir]=${HOME_PMA}/www/tmp

EOF
fi


# Creation du virtualhost pour phpmyadmin
if [[ ! -f /etc/apache2/sites-available/phpmyadmin ]]; then
cat >> /etc/apache2/sites-available/phpmyadmin << _EOF_
<VirtualHost *:${PORT}>
	# phpMyAdmin default Apache configuration

	# Fast CGI + FPM
	FastCgiExternalServer ${HOME_PMA}/www/cgi-bin/php5.external -socket ${HOME_PMA}/.socks/pma.sock
	Alias /cgi-bin ${HOME_PMA}/www/cgi-bin/

	DocumentRoot ${HOME_PMA}/www
	<Directory ${HOME_PMA}/www>
    	Options SymLinksIfOwnerMatch
    	DirectoryIndex index.php

#    <IfModule mod_php5.c>
#        AddType application/x-httpd-php .php
#
#        php_flag magic_quotes_gpc Off
#        php_flag track_vars On
#        php_flag register_globals Off
#        php_value include_path .
#    </IfModule>
	</Directory>

	# Authorize for setup
	<Directory ${HOME_PMA}/www/setup>
    	<IfModule mod_authn_file.c>
    	AuthType Basic
    	AuthName "phpMyAdmin Setup"
    	AuthUserFile /etc/phpmyadmin/htpasswd.setup
    	</IfModule>
    	Require valid-user
	</Directory>

	# Disallow web access to directories that do not need it
	<Directory ${HOME_PMA}/www/libraries>
    	Order Deny,Allow
    	Deny from All
	</Directory>
	<Directory ${HOME_PMA}/www/setup/lib>
    	Order Deny,Allow
    	Deny from All
	</Directory>

</VirtualHost>

_EOF_

echo "Creation du VirtualHost pour PhpMyAdmin : [OK]"
fi


if [[ -f /etc/apache2/conf.d/phpmyadmin.conf ]]; then
	mv /etc/apache2/conf.d/phpmyadmin.conf /root/
fi


#On dit a Apache d'ecouter aussi le port 8888 en plus du 80 et 443
PORTS="/etc/apache2/ports.conf"
if [[ $(grep "Listen ${PORT}" ${PORTS} | wc -l) -eq "0" ]]; then
	LIGNE=$(awk '$0 == "Listen 80" {print NR}' ${PORTS})
	sed -i "${LIGNE}a\Listen ${PORT}" ${PORTS}
else
	echo "Le fichier ${PORTS} contient deja un port ${PORT}."
	echo "Verifier le fichier ${PORTS} !"
fi

# Activation du VHost phpmyadmin
a2ensite phpmyadmin


# On restart tous ca !
/etc/init.d/apache2 restart && /etc/init.d/php5-fpm restart



echo "-------------------------------------------------------------------------------------"
echo "--"
echo "-- Info : PHPMYADMIN est maintenant accessible a l adresse http://domain.com:${PORT}"
echo "--"
echo "-------------------------------------------------------------------------------------"

exit 0
