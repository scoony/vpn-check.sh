#!/bin/bash

########################
## Script de Scoony
########################
## Installation: wget -q https://pastebin.com/raw/cz5Hm09d -O vpn-check.sh && sed -i -e 's/\r//g' vpn-check.sh && chmod +x vpn-check.sh
## Micro-config
version="Version: 0.0.0.1" #base du système de mise à jour
description="Surveillance du VPN" #description pour le menu
description_eng="VPN Oversight" #description pour le menu
script_pastebin="https://raw.githubusercontent.com/scoony/vpn-check.sh/main/vpn-check.sh" #emplacement du script original
changelog_pastebin="https://pastebin.com/raw/EmMx3prX" #emplacement du changelog de ce script
langue_fr="https://pastebin.com/raw/6Jm93AM5"
langue_eng="https://pastebin.com/raw/BvTwP75g"
icone_imgur="http://i.imgur.com/AYf9uNb.png" #emplacement de l'icône du script
required_repos="ppa:neurobin/ppa" #ajout de repository
required_tools="net-tools ethtool bc curl shc" #dépendances du script (APT)
required_tools_pip="" #dépendances du script (PIP)
script_cron="* * * * *" #ne définir que la planification
verification_process="" #si ces process sont détectés on ne notifie pas (ou ne lance pas en doublon)
########################

#### Vérification de la langue du system
if [[ "$@" =~ "--langue=FR" ]] || [[ "$@" =~ "--langue=ENG" ]]; then
  if [[ "$@" =~ "--langue=FR" ]]; then
    affichage_langue="french"
  else
    affichage_langue="english"
  fi
else
  os_langue=$(locale | grep LANG | sed -n '1p' | cut -d= -f2 | cut -d_ -f1)
  if [[ "$os_langue" == "fr" ]]; then
    affichage_langue="french"
  else
    affichage_langue="english"
  fi
fi

#### Déduction des noms des fichiers (pour un portage facile)
mon_script_fichier=`basename "$0"`
mon_script_base=`echo ''$mon_script_fichier | cut -f1 -d'.'''`
mon_script_base_maj=`echo ${mon_script_base^^}`
mon_script_config=`echo "/root/.config/"$mon_script_base"/"$mon_script_base".conf"`
mon_script_ini=`echo "/root/.config/"$mon_script_base"/"$mon_script_base".ini"`
mon_script_langue=`echo "/root/.config/"$mon_script_base"/"$affichage_langue".lang"`
mon_script_log=`echo $mon_script_base".log"`
mon_script_desktop=`echo $mon_script_base".desktop"`
mon_script_updater=`echo $mon_script_base"-update.sh"`

#### Chargement du fichier pour la langue (ou installation)
if [[ "$affichage_langue" == "french" ]]; then
  langue_distant_check=`wget -q -O- "$langue_fr" | sed 's/\r//g' | wc -c`
##  echo "Langue: FR"
##  echo "Distant: "$langue_distant_check
else
  langue_distant_check=`wget -q -O- "$langue_eng" | sed 's/\r//g' | wc -c`
##  echo "Langue: ENG"
##  echo "Distant: "$langue_distant_check
fi
langue_local_check=`cat "$mon_script_langue" 2>/dev/null | wc -c`
##echo "Local: "$langue_local_check
if [[ "$langue_distant_check" != "$langue_local_check" ]]; then
  if [[ "$affichage_langue" == "french" ]]; then
    echo "mise à jour du fichier de language disponible"
    echo "téléchargement de la mise à jour et installation..."
    wget -q "$langue_fr" -O "$mon_script_langue" 
    sed -i -e 's/\r//g' $mon_script_langue
  else
    echo "language file update available"
    echo "downloading and applying update..."
    wget -q "$langue_eng" -O "$mon_script_langue"
    sed -i -e 's/\r//g' $mon_script_langue
  fi
fi
source $mon_script_langue

#### Vérification que le script possède les droits root
## NE PAS TOUCHER
if [[ "$EUID" != "0" ]]; then
  if [[ "$CRON_SCRIPT" == "oui" ]]; then
    exit 1
  else
    if [[ "$CHECK_MUI" != "" ]]; then
      source $mon_script_langue
      echo "$mui_root_check"
    else
      echo "Vous devrez impérativement utiliser le compte root"
    fi
    exit 1
  fi
fi

#### Fonction pour envoyer des push
push-message() {
  push_title=$1
  push_content=$2
  for user in {1..10}; do
    destinataire=`eval echo "\\$destinataire_"$user`
    if [ -n "$destinataire" ]; then
      curl -s \
        --form-string "token=$token_app" \
        --form-string "user=$destinataire" \
        --form-string "title=$push_title" \
        --form-string "message=$push_content" \
        --form-string "html=1" \
        --form-string "priority=0" \
        https://api.pushover.net/1/messages.json > /dev/null
    fi
  done
}

#### Vérification de process pour éviter les doublons (commandes externes)
for process_travail in $verification_process ; do
  process_important=`ps aux | grep $process_travail | sed '/grep/d'`
  if [[ "$process_important" != "" ]] ; then
    if [[ "$CRON_SCRIPT" != "oui" ]] ; then
      if [[ "$CHECK_MUI" != "" ]]; then
        source $mon_script_langue
        echo $process_important"$mui_prevent_dupe_task"
      else
        echo $process_important" est en cours de fonctionnement, arrêt du script"
      fi
      fin_script=`date`
      if [[ "$CHECK_MUI" != "" ]]; then
        source $mon_script_langue
        echo -e "$mui_end_of_script"
      else
        if [[ "$CHECK_MUI" != "" ]]; then
          source $mon_script_langue
          echo -e "$mui_end_of_script"
        else
          echo -e "\e[43m -- FIN DE SCRIPT: $fin_script -- \e[0m "
        fi
      fi
    fi
    exit 1
  fi
done

#### Tests des arguments
if [[ "$1" == "--version" ]]; then
  echo "$version"
  exit 1
fi
if [[ "$1" == "--debug" ]] || [[ "$2" == "--debug" ]]; then
  debug="yes"
