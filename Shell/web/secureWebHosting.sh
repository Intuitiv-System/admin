#!/bin/bash
#
# Filename : secureWebHosting.sh
# Version  : 1.0
# Author   : mathieu androz
# Description :
#  1. Create a "secu" system user
#  2. Change user and rights on .htaccess files
#  3. Detect what CMS is used (Joomla/Drupal/Magento/Other...)
#  4. Edit VirtualHost Config File by using open_basedir to chroot
#  5. Edit VirtualHost Config File by adding exclude rules on some critical folders
#
#



## Variables
USER_SECURITY="secu"
# Apache VirtualHost folder
APACHE="/etc/apache2/sites-available/"
# Web user
WEBUSER="www-data"
# Resume file with operations done
LOGFILE="/root/securewebhosting.log"



usage() {
    echo "Answer yes or no to the question about suPHP."
}


log() {
    echo "$(date +%Y-%m-%d) :: " ${1} >> ${LOGFILE}
}


secuExist() {
    if [[ -z $(grep ${USER_SECURITY} /etc/passwd) ]] && [[-z $(grep ${USER_SECURITY} /etc/group) ]]; then
        adduser --system --no-create-home ${USER_SECURITY}
    else
        log "Can't create ${USER_SECURITY} user or ${USER_SECUIRTY} already exists."
    fi
}


# This function takes one parameter !
checkCMSType() {
    cd ${1}
    if [[ -f configuration.php && $(grep "JConfig" configuration.php | wc -l) -gt 0 ]]; then
        #echo "C'est un Joomla !"
        CMS="joomla"
    elif [[ -f sites/default/settings.php && $(grep -i "drupal" sites/default/settings.php | wc -l) -gt 0 ]]; then
        #echo "C'est un Drupal !"
        CMS="drupal"
    elif [[ -f app/etc/local.xml && $(grep "<host><\!\[CDATA" app/etc/local.xml | wc -l) -gt 0 ]]; then
        #echo "C'est un Magento !"
        CMS="magento"
    else
        CMS="other"
        log "Application custom ou non connue : " ${1}
    fi
}

# Create tmp folder for temp and sessions
createTmpFolder() {
    DOCHOME=$(dirname ${DOCROOT})
    if [[ ! -d ${DOCHOME}/tmp ]]; then
        mkdir ${DOCHOME}/tmp && chown ${WEBUSER}:${WEBUSER} ${DOCHOME}/tmp
    fi
}


secureHtaccess() {
    # change user:group + permissions of prime .htaccess in DocumentRoot of the website
    if [[ -f ${DOCROOT}/.htaccess ]]; then
        chown ${USER_SECURITY}:${USER_SECURITY} ${DOCROOT}/.htaccess
        chmod 444 ${DOCROOT}/.htaccess
    fi
}


secureJoomlaNoSuPHP() {
    cd ${APACHE}

    # Chroot virtualhost + unexecutable scripts in images folder and media/media/images folder
    sed -ie "/ErrorLog/i\ \t#Chroot VirtualHost\n\tphp_admin_value open_basedir ${DOCROOT}\n" \
    -ie "ErrorLog/i\ \tphp_admin_value upload_tmp_dir ${DOCHOME}/tmp\n" \
    -ie "ErroLog/i\ \tphp_admin_value session.save_path ${DOCHOME}/tmp\n" \
    -ie "/ErrorLog/i\ \t<Location /images/>\n\t\tOptions -Indexes\n\t\tPhp_flag engine Off\n\t\tRemoveHandler .phtml .php .php3 .php4 .php5 .php6 .phps .cgi .exe .pl .asp .aspx .shtml .shtm .fcgi .fpl .jsp .htm .wml\n\t\tAddType application/x-httpd-php-source .phtml .php .php3 .php4 .php5 .php6 .phps .cgi .exe .pl .asp .aspx .shtml .shtm .fcgi .fpl .jsp .htm .wml\n\t</Location>\n" \
    -ie "/ErrorLog/i\ \t<Location /media/media/images/>\n\t\tOptions -Indexes\n\t\tPhp_flag engine Off\n\t\tRemoveHandler .phtml .php .php3 .php4 .php5 .php6 .phps .cgi .exe .pl .asp .aspx .shtml .shtm .fcgi .fpl .jsp .htm .wml\n\t\tAddType application/x-httpd-php-source .phtml .php .php3 .php4 .php5 .php6 .phps .cgi .exe .pl .asp .aspx .shtml .shtm .fcgi .fpl .jsp .htm .wml\n\t</Location>\n" \
    -ie  "/ErrorLog/i\ \t<Location /modules/mod_fxprev/>\n\t\tdeny from all\n\t</Location>\n" ${vhost}

    # Block web access to tmp folder
    sed -i "/ErrorLog/i\ \t<Location /tmp/>\n\t\tdeny from all\n\t</Location>\n" "${vhost}"

    # Apply changes on .htaccess file
    secureHtaccess
}


