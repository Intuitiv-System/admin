#!/bin/bash

###################################################
## Script de creation et suppression
## d'un utilisateur LDAP SAMBA
###################################################

#---------------------
## Variables
#---------------------

# IP du serveur LDAP
LDAPIP="192.168.0.10"
# LDAPDN = la racine du ldap
LDAPDN="dc=domain,dc=com"
# L'admin LDAP
LDAPADMIN="cn=admin,${LDAPDN}"
# Mot de passe admin LDAP
LDAPADMINPWD=""
# ou= des utilisateurs LDAP
LDAPOUUSERS="ou=Users,${LDAPDN}"
# ou= des groupes LDAP
LDAPOUGROUPS="ou=Groups,${LDAPDN}"

#---------------------
## Fonctions
#---------------------

# Qui suis-je ? Si je ne suis pas root, je ferme le script
qui_suis_je(){
	WHO=`whoami`
	if [ "${WHO}" != "root" ] ; then
		echo -e "Vous executez le script en tant que ${WHO}."
		echo -e "Veuillez relancer ce script en tant que root svp."
		echo -e "A bientot !"
		exit 1
	fi
}


# Pwgen est-il installe ?
pwgen_present() {
	PWGEN_OK=`dpkg --list | grep pwgen | cut -c 1-2`
	if [ "${PWGEN_OK}" != "ii" ] ; then
		echo -e "Pwgen n'est pas installe sur la machine.\nL'installation de pwgen va demarrer..."
		sleep 1
		echo -e "Installation en cours..."
		aptitude install -y pwgen > /dev/null
		echo -e "Pwgen a ete installe avec succes"
	fi
}

#Generation aleatoire d'un mot de passe
gen_pwd() {
	LDAPPWD=$(pwgen 8 -B -c -n -N 1)
	echo -e "Le mot de passe utilisateur genere pour ${LDAPLOGIN} est : ${LDAPPWD}"
	echo -e "\nCe mot de passe vous convient-il ?"
	select pwd_ok in yes no
	do
		case ${pwd_ok} in
			yes|oui|y)
				break
			;;
			no|non|n)
				echo -e "\nGeneration d'un nouveau mot de passe :"
				LDAPPWD=$(pwgen 8 -B -c -n -N 1)
				echo -e "nouveau mot de passe : ${LDAPPWD}"
				echo -e "Ce mot de passe convient-il ? (yes = 1 / no = 2)"
				continue
			;;
		esac
	done
}

enter_ldap_infos() {
	read -p "Entrer le nom de l'utilisateur : " LDAPNAME
	read -p "Entrer le prenom de l'utilisateur : " LDAPFIRSTNAME
	read -p "Entrer le login : " LDAPLOGIN
	gen_pwd
	echo -e "\nResume des informations utilisateur :"
	echo -e "Nom utilisateur : \e[0;31m ${LDAPNAME} \e[0m"
	echo -e "Prenom utilisateur : \e[0;31m ${LDAPFIRSTNAME} \e[0m"
	echo -e "Login utilisation : \e[0;31m ${LDAPLOGIN} \e[0m"
	echo -e "Mot de passe utilisateur : \e[0;31m ${LDAPPWD} \e[0m\n"
}

add2ldapgroup() {
	echo -e "\nA quel groupe voulez-vous que ${LDAPLOGIN} appartient ?"
	echo -e "Les groupes LDAP proposes sont :"
	select LDAPGROUP in \
		"Domain Users" \
		"Domain Admins" \
		"Domain Guests" \
		"Domain Computers"
	do
		echo -e "Le groupe choisi est ${LDAPGROUP}"
		read -p "Est-ce correct (yes/no) ? : " CORRECT
		case ${CORRECT} in
			yes|oui|y)
				smbldap-groupmod -m ${LDAPLOGIN} "${LDAPGROUP}"
				break
			;;
			no|non|n)
				continue
			;;
			*)
				continue
			;;
		esac
	done
}

check_user_exists() {
	read -p "Entrer le login de l'utilisateur a supprimer : " LDAPLOGIN
	CHECK=$(ldapsearch -h ${LDAPIP} -D ${LDAPADMIN} -w ${LDAPADMINPWD} -b ${LDAPOUUSERS} | \
        egrep '^dn: uid' | \
        awk -F"," '{print $1}' | \
        cut -c 9- | \
        sed -n -e '/^'"${LDAPLOGIN}"'$/p')

	if [ "${CHECK}" == "${LDAPLOGIN}" ] ; then
    	suppress_user
	else
		echo -e "L'utilisateur LDAP ${LDAPLOGIN} n'existe pas.\n\n"
		check_user_exists
	fi
}

