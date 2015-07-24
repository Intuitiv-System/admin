Install serveur de mails :

apt-get install postfix postfix-pcre libsasl2-2 libsasl2-modules sasl2-bin openssl ntp


On faut une configuration Site internet puis dpkg-reconfigure postfix :

Configuration type du serveur de messagerie : Site Internet
Nom de courrier: server1.example.com
Destination des courriels de "root" et de "postmaster":
Autres destinations pour lesquelles le courrier sera accepté (champ vide autorisé): server1.example.com, localhost.example.com, localhost.localdomain, localhost
Faut-il forcer des mises à jour synchronisées de la file d\'attente des courriels: Non
Réseaux internes:127.0.0.0/8
Faut-il utiliser procmail pour la distribution locale: Oui
Taille maximale des boîtes aux lettres: 0 (pas de limite; vous pouvez en fixer une)
Caractère d'extension des adresses locales: +
Protocoles internet à utiliser: tous

On édite le fichier main.cf avec les commandes suivantes :

POSTFIXPATH="/etc/postfix"
MAIN="${POSTFIXPATH}/main.cf"

if [[ -f ${MAIN} ]]; then
    cp ${MAIN} ${MAIN}.orig
    echo "
# Add 
smtpd_recipient_restrictions = permit_sasl_authenticated,permit_mynetworks,reject_unauth_destination
inet_interfaces = all
" >> ${MAIN}

    test ! -d ${POSTFIXPATH}/sasl && mkdir ${POSTFIXPATH}/sasl
    echo 'pwcheck_method: saslauthd' >> ${POSTFIXPATH}/sasl/smtpd.conf
    echo 'mech_list: plain login' >> ${POSTFIXPATH}/sasl/smtpd.conf
fi


On rajoute également ce bloc dans main.cf pour la partie SASL :

# SASL bloc
smtpd_sasl_auth_enable = yes
smtpd_sasl_local_domain = $mydomain       # le nom du domaine d\'authentification SASL
smtpd_sasl_path = smtpd                   # smtpd_sasl_path: détermine l'emplacement du fichier contenant les paramètres SASL. La construction de ce chemin est la suivante : le chemin par défaut est /etc/postfix/sasl/[VARIABLE].conf
smtpd_sasl_security_options = noanonymous
#smtpd_sasl_authenticated_header = no     # fait apparaitre le status d'authentification dans le header de l'email envoyé
broken_sasl_auth_clients = yes




Creation des certificats :


test ! -d /etc/postfix/ssl && mkdir /etc/postfix/ssl
cd /etc/postfix/ssl/
openssl genrsa -des3 -rand /etc/hosts -out smtpd.key 1024

chmod 600 smtpd.key
openssl req -new -key smtpd.key -out smtpd.csr

openssl x509 -req -days 3650 -in smtpd.csr -signkey smtpd.key -out smtpd.crt

openssl rsa -in smtpd.key -out smtpd.key.unencrypted

mv -f smtpd.key.unencrypted smtpd.key
openssl req -new -x509 -extensions v3_ca -keyout cakey.pem -out cacert.pem -days 3650


Configuration de Postfix pour TLS :

postconf -e 'smtpd_tls_auth_only = yes'
postconf -e 'smtp_use_tls = yes'
postconf -e 'smtpd_use_tls = yes'
postconf -e 'smtp_tls_note_starttls_offer = yes'
postconf -e 'smtpd_tls_key_file = /etc/postfix/ssl/smtpd.key'
postconf -e 'smtpd_tls_cert_file = /etc/postfix/ssl/smtpd.crt'
postconf -e 'smtpd_tls_CAfile = /etc/postfix/ssl/cacert.pem'
postconf -e 'smtpd_tls_loglevel = 1'
postconf -e 'smtpd_tls_received_header = yes'
postconf -e 'smtpd_tls_session_cache_timeout = 3600s'
postconf -e 'tls_random_source = dev:/dev/urandom'
postconf -e 'myhostname = test1.intuitiv.lan'


/etc/init.d/postfix restart

mkdir -p /var/spool/postfix/var/run/saslauthd



Editer /etc/default/saslauthd :

