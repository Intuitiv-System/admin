#!/bin/bash -x

#############################################################
#
# Script de customisation et securisation de Phpmyadmin
#
#############################################################


read -p "Entrer le chemin complet de Phpmyadmin : " PMA

#cd /tmp
#wget "https://downloads.sourceforge.net/project/phpmyadmin/themes/pmahomme/1.0b/pmahomme-1.0b.zip"


#if [[ $(dpkg --list | grep zip | awk '{print $1}') != "ii" ]]; then
#	aptitude -y install zip > /dev/null
#fi

#unzip pmahomme-1.0b.zip

#mv /tmp/pmahomme ${PMA}/www/themes/


# On check la version de PhpMyAdmin
if [[ $(dpkg --list | grep phpmyadmin | awk -F":" '{print $2}' | cut -c 1-6) = "3.4.11" ]]; then
	if [[ ! -f ${PMA}/www/config.inc.php ]]; then
		cp ${PMA}/www/config.sample.inc.php ${PMA}/www/config.inc.php
		sed -i 's/^\(.*blowfish_secret\)/\/\/\1/g' ${PMA}/www/config.inc.php
		sed -i '/?>/d' ${PMA}/www/config.inc.php
# On rajoute les parametres custom
cat <<- EOF >> ${PMA}/www/config.inc.php
	// Intuitiv
	\$cfg['blowfish_secret'] = 'We can secure this installation';
	\$cfg['Servers'][\$i]['hide_db'] = '^(information_schema|performance_schema|mysql|phpmyadmin)$';
	\$cfg['ShowStats'] = false;
	\$cfg['ShowPhpInfo'] = false;
	\$cfg['ShowServerInfo'] = false;
	\$cfg['ShowChgPassword'] = false;
	\$cfg['ShowCreateDb'] = false;
	\$cfg['SuggestDBName'] = false;
	\$cfg['Export']['compression'] = 'zip';
	\$cfg['ThemeDefault'] = 'pmahomme';
	\$cfg['ThemeManager'] = false;
	\$cfg['MySQLManualType'] = 'none';
	\$cfg['TitleTable'] = '@DATABASE@ / @TABLE@ | @PHPMYADMIN@';
	\$cfg['TitleDatabase'] = '@DATABASE@ | @PHPMYADMIN@';
	\$cfg['TitleServer'] = '@PHPMYADMIN@';
	\$cfg['TitleDefault'] = '@PHPMYADMIN@';
	\$cfg['VersionCheck'] = false;
?>
EOF
	fi

elif [[ $(dpkg --list | grep phpmyadmin | awk -F":" '{print $2}' | cut -c 1-6) = "3.3.7-" ]]; then
	# On securise PHPmyadmin
	if [[ ! -f ${PMA}/www/config.inc.php.orig ]]; then
		cp ${PMA}/www/config.inc.php ${PMA}/www/config.inc.php.orig
		# On supprime les dernieres lignes vides
		sed -i '${/^$/d}' ${PMA}/www/config.inc.php
		#On supprime la derniere ligne (l'accollade fermante)
		sed -i '${/^\}/d}' ${PMA}/www/config.inc.php
# On rajoute les parametres custom
cat >> ${PMA}/www/config.inc.php << EOF
// Intuitiv
\$cfg['blowfish_secret'] = 'We can secure this installation';
\$cfg['Servers'][\$i]['hide_db'] = '^(information_schema|performance_schema|mysql|phpmyadmin)$';
\$cfg['ShowStats'] = false;
\$cfg['ShowPhpInfo'] = false;
\$cfg['ShowServerInfo'] = false;
\$cfg['ShowChgPassword'] = false;
\$cfg['ShowCreateDb'] = false;
\$cfg['SuggestDBName'] = false;
\$cfg['Export']['compression'] = 'zip';
\$cfg['ThemeDefault'] = 'pmahomme';
\$cfg['ThemeManager'] = false;
\$cfg['MySQLManualType'] = 'none';
\$cfg['TitleTable'] = '@DATABASE@ / @TABLE@ | @PHPMYADMIN@';
\$cfg['TitleDatabase'] = '@DATABASE@ | @PHPMYADMIN@';
\$cfg['TitleServer'] = '@PHPMYADMIN@';
\$cfg['TitleDefault'] = '@PHPMYADMIN@';
\$cfg['VersionCheck'] = false;
}
EOF
	fi
else
	echo "Version de PhpMyAdmin non reconnue."
	exit 2
fi


# Il faut editer le fichier main.php
echo ""
echo ""
echo "------------------------------------------------------------------------------------------------------"
echo "-- Il faut enfin editer le fichier $PMA/www/main.php :"
echo "-- Supprimer l'accolade fermante aux environs de la ligne 229"
echo "-- et la placer au debut du nouveau depart de balise PHP, aux alentours de la ligne 254"
echo "------------------------------------------------------------------------------------------------------"


#rm -rf /tmp/pmahomme*

exit 0
