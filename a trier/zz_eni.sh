#!/bin/bash

[[ -z ${2} ]] && echo "Missing article Id and/or output folder" && exit 1

IDR=${1}
OPD=${2}
IDSESSION="1a0de514-ef85-4493-b8b7-10c1ffe3b948"

[[ ! -d ${OPD} ]] && mkdir ${OPD}

if [[ ! -f ${OPD}/all.tmp ]]; then
  # Recup de tout le contenu de la page
  wget --quiet "http://www.eni-training.com/client_net/mediabook.aspx?idsession=${IDSESSION}&idr=${IDR}" -O ${OPD}/all.tmp
fi

if [[ ! -f ${OPD}/summary.tmp ]]; then
  # Recup du sommaire de l'eBook
  sed '/<div id="Summary">/,/<\/div>/p' ${OPD}/all.tmp > ${OPD}/summary.tmp
fi

if [[ ! -f ${OPD}/links.tmp ]]; then
  # Recup des liens du sommaire
  cat ${OPD}/summary.tmp | grep -o '<a .*href=.*>' | sed -e 's/<a /\n<a /g' | sed -e 's/<a .*href=['"'"'"]//' -e 's/["'"'"'].*$//' -e '/^$/ d' > ${OPD}/links.tmp
fi

if [[ ! -f ${OPD}/links2.tmp ]]; then
  # Verif validite idA (id page de l'eBook)
  while read line; do
    LINK="idsession=${IDSESSION}&idA=$(echo ${line} | awk -F 'ida=' '{print $2}')"
    echo ${LINK} >> ${OPD}/links2.tmp
  done < ${OPD}/links.tmp
fi

# Rendre unique chaque lien
[[ ! -f ${OPD}/links.txt ]] && cat ${OPD}/links2.tmp | uniq > ${OPD}/links.txt

while read link; do
  #echo -n "${link} : "
  if [[ ! -z $(echo ${link} | grep -E "[0-9]+$") ]]; then
    echo -n "."
    #echo "good"
    PID="${OPD}/$(echo ${link} | awk -F 'idA=' '{print $2}').html"
    #echo ${PID}
    ## ON RECUPERE COMME UN GROS PORC LE CONTENU DES PAGES DE L'EBOOK
    ## VICTORY
    curl -s -X POST --data "${link}" http://www.eni-training.com/client_net/get_Resource.aspx > ${PID}
  fi
  # Pour éviter de faire trop de requetes rapprochees
  # Passe peut etre avec un sleep 1 mais bon...
  sleep 2
done < ${OPD}/links.txt

## On parse les fichiers html a la recherche d'images
if [[ ! -f ${OPD}/imgs.tmp ]]; then
  for file in ${OPD}/*.html; do
    echo -n "."
    # On stocke tous les liens bruts dans un fichier temporaire
    cat ${file} | grep -o '<img .*>' | sed -e 's/<img /\n<img /g' | sed -e 's/<img .*src=['"'"'"]//' -e 's/["'"'"'].*$//' -e '/^$/d' >> ${OPD}/imgs.tmp
  done
fi

# On recupere les images
while read line; do
  # si l'image existe deja, on skip
  if [[ -n $(echo ${line} | grep -E "^../") ]]; then
    echo -n "."
    IMG_LOCATION="http://www.eni-training.com$(echo ${line} | sed 's/..//')"
    IMG_NAME=$(echo ${IMG_LOCATION} | awk -F '?' '{print $1}' | awk -F 'images' '{print "images"$2}')
    [[ ! -f ${OPD}/${IMG_NAME} ]] && wget --quiet "${IMG_LOCATION}" -O ${OPD}/${IMG_NAME}
    sleep 2
  fi
done < ${OPD}/imgs.tmp

echo
echo "eBook ${IDR} disponible dans ${OPD}"

exit 0
