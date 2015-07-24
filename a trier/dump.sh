#!/bin/bash

## Backup MySQL databases on RDS

usage() {
    echo "DB name has to be entered as parameters..."
    echo ""
    echo "Usage : ${0} dbname1 dbname2 ..."
}

MYSQLUSER=""
MYSQLPASS=""
MYSQLHOST=""
BKPPATH=""
BKPRETENTION=""


if [[ ${#} -eq 0 ]]; then
    usage && exit 1
elif [[ -z ${MYSQLUSER} ]] || [[ -z ${MYSQLPASS} ]] || [[ -z ${MYSQLHOST} ]] || [[ -z ${BKPPATH} ]] || [[ -z ${BKPRETENTION} ]];
    echo "One or more variables in teh script wasn't edited. Please fix it..." && exit 2
else
    for (( i=1; i<=${#}; i++ ))
    do
        MYSQLDBNAME=$(eval echo \$$i)
        mysqldump -u ${MYSQLUSER} -p"${MYSQLPASS}" -h "$#{MYSQLHOST}" --single-transaction ${MYSQLDBNAME} | gzip > "${BKPPATH}"/${MYSQLDBNAME}_$(date +%Y%m%d).sql.gz
        test -f "${BKPPATH}"/${MYSQLDBNAME}_$(date --date '${BKPRETENTION} days ago' +%Y%m%d).sql.gz && rm "${BKPPATH}"/${MYSQLDBNAME}_$(date --date '${BKPRETENTION} days ago' +%Y%m%d).sql.gz
    done
fi


exit 0