#!/bin/bash

#---------------------------------------------------------
# Script d execution de rkhunter : Detection de Rootkits
# Dans l ordre :
# 1.rkhunter --versioncheck => derniere version ?
# 2.rkhunter --update       => Mise a jour de rkhunter
# 3.rkhunter --check	    => Scan de toute la machine
#
# Cron : Execution tous les matins a 1h00
# 00 1 * * * sh /root/auto-rkhunter.sh
#---------------------------------------------------------

rkhunter --versioncheck && rkhunter --update && rkhunter --check
