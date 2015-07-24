#!/bin/bash

#---------------------------------------------------------------#
# Script de backup de site
# Date:		3 aout 2011
# Author : Mathieu Androz
# Conrtib : Olivier Renard
#
# Crontab / tous les soirs a 23h32
# Suppression du backup ftp datant de plus de ${DATE_RENTENSION} jours
# crontab -e
# 32 23 * * * /home/backup/${SITE_NAME}_backup.sh
#---------------------------------------------------------------#

#---------------------------------------------------------------#
# !!! IMPORTANT - PREREQUIS !!!
#       - avoir installe ncftp
#       - avoir installe zip
#---------------------------------------------------------------#

# Variables
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

#--- Parametres a editer ---#

## FTP
#########################
# Utilisateur ftp
FTPUSER=""
# Mot de passe ftp
FTPPWD=""
# Hote ftp
FTPHOST=""
# "Home" du backup
FTP_REMOTE_DIR=""
# Chemin ftp de backup du site
FTPSITE="${FTP_REMOTE_DIR}/site"
# Chemin ftp de backup de la base mysql
FTPMYSQL="${FTP_REMOTE_DIR}/mysql"

## Activation des backups
#########################
# 0 = pas actif
# 1 = actif
# Activation du backup site
ACTIVATE_SITE="1"
# Activation du backup msqyl
ACTIVATE_MYSQL="1"

## Infos locales
#########################
# Nom du site, n'influence que le nom des archives
SITE_NAME=""
# Chemin local de backup
BACKUP_DIR=""
# Chemin local du site ou de l'application
BACKUPED_DIR=""
# Utilisateur mysql
MYSQLUSER=""
# Mot de passe mysql
MYSQLPWD=""
# Nom de la base de donnees mysql
MYSQLDBNAME=""
# IP de la machine locale
IP=""
# Type d'application a sauvegarder
# Si c'est un magento, il faut activer en mettant 1
# car la commande mysqldump est diffÃ©rente !
SITE_TYPE="1"

DATE_RENTENSION="8"

## Infos personnelles
########################
# Adresse email pour envoi des infos de backup
EMAIL=""


#--- Parametres fixes ---#

DATE=$(date +"%Y%m%d")
DATE_RETENSION=$(date --date="${FTP_RETENSION} days ago" +"%Y%m%d")
####### MAIS POURQUOI TANT DE HAINE #######
## Date
#DATE=`date +%Y%m%d`
## date du jour au format seconde depuis le 1/1/1970
#DATEENS=`date +%s`
## Date - 1 jour au format seconde depuis le 1/1/1970
#JOUR1S=`expr $DATEENS - 86400`
## Date - 1 jour au format %Y%m%d
#JOUR1=`date --date=@$JOUR1S +%Y%m%d`
## Date - 2 jour au format seconde depuis le 1/1/1970
#JOUR2S=`expr $DATEENS - 172800`
## Date - 2 jours au format %Y%m%d
#JOUR2=`date --date=@$JOUR2S +%Y%m%d`
## Quel jour sommes-nous ?
#JOUR=`date | awk '{print $1}'`
#JOUR8S=`expr $DATEENS - 691200`
##JOUR8=`date --date=@$JOUR8S +%Y%m%d`
#JOUR7S=`expr $DATEENS - 604800`
#JOUR7=`date --date=@$JOUR7S +%Y%m%d`
#JOUR6S=`expr $DATEENS - 518400`
#JOUR6=`date --date=@$JOUR6S +%Y%m%d`
#JOUR5S=`expr $DATEENS - 432000`
#JOUR5=`date --date=@$JOUR5S +%Y%m%d`
#JOUR4S=`expr $DATEENS - 345600`
#JOUR4=`date --date=@$JOUR4S +%Y%m%d`
#JOUR3S=`expr $DATEENS - 259200`
#JOUR3=`date --date=@$JOUR3S +%Y%m%d`

BACKUPED_SIZE=$(du -sh $BACKUPED_DIR | awk '{print $2 " : " $1}')
OCCUPATION_LOCALE=`df -h /home/ | sed -e '1d' | awk '{print "Espace disponible : " $4 "/" $2 " ........ % occupation : " $5}'`

#FTP_AVANT=`sed '1,22d' /home/backup/espace.txt | sed '2,3d' | awk '{print "ESPACE FTP = " $8,$9,$10,$11,$12,$13,$14,$15,$16,$17}'`


#--------------------------------------------------------------------------------------------
# Fonctions
#--------------------------------------------------------------------------------------------