fi
if [[ "$1" == "--edit-config" ]]; then
  nano $mon_script_config
  exit 1
fi
if [[ "$1" == "--debug" ]] || [[ "$2" == "--debug" ]]; then
  debug="yes"
fi
if [[ "$1" == "--efface-lock" ]]; then
  mon_lock=`echo "/root/.config/"$mon_script_base"/lock-"$mon_script_base`
  rm -f "$mon_lock"
  echo "Fichier lock effacé"
  exit 1
fi
if [[ "$1" == "--statut-lock" ]]; then
  statut_lock=`cat $mon_script_config | grep "maj_force=\"oui\""`
  if [[ "$statut_lock" == "" ]]; then
    echo "Système de lock activé"
  else
    echo "Système de lock désactivé"
  fi
  exit 1
fi
if [[ "$1" == "--active-lock" ]]; then
  sed -i 's/maj_force="oui"/maj_force="non"/g' $mon_script_config
  echo "Système de lock activé"
  exit 1
fi
if [[ "$1" == "--desactive-lock" ]]; then
  sed -i 's/maj_force="non"/maj_force="oui"/g' $mon_script_config
  echo "Système de lock désactivé"
  exit 1
fi
if [[ "$1" == "--extra-log" ]] || [[ "$2" == "--extra-log" ]]; then
  date_log=`date +%Y%m%d`
  heure_log=`date +%H%M`
  path_log=`echo "/root/.config/"$mon_script_base"/log/"$date_log`
  mkdir -p $path_log 2>/dev/null
  fichier_log_perso=`echo $path_log"/"$heure_log".log"`
  mon_log_perso="| tee -a $fichier_log_perso"
fi
if [[ "$1" == "--purge-process" ]]; then
  ps aux | grep $mon_script_base | awk '{print $2}' | xargs kill -9
  echo "Les processus de ce script ont été tués"
fi
if [[ "$1" == "--purge-log" ]]; then
  path_global_log=`echo "/root/.config/"$mon_script_base"/log"`
  cd $path_global_log
  mon_chemin=`echo $PWD`
  if [[ "$mon_chemin" == "$path_global_log" ]]; then
    printf "Êtes-vous sûr de vouloir effacer l'intégralité des logs de --extra-log? (oui/non) : "
    read question_effacement
    if [[ "$question_effacement" == "oui" ]]; then
      rm -rf *
      echo "Les logs ont été effacés"
    fi
  else
    echo "Une erreur est survenue, veuillez contacter le développeur"
  fi
  exit 1
fi
if [[ "$1" == "--changelog" ]]; then
  wget -q -O- $changelog_pastebin
  echo ""
  exit 1
fi
if [[ "$1" == --message=* ]]; then
  source $mon_script_config
  message=`echo "$1" | sed 's/--message=//g'`
  for user in {1..10}; do
    destinataire=`eval echo "\\$destinataire_"$user`
    if [ -n "$destinataire" ]; then
      curl -s \
        --form-string "token=$token_app" \
        --form-string "user=$destinataire" \
        --form-string "title=Un processus bloque selfcheck" \
        --form-string "message=$push_content" \
        --form-string "html=1" \
        --form-string "priority=0" \
        https://api.pushover.net/1/messages.json > /dev/null
      fi
    done
  exit 1
fi
if [[ "$1" == "--help" ]]; then
  if [[ "$CHECK_MUI" != "" ]]; then
    i=""
    for i in _ {a..z} {A..Z}; do eval "echo \${!$i@}" ; done | xargs printf "%s\n" | grep mui_menu_help > variables
    help_lignes=`wc -l variables | awk '{print $1}'`
##    cat variables
##    echo $help_lignes
    rm -f variables
    j=""
    mui_menu_help="mui_menu_help_"
    path_log=`echo "/root/.config/"$mon_script_base"/log/"$date_log`
    for j in $(seq 1 $help_lignes); do
      source $mon_script_langue
      mui_menu_help_display=`echo -e "$mui_menu_help$j"`
##      echo $mui_menu_help_display
      echo -e "${!mui_menu_help_display}"
    done
    exit 1
  fi
  if [[ "$CHECK_MUI" == "" ]]; then
    path_log=`echo "/root/.config/"$mon_script_base"/log/"$date_log`
    echo -e "\e[1m$mon_script_base_maj\e[0m ($version)"
    echo "Objectif du programme: $description"
    echo "Auteur: Sc00nY <scoonydeus@gmail.com>"
    echo ""
    echo "Utilisation: \"$mon_script_fichier [--option]\""
    echo ""
    echo -e "\e[4mOptions:\e[0m"
    echo "  --version               Affiche la version de ce programme"
    echo "  --edit-config           Édite la configuration de ce programme"
    echo "  --extra-log             Génère un log à chaque exécution dans "$path_log
    echo "  --debug                 Lance ce programme en mode debug"
    echo "  --efface-lock           Supprime le fichier lock qui empêche l'exécution"
    echo "  --statut-lock           Affiche le statut de la vérification de process doublon"
    echo "  --active-lock           Active le système de vérification de process doublon"
    echo "  --desactive-lock        Désactive le système de vérification de process doublon"
    echo "  --maj-uniquement        N'exécute que la mise à jour"
    echo "  --changelog             Affiche le changelog de ce programme"
    echo "  --help                  Affiche ce menu"
    echo ""
    echo "Les options \"--debug\" et \"--extra-log\" sont cumulables"
    echo ""
    echo -e "\e[4mUtilisation avancée:\e[0m"
    echo "  --message=\"...\"         Envoie un message push au développeur (urgence uniquement)"
    echo "  --purge-log             Purge définitivement les logs générés par --extra-log"
    echo "  --purge-process         Tue tout les processus générés par ce programme"
    echo ""
    echo -e "\e[3m ATTENTION: CE PROGRAMME DOIT ÊTRE EXÉCUTÉ AVEC LES PRIVILÈGES ROOT \e[0m"
    echo "Des commandes comme les installations de dépendances ou les recherches nécessitent de tels privilèges."
    echo ""
    exit 1
  fi
