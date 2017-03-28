#!/bin/sh

#Description. Script to deploy ocs inventory agent

test=$(whoami)
if [ "${test}" != "root" ]
then
  echo "This script must be run as root"
  exit 1
fi

mkdir /etc/ocsinventory
file="/etc/ocsinventory/ocsinventory-agent.cfg"

if [ -f ${file} ]; then
	rm ${file}
fi

cat >> ${file} << _EOF_
logfile=/var/log/ocsinventory/ocsng.log
server=http://ocs.itserver.fr/ocsinventory
basevardir=/var/lib/ocsinventory-agent
debug=1
ssl=0
user=agent
password=VzHN1YLtdX72
realm=Realm
_EOF_

mkdir /var/log/ocsinventory
touch /var/log/ocsinventory/ocsng.log
##Installation des dépendances
apt-get update --fix-missing
apt-get install dmidecode -y
apt-get install libxml-simple-perl -y
apt-get install libcompress-zlib-perl -y || apt-get install libio-compress-perl -y
apt-get install libnet-ip-perl -y
apt-get install libwww-perl -y
apt-get install libdigest-md5-perl -y
apt-get install libnet-ssleay-perl -y
apt-get install gcc make -y
##Téléchargement de la bonne version de l'agent

cd /root/
wget https://github.com/OCSInventory-NG/UnixAgent/releases/download/2.3/Ocsinventory-Unix-Agent-2.3.tar.gz
tar xvf Ocsinventory-Unix-Agent-2.3.tar.gz
cd /root/Ocsinventory-Unix-Agent-2.3/
env PERL_AUTOINSTALL=1 perl Makefile.PL
make
make install
ocsinventory-agent

exit 0