test_error() {
    if [ "$?" != 0 ] ; then
        case $CODE in
            "01")
                PROBLEME="probleme au niveau 01 : creation du repertoire de backup local du site"
            ;;
            "02")
                PROBLEME="probleme au niveau 02 : copie locale du site dans /home/backup"
            ;;
            "03")
                PROBLEME="probleme au niveau 03 : compression du site"
            ;;
            "04")
                PROBLEME="probleme au niveau 04 : suppression locale et deplacement du tar.gz du site"
            ;;
            "05")
                PROBLEME="probleme au niveau 05 : envoi du backup du site par ftp"
            ;;
            "06")
                PROBLEME="probleme au niveau 06 : suppression du backup du site datant de plus de 7 jours"
            ;;
            "07")
                PROBLEME="probleme au niveau 07 : dump mysql de la base de donnees"
            ;;
            "08")
                PROBLEME="probleme au niveau 08 : compression de la base de donnees"
            ;;
            "09")
                PROBLEME="probleme au niveau 09 : suppression locale de la base de donnees"
            ;;
            "10")
                PROBLEME="probleme au niveau 10 : envoi du backup de la base de donnees par ftp"
            ;;
            "11")
                PROBLEME="probleme au niveau 11 : suppression du backup de la base de donnees datant de plus de 7 jours"
            ;;
            *)
                exit 2
            ;;
        esac
        echo -e "$PROBLEME pour $SITE_NAME sur $IP" \
        "\n\nPour info :\n\nOccupation disque :\n\t$OCCUPATION_LOCALE" \
        "\n\nTaille du rÃ©pertoire a backuper :\n\t$BACKUPED_SIZE" | \
        mail -s "[WARNING] Backup Site $SITE_NAME" $EMAIL
        exit 1
    fi
}

get_soft_status() {
    SOFT=${1}
    echo $(dpkg -l | grep "^ii[[:blank:]]*${SOFT}")
}

check_install() {
    # On check si ncftp et <del>zip</del> sont installes.
    # Si ils ne le sont pas, on les installe.
    NCFTP_OK=$(get_soft_status "ncftp")
    [[ -z "${NCFTP_OK}" ]] && INSTALL_PKGS="ncftp"
    
    ## Plus besoin de zip, on passe a tar!
    #ZIP_OK=$(get_soft_status "zip")
    #if [[ -z "ZIP_OK" ]] ; then
    #    INSTALL_PKGS="${INSTALL_PKGS} zip"
    #fi
    
    
    [[ -n ${INSTALL_PKGS} ]] && aptitude install -y ${INSTALL_PKGS}
}

open_ftp() {
    ncftp -u ${FTP_USER} -p ${FTP_PWD} ${FTP_HOST}
}

list_ftp() {
    FILE=${1}
    ncftpls -l -u ${FTP_USER} -p ${FTP_PWD} ftp://${FTP_HOST}/${FILE}
}

check_espace_ftp() {
    ncftp ftp://"$FTPUSER":"$FTPPWD"@"$FTPHOST" > /home/backup/espace.txt
    sed '1,22d' /home/backup/espace.txt | sed '2,3d' | awk '{print "ESPACE FTP = " $8,$9,$10,$11,$12,$13,$14,$15,$16,$17}'
}

copy_folder() {
    # Fonction qui copie le dossier
    # a sauvegarder dans /home/backup/
    if [ ! -d $BACKUP_DIR/site ] ; then
        CODE="01"
        mkdir -p $BACKUP_DIR/site
        test_error
    fi
    CODE="02"
    cp -R $BACKUPED_DIR $BACKUP_DIR/site
    test_error
}

