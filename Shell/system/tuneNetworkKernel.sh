#!/bin/bash
#
# Filename : tuneNetworkKernel.sh
# Version  : 1.0
# Author   : mathieu androz
#
# Description :
#  . Edit /etc/sysctl.conf to prevent some network attacks
#  . 
#


[[ $(id -u) -eq "0" ]] || ( echo "This script have to run as root. Aborted..." && exit 2 )

SYSFILE="/etc/sysctl.conf"

[[ -f ${SYSFILE} ]] && cp ${SYSFILE} ${SYSFILE}.orig || ( echo "The file ${SYSFILE} does not exist. Aborted..." && exit 2 )

sed -i 's/^net.ipv4.conf.all.rp_filter/#net.ipv4.conf.all.rp_filter/g'                               ${SYSFILE}
sed -i 's/^net.ipv4.tcp_syncookies/#net.ipv4.tcp_syncookies/g'                                       ${SYSFILE}
sed -i 's/^net.ipv4.conf.all.accept_redirects/#net.ipv4.conf.all.accept_redirects/g'                 ${SYSFILE}
sed -i 's/^net.ipv6.conf.all.accept_redirects/#net.ipv6.conf.all.accept_redirects/g'                 ${SYSFILE}
sed -i 's/^net.ipv4.conf.all.accept_source_route/#net.ipv4.conf.all.accept_source_route/g'           ${SYSFILE}
sed -i 's/^net.ipv6.conf.all.accept_source_route/#net.ipv6.conf.all.accept_source_route/g'           ${SYSFILE}
sed -i 's/^net.ipv4.conf.all.log_martians/#net.ipv4.conf.all.log_martians/g'                         ${SYSFILE}
sed -i 's/^net.ipv4.icmp_echo_ignore_broadcasts/#net.ipv4.icmp_echo_ignore_broadcasts/g'             ${SYSFILE}
sed -i 's/^net.ipv4.icmp_echo_ignore_all/#net.ipv4.icmp_echo_ignore_all/g'                           ${SYSFILE}
sed -i 's/^net.ipv4.icmp_ignore_bogus_error_responses/#net.ipv4.icmp_ignore_bogus_error_responses/g' ${SYSFILE}
sed -i 's/^net.ipv4.tcp_max_syn_backlog/#net.ipv4.tcp_max_syn_backlog/g'                             ${SYSFILE}

echo "

########################
# Custom M.A
########################
net.ipv4.conf.all.rp_filter=1
net.ipv4.tcp_syncookies=1
net.ipv4.conf.all.accept_redirects=0
net.ipv6.conf.all.accept_redirects=0
net.ipv4.conf.all.accept_source_route=0
net.ipv6.conf.all.accept_source_route=0
net.ipv4.conf.all.log_martians=1

# Ignorer les messages 'ICMP Echo Request' :
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.icmp_echo_ignore_all=1

# Ignorer les messages 'ICMP Bogus Responses' :
net.ipv4.icmp_ignore_bogus_error_responses=1

# 1024 connexions non confirmées max, limite le SYN flood
net.ipv4.tcp_max_syn_backlog=1024
" >> ${SYSFILE}

