#!/bin/bash
#
#
# Script qui verifie si la machine possede la vip
# Si elle ne l'a plus :
#   - Envoi d'un mail
#   - Creation d'un fichier lck dans /tmp
#
#

#Variables :
IP="178.170.110.131"
IPNAT="172.31.0.131"
LCKFILE="/tmp/ip.lck"
LOGFILE="/var/log/vip.log"
DATE=$(date +%Y-%m-%d::%Hh%M)
VIP=$(ifconfig -a | grep -c "eth[0-5]:[0-5]") # 1 = vip ok ; 0 = pas de vip

MAILADDR="system@intuitiv.fr"
MAILSUBJECT="[Ikoula] bascule vip !"

MAILMSG="La vip a basculé à $DATE.<br />
Elle n'est plus sur le serveur $IP ($IPNAT) !<br /><br />
Veuillez régler le problème au plus vite...<br /><br />

!!! WARNING !!!<br />
Il faut penser a desactiver les backups sur le serveur ${IP} dans /etc/crontab et
les activer sur le serveur de backup si le probleme ne doit pas etre regle tout de suite !
<br />
vip checker."



if [[ ! -f $LCKFILE ]]; then
        if [[ $VIP == 1 ]]; then
                exit 0
        else
                touch $LCKFILE
                echo "$DATE : La vip est tombée" >> $LOGFILE
                echo "$MAILMSG" | mail  -a 'Content-type: text/html; charset="UTF-8"' -s "$MAILSUBJECT" $MAILADDR
        fi
else
        if [[ $VIP == 1 ]]; then
                rm $LCKFILE
                echo "$DATE : La vip est rétablie" >> $LOGFILE
        else
                exit 0
        fi
fi

exit 0
