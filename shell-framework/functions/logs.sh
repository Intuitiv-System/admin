LOG_PATH="/var/log/admin"
CHECK_LOG_PATH=0

function log_usage {
  echo "
You must specify in your script the LOG_FILE variable.

Example : 
  # Source the log.sh file in the top of your script
  source /path/to/scripts/function/log.sh
  # define the path and name for the log file
  LOG_FILE=\${LOG_PATH}/file.log
  # init the log function
  log

After that, just call the 'log' function.
Example :
  log \"Message I want to log\" [\"E\"|\"W\"]
If the log tree does not exists, it will be automatically created."
  exit 1
}

function log {
  # Check logfile name
  [[ ! ${LOG_FILE} =~ '.log$' ]] && log_usage

  # Check dossier de log
  if [[ ${CHECK_LOG_PATH} == 0 ]]; then
    if [[ ! -d $(dirname ${LOG_FILE}) ]]; then
      mkdir -p $(dirname ${LOG_FILE})
      CHECK_LOG_PATH=1
    fi
  else
    if [[ -n "${2}" ]]; then
      if [[ "${2}" == "E" ]]; then
        LOGTYPE="[ERROR] "
      else
        LOGTYPE="[WARNING] "
      fi
    else
      LOGTYPE=""
    fi
    echo "$(date "+%Y-%m-%d %H:%M.%S") ${LOGTYPE}${1}" >> ${LOG_FILE}
  fi
}
