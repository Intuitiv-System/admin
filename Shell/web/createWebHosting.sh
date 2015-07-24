#!/bin/bash
#
# Filename : createWebHosting.sh
# Version  : 1.3
# Author   : Mathieu ANDROZ
# Contrib  : Olivier RENARD
#
# Description :
#  . check and create user adduser -d /home/<PROJECT> -m <PROJECT>
#  . ask to add <PROJECT> to 'nosu' group (or not)
#  . create web directories /home/<PROJECT>/www, /home/<PROJECT>/tmp and /home/<PROJECT>/logs 
#  . create site-avaiable virtual host with <PROJECT> servername
#  . ask to update ServerName parameters for new virtual host (or not)
#  . run the site a2ensite <PROJECT>
#  . reload the apache service apache reload
#  . crate mysql database for the project with user <PROJECT> db name <PROJECT> and random password
#  . generate ssh public private keys without prompt: sudo -u <PROJECT> -H ssh-keygen -f /home/<PROJECT>/.ssh/id_rsa -t rsa -N ''
#  . add ssh pub key to gitlab as deploy key: it gonna be mysql query 
#  . git clone git@projects.intuitiv.bg:<PROJECT>.git into /home/<PROJECT>/www directory
#  . Log rotation
#  . A file with informations about the project is created in the homedir, called project_info
#  . An email is sent to somebody with all informations (check function sendInfo to change email address)
### 1.2
#  . Adding mysql_cmd function to execute more readable sql requests
#  . Adding generate_password function which accept as an optionnal param the length of the password. It aims to ... generate a password ... :D
#  . Adding createFtpUser function to create a ftp account for the project. 
### 1.3
#  . Ask for creation of DB and FTP


usage() {
    ::
}

createLogrotate() {
    LOGFILE="/var/log/admin/createWebHosting.log"
    LOGROTATEDIR="/etc/logrotate.d"
    LOGROTATEFILE="createWebHosting"
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
                \n\tcreate 640 root root \
                \n}" > ${LOGROTATEDIR}/${LOGROTATEFILE}
        fi
    fi
}

installPackage() {
    if [[ $(dpkg -l | awk '{print $1" "$2}' | grep " ${1}"$) != "ii ${1}" ]]; then
        log "Installation du package ${1}..."
        apt-get -y -q install "${1}" &> /dev/null
    else
        log "Package ${1} already installed on your system."
    fi
}

log() {
    LOGFILE="/var/log/admin/createWebHosting.log"
    if [[ ! -d $(dirname ${LOGFILE}) ]]; then
        mkdir $(dirname ${LOGFILE})
    fi
    echo "$(date +%Y%m%d-%H:%M:%s) :: " ${1} | tee -a ${LOGFILE}
}

checkDistrib()
{
    # On what linux distribution you are
    DIR=$(pwd)
    FILE=$(basename $0)
    if [[ -f "/etc/debian_issue" ]]; then
        DISTRIB=$(cat /etc/debian_issue | cut -c 1)
        DIGIT="^[:digit].$]"
        ALPHA="^[:alpha].$]"
        if [[ ${DISTRIB} =~ ${DIGIT} ]]; then
            if [[ $(whoami) != "root" ]]; then 
                log "Login as root and execute this command : ${DIR}/${FILE}" && su -
                exit 0
            fi
        elif [[ ${DISTRIB} =~ ${ALPHA} ]]; then
            if [[ $(whoami) != "root" ]]; then
                log "Login as root and execute this command : ${DIR}/${FILE}" && sudo su -
                exit 0
            fi
        else
            log "You're running on $(cat /etc/issue | head -n 1).\nThis script is adapted for Debian-Like OS.\nBye"
            exit 1
        fi
        DISTRIB_OS="0"
    else
        log "You're not running on a Debian-Like OS."
        DISTRIB_OS="1"
    fi
}

# UserExist()
# {
    # USER=$(awk -F":" '{print $1}' /etc/passwd | egrep -i "^${PROJECT}$")
    # if [[ -n $USER ]]; then
        # log "A user ${PROJECT} already exists...\nexit"
        # exit 1
    # fi
# }


createUser()
{
    while true; do
        read -p "Enter the project's name : " PROJECT
        PROJECT=$(echo ${PROJECT} | sed "s/-//g")
        if [[ -n $(awk -F":" '{print $1}' /etc/passwd | egrep -i "^${PROJECT}$") ]]; then
            log "A user '${PROJECT}' already exists, please rename it!"
        else
            useradd -d /home/"${PROJECT}" -m "${PROJECT}"
            log "Creation of '${PROJECT}' user : [OK]"
            break
        fi
    done
}

