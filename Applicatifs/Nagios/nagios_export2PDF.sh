#!/bin/bash
#
# Filename : .sh
# Version  : 1.0
# Author   :
# Contrib  :
# Description :
#  .
#  .
#

#
# Edit Variables
#
NAGIOS_USERNAME="nagiosadmin"
NAGIOS_PASSWORD="JvmL;69NAGIOS"
LOGFILE="/var/log/admin/admin.log"


#
# include
if [[ -f "/etc/debian_version" ]]; then
  OS_VERSION="Debian"
  . /lib/lsb/init-functions
elif [[ -f "/etc/lsb_release" ]]; then
  OS_VERSION="RHEL / CentOS"
  # . /.....
else
  OS_VERSION="unknown OS"
fi


function usage() {
  echo "
Usage : $0 [hostname] [website_url]
"
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

function log() {
    [[ ! -d $(dirname ${LOGFILE}) ]] && mkdir -p $(dirname ${LOGFILE})
    echo "$(date +%Y%m%d-%H:%M:%S) :: " ${1} | tee -a ${LOGFILE}
}

function getLastMonthDay() {
  if [[ -z ${LASTDAY} ]]; then
    MONTH=$(date +%m)
    LASTDAY=$(date -d "$MONTH/1 - 1 day" "+%d";)
    LASTMONTH=$(date -d "$MONTH/1 - 1 month" "+%m";)
    LASTMONTHYEAR=$(date -d "$MONTH/1 - 1 month" "+%Y";)
  fi
}

function genTimeStamp() {
  getLastMonthDay
  if [[ $(date +%d) -eq "10" ]]; then
    TS_START=$(date -d"$LASTMONTHYEAR-$LASTMONTH-16 00:00:00" +%s)
    TS_END=$(date -d"$LASTMONTHYEAR-$LASTMONTH-$LASTDAY 00:00:00" +%s)
  elif [[ $(date +%d) -eq "16" ]]; then
    TS_START=$(date -d"$LASTMONTHYEAR-$LASTMONTH-01 00:00:00" +%s)
    TS_END=$(date -d"$LASTMONTHYEAR-$LASTMONTH-15 00:00:00" +%s)
  fi
}


##################
#
#     MAIN
#
##################

if [[ -z "${1}" ]] || [[ -z "${2}" ]] && [[ "${#}" -ne 2 ]]; then
  echo "This script takes 2 arguments. See usage..."
  exit 1
fi

createLogrotate

# If we are le 1st or the 16th of the month,
# then print a Nagios report and put it into a web dir
TODAY=$(date +%d)
if [[ ${TODAY} -eq "10" ]] || [[ ${TODAY} -eq "16" ]]; then
  getLastMonthDay
  genTimeStamp

  #wget \
  #  --page-requisites \
  #  -r --convert-links \
  #  --http-user=${NAGIOS_USERNAME} \
  #  --http-password=${NAGIOS_PASSWORD} \
  #"http://bkp02.itserver.fr/nagios/cgi-bin/avail.cgi?t1=${TS_START}&t2=${TS_END}&show_log_entries=&host=${1}&assumeinitialstates=yes&assumestateretention=yes&assumestatesduringnotrunning=yes&includesoftstates=no&initialassumedhoststate=0&initialassumedservicestate=0&backtrack=4"

  [[ ! -f $(pwd)/reports/report1_$(date +%Y%m%d).pdf ]] && wkhtmltopdf --username ${NAGIOS_USERNAME} --password ${NAGIOS_PASSWORD} "http://vsv2-au-uat.sanofi.com/nagios/cgi-bin/avail.cgi?t1=${TS_START}&t2=${TS_END}&show_log_entries=&host=${1}&assumeinitialstates=yes&assumestateretention=yes&assumestatesduringnotrunning=yes&includesoftstates=no&initialassumedhoststate=0&initialassumedservicestate=0&backtrack=4" $(pwd)/reports/report1_$(date +%Y%m%d).pdf

  [[ ! -f $(pwd)/reports/report2_$(date +%Y%m%d).pdf ]] && wkhtmltopdf --username ${NAGIOS_USERNAME} --password ${NAGIOS_PASSWORD} "http://vsv2-au-uat.sanofi.com/nagios/cgi-bin/avail.cgi?t1=${TS_START}&t2=${TS_END}&show_log_entries=&host=${2}&assumeinitialstates=yes&assumestateretention=yes&assumestatesduringnotrunning=yes&includesoftstates=no&initialassumedhoststate=0&initialassumedservicestate=0&backtrack=4" $(pwd)/reports/report2_$(date +%Y%m%d).pdf
else
  echo nop...
fi

# Ok, c'est moche, mais ca permet de se retrouver plus facilement dans les logs...
#log "------------------------------"


#    -E -H -k \
