ORA_HOME="$(cat /etc/passwd | grep -w "oracle" | awk -F ':' '{print $6}')"

function ora_query {
  su -c "sqlplus -s / as sysdba" - oracle <<EOF
set sqlp ""
set sqln off
set head off
set echo off
set term off
set wrap off
set flush off
set feed off
set trim on
set array 100
set pages 0
set feedback off
set verify off
${1};
QUIT;
EOF
}

function update_cree_user_file {
  if [[ ! -f "${ORA_HOME}/cree_user-1g.sql.bkp" ]]; then
    if [[ -z ${1} ]]; then
      TBS_AUTOEXT_VALUE="100M"
    else
      # Faire un check sur le format du parametre si il est passe a la fonction
      TBS_AUTOEXT_VALUE="${1}"
    fi
    cp ${ORA_HOME}/cree_user.sql ${ORA_HOME}/cree_user-1g.sql.bkp
    [[ -n $(cat ${ORA_HOME}/cree_user.sql | grep -w "1G") ]] && sed -i "s/1G/${TBS_AUTOEXT_VALUE}/g" "${ORA_HOME}/cree_user.sql"
  fi
}