askNosuGroup()
{
    read -p "Add '${PROJECT}' to 'nosu' group [Y/n] : " CONFIRM_NOSU
    CONFIRM_NOSU=${CONFIRM_NOSU:-Y}
    case ${CONFIRM_NOSU} in
        Y|y|O|o*) # Check if nosu group exists. If not, create it
                  [[ -z $(cut -d":" -f1 /etc/group | egrep "^nosu$") ]] && groupadd nosu
                  # Add ${PROJECT} in nosu group
                  usermod -G nosu ${PROJECT}
                  log "Adding '${PROJECT}' to 'nosu' group : [OK]";;
        *) log "Adding '${PROJECT}' to 'nosu' group : [CANCEL]";;
    esac
}

mysql_cmd() {
    mysql -u root -p"${MYSQLPWD}" -B -N -L -e "${1}"
}

generate_password() {
    [[ -z ${1} ]] && PASS_LEN="10" || PASS_LEN=${1}
    echo $(cat /dev/urandom|tr -dc "a-zA-Z0-9\$\?"|fold -w ${PASS_LEN}|head -1)
}

createHostFolders()
{
    if [[ -d /home/${PROJECT} ]]; then
        cd /home/"${PROJECT}"
        mkdir www logs tmp config 2> /dev/null
        chown -R www-data:www-data www logs tmp config
        log "Rights fixed for www & logs folders : [OK]"
    else
        log "Folders www & logs can't be created in /home/${PROJECT}"
    fi
}

createApacheVhost()
{
    APACHEVHOSTFOLDER="/etc/apache2/sites-available"
    if [[ ! -f ${APACHEVHOSTFOLDER}/${PROJECT} ]]; then
cat >> ${APACHEVHOSTFOLDER}/${PROJECT} << EOF
<VirtualHost *:80>
    ServerAdmin admin@server.com

    ServerName ${PROJECT}
    #ServerAlias

    DocumentRoot /home/${PROJECT}/www/
    <Directory /home/${PROJECT}/www/>
        Options -Indexes FollowSymLinks MultiViews
        AllowOverride All
        Order allow,deny
        allow from all
    </Directory>

    Redirect 404 /favicon.ico
    <Location /favicon.ico>
        ErrorDocument 404 "No favicon"
    </Location>

    #ScriptAlias /cgi-bin/ /home/${PROJECT}/www/cgi-bin/
    #<Directory "/home/${PROJECT}/www/cgi-bin">
    #    AllowOverride None
    #    Options +ExecCGI -MultiViews +SymLinksIfOwnerMatch
    #    AddHandler cgi-script .cgi
    #    Order allow,deny
    #    Allow from all
    #</Directory>

    #Chroot VirtualHost
    php_admin_value open_basedir /home/${PROJECT}/www:/home/${PROJECT}/tmp
    php_admin_value upload_tmp_dir /home/${PROJECT}/tmp
    php_admin_value session.save_path /home/${PROJECT}/tmp

    # Path of private php.ini
    #PHPINIDir /home/${PROJECT}/config

    ErrorLog /home/${PROJECT}/logs/error.log
    LogLevel warn
    CustomLog /home/${PROJECT}/logs/access.log combined
    ServerSignature Off
</VirtualHost>

EOF
    log "Creation of '${PROJECT}' virtualhost : [OK]"
    fi

    a2ensite ${PROJECT} > /dev/null && log "Activation of '${PROJECT}' virtualhost : [OK]"
    service apache2 reload > /dev/null && log "Reload Apache2 service : [OK]"
}