fi

#### je dois charger le fichier conf ici ou trouver une solution (script_url et maj_force)
dossier_config=`echo "/root/.config/"$mon_script_base`
if [[ -d "$dossier_config" ]]; then
  useless="1"
else
  mkdir -p $dossier_config
fi

if [[ -f "$mon_script_config" ]] ; then
  source $mon_script_config
else
    if [[ "$script_url" != "" ]] ; then
      script_pastebin=$script_url
    fi
    if [[ "$maj_force" == "" ]] ; then
      maj_force="non"
    fi
fi

#### Vérification qu'au reboot les lock soient bien supprimés
if [[ -f "/etc/rc.local" ]]; then
  test_rc_local=`cat /etc/rc.local | grep -e 'find /root/.config -name "lock-\*" | xargs rm -f'`
  if [[ "$test_rc_local" == "" ]]; then
    sed -i -e '$i \find /root/.config -name "lock-*" | xargs rm -f\n' /etc/rc.local >/dev/null
  fi
else
  test_crontab=`crontab -l | grep "clean-lock"`
  if [[ "$test_crontab" == "" ]]; then
    crontab -l > mon_cron.txt
    sed -i '5i@reboot\t\t\tsleep 10 && /opt/scripts/clean-lock.sh' mon_cron.txt
    crontab mon_cron.txt
    rm -f mon_cron.txt
  fi
fi
 
#### Vérification qu'une autre instance de ce script ne s'exécute pas
computer_name=`hostname`
pid_script=`echo "/root/.config/"$mon_script_base"/lock-"$mon_script_base`
if [[ "$maj_force" == "non" ]] ; then
  if [[ -f "$pid_script" ]] ; then
    if [[ "$CHECK_MUI" != "" ]]; then
      source $mon_script_langue
      echo "$mui_pid_check"
      message_alerte=`echo -e "$mui_pid_push"`
    else
      echo "Il y a au moins un autre process du script en cours"
      message_alerte=`echo -e "Un process bloque mon script sur $computer_name"`
    fi
    ## petite notif pour scoony
    curl -s \
    --form-string "token=a6SLRQFfaUTgdo28wgZb6tVd1vgizs" \
    --form-string "user=$destinataire_1" \
    --form-string "title=$mon_script_base_maj HS" \
    --form-string "message=$message_alerte" \
    --form-string "html=1" \
    --form-string "priority=1" \
    https://api.pushover.net/1/messages.json > /dev/null
    exit 1
  fi
fi
touch $pid_script
 
#### Chemin du script
## necessaire pour le mettre dans le cron
cd /opt/scripts

#### Indispensable aux messages de chargement
mon_printf="\r                                                            "

#### Nettoyage obligatoire et push pour annoncer la maj
if [[ -f "$mon_script_updater" ]] ; then
  rm "$mon_script_updater"
  source $mon_script_config 2>/dev/null
  version_maj=`echo $version | awk '{print $2}'`
  if [[ "$CHECK_MUI" != "" ]]; then
    source $mon_script_langue
    message_maj=`echo -e "$mui_pushover_updated_msg"`
    message_titre=`echo -e "$mui_pushover_updated_title"`
  else
    message_maj=`echo -e "Le progamme $mon_script_base est désormais en version $version_maj"`
    message_titre=`echo -e "Mise à jour"`
  fi  
  for user in {1..10}; do
    destinataire=`eval echo "\\$destinataire_"$user`
    if [ -n "$destinataire" ]; then
      curl -s \
      --form-string "token=$token_app" \
      --form-string "user=$destinataire" \
      --form-string "title=$message_titre" \
      --form-string "message=$message_maj" \
      --form-string "html=1" \
      --form-string "priority=-1" \
      https://api.pushover.net/1/messages.json > /dev/null
    fi
  done
fi

#### Vérification de version pour éventuelle mise à jour
version_distante=`wget -O- -q "$script_pastebin" | grep "Version:" | awk '{ print $2 }' | sed -n 1p | awk '{print $1}' | sed -e 's/\r//g' | sed 's/"//g'`
version_locale=`echo $version | awk '{print $2}'`
 
vercomp () {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}
testvercomp () {
    vercomp $1 $2
    case $? in
        0) op='=';;
        1) op='>';;
        2) op='<';;
    esac
    if [[ $op != $3 ]]
    then
        echo "FAIL: Expected '$3', Actual '$op', Arg1 '$1', Arg2 '$2'"
    else
        echo "Pass: '$1 $op $2'"
    fi
}
compare=`testvercomp $version_locale $version_distante '<' | grep Pass`
if [[ "$compare" != "" ]] ; then
  if [[ "$CHECK_MUI" != "" ]]; then
    source $mon_script_langue
    eval 'echo -e "$mui_update_available"' $mon_log_perso
    eval 'echo -e "$mui_update_download"' $mon_log_perso
  else
    echo "une mise à jour est disponible ($version_distante) - version actuelle: $version_locale"
    echo "téléchargement de la mise à jour et installation..."
  fi
  touch $mon_script_updater
  chmod +x $mon_script_updater
  echo "#!/bin/bash" >> $mon_script_updater
  mon_script_fichier_temp=`echo $mon_script_fichier"-temp"`
  echo "wget -q $script_pastebin -O $mon_script_fichier_temp" >> $mon_script_updater
  echo "sed -i -e 's/\r//g' $mon_script_fichier_temp" >> $mon_script_updater
  if [[ "$mon_script_fichier" =~ \.sh$ ]]; then
    echo "mv $mon_script_fichier_temp $mon_script_fichier" >> $mon_script_updater
    echo "chmod +x $mon_script_fichier" >> $mon_script_updater
    echo "bash $mon_script_fichier $1 $2" >> $mon_script_updater
  else
    echo "shc -f $mon_script_fichier_temp -o $mon_script_fichier" >> $mon_script_updater
    echo "rm -f $mon_script_fichier_temp" >> $mon_script_updater
    compilateur=`echo $mon_script_fichier".x.c"`
    echo "rm -f *.x.c" >> $mon_script_updater
    echo "chmod +x $mon_script_fichier" >> $mon_script_updater
    if [[ "$CHECK_MUI" != "" ]]; then
      source $mon_script_langue
      echo "$mui_update_done" >> $mon_script_updater
    else
      echo "echo mise à jour mise en place" >> $mon_script_updater
    fi
    echo "./$mon_script_fichier $1 $2" >> $mon_script_updater
  fi
  echo "exit 1" >> $mon_script_updater
  rm "$pid_script"
  bash $mon_script_updater
  exit 1
