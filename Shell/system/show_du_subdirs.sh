#!/bin/bash
# Affiche le poids des sous-dossiers du dossier passe en parametre
clear

function usage {
  echo "$0 DIRECTORY [SIZETYPE]
  PARAMS :
    DIRECTORY   Required        Directory path. Must be defined and not be '/'
    SIZETYPE    Optional        Grab size type.
      Example : \"M\" for folders which weigth Mega
                \"M|G\" for folders which weigth Mega or Giga
"
  exit 1
}

if [[ -z "${1}" ]] || [[ ! -d "${1}" ]] || [[ "${1}" == "/" ]]; then
  usage
fi

DU_DIR="${1}"

KEEP=""
[[ -n ${2} ]] && KEEP="[${2}]"

LIST_VAR=$(for FOLDER in $(find ${DU_DIR}/* -maxdepth 1 -type d); do du -sh ${FOLDER}; done);

echo "${LIST_VAR}" | grep -E "^[0-9,]+${KEEP}"