editApacheVhostServername()
{
    #while true
    #do
    read -p "Do you want to edit the 'Servername' parameter in '${PROJECT}' virtualhost [Y/n] : " CONFIRM_EDIT
    CONFIRM_EDIT=${CONFIRM_EDIT:-Y}
    case ${CONFIRM_EDIT} in
        Y|y*)
            read -p "Enter the domain name suffix attached to that virtualhost [itdev.lan] : " VHOST_DNS_SUFFIX
            VHOST_DNS_SUFFIX=${VHOST_DNS_SUFFIX:-"itdev.lan"}
            sed -i "s/\(ServerName.*\)/\1.${VHOST_DNS_SUFFIX}/g" ${APACHEVHOSTFOLDER}/${PROJECT}
            a2dissite ${PROJECT} > /dev/null && service apache2 reload > /dev/null
            mv ${APACHEVHOSTFOLDER}/${PROJECT} ${APACHEVHOSTFOLDER}/${PROJECT}.$(echo ${VHOST_DNS_SUFFIX} | cut -d"." -f1)
            log "Update ServerName parameter for '${PROJECT}' : [OK]"
            a2ensite ${PROJECT}.$(echo ${VHOST_DNS_SUFFIX} | cut -d"." -f1) > /dev/null && service apache2 reload > /dev/null
            ;;
        *)  log "Update ServerName parameter for '${PROJECT}' : [CANCEL]"
            ;;
    esac
    #done
}

