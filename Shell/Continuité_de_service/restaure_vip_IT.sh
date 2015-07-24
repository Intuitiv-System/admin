#!/bin/bash
#
#
# Script qui permet de restaurer la vip sur le serveur de production
#
#

IPSLAVE="172.31.0.132"
IPMASTER="172.31.0.131"
SSHPORT="6622"
SSHUSER="root"
VIP=$(ifconfig -a | grep -c "eth[0-5]:[0-5]") # 1 = vip ok ; 0 = pas de vip

MAILADDR="system@intuitiv.fr"
MAILSUBJECT="[Ikoula] Retablissement de la vip en production"

MAILMSG="La vip a été rétablie sur le serveur de production Ikoula.<br />
Ce rétablissement s'est effectué automatiquement grace au cron :<br /><br />
# INTUITIV : script de retablissement de la vip en production<br />
0,30 1-5 &#42; &#42; &#42; root /bin/sh /root/Intuitiv/scripts/restaure_vip.sh 2> /dev/null<br /><br />
défini dans /etc/crontab.<br /><br />
vip checker"


if [[ $VIP == 0 ]]; then
        ssh -p $SSHPORT -l $SSHUSER $IPSLAVE "/etc/init.d/heartbeat stop"
        sleep 5
        /etc/init.d/heartbeat stop
        /etc/init.d/heartbeat start
        sleep 5
        ssh -p $SSHPORT -l $SSHUSER $IPSLAVE "/etc/init.d/heartbeat start"
        sleep 30
        if [[ $(ifconfig -a | grep -c "eth[0-5]:[0-5]") == 1 ]]; then
                echo "$MAILMSG" | /usr/bin/mail -a 'Content-type: text/html; charset="UTF-8"' -s "$MAILSUBJECT" $MAILADDR
        fi
elif [[ $VIP == 1 ]]; then
        #echo "Ca passe dans le script mais pas au bon endroit !" | /usr/bin/mail -a 'Content-type: text/html; charset="UTF-8"' -s "$MAILSUBJECT" $MAILADDR
        exit 0
else
        exit 0
fi

exit 0
