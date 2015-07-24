#!/bin/bash
#
### BEGIN INIT INFO
# Provides:          alfresco
# Required-Start:
# Required-Stop:
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start and stop alfresco tomcat application
# Description:
### END INIT INFO
#
set -e
set -u


# Set Up Variables
ALFRESCO_USER=alfresco
ALFRESCO_ROOT_DIR=/home/alfresco/alfresco-4.2.b


test -x ${ALFRESCO_ROOT_DIR}/alfresco.sh || exit 0


alfresco_start() {
        su -c "cd ${ALFRESCO_ROOT_DIR} && ./alfresco.sh start" ${ALFRESCO_USER}
        echo ""
        echo "Alfresco Started... [OK]"
        return 0
}

alfresco_stop() {
        su -c "cd ${ALFRESCO_ROOT_DIR} && ./alfresco.sh stop" ${ALFRESCO_USER}
        echo ""
        echo "Alfresco stopped successfully..."
        return 0
}

alfresco_pid() {
        if [[ -e ${ALFRESCO_ROOT_DIR}/tomcat/temp/catalina.pid ]]; then
                if pidof java | tr ' ' '\n' | grep -w $(cat ${ALFRESCO_ROOT_DIR}/tomcat/temp/catalina.pid); then
                        return 0
                fi
        fi
        return 1
}

alfresco_status() {
        PID=$(alfresco_pid) || true
        if [ -n "${PID}" ]; then
                PS_LINE=$(ps aux | grep java | grep -w ${PID})
                PS_USER=$(echo ${PS_LINE} | awk '{print $1}')
                PS_PID=$(alfresco_pid)
                PS_ROOT_DIR=$(echo ${PS_LINE} | awk -F"-Dcatalina.home=" '{print $2}' | awk '{print $1}' | colrm 7 )
                echo "Alfresco Status           = Started"
                echo "Process ID                = ${PS_PID}"
                echo "Process User              = ${PS_USER}"
                echo "Alfresco root path        = ${ALFRESCO_ROOT_DIR}"
        else
                echo "Alfresco process is NOT running..."
                if [[ -e ${ALFRESCO_ROOT_DIR}/tomcat/temp/catalina.pid ]]; then
                        exit 1
                else
                        exit 3
                fi
        fi
}

alfresco_log() {
        echo "Press Ctrl+C to quit :"
        su -c "tail -f ${ALFRESCO_ROOT_DIR}/tomcat/logs/catalina.out" -m ${ALFRESCO_USER}
        return 0
}


alfresco_clean() {
        echo "check alfresco alive :"
        if alfresco_pid ; then
                echo "  -> No alfresco process is running"
                echo "check PID file :"
                if [[ -x ${ALFRESCO_ROOT_DIR}/tomcat/temp/catalina.pid ]]; then
                        rm ${ALFRESCO_ROOT_DIR}/tomcat/temp/catalina.pid
                        echo "  -> PID file deleted"
                else
                        echo "  -> no PID file present"
                fi
                echo "Alfresco instance cleaned now !"
        else
                echo "  -> An Alfresco process is alive."
                echo "Please use {stop|restart} argument."
        fi
        return 0
}

#########
# Main
#########

case $1 in
        start)
                alfresco_start
        ;;
        stop)
                alfresco_stop
        ;;
        restart)
                alfresco_stop
                echo "Alfresco restarting..."
                alfresco_start
        ;;
        status)
                alfresco_status
        ;;
        log|logs)
                alfresco_log
        ;;
        clean)
                alfresco_clean
        ;;
        *)
                echo "Usage : $0 {start|stop|restart|status|log|clean}"
                exit 1
        ;;
esac

exit 0