else
  if [[ "$CHECK_MUI" != "" ]]; then
    source $mon_script_langue
    my_title_count=`echo -n "$mui_title" | sed "s/\\\e\[[0-9]\{1,2\}m//g" | wc -c`
    line_lengh="78"
    before_after_count=$(bc -l <<<"scale=1; ( $line_lengh - $my_title_count ) / 2")
    if [[ $before_after_count =~ ".5" ]]; then
      before_after_count=$((($line_lengh-$my_title_count)/2))
      before=`eval printf "%0.s-" {1..$before_after_count}`
      before_after_count=$(((($line_lengh-$my_title_count)/2)+1))
      after=`eval printf "%0.s-" {1..$before_after_count}`
    else
      before_after_count=$((($line_lengh-$my_title_count)/2))
      before=`eval printf "%0.s-" {1..$before_after_count}`
      after=`eval printf "%0.s-" {1..$before_after_count}`
    fi
    printf "\e[43m%s%s%s\e[0m\n" "$before" "$mui_title" "$after"
  else
    eval 'echo -e "\e[43m-- $mon_script_base_maj - VERSION: $version_locale --\e[0m"' $mon_log_perso
  fi
fi

#### Nécessaire pour l'argument --maj-uniquement
if [[ "$1" == "--maj-uniquement" ]]; then
  rm "$pid_script"
  exit 1
fi

#### Vérification de la conformité du cron
crontab -l > mon_cron.txt
cron_path=`cat mon_cron.txt | grep "PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"`
if [[ "$cron_path" == "" ]]; then
  sed -i '1iPATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin' mon_cron.txt
  cron_a_appliquer="oui"
fi
if [[ "$affichage_langue" == "french" ]]; then
  cron_lang=`cat mon_cron.txt | grep "LANG=fr_FR.UTF-8"`
else
  cron_lang=`cat mon_cron.txt | grep "LANG=en_US.UTF-8"`
fi
if [[ "$cron_lang" == "" ]]; then
  if [[ "$affichage_langue" == "french" ]]; then
    sed -i '1iLANG=fr_FR.UTF-8' mon_cron.txt
    cron_a_appliquer="oui"
  else
    sed -i '1iLANG=en_US.UTF-8' mon_cron.txt
    cron_a_appliquer="oui"
  fi
fi
cron_variable=`cat mon_cron.txt | grep "CRON_SCRIPT=\"oui\""`
if [[ "$cron_variable" == "" ]]; then
  sed -i '1iCRON_SCRIPT="oui"' mon_cron.txt
  cron_a_appliquer="oui"
fi
if [[ "$cron_a_appliquer" == "oui" ]]; then
  crontab mon_cron.txt
  rm -f mon_cron.txt
  if [[ "$CHECK_MUI" != "" ]]; then
    source $mon_script_langue
    eval 'echo -e "$mui_cron_path_updated"' $mon_log_perso
  else
    eval 'echo "-- Cron mis en conformité"' $mon_log_perso
  fi
else
  rm -f mon_cron.txt
fi

#### Mise en place éventuelle d'un cron
if [[ "$script_cron" != "" ]]; then
  mon_cron=`crontab -l`
  verif_cron=`echo "$mon_cron" | grep "$mon_script_fichier"`
  if [[ "$verif_cron" == "" ]]; then
    if [[ "$CHECK_MUI" != "" ]]; then
      source $mon_script_langue
      eval 'echo -e "$mui_no_cron_entry"' $mon_log_perso
      eval 'echo -e "$mui_no_cron_creating"' $mon_log_perso
    else
      eval 'echo -e "\e[41mAUCUNE ENTRÉE DANS LE CRON\e[0m"' $mon_log_perso
      eval 'echo "-- Création..."' $mon_log_perso
    fi
    ajout_cron=`echo -e "$script_cron\t\t/opt/scripts/$mon_script_fichier > /var/log/$mon_script_log 2>&1"`
    if [[ "$CHECK_MUI" != "" ]]; then
      source $mon_script_langue
      eval 'echo -e "$mui_no_cron_adding"' $mon_log_perso
    else
      eval 'echo "-- Mise en place dans le cron..."' $mon_log_perso
    fi
    crontab -l > mon_cron.txt
    echo -e "$ajout_cron" >> mon_cron.txt
    crontab mon_cron.txt
    rm -f mon_cron.txt
    if [[ "$CHECK_MUI" != "" ]]; then
      source $mon_script_langue
      eval 'echo -e "$mui_no_cron_updated"' $mon_log_perso
    else
      eval 'echo "-- Cron mis à jour"' $mon_log_perso
    fi
  else
    if [[ "${verif_cron:0:1}" == "#" ]]; then
 
      if [[ "$CHECK_MUI" != "" ]]; then
        source $mon_script_langue
        my_title_count=`echo -n "$mui_script_in_cron_disable" | sed "s/\\\e\[[0-9]\{1,2\}m//g" | wc -c`
        line_lengh="78"
        before_after_count="0"
        before_after_count=$(bc -l <<<"scale=1; ( $line_lengh - $my_title_count ) / 2")
        if [[ $before_after_count =~ ".5" ]]; then
          before_after_count=$((($line_lengh-$my_title_count)/2))
          before=`eval printf "%0.s-" {1..$before_after_count}`
          before_after_count=$(((($line_lengh-$my_title_count)/2)+1))
          after=`eval printf "%0.s-" {1..$before_after_count}`
        else
          before_after_count=$((($line_lengh-$my_title_count)/2))
          before=`eval printf "%0.s-" {1..$before_after_count}`
          after=`eval printf "%0.s-" {1..$before_after_count}`
        fi
        printf "\e[101m%s%s%s\e[0m\n" "$before" "$mui_script_in_cron_disable" "$after"
      else
        eval 'echo -e "\e[101mLE SCRIPT EST PRÉSENT DANS LE CRON MAIS DÉSACTIVÉ\e[0m"' $mon_log_perso
      fi

    else
      if [[ "$CHECK_MUI" != "" ]]; then
        source $mon_script_langue
        my_title_count=`echo -n "$mui_script_in_cron" | sed "s/\\\e\[[0-9]\{1,2\}m//g" | wc -c`
        line_lengh="78"
        before_after_count=$(bc -l <<<"scale=1; ( $line_lengh - $my_title_count ) / 2")
        if [[ $before_after_count =~ ".5" ]]; then
          before_after_count=$((($line_lengh-$my_title_count)/2))
          before=`eval printf "%0.s-" {1..$before_after_count}`
          before_after_count=$(((($line_lengh-$my_title_count)/2)+1))
          after=`eval printf "%0.s-" {1..$before_after_count}`
        else
          before_after_count=$((($line_lengh-$my_title_count)/2))
          before=`eval printf "%0.s-" {1..$before_after_count}`
          after=`eval printf "%0.s-" {1..$before_after_count}`
        fi
        printf "\e[101m%s%s%s\e[0m\n" "$before" "$mui_script_in_cron" "$after"
      else
        eval 'echo -e "\e[101mLE SCRIPT EST PRÉSENT DANS LE CRON\e[0m"' $mon_log_perso
      fi
    fi