logRotate()
{
    # Add /home/${PROJECT}/logs/*.log to /etc/logrotate.d/apache2 file
    if [[ ! -f /etc/logrotate.d/apache2.${PROJECT} ]]; then
        #if [[ $(grep "/home/${PROJECT}/logs/*/log" /etc/logrotate.d/apache2) == "" ]]; then
            cat > /etc/logrotate.d/apache2.${PROJECT} << EOF
#
/home/${PROJECT}/logs/*.log {
        weekly
        missingok
        rotate 52
        compress
        delaycompress
        notifempty
        create 640 root adm
        sharedscripts
        postrotate
                /etc/init.d/apache2 reload > /dev/null
        endscript
}

EOF
        #fi
    else
        log "[ Warning] Log rotate file called apache2.${PROJECT} already exists. Not created."
    fi
}

testMysqlConnection() {
    while true; do
        read -s -p "Enter MySQL root password : " MYSQLPWD
        MYSQLCMD="/usr/bin/mysql -u root -p${MYSQLPWD} -B -N -L"
        MYSQLTEST=$(${MYSQLCMD} -e "STATUS ;" 2> /dev/null)
        MYSQLTESTERROR=$(echo "${MYSQLTEST}" | head -n 1 | awk '{print $1}')
        if [[ -z ${MYSQLTESTERROR} ]] || [[ ${MYSQLTESTERROR} == "ERROR" ]]; then
            echo -e "Error while connect to MySQL server."
            echo -e "Please check if you're using the good password..."
        else
            break
        fi
    done
}

createDB()
{
    testMysqlConnection
    echo ""
    log "Creation of MySQL '${PROJECT}' database..."
    DBEXIST=$(mysql -u root -p"${MYSQLPWD}" -B -N -e "SHOW DATABASES LIKE '${PROJECT}' ;" | wc -l)
    if [[ ${DBEXIST} -gt 0 ]]; then
        log "A MySQL database called '${PROJECT}' already exists"
    else
        mysql -u root -p"${MYSQLPWD}" -e "CREATE DATABASE ${PROJECT} character set utf8 ;"
        log "...done"
    fi
    log "Creation of MySQL '${PROJECT}' user..."
    USEREXIST=$(mysql -u root -p"${MYSQLPWD}" -B -N -e "use mysql; SELECT User FROM user;" | grep ${PROJECT} | wc -l)
    if [[ ${USEREXIST} -gt 0 ]]; then
        log "A MySQL user called '${PROJECT}' already exists"
    else
        #PASS=$(cat /dev/urandom|tr -dc "a-zA-Z0-9\$\?"|fold -w 10|head -1)
        
        MYSQL_PROJECT_PASS=$(generate_password)
        
        mysql -u root -p"${MYSQLPWD}" -e "CREATE USER '${PROJECT}'@'localhost' identified by '${MYSQL_PROJECT_PASS}' ;"
        log "...done"
        log "Fix MySQL privileges..."
        mysql -u root -p"${MYSQLPWD}" -e "GRANT ALL PRIVILEGES on ${PROJECT}.* to '${PROJECT}'@'localhost' ;"
        log "...done"
    fi
}

generateSshKeys()
{
    if [[ ! -f /home/${PROJECT}/.ssh/id_rsa.pub ]]; then
        su -c "ssh-keygen -f /home/${PROJECT}/.ssh/id_rsa -t rsa -N \"\"" ${PROJECT} > /dev/null
        log "Generation of SSH public/private keys for '${PROJECT}' : [OK]"
    else
        log -e "SSH public/private keys were already generated for the user ${PROJECT}"
    fi
}

gitkeyPast()
{
    # This like can help you : https://gist.github.com/lanwin/1722391
    ::
}

gitClone()
{
    GITURL=""
    GITSYSTEMUSER=""
    if [[ -n ${GITURL} ]] || [[ -n ${GITSYSTEMUSER} ]]; then
        cd /home/${PROJECT}/www
        su -c "git clone ${GITSYSTEMUSER}@${GITURL}:${PROJECT}.git" ${PROJECT}
        if [[ $? != "0" ]]; then
            log "A problem happened during GIT cloning !"
        else
            log "Clone GIT project : [OK]"
        fi
    else
        log "No GITURL or GITSYSTEMUSER is set."
    fi
}

createFtpUser() {
    FTP_SQL_FILE="/etc/pure-ftpd/db/mysql.conf"
    FTP_DB=$(cat ${FTP_SQL_FILE} | grep -E "^MYSQLDatabase" | awk '{print $2}')
    
    if [[ -f "${FTP_SQL_FILE}" ]] && [[ -n "${FTP_DB}" ]]; then
        read -p "Create FTP user ${PROJECT} [Y/n] : " CREATE_FTP_USER_CONF
        CREATE_FTP_USER=${CREATE_FTP_USER_CONF:-Y}
        case ${CREATE_FTP_USER} in
            Y|y|O|o*)
                log "Generating password for FTP user"
                FTP_PASS=$(generate_password "12")
                #FTP_PASS_MD5=$(echo ${FTP_PASS} | md5sum | awk '{print $1}')
                read -p "Default FTP home [/home/${PROJECT}/www] : " FTP_HOME_DEF
                FTP_HOME=${FTP_HOME_DEF:-"/home/${PROJECT}/www"}
                ## Request to add new FTP user in Pure-FTPD database
                SQL_REQ="USE ${FTP_DB}; INSERT INTO users VALUES ('${PROJECT}_ftp', MD5( '${FTP_PASS}' ), '33', '33', '${FTP_HOME}');"
                mysql_cmd "${SQL_REQ}"
                log "FTP user account creation : [OK]"
            ;;
            *) log "Creation of ${PROJECT} FTP user skipped"
            ;;
        esac
    else
        log "No MySQL configuration or no database found for Pure-ftp server, abording..."
    fi
}

resumeInfo()
{
    echo -e "\n------------------------------------------------
           Resume Informations                  
------------------------------------------------\n
Project's Name   :   ${PROJECT}
Project's Home   :   /home/${PROJECT}
MySQL User       :   ${PROJECT}
MySQL Password   :   ${MYSQL_PROJECT_PASS}
MySQL DBName     :   ${PROJECT}
FTP User         :   ${PROJECT}_ftp
FTP Password     :   ${FTP_PASS}" | tee /home/${PROJECT}/project_info
    chmod 600 /home/${PROJECT}/project_info
}

sendInfo()
{
    DEST=""
    while [[ -z ${DEST} ]]
    do
        read -p "Enter a valid email address : " DEST
    done
    cat /home/${PROJECT}/project_info | mail -s "Resume creation of ${PROJECT} project" ${DEST}
}


#--------------------------------#
#              Main              #
#--------------------------------#


PROJECT=""

createLogrotate

while getopts ":ha:" option
do
    case "$option" in

checkDistrib
createUser
askNosuGroup
createHostFolders
createApacheVhost
editApacheVhostServername
logRotate
read -p "Do you want to create MySQL Database ? [Y/n] : " CONFIRM_DB
CONFIRM_DB=${CONFIRM_DB:-Y}
case ${CONFIRM_DB} in
    Y|y|O|o*) createDB ;;
    *) log "No MySQL Database created : [CANCEL]" ;;
esac

read -p "Do you want to create a FTP user ? [Y/n] : " CONFIRM_FTP
CONFIRM_FTP=${CONFIRM_FTP:-Y}
case ${CONFIRM_FTP} in
    Y|y|O|o*) createFtpUser ;;
    *) log "No FTP user created : [CANCEL]";;
esac

#generateSshKeys
#gitkeyPast
#gitClone
resumeInfo
sendInfo


        :)  
            echo "Option ${OPTARG} requieres an argument. Aborted..." && exit 1
        ;;
        \?) 
            echo "${OPTARG}: INVALID OPTION. Aborted..." && exit 1
        ;;
    esac
done


# Ok, c'est moche, mais ca permet de se retrouver plus facilement dans les logs...
log "------------------------------"

exit 0