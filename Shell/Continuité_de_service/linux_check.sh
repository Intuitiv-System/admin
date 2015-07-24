#===========================
# System Audit v1.45
#
# Script generant un audit system
# by Nicolas Trauwaen
# Update by Anthony
#
#---------CHANGELOG---------
# 20120821 :
#     - Modification de la recuperation du Hostname
# 20120808 :
#     - remplacement de la recuperation des partitions via sfdisk par /proc/partitions
#     - diverses petit changement et remise au propre
# 20091013 :
#     - remplacement de /proc/mdstat par mdadm pour avoir etat du RAID
# 20080807 :
#     - ajout detection des disques
#     - plus d'argument necessaire pour lancer le script
#     - ajout check queue postfix
#     - correction lacement de qmail-qstat avec which au lieu de path en dur
#     - modification detection RAID + correction bug affichage mdstat
# 20071105 :
#     - ajout de qmail-qstat (pour les linux ayant qmail)
#     - correctif bug pour l'affichage du top
# 20070810 :
#     - ajout de commentaires et changelog :)
#     - passage des commandes par which, pour coller a toutes les distributions
#     - ajout d'une interpretation de l'espace disque (merci Xavier)
#     - amelioration de la detection du RAID
#     - ajout support S-ATA pour le smart
#===========================
#!/bin/bash
# environnement
export TERM=xterm

# VAR
now=`date +%Y%m%d`
log="/var/log/report_$now.log"
args=$#
subject="Audit report from `uname -n`"
dest="ikoula@ikoula.com"

#= Informations systemes
echo "Running $0"

echo "----uptime----" >> $log
`which uptime` >> $log
echo " " >> $log
echo " " >> $log

echo "----df -h----" >> $log
DF="`which df` -h"
$DF >> $log

# interpretation du df
alertvalue="90"
space=`$DF | awk '{print $5}' | grep % | grep -v Use | sort -n | tail -1 | cut -d "%" -f1 -`
if [ "$space" -ge "$alertvalue" ]; then
  echo "*************************" >> $log
  echo "| ALERT! Low disk space |" >> $log
  echo "*************************" >> $log
fi
echo " " >> $log
echo " " >> $log

echo "----free----" >> $log
`which free` >> $log
echo " " >> $log
echo " " >> $log

echo "----top----" >> $log
`which top` -b -n 1 >> $log
echo " " >> $log
echo " " >> $log

# detection des disques et execution du smart
echo "Lancement de la recuperation de la liste des devices = disques durs" >> $log
cat /proc/partitions | sed -e "s/.*major.*//; s/^[:0-9 :]* \([:a-z:]*\).*/\1/; s/^\([:a-z:].*\)/\/dev\/\1/g" | uniq | grep -v "md" > /tmp/devices
for dev in `cat /tmp/devices`
do
  echo "Valeurs retournees par $dev" >> $log
  echo "Checking IDE or SCSI" >> $log
  disktype=`grep "hda" /tmp/devices | wc -l`
  if [ 1 -eq $disktype ]; then
    echo "IDE Detected" >> $log
    opt="-a"
  else
    echo "SCSI or S-ATA Detected" >> $log
    opt="-d ata -a"
  fi
  echo "----smartctl-$dev----" >> $log
  `which smartctl` $opt $dev >> $log
done
echo " " >> $log
echo " " >> $log

# detection du RAID
# si existe alors recuperation du mdstat
raid=`cat /proc/partitions | sed -e "s/.*major.*//; s/^[:0-9 :]* \([:a-z:0-9:]*\).*/\1/; s/^\([:a-z:].*\)/\/dev\/\1/g" | grep "md"`
if [ -n "$raid" ]; then
  for dev in $raid
  do
    echo "----mdadm----" >> $log
    `which mdadm` --detail $dev >> $log
    echo " " >> $log
    echo " " >> $log
  done
fi

# detection de rkhunter
# si existe alors execution du scan
rkh=`find / -name rkhunter`
if [ -n "$rkh" ]; then
  echo "----rkhnuter----" >> $log
  `which rkhunter` --update >> $log
  `which rkhunter` --checkall --nocolors --skip-keypress >> $log
fi

# nombre de mails en queue
qmail=`find / -name qmail`
if [ -n "$qmail" ]; then
  echo "----qmail-qstat----" >> $log
  `which qmail-qstat` >> $log
fi
postfix=`find / -name postfix`
if [ -n "$postfix" ]; then
  echo "----postqueue----" >> $log
  `which postqueue` -p >> $log
fi

# envoi du rapport par mail
echo "Sending log by mail to $dest"
`which mail` -s "$subject" "$dest" < $log
echo "See $log to view result"

# Fin du script
echo "$0 successfull executed"

exit 0
#EOF
