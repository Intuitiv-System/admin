#!/bin/bash
#
# Filename : switch2lines.sh
# Version  : 1.0
# Author   : http://stackoverflow.com/questions/3992066/how-can-i-swap-two-lines-using-sed-linux-os
# Contrib  : 
# Description :
#  . Switch 2 lines of a file, called in parameter
# 


usage() {
    echo "Usage : sitch2lines.sh file line-x line-y"
    echo -e "\t- $1 : path/file"
    echo -e "\t- $2 : content of one line"
    echo -e "\t- $3 : content of the other line to switch with"
}


log() {
    LOGFILE="/var/log/admin/admin.log"
    if [[ ! -d $(dirname ${LOGFILE}) ]]; then
        mkdir $(dirname ${LOGFILE})
    fi
    echo "$(date +%Y%m%d) :: " ${1} | tee -a ${LOGFILE}
}


##################
#
#     MAIN
#
##################

if [[ -n "${1}" ]] || [[ -n "${2}" ]] || |[[ -n "${3}" ]] ; then
    usage && exit 1
fi

#Make a backup of the file, just in case...
cp "${1}" "${1}".bak

s1="$2"
s2="$3"
awk -vs1="$s1" -vs2="$s2" '
{ a[++d]=$0 }
$0~s1{ h=$0;ind=d}
$0~s2{
	a[ind]=$0
	for(i=1;i<d;i++ ){ print a[i]}
	print h
	delete a;d=0;
}
END{
	for(i=1;i<=d;i++ ){
		print a[i]
	}
}' "${1}"

echo "A backup of original file has been done : ${1}.bak"

exit 0