#    if [[ "$CHECK_MUI" != "" ]]; then
#      source $mon_script_langue
#      eval 'echo -e "$mui_script_in_cron"' $mon_log_perso
#    else
#      eval 'echo -e "\e[101mLE SCRIPT EST PRÉSENT DANS LE CRON\e[0m"' $mon_log_perso
#    fi
  fi
fi
 
#### Vérification/création du fichier conf
if [[ -f $mon_script_config ]] ; then
  if [[ "$CHECK_MUI" != "" ]]; then
    source $mon_script_langue
    my_title_count=`echo -n "$mui_conf_ok" | sed "s/\\\e\[[0-9]\{1,2\}m//g" | wc -c`
    line_lengh="78"
    before_after_count=$(bc -l <<<"scale=1; ( $line_lengh - $my_title_count ) / 2")
    if [[ $before_after_count =~ ".5" ]]; then
      before_after_count=$((($line_lengh-$my_title_count)/2))
      before=`eval printf "%0.s-" {1..$before_after_count}`
      before_after_count=$(((($line_lengh-$my_title_count)/2)+1))
      after=`eval printf "%0.s-" {1..$before_after_count}`
    else
      before_after_count=$((($line_lengh-$my_title_count)/2))
      before=`eval printf "%0.s-" {1..$before_after_count}`
      after=`eval printf "%0.s-" {1..$before_after_count}`
    fi
    printf "\e[42m%s%s%s\e[0m\n" "$before" "$mui_conf_ok" "$after"
  else
    eval 'echo -e "\e[42mLE FICHIER CONF EST PRESENT\e[0m"' $mon_log_perso
  fi
else
  if [[ "$CHECK_MUI" != "" ]]; then
    source $mon_script_langue
    my_title_count=`echo -n "$mui_no_conf_missing" | sed "s/\\\e\[[0-9]\{1,2\}m//g" | wc -c`
    line_lengh="78"
    before_after_count=$(bc -l <<<"scale=1; ( $line_lengh - $my_title_count ) / 2")
    if [[ $before_after_count =~ ".5" ]]; then
      before_after_count=$((($line_lengh-$my_title_count)/2))
      before=`eval printf "%0.s-" {1..$before_after_count}`
      before_after_count=$(((($line_lengh-$my_title_count)/2)+1))
      after=`eval printf "%0.s-" {1..$before_after_count}`
    else
      before_after_count=$((($line_lengh-$my_title_count)/2))
      before=`eval printf "%0.s-" {1..$before_after_count}`
      after=`eval printf "%0.s-" {1..$before_after_count}`
    fi
    printf "\e[42m%s%s%s\e[0m\n" "$before" "$mui_no_conf_missing" "$after"
    my_title_count=`echo -n "$mui_no_conf_creating" | sed "s/\\\e\[[0-9]\{1,2\}m//g" | wc -c`
    line_lengh="78"
    before_after_count=$(bc -l <<<"scale=1; ( $line_lengh - $my_title_count ) / 2")
    if [[ $before_after_count =~ ".5" ]]; then
      before_after_count=$((($line_lengh-$my_title_count)/2))
      before=`eval printf "%0.s-" {1..$before_after_count}`
      before_after_count=$(((($line_lengh-$my_title_count)/2)+1))
      after=`eval printf "%0.s-" {1..$before_after_count}`
    else
      before_after_count=$((($line_lengh-$my_title_count)/2))
      before=`eval printf "%0.s-" {1..$before_after_count}`
      after=`eval printf "%0.s-" {1..$before_after_count}`
    fi
    printf "\e[42m%s%s%s\e[0m\n" "$before" "$mui_no_conf_creating" "$after"
  else
    eval 'echo -e "\e[41mLE FICHIER CONF EST ABSENT\e[0m"' $mon_log_perso
    eval 'echo "-- Création du fichier conf..."' $mon_log_perso
  fi
  touch "$mon_script_config"
  chmod 777 "$mon_script_config"
  if [[ "$affichage_langue" == "french" ]]; then
    cat <<EOT >> "$mon_script_config"
####################################
## Configuration
####################################
 
#### Mise à jour forcée
## à n'utiliser qu'en cas de soucis avec la vérification de process (oui/non)
maj_force="non"
 
#### Chemin complet vers le script source (pour les maj)
script_url=""
 
#### Affichage de la section dépendances
## mettre oui/non
affiche_dependances="non"

#### Déclaration des services à surveiller
## mettre les services les uns à la suite des autres séparés d'un espace
services=""
 