secureJoomlaSuPHP() {
    cd ${APACHE}

    # Chroot virtualhost --> Impossible with suPHP
    # Disable executable scripts on images folder and media/media/images folder
    sed -ie "/ErrorLog/i\ \t<Location /images/>\n\t\tOptions -Indexes\n\t\tsuPHP_RemoveHandler .phtml .php .php3 .php4 .php5 .php6 .phps .cgi .exe .pl .asp .aspx .shtml .shtm .fcgi .fpl .jsp .htm .wml\n\t\tAddType application/x-httpd-php-source .phtml .php .php3 .php4 .php5 .php6 .phps .cgi .exe .pl .asp .aspx .shtml .shtm .fcgi .fpl .jsp .htm .wml\n\t</Location>\n" \
    -ie "/ErrorLog/i\ \t<Location /media/media/images/>\n\t\tOptions -Indexes\n\t\tPhp_flag engine Off\n\t\tRemoveHandler .phtml .php .php3 .php4 .php5 .php6 .phps .cgi .exe .pl .asp .aspx .shtml .shtm .fcgi .fpl .jsp .htm .wml\n\t\tAddType application/x-httpd-php-source .phtml .php .php3 .php4 .php5 .php6 .phps .cgi .exe .pl .asp .aspx .shtml .shtm .fcgi .fpl .jsp .htm .wml\n\t</Location>\n" \
    -ie  "/ErrorLog/i\ \t<Location /modules/mod_fxprev/>\n\t\tdeny from all\n\t</Location>\n" ${vhost}

    # Block web access to tmp folder
    sed -i "/ErrorLog/i\ \t<Location /tmp/>\n\t\tdeny from all\n\t</Location>\n" "${vhost}"

    # Apply changes on .htaccess file
    secureHtaccess
}


secureDrupalNoSuPHP() {
    cd ${APACHE}

    # Images folder on Drupal is already secured by default in www/sites/default/files
    
    # Chroot virtualhost + unexecutable scripts in media folder
    sed -ie "ErrorLog/i \t#Chroot VirtualHost\n\tphp_admin_value open_basedir ${DOCROOT}\n" \
    -ie "ErrorLog/i\ \tphp_admin_value upload_tmp_dir ${DOCHOME}/tmp\n" \
    -ie "ErroLog/i\ \tphp_admin_value session.save_path ${DOCHOME}/tmp\n" ${vhost}

    # Apply changes on .htaccess file
    secureHtaccess
}


secureDrupalSuPHP() {
    cd ${APACHE}

    # Images folder on Drupal is already secured by default in www/sites/default/files

    # Apply changes on .htaccess file
    secureHtaccess
}


secureMagentoNoSuPHP() {
    cd ${APACHE}

    # Chroot virtualhost + unexecutable scripts in media folder
    sed -ie "ErrorLog/i \t#Chroot VirtualHost\n\tphp_admin_value open_basedir ${DOCROOT}\n" \
    -ie "ErrorLog/i\ \tphp_admin_value upload_tmp_dir ${DOCHOME}/tmp\n" \
    -ie "ErroLog/i\ \tphp_admin_value session.save_path ${DOCHOME}/tmp\n" \
    -ie "ErrorLog/i\ \t<Location /media/>\n\t\tOptions -Indexes\n\t\tPhp_flag engine Off\n\t\tRemoveHandler .phtml .php .php3 .php4 .php5 .php6 .phps .cgi .exe .pl .asp .aspx .shtml .shtm .fcgi .fpl .jsp .htm .wml\n\t\tAddType application/x-httpd-php-source .phtml .php .php3 .php4 .php5 .php6 .phps .cgi .exe .pl .asp .aspx .shtml .shtm .fcgi .fpl .jsp .htm .wml\n\t</Location>\n" ${vhost}

    # Apply changes on .htaccess file
    secureHtaccess
}


secureMagentoSuPHP() {
    cd ${APACHE}

    sed -ie "ErrorLog/i\ \t<Location /media/>\n\t\tOptions -Indexes\n\t\tsuPHP_RemoveHandler .phtml .php .php3 .php4 .php5 .php6 .phps .cgi .exe .pl .asp .aspx .shtml .shtm .fcgi .fpl .jsp .htm .wml\n\t\tAddType application/x-httpd-php-source .phtml .php .php3 .php4 .php5 .php6 .phps .cgi .exe .pl .asp .aspx .shtml .shtm .fcgi .fpl .jsp .htm .wml\n\t</Location>\n" ${vhost}

    # Apply changes on .htaccess file
    secureHtaccess
}






####################
## Main
####################

if [[ -z ${USER_SECURITY} ]] || [[ -z ${APACHE} ]] || [[ -z ${WEBUSER} ]] || [[ -z ${LOGFILE} ]]; then
    echo "Please fix variables in script before execute it !"
    exit 2
fi

clear

secuExist

read -p "Is suPHP configured and used on this server (yes/no) : " SUPHPUSED

case ${SUPHP} in
    yes|y|oui|o|Y|O)
        for vhost in /etc/apache2/sites-available/*
        do
            DOCROOT=$(grep "DocumentRoot" ${vhost} | awk '{print $2}')
            checkCMSType ${DOCROOT}
            createTmpFolder
            if [[ ${CMS} = "joomla" ]]; then
                secureJoomlaSuPHP

            elif [[ ${CMS} = "drupal" ]]; then
                secureDrupalSuPHP

            elif [[ ${CMS} = "magento" ]]; then
                secureMagentoSuPHP

            else
                log "Application custom ou non connue : " ${1}
            fi
        done
    ;;
    no|n|non|N)
        for vhost in /etc/apache2/sites-available/*
        do
            DOCROOT=$(grep "DocumentRoot" ${vhost} | awk '{print $2}')
            checkCMSType ${DOCROOT}
            createTmpFolder
            if [[ ${CMS} = "joomla" ]]; then
                secureJoomlaNoSuPHP
            
            elif [[ ${CMS} = "drupal" ]]; then
                secureDrupalNoSuPHP
            
            elif [[ ${CMS} = "magento" ]]; then
                secureMagentoNoSuPHP
            
            else
                log "Application custom ou non connue : " ${1}
            fi
        done
    ;;
    *)
        usage && exit 1 
    ;;
esac

echo "A log file is available here : ${LOGFILE}" 
exit 0

