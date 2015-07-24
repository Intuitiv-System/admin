#!/bin/bash
#
# Filename : configServer.sh
# Version  : 1.2
# Author   : mathieu androz
# Description :
#   Apache2 Configuration script :
# - Blocage acces phpmyadmin par noms de domaine
# - Access phpmyadmin from a difined port
# - securisation d'Apache2
# - Creation d'un VHost de maintenance
# - Modification des pages d'erreur 4xx et 5xx
# - Ajout de l'option optimisation d'apache
#


usage() {
    echo "" 
    echo "Usage : $0 {security|maintenance|phpmyadmin}"
    echo ""
    echo -e "security\t\t- Change apache2 security variables (ServerSignature/ServerTokens/TraceEnable)"
    echo -e "maintenance\t\t- Create a VirtualHost 0-maintenance\n\t\t\t- Activate the VirtualHost\n\t\t\t- Reload apache2"
    echo -e "phpmyadmin\t\t- Install phpmyadmin\n\t\t\t- Create a VirtualHost for phpmyadmin\n\t\t\t- Change the access port\n\t\t\t- Customize phpmyadmin configuration"
}

#On edite le fichier security d'apache2 pour bloquer les infos sur le serveur
change_security() {
    SECURITY_FILE="/etc/apache2/conf.d/security"
    if [ -e "${SECURITY_FILE}" ] ; then
        cp ${SECURITY_FILE} /root/security.orig
        #ServerSignature : Off
        sed -i "s/^ServerSignature/#ServerSignature/g" ${SECURITY_FILE}
        #ServerTokens : Prod
        sed -i "s/^ServerTokens/#ServerTokens/g" ${SECURITY_FILE}
        #TraceEnable : off
        sed -i "s/^TraceEnable/#TraceEnable/g" ${SECURITY_FILE}
        echo -e "\nServerSignature Off\nServerTokens Prod\nTraceEnable off" >> ${SECURITY_FILE}
        /etc/init.d/apache2 restart
    else
        echo "Le fichier /etc/apache2/conf.d/security n'existe pas..."
        exit 1
    fi
}


#On cree un VHost pour la maintenance
#et pour acceder a phpmyadmin uniquement par l'IP du serveur
create_maintenance() {
    MAINTENANCE="/etc/apache2/sites-available/0-maintenance"
    if [ -e "${MAINTENANCE}" ] ; then
        echo "Le VHost 0-maintenance existe deja !"
        exit 1
    else
cat > ${MAINTENANCE} << EOF
<VirtualHost *:80>
	ServerAdmin contact@intuitiv.fr

	DocumentRoot /var/www

	<Directory /var/www>
		Options -Indexes FollowSymLinks MultiViews
		AllowOverride None
	</Directory>
</VirtualHost>
EOF

    cp /var/www/index.html /var/www/index.html.orig

#Contenu de la page maintenance
cat > /var/www/index.html << _EOF_
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
   "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
    <title>En maintenance</title>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <meta name="robots" content="noindex" />
    <style type="text/css"><!--
    body {
        color: #444444;
        background-color: #EEEEEE;
        font-family: 'Trebuchet MS', sans-serif;
        font-size: 80%;
    }
    h1 {}
    h2 { font-size: 1.2em; }
    #page{
        background-color: #FFFFFF;
        width: 60%;
        margin: 24px auto;
        padding: 12px;
    }
    #header {
        padding: 6px ;
        text-align: center;
    }
    .status3xx { background-color: #475076; color: #FFFFFF; }
    .status4xx { background-color: #09F; color: #FFFFFF; }
    .status5xx { background-color: #F2E81A; color: #000000; }
    #content {
        padding: 4px 0 24px 10px;
    }
    #footer {
        color: #666666;
        background: #f9f9f9;
        padding: 10px 20px;
        border-top: 5px #efefef solid;
        font-size: 0.8em;
        text-align: center;
    }
    #footer a {
        color: #999999;
    }
    --></style>
</head>
<body>
    <div id="page">
        <div id="header" class="status4xx">
            <h1>Site en maintenance</h1>
        </div>
        <div id="content">
            <h2>Site en maintenance</h2>
            <p>Le site web est momentan&eacute;ment indisponible.</p>
                        <P>Veuillez revenir ult&eacute;rieurement.</p>
            <p>Merci de votre compr&eacute;hension.</p>
        </div>
        <div id="footer">
        </div>
    </div>
</body>
</html>
_EOF_

#On bloque le referencement de cette page sur les moteurs de recherche
cat > /var/www/robots.txt << -EOF-
User-Agent: *
Disallow: /
-EOF-
    #Activation du VHost maintenance
    a2ensite 0-maintenance
    #On recharge Apache2
    /etc/init.d/apache2 reload

    fi
}



