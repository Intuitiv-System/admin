#!/bin/bash

#allBounced=$(cat /var/log/mail.log | grep status=bounced)
messages_id=$(cat /var/log/mail.log | grep status=bounced | awk '{print $6}' | sed 's/://')
nbBounced=$(cat /var/log/mail.log | grep status=bounced | wc -l)
file="/tmp/messages_id.txt"
senders="/tmp/senders.txt"
log_file="/tmp/bounces.log"
final_file="/root/bounces.log"
date_debut=$(cat /var/log/mail.log | head -n 1 | awk '{$1; $2; NF=2; print}')
date_fin=$(tac /var/log/mail.log | head -n 1 | awk '{$1; $2; NF=2; print}')

  echo -e "${messages_id}\n" > ${file}
  sed  '/^$/d' ${file} > /tmp/tmp.txt && mv /tmp/tmp.txt ${file}
  
##On récupère les NDD qui bounce
cat ${file} | while read line
do
  sender_address=$(cat /var/log/mail.log | grep $line | grep -oP '(?<=from=<).*?(?=>)' | tail -n 1)
  echo ${sender_address} >> ${senders}
done

sed  '/^$/d' ${senders} > /tmp/tmp.txt && mv /tmp/tmp.txt ${senders}

##Compteur de bounces par NDD
cat ${senders} | while read line
do

  occurences=$(grep -c "${line}" ${senders})
  stats=$(echo "scale=2; ${occurences}/${nbBounced} * 100" | bc)
  echo -e "${line} \t ${occurences} \t \t ${stats}%" >> ${log_file}
done

echo "Rapport de bounce du ${date_debut} au ${date_fin}" > ${final_file}
echo -e "--------------------------------------------------------------|
        Adresses \t Nombre de Bounces \t Pourcentage  |" >> ${final_file}
echo -e "--------------------------------------------------------------|" >> ${final_file}
cat ${log_file} | sort -u >> /root/bounces.log

##On fait un peu le ménage
rm ${senders} ${log_file} ${file}
exit 0
