#!/bin/bash
#
# Filename : searchInLogs.sh
# Version  : 1.0.1
# Author   : Mathieu Androz
# Contrib  : 
# Description :
#  . 
#  . 
#

LIST="/tmp/itsearch.list"

# include
#. /lib/lsb/init-functions
. /etc/init.d/functions

usage() {
    echo "
Description :
  Use this script in order to analyze logfiles and find all lines containing
  a string you're searching. Send results in a file you define.

Parameters :
  -t)     Search until time (in days)
  -p)     Path of folder to search in
  -f)     Filename to search in
  -d)     Result destination & filename (ie. /tmp/result.txt)
  -s)     String to search

Usage :
  $0 [-t days] [-d results destination] [-s string]
"
}

##################
#
#     MAIN
#
##################

while getopts t:p:f:d:s: param
do
  case $param in
    t)
      TIME=${OPTARG}
      test -z ${TIME} && log_failure_msg "Bad usage of '-t' param" && usage && exit 1
      ;;
    p)
      SEARCHPATH="${OPTARG}"
      test ! -d "${SEARCHPATH}" && log_failure_msg "Folder ${SEARCHPATH} doesn't exist" && exit 1
      ;;
    f)
      SEARCHFILE="${OPTARG}"
      if [[ -z "${SEARCHPATH}" ]]; then
        log_failure_msg "Please use '-d' param before '-f' param"
        exit 1
      #elif [[ ! -f "${SEARCHPATH}"/"${SEARCHFILE}" ]]; then
      #  log_failure_msg "File ${SEARCHFILE} doesn't exist"
      #  exit 1
      fi
    ;;
    d)
      RESULTFILE="${OPTARG}"
      test -f "${OPTARG}" && mv "${RESULTFILE}" "${RESULTFILE}".$(date +%Y%m%d-%H%M%S)
      ;;
    s)
      STRING="${OPTARG}"
      ;;
    ?)
      usage && exit 1
      ;;
  esac
done


if [[ $# != "10" ]]; then
  #log_failure_msg "Bad usage of parameters"
  echo -n "Bad usage of parameters" && failure && echo
  usage && exit 1
fi

cd "${SEARCHPATH}"

find  -mtime -"${TIME}" -iname "*${SEARCHFILE}*" > "${LIST}"

while read line
do
  echo "~~~~ Working on ${line}..." | tee -a "${RESULTFILE}"
  if [[ "${line}" =~ .gz$ ]]; then
    gunzip "${line}"
    WORK=$(echo "${line}" | sed '$s/...$//')
    grep "${STRING}" "${WORK}" >> "${RESULTFILE}"
    gzip "${WORK}"
  else
      grep "${STRING}" "${line}" >> "${RESULTFILE}"
  fi
  echo >> "${RESULTFILE}"
done < "${LIST}"


exit 0