# Should saslauthd run automatically on startup? (default: no)
START=yes
# Note: See /usr/share/doc/sasl2-bin/README.Debian
OPTIONS="-c -m /var/spool/postfix/var/run/saslauthd -r"

Puis : /etc/init.d/saslauthd restart


On teste : telnet localhost 25
ehlo localhost

Il faut avoir les lignes suivantes dans la réponse :
250-STARTTLS
250-AUTH PLAIN LOGIN
quit



##############
# Creation d'un utilisateur dans la base de données sasldb
    command : saslpasswd2 -c username
    ATTENTION !!! les mots de passe ne doivent pas commencer par un chiffre !!!!!


# IMPORTANT, arreter le service saslauth et lancer ces 2 commandes !!!
adduser postfix sasl
rm -rf /var/run/saslauthd
ln -s /var/spool/postfix/var/run/saslauthd /var/run/saslauthd



AIDE : 
http://www.alsacreations.com/tuto/lire/614-Serveur-mail-Postfix.html
http://wiki.linuxwall.info/doku.php/fr:ressources:dossiers:postfix:authentification_sasl
http://postfix.traduc.org/index.php/SMTPD_ACCESS_README.html
http://postfix.traduc.org/index.php/SASL_README.html
http://www.postfix.org/SASL_README.html#testing_saslauthd
http://gogs.info/books/debian-mail/chunked/postfix.sasl.html


Un fichier main.cf qui fonctionne :::


#########################################################
#########################################################
#########################################################
# See /usr/share/postfix/main.cf.dist for a commented, more complete version


# Debian specific:  Specifying a file name will cause the first
# line of that file to be used as the name.  The Debian default
# is /etc/mailname.
#myorigin = /etc/mailname

smtpd_banner = $myhostname ESMTP $mail_name (Debian/GNU)
biff = no

# appending .domain is the MUA's job.
append_dot_mydomain = no

# Uncomment the next line to generate "delayed mail" warnings
#delay_warning_time = 4h

readme_directory = no

# TLS parameters
smtpd_tls_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
smtpd_tls_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
smtpd_use_tls=yes
smtpd_tls_session_cache_database = btree:${data_directory}/smtpd_scache
smtp_tls_session_cache_database = btree:${data_directory}/smtp_scache

# See /usr/share/doc/postfix/TLS_README.gz in the postfix-doc package for
# information on enabling SSL in the smtp client.

myhostname = test1.intuitiv.lan
alias_maps = hash:/etc/aliases
alias_database = hash:/etc/aliases
myorigin = /etc/mailname
mydestination = test1.intuitiv.lan, localhost.intuitiv.lan, , localhost
relayhost =
mynetworks = 192.168.1.0/24 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
mailbox_command = procmail -a "$EXTENSION"
mailbox_size_limit = 0
recipient_delimiter = +
inet_interfaces = all
inet_protocols = all

#### TLS
smtp_use_tls = yes
smtp_tls_note_starttls_offer = yes
smtpd_tls_auth_only = yes
smtpd_use_tls = yes
smtpd_tls_key_file = /etc/postfix/ssl/smtpd.key
smtpd_tls_cert_file = /etc/postfix/ssl/smtpd.crt
smtpd_tls_CAfile = /etc/postfix/ssl/cacert.pem
smtpd_tls_loglevel = 1
smtpd_tls_received_header = yes
smtpd_tls_session_cache_timeout = 3600s
tls_random_source = dev:/dev/urandom
smtpd_recipient_limit = 100
smtpd_helo_restrictions = reject_invalid_hostname
smtpd_sender_restrictions = reject_unknown_address
smtpd_recipient_restrictions = permit_sasl_authenticated,reject_unauth_destination,permit_mynetworks,reject_unknown_sender_domain,reject_unknown_client,reject_rbl_client zen.spamhaus.org,reject_rbl_client bl.spamcop.net,reject_rbl_client cbl.abuseat.org,permit

#### SASL
smtpd_sasl_local_domain =
smtpd_sasl_auth_enable = yes
smtpd_sasl_security_options = noanonymous
broken_sasl_auth_clients = yes
smtpd_sasl_authenticated_header = yes

#########################################################
#########################################################
#########################################################





















