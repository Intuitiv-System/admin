#!/bin/bash

## Création BDD et USER
echo -e "Enter un nom d'utilisateur SQL\n"
read username
echo -e "Choisir le format de DB\n"
echo "1). utf8"
echo "2). utf8mb4"

read choice

if [ $choice -eq 1 ]
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
elif [ $choice -eq 2 ]
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

else
  echo "Choisir une bonne valeur"
  exit 1
fi

exit 0
