#!/bin/bash
#
# Filename : nosu.sh
# Version  : 1.1
# Author   : Olivier RENARD
#
# Use this script for a server already in production, in order to disable access to the su command
# Check for all existing standards users
#
# . Check if an allowed user is defined
# . Enable restriction for su command to nosu group
# . Retrieve all web users, based on MIN_IUD and MAX_UID defined in login.defs
# . Check if the group 'nosu' exists. If not, it is created
# . Add web users to the nosu group, depending of the ${METHOD} variable (0 : automatic add / 1 : asking before add)

clear

ALLOWED_USER=""

## Method=0 : automatically add users in nosu group
## Method=1 : ask to add users in nosu group
METHOD="1"

usage() {
    ::
}

show_errors() {
    ERR_CODE=${1}
    case ${ERR_CODE} in
        1) MSG="No user is allowed to exec 'su' command!";;
        *) MSG="Unknown error code : ${ERR_CODE}";;
    esac
    echo -e "${MSG}\nexiting\n"
    exit ${ERR_CODE}
}

check_allowed_user() {
    [[ -z ${ALLOWED_USER} ]] && show_errors 1
}

enable_group_nosu() {
    sed -i "s/# \(auth.*group=nosu\)/\1/g" /etc/pam.d/su && \
    echo "Enable restriction for su command to nosu group members : [OK]"
}

get_web_users() {
    ## get mini UID limit ##
    l=$(grep "^UID_MIN" /etc/login.defs)

    ## get max UID limit ##
    l1=$(grep "^UID_MAX" /etc/login.defs)

    ## use awk to print if UID >= ${MIN} and UID <= ${MAX}   ##
    WEB_USERS=$(awk -F':' -v "min=${l##UID_MIN}" -v "max=${l1##UID_MAX}" \
                '{ if ( $3 >= min && $3 <= max ) print $1}' /etc/passwd)
}

ask_nosu() {
    read -p "Add ${WEB_USER} to 'nosu' group [Y/n] : " CONFIRM_NOSU
    CONFIRM_NOSU=${CONFIRM_NOSU:-Y}
    case ${CONFIRM_NOSU} in
        Y|y|O|o*) usermod -G nosu ${WEB_USER} && \
                  echo "Adding ${WEB_USER} to 'nosu' group : [OK]";;
        *) echo "Adding ${WEB_USER} cancelled!"
    esac
}

add_nosu() {
    echo -n "Add user ${WEB_USER} in nosu group : " && \
    usermod -G nosu ${WEB_USER} && echo "[OK]" || echo "[FAIL]"
}

check_group() {
    if [[ -z $(cut -d":" -f1 /etc/group | grep "nosu") ]]; then
        groupadd nosu
        echo "Creation of the nosu group : [OK]"
    fi
}

check_users() {
    if [[ -z $(cut -d":" -f1 /etc/passwd | grep "^${ALLOWED_USER}$") ]]; then
        echo "[WARN] User ${ALLOWED_USER} not found. Creation..."
        adduser ${ALLOWED_USER}
    fi

    for WEB_USER in ${WEB_USERS}; do
        if [[ ${WEB_USER} != "${ALLOWED_USER}" ]]; then
            if [[ -z $(cut -d":" -f4 /etc/group | grep ",${WEB_USER},") ]]; then
                if [[ ${METHOD} -eq 1 ]]; then
                    read -p "Add ${WEB_USER} to 'nosu' group [Y/n] : " CONFIRM_NOSU
                    CONFIRM_NOSU=${CONFIRM_NOSU:-Y}
                    case ${CONFIRM_NOSU} in
                        Y|y|O|o*) usermod -G nosu ${WEB_USER} && \
                                  echo "Adding ${WEB_USER} to 'nosu' group : [OK]";;
                        *) echo "Adding ${WEB_USER} cancelled!"
                    esac
                else
                    echo -n "Add user ${WEB_USER} in nosu group : " && \
                    usermod -G nosu ${WEB_USER} && echo "[OK]" || echo "[FAIL]"
                fi
                ask_nosu
                #add_nosu
            fi
        fi
    done    
}

############
### MAIN ###
############

check_allowed_user

enable_group_nosu

get_web_users

check_group

check_users
