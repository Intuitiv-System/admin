#!/bin/bash
#Script pour verifier la VIP sur un setup Master-Slave
#
#Ce script doit pouvoir tourner sur n'importe quelle distribution via l'usage d'outils GNU de base.
#Il sera execute via cron a interval regulier depuis le slave MySQL.
#
#Fonctionnement :
#
# Le script se connecte au serveur maitre depuis le slave via SSH (authentification par clef fonctionnelle requise) et recupere via ifconfig la liste des interfaces.
#
# Le mapping des erreurs dans le fichier $RESULTFILE destine a Zabbix est le suivant :
# 0 = VIP sur master (RAS)
# 1 = VIP sur slave (Bascule)
# 2 = Aucune VIP
# 3 = Probleme de connexion au master

#Variables systeme
DATE=`/bin/date +'%Y%m%d_%H%M%S'`
LOGFILE='/var/log/checkvip.log' #Fichier de log verbeux
RESULTFILE='/var/log/zabbix/checkvip.log' #Fichier de resultat pour Zabbix

#Configuration du master
MASTERIP='172.31.0.131' #IP du serveur Master

#Configuration du fonctionnement
TIMEOUT='10' #Timeout en secondes de la connexion SSH
SSHPORT='6622' #Port SSH

echo $DATE > $LOGFILE
echo "Test de connexion au master" >> $LOGFILE
ssh -p $SSHPORT -o ConnectTimeout=$TIMEOUT root@$MASTERIP uname -a >> /dev/null 2>&1

# Si on ne peut se connecter (au cause d'un timeout ou autre), on log l'erreur et on arrete l'execution
if [ $? -ne 0 ] ; then
 echo "Erreur lors de la connexion au master." >> $LOGFILE
 echo "3" > $RESULTFILE
 exit 1
fi

echo "Verification de la presence d'une ou plusieurs VIP(s) sur le master" >> $LOGFILE
TEST1=`ssh -p $SSHPORT -o ConnectTimeout=$TIMEOUT root@$MASTERIP ifconfig -a |grep -c "eth[0-5]:[0-5]"`


if [ $TEST1 -eq 0 ] ; then
 echo "Le Master ne dispose pas de VIP" >> $LOGFILE
else
 echo "Le Master dispose d'au moins une VIP" >> $LOGFILE
 echo "0" > $RESULTFILE
fi

echo "Verification de la presence d'une ou plusieurs VIP(s) sur le slave" >> $LOGFILE
TEST2=`ifconfig -a |grep -c "eth[0-5]:[0-5]"`

if [ $TEST2 -eq 0 ] ; then
 echo "Le Slave ne dispose pas de VIP" >> $LOGFILE
else
 echo "Le slave dispose d'au moins une VIP" >> $LOGFILE
 echo "1" > $RESULTFILE
fi

if [ $TEST1 -eq 0 ] && [ $TEST2 -eq 0 ] ; then
 echo "Aucune des deux machines ne dispose de VIP" >> $LOGFILE
 echo "2" > $RESULTFILE
fi

exit 0