#### Déclaration du no-ip et du service vpn
## laisser vide "vpn_service" si aucun vpn, sinon mettre le nom du service
vpn_service=""
 
#### Vérification de la présence du site internet
## laisser "site_url" vide pour désactiver
site_url=""
id_adsense=""
 
#### Vérification de la présence d'un autre serveur
## mettre des IP les unes à la suite des autres séparées d'un espace
other_servers=""
 
#### Utilisateurs autorisés
allowed_users=""
 
#### Paramètre du push
## ces réglages se trouvent sur le site http://www.pushover.net
token_app=""
destinataire_1=""
destinataire_2=""
titre_push=""
 
####################################
## Fin de configuration
####################################
EOT
  else
    cat <<EOT >> "$mon_script_config"
####################################
## Settings
####################################
 
#### Overriding updates
## only use if the process dupe checker is stuck (oui/non)
maj_force="non"
 
#### Full path to script's source (for updates)
script_url=""

#### Display the dependencies checking
## use yes/no
display_dependencies="no"
 
#### Declare the names of the process under survey
## put services name one after the other separated by a space
services=""
 
#### Déclaration du no-ip et du service vpn
## laisser vide "vpn_service" si aucun vpn, sinon mettre le nom du service
vpn_service=""
 
#### Vérification de la présence du site internet
## laisser "site_url" vide pour désactiver
site_url=""
id_adsense=""
 
#### Vérification de la présence d'un autre serveur
## mettre des IP les unes à la suite des autres séparées d'un espace
other_servers=""
 
#### Allowed users
allowed_users=""
 
#### Paramètre du push
## ces réglages se trouvent sur le site http://www.pushover.net
token_app=""
destinataire_1=""
destinataire_2=""
titre_push=""
 
####################################
## Fin de configuration
####################################
EOT
  fi
  if [[ "$CHECK_MUI" != "" ]]; then
    source $mon_script_langue
    eval 'echo -e "$mui_no_conf_created"' $mon_log_perso
    eval 'echo -e "$mui_no_conf_edit"' $mon_log_perso
    eval 'echo -e "$mui_no_conf_help"' $mon_log_perso
  else
    eval 'echo "-- Fichier conf créé"'
    eval 'echo "Vous dever éditer le fichier \"$mon_script_config\" avant de poursuivre"'
    eval 'echo "Vous pouvez utiliser: ./"$mon_script_fichier" --edit-config"'
  fi
  rm $pid_script
  exit 1
fi

#### Vérification/création du fichier ini
if [[ -f "$mon_script_ini" ]] ; then
  if [[ "$CHECK_MUI" != "" ]]; then
    source $mon_script_langue
    my_title_count=`echo -n "$mui_ini_ok" | sed "s/\\\e\[[0-9]\{1,2\}m//g" | wc -c`
    line_lengh="78"
    before_after_count=$(bc -l <<<"scale=1; ( $line_lengh - $my_title_count ) / 2")
    if [[ $before_after_count =~ ".5" ]]; then
      before_after_count=$((($line_lengh-$my_title_count)/2))
      before=`eval printf "%0.s-" {1..$before_after_count}`
      before_after_count=$(((($line_lengh-$my_title_count)/2)+1))
      after=`eval printf "%0.s-" {1..$before_after_count}`
    else
      before_after_count=$((($line_lengh-$my_title_count)/2))
      before=`eval printf "%0.s-" {1..$before_after_count}`
      after=`eval printf "%0.s-" {1..$before_after_count}`
    fi
    printf "\e[42m%s%s%s\e[0m\n" "$before" "$mui_ini_ok" "$after"
  else
    echo -e "\e[42mLE FICHIER INI EST PRESENT\e[0m"
  fi
else
  if [[ "$CHECK_MUI" != "" ]]; then
    source $mon_script_langue
    eval 'echo -e "$mui_ini_missing"' $mon_log_perso
    eval 'echo -e "$mui_ini_creating"' $mon_log_perso
  else
    echo -e "\e[41mLE FICHIER INI EST ABSENT\e[0m"
    echo "-- Création du fichier ini..."
  fi
  touch $mon_script_ini
  chmod 777 $mon_script_ini
  echo "cpu_test = 1" >> $mon_script_ini
  echo "curl_test = 1" >> $mon_script_ini
  echo "ventilo_test = 1" >> $mon_script_ini
  if [[ "$CHECK_MUI" != "" ]]; then
    source $mon_script_langue
    eval 'echo -e "$mui_ini_created"' $mon_log_perso
  else
    echo "-- Fichier ini créé"
  fi
fi

echo "------------------------------------------------------------------------------"

if [[ "$display_dependencies" == "yes" ]] || [[ "$affiche_dependances" == "oui" ]]; then
  #### VERIFICATION DES DEPENDANCES
  ##########################
  if [[ "$CHECK_MUI" != "" ]]; then
    source $mon_script_langue
    eval 'echo -e "$mui_section_dependencies"' $mon_log_perso
  else
    eval 'echo -e "\e[44m\u2263\u2263  \e[0m \e[44m \e[1mVÉRIFICATION DE(S) DÉPENDANCE(S)  \e[0m \e[44m  \e[0m \e[44m \e[0m \e[34m\u2759\e[0m"' $mon_log_perso
  fi

  #### Vérification et installation des repositories (apt)
  for repo in $required_repos ; do
    ppa_court=`echo $repo | sed 's/.*ppa://' | sed 's/\/ppa//'`
    check_repo=`grep ^ /etc/apt/sources.list /etc/apt/sources.list.d/* | grep "$ppa_court"`
    if [[ "$check_repo" == "" ]]; then
      add-apt-repository $repo -y
      update_a_faire="1"
    else
      if [[ "$CHECK_MUI" != "" ]]; then
        source $mon_script_langue
        eval 'echo -e "$mui_required_repository"' $mon_log_perso
      else
        eval 'echo -e "[\e[42m\u2713 \e[0m] Le dépôt apt: "$repo" est installé"' $mon_log_perso
      fi
    fi
  done
  if [[ "$update_a_faire" == "1" ]]; then
    apt update
  fi

  #### Vérification et installation des outils requis si besoin (apt)
  for tools in $required_tools ; do
    check_tool=`dpkg --get-selections | grep -w "$tools"`
    if [[ "$check_tool" == "" ]]; then
      apt-get install $tools -y
    else
      if [[ "$CHECK_MUI" != "" ]]; then
        source $mon_script_langue
        eval 'echo -e "$mui_required_apt"' $mon_log_perso
      else
        eval 'echo -e "[\e[42m\u2713 \e[0m] La dépendance: "$tools" est installée"' $mon_log_perso
      fi
    fi
  done

  #### Vérification et installation des outils requis si besoin (pip)
  for tools_pip in $required_tools_pip ; do
    check_tool=`pip freeze | grep "$tools_pip"`
      if [[ "$check_tool" == "" ]]; then
        pip install $tools_pip
      else
        if [[ "$CHECK_MUI" != "" ]]; then
          source $mon_script_langue
          eval 'echo -e "$mui_required_pip"' $mon_log_perso
        else
          eval 'echo -e "[\e[42m\u2713 \e[0m] La dépendance: "$tools_pip" est installée"' $mon_log_perso
        fi
      fi
  done
