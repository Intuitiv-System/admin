#!/bin/bash
#
# Filename : analyzeMySQL.sh
# Version  : 1.1.1
# Author   : mathieu androz
# Contrib  :
# Description :
#  . v.1.1.1
#  \_ Add check Debian-like
#  \_ Add usage of debian.cnf file
#  . v.1.1.0
#  \_ Add option "--show" + usage function
#  . v.1.0.1
#  \_ Add check MySQL server version
#  \_ change Uptime discover method
#  . v.1.0.0
#  \_ Request a MySQL Server to recover lots of informations
#  \_ and give some values in order to analyze its use
#

MYSQLHOST="localhost"
MYSQLPORT="3306"
MYSQLROOT="root"
MYSQLPWD=""
MYSQLSTATUS="/tmp/global_status.txt"
MYSQLVARIABLES="/tmp/global_variables.txt"


VERT="\\033[1;32m"
NORMAL="\\033[0;39m"
ROUGE="\\033[1;31m"
ROSE="\\033[1;35m"
BLEU="\\033[1;34m"
BLANC="\\033[0;02m"
BLANCLAIR="\\033[1;08m"
JAUNE="\\033[1;33m"
CYAN="\\033[1;36m"


usage() {
    echo "Usage : $0 {--check|--show|--help}"
    echo -e "\t-c | --check | check\tAnalyze and display results and informations about your MySQL server configuration"
    echo -e "\t-s | --show  | show\tDisplay mysql commands to use in order to solve remarks"
    echo -e "\t-h | --help  | help\tPrint this help"
}

log() {
    LOGFILE="/var/log/admin/mysql.log"
    if [[ ! -d $(dirname ${LOGFILE}) ]]; then
        mkdir -p $(dirname ${LOGFILE})
    fi
    echo -e ${1} | tee -a ${LOGFILE}
}

cleanTmpFiles() {
    [[ -f ${MYSQLSTATUS} ]] && rm ${MYSQLSTATUS}
    [[ -f ${MYSQLVARIABLES} ]] && rm ${MYSQLVARIABLES}
}

byte2mega() {
    # Convert Bytes to MegaBytes
    echo "scale=7; ${1} / 1024 / 1024" | bc -l
}

showTime () {
    num=$1 ; min=0 ; hour=0 ; day=0
    if((num>59));then
        ((sec=num%60))
        ((num=num/60))
        if((num>59));then
            ((min=num%60))
            ((num=num/60))
            if((num>23));then
                ((hour=num%24))
                ((day=num/24))
            else
                ((hour=num))
            fi
        else
            ((min=num))
        fi
    else
        ((sec=num))
    fi
    echo "$day"d "$hour"h "$min"m "$sec"s
}

CheckDistrib()
{
    # On what linux distribution you are
    DISTRIB=$(awk '{print $1}' /etc/issue)
    DIR=$(pwd)
    FILE=$(basename $0)
    if [[ ${DISTRIB} = "Ubuntu" ]]; then
        if [[ $(whoami) != "root" ]]; then 
            echo "Login as root and execute this command : ${DIR}/${FILE}" && sudo su -
            exit 0
        fi
        if [[ -f "/etc/mysql/debian.cnf" ]]; then
            MYSQLCMD="/usr/bin/mysql --defaults-file=/etc/mysql/debian.cnf -B -N -L"
        else
            [[ -z ${MYSQLPWD} ]] && read -s -p "Enter root MySQL password : " MYSQLPWD
            MYSQLCMD="/usr/bin/mysql -u ${MYSQLROOT} -P ${MYSQLPORT} --host=${MYSQLHOST} -p${MYSQLPWD} -B -N -L"
        fi
    elif [[ ${DISTRIB} = "Debian" ]]; then
        if [[ $(whoami) != "root" ]]; then
            echo "Login as root and execute this command : ${DIR}/${FILE}" && su -
            exit 0
        fi
        if [[ -f "/etc/mysql/debian.cnf" ]]; then
            MYSQLCMD="/usr/bin/mysql --defaults-file=/etc/mysql/debian.cnf -B -N -L"
        else
            [[ -z ${MYSQLPWD} ]] && read -s -p "Enter root MySQL password : " MYSQLPWD
            MYSQLCMD="/usr/bin/mysql -u ${MYSQLROOT} -P ${MYSQLPORT} --host=${MYSQLHOST} -p${MYSQLPWD} -B -N -L"
        fi
    else
        echo "You're running on ${DISTRIB}.\nThis script is adapted for Debian-Like OS.\nBye"
        [[ -z ${MYSQLPWD} ]] && read -s -p "Enter root MySQL password : " MYSQLPWD
        MYSQLCMD="/usr/bin/mysql -u ${MYSQLROOT} -P ${MYSQLPORT} --host=${MYSQLHOST} -p${MYSQLPWD} -B -N -L"
    fi
}