#On verifie si phpmyadmin est present.
#S il n est pas installe, on demande pour l'installer
phpmyadmin_present() {
    PHPMYADMIN_OK=`aptitude show phpmyadmin | awk 'NR==2 {print $0}'`
    echo -e "Phpmyadmin est-il installe ? : ${PHPMYADMIN_OK}"
    if [ "${PHPMYADMIN_OK}" != "État: installé" ] ; then
        echo -e "Voulez-vous installer phpmyadmin maintenant ? :"
        select ok_phpmyadmin in oui non
        do
            case ${ok_phpmyadmin} in
                "oui")
                    aptitude install phpmyadmin
                    break
                ;;
                "non")
                    echo "A bientot !"
                    exit 0
                ;;
                "*")
                    echo "Je n'ai pas compris votre reponse..."
                ;;
            esac
        done
    fi
}


create_phpmyadmin() {
    if [ -e /etc/apache2/sites-available/phpmyadmin ] ; then
        echo -e "Le VHost phpmyadmin existe deja !"
        exit 1
    else
        read -p "Quelle est l'IP du serveur ? : " IP
        read -p "Sur quel port vouluez-vous accéder à PhpMyAdmin ? : " PMAPORT
        cat > /etc/apache2/sites-available/phpmyadmin << _EOF
<VirtualHost ${IP}:${PMAPORT}>
# phpMyAdmin default Apache configuration

DocumentRoot /usr/share/phpmyadmin

#Alias /phpmyadmin /usr/share/phpmyadmin

<Directory /usr/share/phpmyadmin>
        AllowOverride All
        Options FollowSymLinks
        DirectoryIndex index.php

        #AuthType Basic
        #AuthName "Restricted Access : please login"
        #AuthUserFile /etc/phpmyadmin/.htpasswd
        #Require valid-user

        <IfModule mod_php5.c>
                AddType application/x-httpd-php .php
                php_flag magic_quotes_gpc Off
                php_flag track_vars On
                php_flag register_globals Off
                php_value include_path .
        </IfModule>

</Directory>

# Authorize for setup
<Directory /usr/share/phpmyadmin/setup>
    <IfModule mod_authn_file.c>
    AuthType Basic
    AuthName "phpMyAdmin Setup"
    AuthUserFile /etc/phpmyadmin/htpasswd.setup
    </IfModule>
    Require valid-user
</Directory>

# Disallow web access to directories that don't need it
<Directory /usr/share/phpmyadmin/libraries>
    Order Deny,Allow
    Deny from All
</Directory>
<Directory /usr/share/phpmyadmin/setup/lib>
    Order Deny,Allow
    Deny from All
</Directory>

</VirtualHost>
_EOF

        #Deplacement du fichier de config phpmaydmin d'apache
        mv /etc/apache2/conf.d/phpmyadmin.conf /root/phpmyadmin.conf
        #On dit a Apache d'ecouter aussi le port 8888 en plus du 80 et 443
        PORTS="/etc/apache2/ports.conf"
        LIGNE=`awk '$0 == "Listen 80" {print NR}' ${PORTS}`
        sed -i "${LIGNE}a\Listen ${PMAPORT}" ${PORTS}
        #Activation du VHost phpmyadmin
        a2ensite phpmyadmin
        /etc/init.d/apache2 reload
    fi
}

#configurePMA() {
#    if [[ $(dpkg -l | grep phpmyadmin | awk '{print $1}') = 'ii' ]] && [[ $(dpkg -l | grep phpmyadmin | awk '{print $3}' | cut -c 1-5) = "4:3.3" ]]; then
#        PMACONFIG="/usr/share/phpmyadmin/config.inc.php"
#        if [[ -f ${PMACONFIG} ]]; then
#            if [[ ! -f ${PMACONFIG}.orig ]]; then
#                mv ${PMACONFIG} ${PMACONFIG}.orig
#                # Custom phpmyadmin configuration
#                cat > ${PMACONFIG} << EOF
#<?php
#/**
# * Please, do not edit this file. The configuration file for Debian
# * is located in the /etc/phpmyadmin directory.
# */
#
#// Load secret generated on postinst
#include('/var/lib/phpmyadmin/blowfish_secret.inc.php');
#
#// Load autoconf local config
#include('/var/lib/phpmyadmin/config.inc.php');
#
#// Load user's local config
#include('/etc/phpmyadmin/config.inc.php');
#
#// Set the default server if there is no defined
#if (!isset($cfg['Servers'])) {
#    $cfg['Servers'][1]['host'] = 'localhost';
#}
#
#// Set the default values for $cfg['Servers'] entries
#for ($i=1; (!empty($cfg['Servers'][$i]['host']) || (isset($cfg['Servers'][$i]['connect_type']) && $cfg['Servers'][$i]['connect_type'] == 'socket')); $i++) {
#    if (!isset($cfg['Servers'][$i]['auth_type'])) {
#        $cfg['Servers'][$i]['auth_type'] = 'cookie';
#    }
#    if (!isset($cfg['Servers'][$i]['host'])) {
#        $cfg['Servers'][$i]['host'] = 'localhost';
#    }
#    if (!isset($cfg['Servers'][$i]['connect_type'])) {
#        $cfg['Servers'][$i]['connect_type'] = 'tcp';
#    }
#    if (!isset($cfg['Servers'][$i]['compress'])) {
#        $cfg['Servers'][$i]['compress'] = false;
#    }
#    if (!isset($cfg['Servers'][$i]['extension'])) {
#        $cfg['Servers'][$i]['extension'] = 'mysql';
#    }
#        $cfg['Servers'][$i]['hide_db'] = '(information_schema|phpmyadmin|mysql)';
#        $cfg['ShowServerInfo'] = false;
#        $cfg['ShowPhpInfo'] = false;
#        $cfg['ShowChgPassword'] = false;
#        $cfg['ShowCreateDb'] = false;
#        $cfg['SuggestDBName'] = false;
#        $cfg['ThemeManager'] = false;
#        $cfg['blowfish_secret'] = 'IntuitivTechnologySecretPassphrase';
#        $cfg['ThemeDefault'] = 'pmahomme';
#        $cfg['SuhosinDisableWarning'] = true;
#        $cfg['PmaNoRelation_DisableWarning'] = true;
#}
#
#EOF
#                # Change phpmyadmin Theme
#                cd /tmp
#                wget "http://downloads.sourceforge.net/project/phpmyadmin/themes/pmahomme/1.0b/pmahomme-1.0b.zip"
#                [[ $(dpkg -l | grep zip) = "ii" ]] && aptitude -y -q install zip
#                unzip pmahomme-1.0b.zip && mv pmahomme /usr/share/phpmyadmin/themes/ && rm /tmp/pmahomme-1.0b.zip
#            fi
#        fi
#    fi
#
#}

