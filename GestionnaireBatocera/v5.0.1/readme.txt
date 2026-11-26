============================================================
               GESTIONNAIRE BATOCERA
                 ★ BLONDIN EDITION ★
                      VERSION 5.0.1
============================================================

Version officielle - Batocera 44
Développement : Blondin / ChatGPT
Distribution : installateur complet et autonome

1. PRÉSENTATION
------------------------------------------------------------
Le Gestionnaire Batocera centralise les outils d'installation,
de configuration, de sauvegarde et de maintenance du système.
Il est utilisable depuis Ports (interface xterm) ou en SSH.

Compatibilité prévue : Mini-PC x86_64 et Steam Deck sous
Batocera 44. Cette version n'est pas destinée aux versions
antérieures de Batocera.

2. NOUVEAUTÉS DE LA VERSION 5.0.1
------------------------------------------------------------
- Informations système sur deux colonnes si la largeur le permet.
- Adaptation de l'affichage à la taille du terminal.
- Pagination des rapports système, disques et diagnostics.
- Conservation des titres et des commandes de navigation.
- Accès aux sorties précédentes avec Maj + molette dans xterm.
- Conservation des améliorations souris, manette et clavier
  de la version 5.0.
- Interface SSH sur téléphone conservée.

3. INSTALLATION LOCALE (SANS CONNEXION INTERNET)
------------------------------------------------------------
Nom du fichier :
install-gestionnaire-v5.0.1-COMPLET.py

Dossier recommandé :
/userdata/saves/Installscripts/

Créer le dossier si nécessaire :
mkdir -p /userdata/saves/Installscripts

Copier l'installateur dans ce dossier, fermer le Gestionnaire
s'il est ouvert, puis exécuter en SSH (root) :

python3 /userdata/saves/Installscripts/install-gestionnaire-v5.0.1-COMPLET.py

L'installateur contient les neuf composants du kit. Il ne
nécessite pas l'installation préalable d'une ancienne version.
Les fonctions de téléchargement ou de sauvegarde distante du
Gestionnaire nécessitent cependant une connexion Internet.

4. INSTALLATION DEPUIS GITHUB
------------------------------------------------------------

Commande permanente (dernière version officielle publiée) :

bash -o pipefail -c 'curl -fsSL https://raw.githubusercontent.com/blondin-svg/blondin.rep/main/install-gestionnaire.sh | bash'

Le lanceur vérifie le kit avant de l'exécuter. Son lien ne
change pas lors des mises à jour. La commande versionnée
ci-dessous reste disponible pour installer précisément la v5.0.1.

Fermer le Gestionnaire, puis exécuter en SSH (root) :

curl -fsSL https://raw.githubusercontent.com/blondin-svg/blondin.rep/main/GestionnaireBatocera/v5.0.1/install-gestionnaire-v5.0.1-COMPLET.py -o /tmp/install-gestionnaire-v5.0.1-COMPLET.py && python3 /tmp/install-gestionnaire-v5.0.1-COMPLET.py

Téléchargement direct :
https://raw.githubusercontent.com/blondin-svg/blondin.rep/main/GestionnaireBatocera/v5.0.1/install-gestionnaire-v5.0.1-COMPLET.py

5. VÉRIFICATION AVANT INSTALLATION (FACULTATIVE)
------------------------------------------------------------
Le mode --check contrôle l'intégrité des composants et la
syntaxe des scripts sans effectuer l'installation :

python3 /userdata/saves/Installscripts/install-gestionnaire-v5.0.1-COMPLET.py --check

6. LANCEMENT
------------------------------------------------------------
Depuis EmulationStation :
Ports > Gestionnaire Batocera

Depuis une connexion SSH :
bash /userdata/system/gestionnaire-batocera.sh

Aucun redémarrage automatique de Batocera n'est nécessaire.
Après la mise à jour, fermer puis relancer le Gestionnaire.
Si la fiche Ports n'apparaît pas après une première installation,
actualiser la liste des jeux.

7. NAVIGATION DANS PORTS
------------------------------------------------------------
Souris :
- Survol : sélectionner une option avant utilisation de la molette.
- Molette : déplacer la sélection.
- Clic gauche : valider l'option sélectionnée.
- Clic droit : revenir en arrière dans les menus compatibles.
- Dans les rapports paginés, molette sur les informations :
  changer de page ; molette sur les options : changer de sélection.
- Maj + molette : consulter les sorties précédentes dans xterm.

Manette et clavier :
- Haut / Bas : déplacer la sélection.
- Validation / Entrée : confirmer.
- B / Retour : revenir en arrière selon le menu.
- Gauche / Droite : changer de page dans les rapports compatibles.
- 0 : Retour ; Q : Quitter le Gestionnaire.

Les phrases secrètes, jetons GitHub et autres saisies de texte
restent à saisir au clavier. Certains écrans anciens disposent
encore de leur propre mode de navigation.

8. PRÉCAUTIONS ET ASSISTANCE
------------------------------------------------------------
- Sauvegarder ses paramètres avant toute opération importante.
- Ne pas interrompre une installation ou une restauration.
- Les sauvegardes locales de paramètres non chiffrées doivent
  être conservées sur un support protégé.
- Le kit est publié en version officielle ; son installation
  intégrale et son rendu réel sous Batocera 44 / Wayland restent
  à confirmer sur les appareils concernés.

Dépôt GitHub :
https://github.com/blondin-svg/blondin.rep/tree/main/GestionnaireBatocera/v5.0.1

============================================================
                  ★ BLONDIN EDITION ★
============================================================