testMysqlConnection() {
    CheckDistrib
    MYSQLTEST=$(${MYSQLCMD} -e "STATUS ;" 2> /dev/null)
    MYSQLTESTERROR=$(echo "${MYSQLTEST}" | head -n 1 | awk '{print $1}')
    if [[ -z ${MYSQLTESTERROR} ]] || [[ ${MYSQLTESTERROR} == "ERROR" ]]; then
        echo "Error while connect to MySQL server."
        echo "Please check if you're using the good password for example..."
        exit 1
    fi
}

mysqlStatus() {
    ${MYSQLCMD} -e "SHOW GLOBAL STATUS ;" > ${MYSQLSTATUS}
}

mysqlVariables() {
    ${MYSQLCMD} -e "SHOW GLOBAL VARIABLES ;" > ${MYSQLVARIABLES}
}

checkMysqlversion() {
    MYSQLVERSION=$(grep -E "^version" "${MYSQLVARIABLES}" | grep -vE "version_(.*)" | cut -f2 -s)
    if [[ $(echo ${MYSQLVERSION} | cut -d"." -f1) == "4" ]]; then
        echo "MySQL Server Version is : ${MYSQLVERSION}"
        echo "MySQL Server Version is not supported by this script :"
    elif [[ $(echo ${MYSQLVERSION} | cut -d"." -f1) == "5" ]] && [[ $(echo ${MYSQLVERSION} | cut -d"." -f2) == "0" ]]; then
        MYSQL5=$(echo ${MYSQLVERSION} | cut -c 1-3)
    elif [[ $(echo ${MYSQLVERSION} | cut -d"." -f1) == "5" ]] && [[ $(echo ${MYSQLVERSION} | cut -d"." -f2) == "1" ]]; then
        MYSQL5=$(echo ${MYSQLVERSION} | cut -c 1-3)
    elif [[ $(echo ${MYSQLVERSION} | cut -d"." -f1) == "5" ]] && [[ $(echo ${MYSQLVERSION} | cut -d"." -f2) == "5" ]]; then
        MYSQL5=$(echo ${MYSQLVERSION} | cut -c 1-3)
    else
        echo "MySQL Server Version is : ${MYSQLVERSION}"
        echo "MySQL Server Version is not supported by this script :"
    fi
}

mysqlUptime() {
    MYSQLUPTIME=$(grep "Uptime" "${MYSQLSTATUS}" | grep -v "Uptime_since_flush_status" | cut -f2 -s)
}

