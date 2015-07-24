#!/bin/bash
#
# Filename : post-receive_creation.sh
# Version  :  1.1
# Author   : mathieu androz
# Description :
# . Ask project name
# . Check if post-receive exists
# . Recover existing post-receive file content
# . Add SSH command to automatically update DEV server in post-receive file
#

GIT="/home/git/repositories"

usage() {
        ::
}

# Remove the first / if present
# The function takes 2 parameters :
# 1st : string to check
# 2nd : char to remove
removeFirstChar() {
        eval "string=\$$1"
        if [[ $(echo $string | cut -c 1) = $2 ]]; then
                result=$(echo $string | cut -c 2-)
                eval "$1=$result"
        fi
}

# Remove the last / if present
# The function takes 2 parameters
# 1st : string to check
# 2nd : char to remove
removeLastChar() {
        eval "string=\$$1"
        if [[ $(echo ${string:${#string} - 1}) = $2 ]]; then
                result=${string%?}
                eval "$1=$result"
        fi
}



#########################
#
#      MAIN
#
#########################


read -p "Enter the project name (ie. php/itmobile) : " PROJECT
read -p "Enter the DEV server IP : " DEVIP
read -p "Enter the SSH port of DEV server : " DEVSSHPORT
read -p "Enter the web user on DEV server : " WEBUSER
read -p "Enter the HOME path of th eproject on DEV server (ie. /home/projet) : " DEVHOME

removeFirstChar PROJECT "/"
removeLastChar PROJECT "/"
removeLastChar DEVHOME "/"

[[ ! -d ${GIT}/${PROJECT}.git/hooks/post-receive.secondary.d ]] && mkdir ${GIT}/${PROJECT}.git/hooks/post-receive.secondary.d

cat > ${GIT}/${PROJECT}.git/hooks/post-receive.secondary.d/post-receive_${PROJECT}.sh << EOF
#!/usr/bin/env bash
#
# Filename : post-receive
# Version  : 1.0
# Author   : mathieu androz
# Description :
# . Call the initial script associated to GitLab
# . Add ssh command to update a DEV server repository

# Update DEV server repository
/usr/bin/ssh -p ${DEVSSHPORT} -l root ${DEVIP} 'cd ${DEVHOME}/www && \
        export GIT_SSL_NO_VERIFY=true && \
        git pull && \
        chown -R ${WEBUSER}:${WEBUSER} ${DEVHOME}/www'

exit 0
EOF

chmod -R 755 ${GIT}/${PROJECT}.git/hooks/post-receive.secondary.d/
chown -R git:git ${GIT}/${PROJECT}.git/hooks/post-receive.secondary.d/

exit 0