suppress_user() {
	echo -e "Vous allez supprimer l'utilisateur LDAP : \e[0;31m ${LDAPLOGIN} \e[0m \n"
	echo -e "Etes-vous sur ?"
	select supp_choix in yes no
	do
		case ${supp_choix} in
			yes)
				smbldap-userdel -r "${LDAPLOGIN}"
				echo -e "L'utilisateur LDAP ${LDAPLOGIN} a été supprimé avec succès."
				break
			;;
			no)
				check_user_exists
				break
			;;
			*)
				echo -e "Veuillez entrer 1 ou 2 ..."
				continue
			;;
		esac
	done
}


ask_group() {
    read -p "Entrer le nom du groupe à créer : " LDAPGROUPNAME
    echo -e "\nVous allez créer le groupe LDAP :\e[0;31m ${LDAPGROUPNAME} \e[0m \n"
    echo -e "Etes-vous sur ?"
}


create_group() {
	select choix in yes no
	do
    	case ${choix} in
        	yes)
        	    smbldap-groupadd -a "${LDAPGROUPNAME}"
            	break
        	;;
        	no)
            	ask_group
            	continue
        	;;
        	*)
            	echo -e "Veuillez entrer 1 ou 2 ..."
           		continue
        	;;
    	esac
	done
	echo -e "Le groupe ${LDAPGROUPNAME} a été crée avec succès !"
}


check_group_exists() {
    read -p "Entrer le CN du groupe a supprimer : " LDAPGROUP
    CHECK=$(ldapsearch -h ${LDAPIP} -D ${LDAPADMIN} -w ${LDAPADMINPWD} -b ${LDAPOUGROUPS} | \
        egrep '^dn: cn' | \
        awk -F"," '{print $1}' | \
        cut -c 8- | \
        sed -n -e '/^'"${LDAPLOGIN}"'$/p')

    if [ "${CHECK}" == "${LDAPLOGIN}" ] ; then
        suppress_group
    else
        echo -e "Le groupe LDAP ${LDAPGROUP} n'existe pas.\n\n"
        check_group_exists
    fi
}

suppress_group() {
    echo -e "Vous allez supprimer le groupe LDAP : \e[0;31m ${LDAPGROUP} \e[0m \n"
    echo -e "Etes-vous sur ?"
    select supp_choix in yes no
    do
        case ${supp_choix} in
            yes)
                smbldap-groupdel -r "${LDAPGROUP}"
                echo -e "Le groupe LDAP ${LDAPGROUP} a été supprimé avec succès."
                break
            ;;
            no)
                check_group_exists
                break
            ;;
            *)
                echo -e "Veuillez entrer 1 ou 2 ..."
                continue
            ;;
        esac
    done
}


#-----------------
## MAIN
#-----------------

clear

echo -e "Que souhaitez-vous faire ?"
select choix in \
	"Ajouter un utilisateur LDAP" \
	"Supprimer un utilisateur LDAP" \
	"Ajouter un groupe LDAP"
do
	case ${choix} in
		"Ajouter un utilisateur LDAP")
			echo -e "---------------------------------------------------\n \
       			   Creation d'un utilisateur LDAP SAMBA\n \
			---------------------------------------------------"

			qui_suis_je
			pwgen_present
			echo ""
			enter_ldap_infos

			echo -e "\nLes informations sont-elles exactes ?"
			select infos_ok in yes no
			do
				case ${infos_ok} in
					yes|oui|y)
						smbldap-useradd -a -N "${LDAPFIRSTNAME}" -S "${LDAPNAME}" -c "${LDAPFIRSTNAME} ${LDAPNAME}" -m -P ${LDAPLOGIN}
						#smbldap-groupmod -m ${LDAPLOGIN} "Domain Users"
						add2ldapgroup
						#smbldap-passwd ${LDAPLOGIN}
						break
					;;
					no|non|n)
						echo -e "\nNouvelle saisie :"
						enter_ldap_infos
						echo -e "\nLes informations sont-elles exactes ? (yes = 1 / no = 2) : "
						continue
					;;
					*)
						echo "Veuillez entrer 1 ou 2 ..."
						continue
					;;
				esac
			done
			exit 0
		;;
		"Supprimer un utilisateur LDAP")
			check_user_exists
			break
		;;
		"Ajouter un groupe LDAP")
			ask_group
			create_group
			break
		;;
		*)
			echo -e "Je n'ai pas saisi votre choix"
			echo -e "Veuillez entre 1 ou 2 ..."
			continue
		;;
	esac
done

exit 0
