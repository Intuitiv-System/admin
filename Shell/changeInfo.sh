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
echo "Renseigner le nouveau mot de passe root"
read -s root_password
echo "root:$root_password" | chpasswd

exit 0