### Query Cache Stats
qCache() {
    QCACHE_SIZE=$(grep "query_cache_size" "${MYSQLVARIABLES}" | cut -f2 -s)
    QCACHE_FREE_MEMORY=$(grep "Qcache_free_memory" "${MYSQLSTATUS}" | cut -f2 -s)
    QCACHE_QUERIES_IN_CACHE=$(grep "Qcache_queries_in_cache" "${MYSQLSTATUS}" | cut -f2 -s)
    QCACHE_AVERAGE_SIZE=$(echo "scale=5; (${QCACHE_SIZE} - ${QCACHE_FREE_MEMORY}) / ${QCACHE_QUERIES_IN_CACHE}" | bc -l)
    QCACHE_LOWMEM=$(grep "Qcache_lowmem_prunes" "${MYSQLSTATUS}" | cut -f2 -s)
    QCACHE_HITS=$(grep "Qcache_hits" "${MYSQLSTATUS}" | cut -f2 -s)
    COM_SELECT=$(grep "Com_select" "${MYSQLSTATUS}" | cut -f2 -s)
    QCACHE_HITS_RATIO=$(echo "scale=2; ${QCACHE_HITS} / (${QCACHE_HITS} + ${COM_SELECT}) * 100" | bc -l)
}

### MyISAM cache
myisamCache() {
    MYISAM_KEYS_READS=$(grep "Key_reads" "${MYSQLSTATUS}" | cut -f2 -s)
    MYISAM_KEY_READ_REQUEST=$(grep "Key_read_request" "${MYSQLSTATUS}" | cut -f2 -s)
    MYISAM_CACHE_EFFICIENCY=$(echo "scale=5; 100 - ((${MYISAM_KEYS_READS} * 100) / ${MYISAM_KEY_READ_REQUEST})" | bc -l)
    MYISAM_KEY_BUFFER_SIZE=$(grep "key_buffer_size" "${MYSQLVARIABLES}" | cut -f2 -s)
    MYISAM_KEY_BLOCKS_UNUSED=$(grep "Key_blocks_unused" "${MYSQLSTATUS}" | cut -f2 -s)
    MYISAM_KEY_CACHE_BLOCK_SIZE=$(grep "key_cache_block_size" "${MYSQLVARIABLES}" | cut -f2 -s)
    MYISAM_AVERAGE_KEY_MEM_USED=$(echo "scale=5; (1 - ((${MYISAM_KEY_BLOCKS_UNUSED} * ${MYISAM_KEY_CACHE_BLOCK_SIZE}) / ${MYISAM_KEY_BUFFER_SIZE})) * 100" | bc -l)
    MYISAM_FAIL_RATE=$(echo "scale=5; ${MYISAM_KEYS_READS} / ${MYISAM_KEY_READ_REQUEST}" | bc -l)
    MYISAM_KEY_BUFFER_SIZE_EFFICIENCY=$(echo "scale=5; 1 - ${MYISAM_FAIL_RATE}" | bc -l)
}

### InnoDB Stats
innondbBufferPoolSize() {
    INNODB_PAGES_FREE=$(grep "Innodb_buffer_pool_pages_free" "${MYSQLSTATUS}" | cut -f2 -s)
    INNODB_POOL_READS=$(grep "Innodb_buffer_pool_reads" "${MYSQLSTATUS}" | cut -f2 -s)
    INNODB_POOL_READ_REQUESTS=$(grep "Innodb_buffer_pool_read_requests" "${MYSQLSTATUS}" | cut -f2 -s)
    # Proportion of reads used by Hard Drive Disk again total of InnoDB read requests
    INNODB_READS_RATE=$(echo "scale=5; (${INNODB_POOL_READS} * 100) / ${INNODB_POOL_READ_REQUESTS}" | bc -l)
    INNODB_BUFFER_POOL_SIZE=$(grep "innodb_buffer_pool_size" "${MYSQLVARIABLES}" | cut -f2 -s)
}

recommandedBuffer() {
    # Give the recommanded innoDB Buffer Pool Size
    MYSQLREQUEST="SELECT CONCAT(ROUND(KBS/POWER(1024, IF(PowerOf1024<0,0,IF(PowerOf1024>3,0,PowerOf1024)))+0.49999), SUBSTR(' KMG',IF(PowerOf1024<0,0, IF(PowerOf1024>3,0,PowerOf1024))+1,1)) recommended_innodb_buffer_pool_size FROM (SELECT SUM(data_length+index_length) KBS FROM information_schema.tables WHERE engine='InnoDB') A, (SELECT 2 PowerOf1024) B ;"
    RECOMMENDEDBUFFER=$(${MYSQLCMD} -e "${MYSQLREQUEST}")
}

