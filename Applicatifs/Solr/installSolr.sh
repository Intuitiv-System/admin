#!/bin/bash
#
# Filename : .sh
# Version  : 1.0
# Author   : mathieu androz
# Contrib  : 
# Description :
#  . Install solr
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

# Create Unix user solr
[[ ! $(grep -E "^solr:" /etc/group) ]] && addgroup --system solr
#[[ ! $(grep -E "^solr:" /etc/passwd) ]] && adduser --system --shell /bin/sh --ingroup solr solr
[[ ! $(grep -E "^solr:" /etc/passwd) ]] && useradd --system --create-home --shell /bin/sh --gid solr solr


# Logs
SOLR_VAR="/var/log/solr"
if [[ ! -d ${SOLR_VAR} ]]; then
    mkdir -p ${SOLR_VAR}
    chmod 750 ${SOLR_VAR}
    chown -R solr:root ${SOLR_VAR}
fi

# Create init
SOLR_INIT="/etc/init.d/solr"
if [[ ! -f ${SOLR_INIT} ]]; then
cat >> ${SOLR_INIT} < __EOF__
#!/bin/bash

### BEGIN INIT INFO
# Provides:          foobar
# Required-Start:    
# Required-Stop:     
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Init for Indexation Engine Solr
# Description:       
### END INIT INFO


WEB_USER="solr"
SOLR_DIR="/home/solr/apache-solr-3.6.2/drupal_multisite"
SOLR_PORT="8983"
JAVA_OPTIONS="-Xmx256m"
JAVA_OPTIONS_START="-Djetty.port=${SOLR_PORT}"
JAVA_OPTIONS_STOP="-DSTOP.PORT=${SOLR_PORT} -DSTOP.KEY=stopkey"
LOG_FILE="/var/log/solr/solr.log"
JAVA=$(which java)

[[ ! -d $(dirname ${LOG_FILE}) ]] && mkdir $(dirname ${LOG_FILE}) && chmod 777 $(dirname ${LOG_FILE})

case $1 in
    start)
        if [[ -n $(lsof -i :${SOLR_PORT}) ]]; then
          echo "A process is already using the port ${SOLR_PORT}. Please change it."
          exit 2
        fi
        echo "Starting Solr"
        cd $SOLR_DIR
        su -c "$JAVA $JAVA_OPTIONS $JAVA_OPTIONS_START -jar start.jar 2>> $LOG_FILE &" ${WEB_USER}
        ;;
    stop)
        echo "Stopping Solr"
        cd $SOLR_DIR
        su -c "$JAVA $JAVA_OPTIONS_STOP -jar start.jar --stop" ${WEB_USER}
        sleep 3
        if [[ -n $(lsof -i :${SOLR_PORT}) ]]; then
          SOLR_PID=$(lsof -i :${SOLR_PORT} | tail -n 1 | awk '{print $2}')
          kill -9 ${SOLR_PID}
        fi
        ;;
    restart)
        $0 stop
        sleep 5
        $0 start
        ;;
    *)
        echo "Usage: $0 {start|stop|restart}" >&2
        exit 1
        ;;
esac
__EOF__

    chmod 755 ${SOLR_INIT}
fi

[[ ! -f $(ls /etc/rc3.d/ | grep "solr") ]] && update-rc.d solr defaults

# Create logrotate
if [[ ! -f /etc/logrotate.d/solr ]]; then
cat >> /etc/logrotate.d/solr << --EOF
/var/log/solr/*.log {
        weekly
        missingok
        rotate 52
        compress
        delaycompress
        size 20M
        notifempty
        sharedscripts
        postrotate
                service solr restart > /dev/null
        endscript
}
--EOF
else
    echo "Logrotate can't be configured at /etc/logrotate.d/solr. Investigate !"
fi

# Ok, c'est moche, mais ca permet de se retrouver plus facilement dans les logs...
#log "------------------------------"