fi
#### Ajout de ce script dans le menu
if [[ -f "/etc/xdg/menus/applications-merged/scripts-scoony.menu" ]] ; then
  useless=1
else
  if [[ "$CHECK_MUI" != "" ]]; then
    source $mon_script_langue
    eval 'echo -e "$mui_creating_menu_entry"' $mon_log_perso
  else
    echo "... création du menu"
  fi
  mkdir -p /etc/xdg/menus/applications-merged
  touch "/etc/xdg/menus/applications-merged/scripts-scoony.menu"
  cat <<EOT >> /etc/xdg/menus/applications-merged/scripts-scoony.menu
<!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
"http://www.freedesktop.org/standards/menu-spec/menu-1.0.dtd">
<Menu>
<Name>Applications</Name>
 
<Menu> <!-- scripts-scoony -->
<Name>scripts-scoony</Name>
<Directory>scripts-scoony.directory</Directory>
<Include>
<Category>X-scripts-scoony</Category>
</Include>
</Menu> <!-- End scripts-scoony -->
 
</Menu> <!-- End Applications -->
EOT
  if [[ "$CHECK_MUI" != "" ]]; then
    source $mon_script_langue
    echo -e "$mui_created_menu_entry"
  else
    echo "... menu créé"
  fi
fi
 
if [[ -f "/usr/share/desktop-directories/scripts-scoony.directory" ]] ; then
  useless=1
else
## je met l'icone en place
  wget -q http://i.imgur.com/XRCxvJK.png -O /usr/share/icons/scripts.png
  if [[ "$CHECK_MUI" != "" ]]; then
    source $mon_script_langue
    echo "$mui_creating_menu_folder"
  else
    echo "... création du dossier du menu"
  fi
  if [[ ! -d "/usr/share/desktop-directories" ]] ; then
    mkdir -p /usr/share/desktop-directories
  fi
  touch "/usr/share/desktop-directories/scripts-scoony.directory"
  cat <<EOT >> /usr/share/desktop-directories/scripts-scoony.directory
[Desktop Entry]
Type=Directory
Name=Scripts Scoony
Icon=/usr/share/icons/scripts.png
EOT
fi
 
if [[ -f "/usr/local/share/applications/$mon_script_desktop" ]] ; then
  useless=1
else
  wget -q $icone_imgur -O /usr/share/icons/$mon_script_base.png
  if [[ -d "/usr/local/share/applications" ]]; then
    useless="1"
  else
    mkdir -p /usr/local/share/applications
  fi
  touch "/usr/local/share/applications/$mon_script_base.desktop"
  cat <<EOT >> /usr/local/share/applications/$mon_script_base.desktop
#!/usr/bin/env xdg-open
[Desktop Entry]
Type=Application
Terminal=true
Name=Script $mon_script_base
Icon=/usr/share/icons/$mon_script_base.png
Exec=/opt/scripts/$mon_script_fichier --menu
Comment[fr_FR]=$description
Comment=$description
Categories=X-scripts-scoony;
EOT
fi
 
####################
## On commence enfin
####################

cd /opt/scripts


#### VÉRIFICATIONS RÉSEAU
##########################
if [[ "$CHECK_MUI" != "" ]]; then
  source $mon_script_langue
  eval 'printf  "\e[44m\u2263\u2263  \e[0m \e[44m \e[1m %-63s  \e[0m \e[44m  \e[0m \e[44m \e[0m \e[34m\u2759\e[0m\n" "$mui_section_network"' $mon_log_perso
else
  eval 'echo -e "\e[44m\u2263\u2263  \e[0m \e[44m \e[1mVÉRIFICATIONS RÉSEAU  \e[0m \e[44m  \e[0m \e[44m \e[0m \e[34m\u2759\e[0m"' $mon_log_perso
fi

#### Vérification de la connectivité à Internet
mon_interface=`ip addr show | grep "state UP" | awk '{print $2}' | sed 's/:$//' | sed -n '1p'`
vitesse_interface=`ethtool $mon_interface | grep Speed | awk '{print $2}' | sed 's/Mb\/s//'`
if [[ "$mon_interface" =~ "wlo" ]]; then
  vitesse_interface=`iwconfig $mon_interface | grep "Bit Rate" | awk '{print $2 $3}' | sed 's/.*Rate=//'`
fi
if [[ "$vitesse_interface" == "" ]]; then
  if [[ "$CHECK_MUI" != "" ]]; then
    source $mon_script_langue
    eval 'echo -e "$mui_network_no_link"' $mon_log_perso
  else
    eval 'echo -e "[\e[41m\u2717 \e[0m] Pas de liaison avec une box"' mon_log_perso
  fi