### networking stats
networkConnection() {
    ABORTED_CLIENTS=$(grep "Aborted_clients" "${MYSQLSTATUS}" | cut -f2 -s)
    ABORTED_CONNECTS=$(grep "Aborted_connects" "${MYSQLSTATUS}" | cut -f2 -s)
    MAX_USED_CONNECTIONS=$(grep "Max_used_connections" "${MYSQLSTATUS}" | cut -f2 -s)
    MAX_ALLOWED_PACKET=$(grep -E "^max_allowed_packet" "${MYSQLVARIABLES}" | cut -f2 -s)
}

### table cache
tableCache() {
    # Check if MySQL server version is 5.1 or 5.5
    if [[ ${MYSQL5} != "5.0" ]]; then
        OPEN_TABLE_DEFINITIONS=$(grep "Open_table_definitions" "${MYSQLSTATUS}" | cut -f2 -s)
    fi
    OPEN_TABLES=$(grep "Open_tables" "${MYSQLSTATUS}" | cut -f2 -s)
    if [[ ${MYSQL5} != "5.0" ]]; then
        OPENED_TABLE_DEFINITIONS=$(grep "Opened_table_definitions" "${MYSQLSTATUS}" | cut -f2 -s)
    fi
    OPENED_TABLES=$(grep "Opened_tables" "${MYSQLSTATUS}" | cut -f2 -s)
    if [[ ${MYSQL5} != "5.0" ]]; then
        TABLE_DEFINITION_CACHE=$(grep "table_definition_cache" "${MYSQLVARIABLES}" | cut -f2 -s)
        TABLE_OPEN_CACHE=$(grep "table_open_cache" "${MYSQLVARIABLES}" | cut -f2 -s)
    fi
}

### Threads cache
threadsCache() {
    [[ -z ${MYSQLUPTIME} ]] && mysqlUptime
    THREADS_CACHED=$(grep "Threads_cached" "${MYSQLSTATUS}" | cut -f2 -s)
    THREADS_CONNECTED=$(grep "Threads_connected" "${MYSQLSTATUS}" | cut -f2 -s)
    THREADS_CREATED=$(grep "Threads_created" "${MYSQLSTATUS}" | cut -f2 -s)
    THREADS_RUNNING=$(grep "Threads_running" "${MYSQLSTATUS}" | cut -f2 -s)
    CONNECTIONS=$(grep "Connections" "${MYSQLSTATUS}" | cut -f2 -s)
    THREADS_CREATED_PER_CONNECTION=$(echo "scale=5; ${THREADS_CREATED} / ${CONNECTIONS}" | bc -l)
    THREADS_CREATED_SINCE_UPTIME=$(echo "scale=5; ${THREADS_CREATED} / ${MYSQLUPTIME}" | bc -l)
    THREAD_CACHE_SIZE=$(grep "thread_cache_size" "${MYSQLVARIABLES}" | cut -f2 -s)
}

##################
#
#     MAIN
#
##################

