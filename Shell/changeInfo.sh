#!/bin/bash
echo "Dans quel subnet va se trouver la machine ?"
echo "1) 164.132.82.32/27"
echo "2) 37.59.237.160/27 "
read choice

case $choice in
  1*)
    echo "Renseigner l'adresse IP du serveur"
    read ip_addr

    cat >> /etc/network/interfaces << _EOF_
    auto eth0
      iface eth0 inet static
        address $ip_addr
        netmask 255.255.255.224
        network 164.132.82.32
        broadcast 164.132.82.63
        gateway 164.132.82.62

        dns-nameservers 213.186.33.99
        dns-search itserver.fr

_EOF_
;;

  2*)
     echo "Renseigner l'adresse IP du serveur"
     read ip_addr

             cat >> /etc/network/interfaces << _EOF_
          auto eth0
          iface eth0 inet static
          address $ip_addr
          netmask 255.255.255.224
          network 37.59.237.160
          broadcast 37.59.237.191
          gateway 37.59.237.190


          dns-nameservers 213.186.33.99
          dns-search itserver.fr

_EOF_
;;

esac
echo "Renseigner le nom de la machine"
read name
echo "${name}" > /etc/hostname
sed -i 's/template/'"${name}"'/g' /etc/hosts
service hostname.sh
echo -e "127.0.0.1\t ${name}.itserver.fr\t ${name} \t localhost" > /etc/hosts
echo "Renseigner le nouveau mot de passe root"
read -s root_password
echo "root:$root_password" | chpasswd

read -s -p "Enter MYSQL root password: " mysqlRootPassword
echo ""
read -s -p "Confirm MYSQL root password: " mysqlRootPassword2
echo ""

while [ "${mysqlRootPassword}" != "${mysqlRootPassword2}" ]
do
  echo "Passwords don't match !"
  read -s -p "Enter MYSQL root password: " mysqlRootPassword
  echo ""
  read -s -p "Confirm MYSQL root password: " mysqlRootPassword2
done

oldpwd="b96DV0u72MK4lobslZdS"
SQLQUERY="SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${mysqlRootPassword}');"

mysql -u root -p$oldpwd -e "${SQLQUERY}"

echo "Voici le nouveau mot de passe root SQL : ${mysqlRootPassword}"

##Mise en place du user pour backuppc
useradd -m -s /bin/bash backupit
echo "backupit ALL=NOPASSWD: /usr/bin/rsync" >> /etc/sudoers
runuser -l backupit -c 'ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa' > /dev/null 2>&1
runuser -l backupit -c 'echo "sh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC/7UY/Fjwt1RNWvE2qBa1YEbqF8DIyUYgPiDCeLKIlwt6X2cjHnQJpzzLqKOT64MGvl5/msvi8bco46NWHnaxc2o5hh3rNCUyN2ZGJHAsE+37CekQAmiqtTHXjCpNOExK6570ZJjOhjO9G/w7pqSIHmLgSMwXcplSBAFUxGDxNTpSw75sCi0L5+14R8yx42rxMovxVfac0psVUhhIHwZbd2JxeeGv8yq69BhBi3758RDsgmkQOGk2fKVLmAu4WcEqdOGtNQNDE2d/F+0x6SnwTO8GkTrbTFPfwoKvTzvXXs1jf5raL8QQ8r+7xtXxEZnNFBsucy5I6HcZ+YM6xRKYB backuppc@bkp02.itserver.fr" > /home/backupit/.ssh/authorized_keys' 

exit 0
