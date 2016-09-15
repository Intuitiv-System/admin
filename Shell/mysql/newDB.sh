#!/bin/bash

## Création BDD et USER

S1='utf8'
S2='utf8mb4'

if [ -z "$1" ]
then
  echo -e "Usage:
  ./newDB.sh utf8
  or
  ./newDB.sh utf8mb4"
exit 1
fi

echo -e "Enter un nom d'utilisateur SQL\n"
read username

if [ "$1" = "$S1" ]
then
  echo "Password for SQL user: ${username}"
  read -s password
  echo "Confirmer le mot de passe SQL pour ${username}"
  read -s password2
  while [ "${password}" != "${password2}" ]
    do
      echo -e "Password don't match\n"
      echo "Password for SQL user: ${username}"
      read -s password
      echo "Confirmer le mot de passe SQL pour ${username}"
      read -s password2
    done
     Q1="CREATE DATABASE IF NOT EXISTS ${username} CHARACTER SET utf8;"
     Q2="CREATE USER '${username}'@'localhost' IDENTIFIED BY '${password}';"
     Q3="GRANT ALL PRIVILEGES ON ${username}.* TO '${username}'@'localhost';"
     Q4="FLUSH PRIVILEGES;"
     SQL="${Q1}${Q2}${Q3}${Q4}"

     mysql -u root -p -e "${SQL}"
elif [ "$1" = "$S2" ]
then
   echo "Password for SQL user: ${username}"
   read -s password
   echo "Confirmer le mot de passe SQL pour ${username}"
   read -s password2
   while [ "${password}" != "${password2}" ]
     do
      echo -e "Password don't match\n"
      echo "Password for SQL user: ${username}"
      read -s password
      echo "Confirmer le mot de passe SQL pour ${username}"
      read -s password2
     done
  Q1="CREATE DATABASE IF NOT EXISTS ${username} CHARACTER SET utf8mb4;"
  Q2="CREATE USER '${username}'@'localhost' IDENTIFIED BY '${password}';"
  Q3="GRANT ALL PRIVILEGES ON ${username}.* TO '${username}'@'localhost';"
  Q4="FLUSH PRIVILEGES;"
  SQL="${Q1}${Q2}${Q3}${Q4}"

  mysql -u root -p -e "${SQL}"

fi

exit 0
