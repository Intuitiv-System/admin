#!/bin/bash

## Preparation de l'environnement :
#
# apt-get install python python-pip python-dev
# pip install xhtml2pdf

usage {
        echo "
        usage : ${0} FOLDER
"
}

BOOKNAME=${1}

for file in ${1}/*
do
        filename=$(basename "${file}")
        extension="${filename##*.}"
        if [[ "${extension}" = "html" ]]; then
                echo "${file}"
                xhtml2pdf "${file}" "${file}".pdf
        fi
done


exit 0