if [[ -n ${1} ]]; then
    case "${1}" in
        "-c"|"--check"|"check")
            testMysqlConnection
            mysqlStatus && mysqlVariables

            mysqlUptime

            clear 

            log ""
            log "::::::::::::: Analysis $(date +%Y%m%d-%H:%M) :::::::::::::"

            checkMysqlversion
            log "\n--------------------- Server informations ---------------------"
            log "\tMySQL server Uptime  : $(showTime ${MYSQLUPTIME})"
            log "\tMySQL server Version : ${MYSQLVERSION}"

            myisamCache
            log "\n--------------------- MyISAM ----------------------------------"
            log "\tKey buffer size : $(byte2mega ${MYISAM_KEY_BUFFER_SIZE})M"
            log "\tPercentage of memory used over total allocated memory for MyISAM cache : ${MYISAM_CACHE_EFFICIENCY}%"
            log "\tApproximate percentage of memory used : ${MYISAM_AVERAGE_KEY_MEM_USED}%"
            log "\tEfficiency of key_buffer_size setting (1 is the best) : ${MYISAM_KEY_BUFFER_SIZE_EFFICIENCY}"


            innondbBufferPoolSize && recommandedBuffer
            log "\n--------------------- InnonDB Section -------------------------"
            log "\tValue of Pages Free : ${INNODB_PAGES_FREE}"
            log "\tRate of HDD reads : ${INNODB_READS_RATE}%"
            log "\tActual InnoDB buffer pool size : $(byte2mega ${INNODB_BUFFER_POOL_SIZE})M"

            log "\n\t${ROUGE}Recommended innoDB Buffer Pool Size : ${RECOMMENDEDBUFFER} ${NORMAL}"
            if [[ -n ${INNODB_PAGES_FREE} ]] && [[ ${INNODB_PAGES_FREE} -gt 0 ]]; then
                log "\n\t${VERT}It seems that innoDB buffer is well proportioned.${NORMAL}"
            else
                log "\n\t${ROUGE}Your buffer pages are full."
                log "\tMaybe your buffer is perfectly proportioned or is too small."
                log "\tTo investigate, you have to check the rate of HDD reads in order to determine if"
                log "\tyour MySQL have lots of reads on HDD. If it's the case, you have to increase your buffer pool size !${NORMAL}"
            fi


            networkConnection
            log "\n--------------------- Networking Section -----------------------"
            log "\tNumber of aborted clients : ${ABORTED_CLIENTS}"
            log "\tNumber of aborted connections : ${ABORTED_CONNECTS}"
            log "\tMaximum used connections : ${MAX_USED_CONNECTIONS}"
            log "\tMax_allowed_packet : $(byte2mega ${MAX_ALLOWED_PACKET})M"

            log "\n\t${ROUGE}If number of 'Aborted_clients' is high, it could be a good thing to increase the value of 'max_allowed_packet' (GLOBAL VARIABLES)${NORMAL}"


            qCache
            log "\n--------------------- Query Cache -------------------------------"
            log "\tQuery cache size : $(byte2mega ${QCACHE_SIZE})M"
            log "\tQcache_free_blocks (Query cache free memory) : $(byte2mega ${QCACHE_FREE_MEMORY})M"
            log "\tAverage size of a cached request : $(byte2mega ${QCACHE_AVERAGE_SIZE})M"
            log "\tQcache_lowmem_prunes (Number of requests removed from cache because of lack of memory) : ${QCACHE_LOWMEM}"
            log "\tQcache hits ratio : ${QCACHE_HITS_RATIO} %"

            log "\n\t${ROUGE}'Qcache_lowmem_prunes' is the number of requests removed beacause of lack of memory."
            log "\tThis result is to check with 'Qcache_free_blocks'. If there are free blocks available, this means that the cache"
            log "\tis probably fragmented. MySQL command 'FLUSH QUERY CACHE' have to be used to defrag."
            log "\n\tIf Qcache hits ratio is less than 10%, you can try to disable Qcache with : query_cache_type = 0 and query_cache_size = 0${NORMAL}"


            tableCache
            log "\n--------------------- Table Cache --------------------------------"
            if [[ ${MYSQL5} != "5.0" ]]; then
                log "\tOpen_table_definitions (number of .frm in cache actually) : ${OPEN_TABLE_DEFINITIONS}"
            fi
            log "\tOpen_tables (number of file describers in cache actually) : ${OPEN_TABLES}"
            if [[ ${MYSQL5} != "5.0" ]]; then
                log "\tOpened_table_definitions (total number of .frm in cache) : ${OPENED_TABLE_DEFINITIONS}"
            fi
            log "\tOpened_tables (total number of file describers wich was put in cache) : ${OPENED_TABLES}"
            if [[ ${MYSQL5} != "5.0" ]]; then
                log "\ttable_open_cache : ${TABLE_OPEN_CACHE}"
                log "\ttable_definition_cache : ${TABLE_DEFINITION_CACHE}"
            fi

            if [[ ${MYSQL5} != "5.0" ]]; then
                log "\n\t${ROUGE}If 'Opened_tables' is high (units per second), increase value of 'table_open_cache' and 'table_definition_cache' (GLOBAL VARIABLES)${NORMAL}"
            fi

            threadsCache
            log "\n--------------------- Threads Cache ------------------------------"
            log "\tThreads_cached (number of threads in cache) : ${THREADS_CACHED}"
            log "\tThreads_connected (number of actual connections) : ${THREADS_CONNECTED}"
            log "\tThreads_created (total number of threads created) : ${THREADS_CREATED}"
            log "\tThreads_running (number of active threads) : ${THREADS_RUNNING}"
            log "\tConnections (number of connections on the server (succeeded or not) : ${CONNECTIONS}"
            log "\tRatio of threads cache creation in function of connections number : ${THREADS_CREATED_PER_CONNECTION}"
            log "\tRatio of threads cache creation in function of MySQL uptime : ${THREADS_CREATED_SINCE_UPTIME}"
            log "\tthread_cache_size : ${THREAD_CACHE_SIZE}"

            log "\n\t${ROUGE}'Threads_created' has to increase slowly. Increase 'thread_cache_size' (GLOBAL VARIABLES) if :"
            log "\t- Ratio of threads cache creation in function of connections number is low"
            log "\t- Ratio of threads cache creation in function of MySQL uptime is low.${NORMAL}"

            ### End
            cleanTmpFiles
        ;;
        
        "-s"|"--show"|"show")
            testMysqlConnection
            mysqlVariables && mysqlStatus
            myisamCache && innondbBufferPoolSize && recommandedBuffer && networkConnection && threadsCache
            echo ""
            echo -e "::::::::::::::::::::: my.cnf configuration :::::::::::::::::::::"
            echo -e "\nTuning of mysql server parameters has to be done in a conf.d file like : /etc/mysql/conf.d/mysqltuning.cnf"
            echo -e "\n[mysqld]"
            echo -e "#---- MyISAM ---"
            echo -e "key_buffer_size = (value > $(byte2mega ${MYISAM_KEY_BUFFER_SIZE})M )"
            echo -e "\n#---- InnoDB ----"
            echo -e "innodb_buffer_pool_size = ${RECOMMENDEDBUFFER}"
            echo -e "\n#---- Networking ----"
            echo -e "max_allowed_packet = (value > $(byte2mega ${MAX_ALLOWED_PACKET})M )"
            checkMysqlversion && if [[ ${MYSQL5} != "5.0" ]]; then
                tableCache
                echo -e "\n#---- Table Cache ----"
                echo -e "table_open_cache = ( value > ${TABLE_OPEN_CACHE} )"
                echo -e "table_definition_cache = (value > ${TABLE_DEFINITION_CACHE} )"
            fi
            echo -e "\n#---- Threads Cache ----"
            echo -e "thread_cache_size = (value > ${THREAD_CACHE_SIZE})"

            echo -e "\n::::::::::::::::::::: command lines ::::::::::::::::::::::::::::"
            echo -e "\nTo defrag the Query Cache, the following SQL command has to be executed in a mysql CLI :"
            echo -e "\t${VERT}mysql -u root -p -e \"FLUSH QUERY CACHE${NORMAL} ;\""
            echo -e "Info : this SQL command doesn't purge the cache, just defrag it."
            echo ""

            ### End
            cleanTmpFiles
        ;;

        "-h"|"--help"|*)
            usage && exit 1
        ;;
    esac
else
    usage && exit 1
fi

exit 0

