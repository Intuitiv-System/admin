#!/bin/bash
clear

check_geoip() {
    # Installation package geoip-bin & dependances
    [[ -z $(dpkg -l | grep geoip-bin) ]] && aptitude install -y geoip-bin
}


ORIG_DIR="/root/scripts/shell/geoip"

TMP_IP_LIST="${ORIG_DIR}/tmp/ip_list.tmp"
[[ ! -d ${ORIG_DIR} ]] && mkdir -p ${ORIG_DIR}

error() {
    case ${1} in
        1) echo "No file to check!";;
        *) echo "Unknown error!";;
    esac
    exit 1
}

get_ip_details() {
    IP=${1}
    curl -s http://www.lookip.net/ip/${IP} > ${ORIG_DIR}/tmp/curl.tmp
    egrep "(Hostname|Reverse Lookup|ISP|Company|City|State/Province|Country)" ${ORIG_DIR}/tmp/curl.tmp > ${ORIG_DIR}/tmp/clean.tmp
    sed -i "s/<[^>]\+>//g" ${ORIG_DIR}/tmp/clean.tmp
    cat ${ORIG_DIR}/tmp/clean.tmp
}

ID=$(ls -l ${ORIG_DIR}/lists/ | wc -l)

ORIG_FILE="${ORIG_DIR}/lists/list.${ID}"

vi ${ORIG_FILE}

sort -u ${ORIG_FILE} | uniq > ${TMP_IP_LIST}
chmod 600 ${TMP_IP_LIST}

while read line; do
    NB_IP_SEEN=$(cat ${ORIG_FILE} | grep ${line} | wc -l)
    IPLOOKUP=$(geoiplookup ${line})
    NSLOOKUP=$(nslookup ${line} | awk -F "name =" '{print $2}' | cut -d" " -f2)
    echo "IP "${line}" ("${NB_IP_SEEN}") >> "${IPLOOKUP} | tee -a ${ORIG_DIR}/reports/report.${ID}.txt
    if [[ ${line} =~ "^$" ]]; then
        continue
    elif [[ -z $(echo ${IPLOOKUP} | grep "FR") ]] || [[ -z ${NSLOOKUP} ]]; then
        get_ip_details ${line} | tee -a ${ORIG_DIR}/reports/report.${ID}.txt
    else
        echo ${NSLOOKUP}
    fi
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" | tee -a ${ORIG_DIR}/reports/report.${ID}.txt
done < ${TMP_IP_LIST}
echo -e "\nReport available : less ${ORIG_DIR}/reports/report.${ID}.txt\n"