compress_folder() {
    # Compression du dossier copie
    cd $BACKUP_DIR
    CODE="03"
    tar czf "$SITE_NAME"_"$DATE".tar.gz site/
    test_error
    CODE="04"
    rm -rf ./site/*
    mv ./"$SITE_NAME"_"$DATE".tar.gz ./site/
    test_error
}

envoi_site_ftp() {
    # Envoi par ftp l archive du site
    CODE="05"
    ncftpput -u $FTPUSER -p $FTPPWD $FTPHOST $FTPSITE "$BACKUP_DIR"/site/"$SITE_NAME"_"$DATE".tar.gz
    test_error
    rm "$BACKUP_DIR"/site/"$SITE_NAME"_"$DATE".tar.gz
}

suppression_old_site_ftp() {
    # Suppression du backup datant de ${FTP_RETENSION} jours
    CODE="06"
    
    ### Avant (swear)
#    OLD_SITE=$(list_ftp "${FTPSITE}/${SITE_NAME}_${JOUR8}.tar.gz")
    #ncftp -u $FTPUSER -p $FTPPWD $FTPHOST<<_EOF_
#cd $FTPSITE
#rm "$SITE_NAME"_"$JOUR8".tar.gz
#quit
#_EOF_

    ### Après (cool)

    local LIST_FTP_8DAYS=$(list_ftp "${FTPSITE}/${SITE_NAME}_${DATE_RETENSION}.tar.gz")
    if [[ -n ${LIST_FTP_8DAYS} ]]; then
        open_ftp << EOF
cd ${FTPSITE}
rm ${SITE_NAME}_${DATE_RETENSION}.tar.gz
bye
EOF
    fi

    test_error
    CODE="Youpi"
}

backup_site_success() {
    # Si tout s'est bien passe,
    # On envoie un mail pour le dire !
    echo -e "La sauvegarde du site $SITE_NAME sur $IP est [OK]" \
    "\n\nPour info :\n\nOccupation disque :\n\t$OCCUPATION_LOCALE" \
    "\n\nTaille du rÃ©pertoire a backuper :\n\t$BACKUPED_SIZE" | \
    mail -s "[OK] Backup Site $SITE_NAME" $EMAIL
}

dump_mysql() {
    # Commande de dump Mysql
    CODE="07"
    if [ "$SITE_TYPE" -eq 1 ]; then
        # Dump d'application Magento
        mysqldump -u $MYSQLUSER -p""$MYSQLPWD"" -h localhost --single-transaction $MYSQLDBNAME > "$BACKUP_DIR"/"$SITE_NAME"_DB.sql
    else
        # Dump classique
        mysqldump -u $MYSQLUSER -p""$MYSQLPWD"" -h localhost $MYSQLDBNAME > "$BACKUP_DIR"/"$SITE_NAME"_DB.sql
    fi
    test_error
}

compress_mysql() {
    # Compression du dump et suppression
    CODE="08"
    cd $BACKUP_DIR
    tar czf "$SITE_NAME"_DB_"$DATE".tar.gz "$SITE_NAME"_DB.sql
    test_error
    CODE="09"
    rm "$SITE_NAME"_DB.sql
    test_error
}

envoi_mysql_ftp() {
    # Envoi par ftp l archive de la base de donnees
    CODE="10"
    ncftpput -u $FTPUSER -p $FTPPWD $FTPHOST $FTPMYSQL "$BACKUP_DIR"/"$SITE_NAME"_DB_"$DATE".tar.gz
    test_error
    rm "$BACKUP_DIR"/"$SITE_NAME"_DB_"$DATE".tar.gz
}

suppression_old_mysql_ftp() {
	# Suppression du backup datant de ${DATE_RETENSION jours
	CODE="11"

  ### Avant (swear)
	#ncftp -u $FTPUSER -p $FTPPWD $FTPHOST<<_EOF_
#cd $FTPMYSQL
#rm "$SITE_NAME"DB_"$JOUR8".zip
#quit
#_EOF_

    ### Après (cool)
    local LIST_FTP_8DAYS=$(list_ftp "${FTPMYSQL}/${SITE_NAME}_DB_${DATE_RETENSION}.tar.gz")
    if [[ -n ${LIST_FTP_8DAYS} ]]; then
        open_ftp << EOF
cd ${FTPMYSQL}
rm ${SITE_NAME}_DB_${DATE_RETENSION}.tar.gz
bye
EOF
    fi
    test_error
    CODE="Youpi"
}

backup_mysql_success() {
    # Si tout s'est bien passe,
    # On envoie un mail pour le dire !
    echo -e "La sauvegarde de la base de donnees de $SITE_NAME sur $IP est [OK]" \
    "\n\nPour info :\n\nOccupation disque :\n\t$OCCUPATION_LOCALE" \
    "\n\nTaille du rÃ©pertoire a backuper :\n\t$BACKUPED_SIZE" | \
    mail -s "[OK] Backup Base de $SITE_NAME" $EMAIL
}

#-----------------------------------------------------------------------------------
# MAIN
#-----------------------------------------------------------------------------------

# Verification de la presence de ncftp et de zip
check_install

# Partie sauvegarde du site ou de l'application
if [ "$ACTIVATE_SITE" -eq 1 ] ; then
    copy_folder
    compress_folder
    envoi_site_ftp
    suppression_old_site_ftp
    backup_site_success
fi

# Partie sauvegarde de la base de donnees
if [ "$ACTIVATE_MYSQL" -eq 1 ] ;then
    dump_mysql
    compress_mysql
    envoi_mysql_ftp
    suppression_old_mysql_ftp
    backup_mysql_success
fi

exit 0