else
  if [[ "$vitesse_interface" == "10" ]]; then
    vitesse_color="41"
  fi
  if [[ "$vitesse_interface" == "100" ]]; then
    vitesse_color="43"
  fi
  if [[ "$vitesse_interface" == "1000" ]]; then
    vitesse_color="42"
  fi
  if [[ "$CHECK_MUI" != "" ]]; then
    source $mon_script_langue
    eval 'printf "[\e[%sm\u2713 \e[0m] [\e[%sm %-22s \e[0m| %-26s |\e[%sm %-16s\e[0m]\n" "42" "0" "$mui_network_card" "" "42" "$mon_interface"' $mon_log_perso
    eval 'printf "[\e[%sm\u2713 \e[0m] [\e[%sm %-22s \e[0m| %-26s |\e[%sm %-16s\e[0m]\n" "42" "0" "$mui_network_speed" "" "$vitesse_color" "$vitesse_interface Mb/s"' $mon_log_perso
  else
    eval 'printf "[\e[%sm\u2713 \e[0m] [\e[%sm %-22s \e[0m| %-26s |\e[%sm %-16s\e[0m]\n" "42" "0" "$mui_network_card" "" "42" "$mon_interface"' $mon_log_perso
    eval 'printf "[\e[%sm\u2713 \e[0m] [\e[%sm %-22s \e[0m| %-26s |\e[%sm %-16s\e[0m]\n" "42" "0" "$mui_network_speed" "" "$vitesse_color" "$vitesse_interface Mb/s"' $mon_log_perso
  fi
fi
 
#### Vérification de l'ip via routeur
ip_locale=`hostname -I | cut -d' ' -f1`
router_ip=`dig -b $ip_locale +short myip.opendns.com @resolver1.opendns.com`
if [[ "$CHECK_MUI" != "" ]]; then
  source $mon_script_langue
  eval 'printf "[\e[%sm\u2713 \e[0m] [\e[%sm %-22s \e[0m| %-26s |\e[%sm %-16s\e[0m]\n" "42" "0" "$router_announce" "" "42" "$router_ip"' $mon_log_perso
else
  eval 'printf "[\e[%sm\u2713 \e[0m] [\e[%sm %-22s \e[0m| %-26s |\e[%sm %-16s\e[0m]\n" "42" "0" "$router_announce" "" "42" "$router_ip"' $mon_log_perso
fi
 
#### Vérification du VPN
vpn_check=`ifconfig tun0 2>/dev/null | grep "UP"`
if [[ "$vpn_check" != "" ]]; then
  vpn_ip=`dig +short myip.opendns.com @resolver1.opendns.com`
    if [[ "$vpn_ip" == "" ]]; then
      vpn_ip=`dig -4 +short myip.opendns.com @resolver1.opendns.com`
    fi
  if [[ "$CHECK_MUI" != "" ]]; then
    source $mon_script_langue
    eval 'printf "[\e[%sm\u2713 \e[0m] [\e[%sm %-22s \e[0m| %-26s |\e[%sm %-16s\e[0m]\n" "42" "0" "$vpn_announce" "" "42" "$vpn_ip"' $mon_log_perso
  else
    eval 'printf "[\e[%sm\u2713 \e[0m] [\e[%sm %-22s \e[0m| %-26s |\e[%sm %-16s\e[0m]\n" "42" "0" "$vpn_announce" "" "42" "$vpn_ip"' $mon_log_perso
  fi
  if [[ "$router_ip" == "$vpn_ip" ]]; then
    service openvpnauto restart
  fi
fi
 
#### Vérification des serveurs DNS
mes_dns=`dig yourserver.somedomain.xyz | grep "SERVER:" | awk '{print $3}' | sed 's/#.*//'`
if [[ "$CHECK_MUI" != "" ]]; then
  source $mon_script_langue
  eval 'printf "[\e[%sm\u2713 \e[0m] [\e[%sm %-22s \e[0m| %-26s |\e[%sm %-16s\e[0m]\n" "42" "0" "$dns_announce" "" "42" "$mes_dns"' $mon_log_perso
else
  eval 'printf "[\e[%sm\u2713 \e[0m] [\e[%sm %-22s \e[0m| %-26s |\e[%sm %-16s\e[0m]\n" "42" "0" "$dns_announce" "" "42" "$mes_dns"' $mon_log_perso
fi

#### Vérification qu'Internet fonctionne
wget -q --spider http://google.com
if [ $? -eq 0 ]; then
  connectivity_announce="OK (Google)"
  connectivity_color="42"
else
  connectivity_announce="NO (Google)"
  connectivity_color="41"
  if [[ "$vpn_check" != "" ]]; then
    service openvpnauto restart
  fi
fi
eval 'printf "[\e[%sm\u2713 \e[0m] [\e[%sm %-22s \e[0m| %-26s |\e[%sm %-16s\e[0m]\n" "$connectivity_color" "0" "Internet" "" "$connectivity_color" "$connectivity_announce"' $mon_log_perso






fin_script=`date`
if [[ "$CHECK_MUI" != "" ]]; then
  source $mon_script_langue
  my_title_count=`echo -n "$mui_end_of_script" | sed "s/\\\e\[[0-9]\{1,2\}m//g" | wc -c`
  line_lengh="78"
  before_after_count=$((($line_lengh-$my_title_count)/2))
  if [[ $before_after_count =~ ".5" ]]; then
      before_after_count=$((($line_lengh-$my_title_count)/2))
      before=`eval printf "%0.s-" {1..$before_after_count}`
      before_after_count=$(((($line_lengh-$my_title_count)/2)+1))
      after=`eval printf "%0.s-" {1..$before_after_count}`
    else
      before_after_count=$((($line_lengh-$my_title_count)/2))
      before=`eval printf "%0.s-" {1..$before_after_count}`
      after=`eval printf "%0.s-" {1..$before_after_count}`
  fi
  printf "\e[43m%s%s%s\e[0m\n" "$before" "$mui_end_of_script" "$after"
else
  eval 'echo -e "\e[43m -- FIN DE SCRIPT: $fin_script -- \e[0m "' $mon_log_perso
fi
rm "$pid_script"

if [[ "$1" == "--menu" ]]; then
  read -rsp $'Press a key to close the window...\n' -n1 key
fi
