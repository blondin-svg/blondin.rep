SAUVEGARDE 1FICHIER ★ BLONDIN EDITION ★
Version 4.0 — complète et autonome — Batocera 44

INSTALLATION
Depuis GitHub, en SSH root :
bash -o pipefail -c 'curl -fsSL https://raw.githubusercontent.com/blondin-svg/blondin.rep/main/Sauvegarde1fichier/install.sh | bash'

Le lanceur télécharge la v4.0 dans /tmp, contrôle sa taille,
son empreinte Git et sa syntaxe Bash avant exécution.

Installation locale (copier le fichier dans Installscripts) :
bash /userdata/saves/Installscripts/install-1fichier-v4.0-COMPLET-AUTONOME.sh

Téléchargement direct :
https://raw.githubusercontent.com/blondin-svg/blondin.rep/main/Sauvegarde1fichier/install-1fichier-v4.0-COMPLET-AUTONOME.sh

Ce fichier autonome contient les modules nécessaires à une installation
neuve ou à une mise à jour. Il ne requiert pas le Gestionnaire Batocera.
Ne pas installer pendant une sauvegarde, une vérification ou un renvoi
de media.zip. Sauvegarder les paramètres avant la mise à jour.
Ne pas interrompre l'installation ; redémarrage prévu sur Batocera.

NOUVEAUTÉS DE LA V4.0
- Style des menus harmonisé avec le Gestionnaire Batocera v5.0.1 :
  fond bleu foncé, sélection cyan, flèche jaune, retour séparé.
- Navigation souris, clavier et manette.
- Molette : choix précédent/suivant dans les menus.
- Clic gauche : validation du choix surligné, indépendamment du pointeur.
- Survol : changement de choix lors d'un nouveau déplacement.
- Clic droit / B / Échap : retour ; Q ou B à l'accueil : quitter.
- Journaux et résultats : molette, flèches et Page Up/Page Down ;
  titre et retour fixes, clic hors du bouton Retour sans fermeture.
- Numéro de version v4.0 dans Batocera et l'interface Web.
- Moteur 1fichier et fonctionnalités v3.4.7 conservés.

FONCTIONS
- Sauvegarde vers 1fichier et interface Web mobile (port 8765).
- Gestion des dossiers, progression, annulation et vérification manuelle.
- Envoi de media.zip et gamelist ; journalisation des contrôles et erreurs.
- Configuration du compte 1fichier et de Rclone.

INTERFACE WEB
http://IP_DU_BATOCERA:8765
À distance, utiliser un VPN (WireGuard Freebox par exemple).
Ne pas exposer directement le port 8765 sur Internet.

VALIDATION
Les transformations Python et les scénarios de navigation ont été
vérifiés sur un terminal simulé. Les essais sur Batocera 44 réel,
notamment xterm et la souris physique, restent à effectuer.
Aucun transfert de sauvegarde n'est déclenché par l'installation.

VERSIONS CONSERVÉES
v4.0 : version actuelle, complète et autonome.
v3.4.7 TEST et v3.4.6 TEST : versions de secours historiques.
sources/ : sources historiques conservées.
Archives : https://github.com/blondin-svg/blondin.rep/tree/archives/avant-nettoyage-2026-11-26/Sauvegarde1fichier