mod_expires() {
    if [[ ! -L "/etc/apache2/mods-enabled/expires.load" ]]; then
        echo "Activation du module Expires..."
        a2enmod expires
    else
        echo "mod_expires is already activated on Apache2."
    fi
    if [[ ! -f "/etc/apache2/conf.d/expires" ]]; then
        cat > /etc/apache2/conf.d/expires < EOF
#        
<IfModule mod_expires.c>
  # Enable expirations.
  ExpiresActive On
 
  # Default rule
  ExpiresDefault "access plus 1 week"
 
  ExpiresByType image/gif "access plus 1 month"
  ExpiresByType image/jpeg "access plus 1 month"
  ExpiresByType image/png "access plus 1 month"
  ExpiresByType video/* "access plus 1 month"
  ExpiresByType audio/* "access plus 1 month"
  ExpiresByType application/* "access plus 1 month"
 
  ExpiresByType text/css "access plus 24 hours"
  ExpiresByType text/javascript "access plus 24 hours"
 
  <FilesMatch \.php$>
    # Do not allow PHP scripts to be cached unless they explicitly send cache
    # headers themselves. Otherwise all scripts would have to overwrite the
    # headers set by mod_expires if they want another caching behavior. This may
    # fail if an error occurs early in the bootstrap process, and it may cause
    # problems if a non-Drupal PHP file is installed in a subdirectory.
    ExpiresActive Off
  </FilesMatch>
</IfModule>
EOF
    else
        echo "mod_expires is already configured in /etc/apache2/conf.d/expires."
    fi
}


etags(){
    if [[ ! -L "/etc/apache2/mods-enabled/headers.load" ]]; then
        echo "Activation du module headers..."
        a2enmod headers
    else
        echo "module headers is already activated on Apache2."
    fi
    if [[ ! -f "/etc/apache2/conf.d/etags" ]]; then
        echo "Desactivation du Etags..."
        cat /etc/apache2/conf.d/etags < EOF
#
## Disable ETags as caching & co is handled by mod_expires & mod_deflate
## /!\ Gzipped items will not have the same etags (even if the content did not change).
## So they're useless in our configuration
#

# Remote ETag from headers - http://www.askapache.com/htaccess/apache-speed-etags.html
Header unset ETag
# Disable ETag for files
FileETag None
EOF
    else
        echo "Etags are already disabled in /etc/apache2/conf.d/etags"
    fi
}



#============#
#    Main    #
#============#


case $1 in
    security)
        echo "Securisation Apache2..."
        change_security
        echo "Securisation d'Apache2 : [OK]"
    ;;
    maintenance)
        echo "Starting Maintenance..."
        create_maintenance
        echo "Creation du VHost 0-maintenance : [OK]"
    ;;
    phpmyadmin)
        echo "Check Phpmyadmin..."
        phpmyadmin_present
        echo "Starting create phpmyadmin"
        create_phpmyadmin
        echo "Creation du VHost phpmyadmin : [OK]"
        echo "Activation du port ${PMAPORT} pour phpmyadmin : [OK]"
    ;;
    optimisation)
        echo "Optimisation d'Apache2 :"
        mod_expires
        etags
        /etc/init.d/apache2 restart
        echo "Optimisation d'Apache2 : [OK]"
    ;;
    *)
        usage && exit 1
    ;;
esac

exit 0
