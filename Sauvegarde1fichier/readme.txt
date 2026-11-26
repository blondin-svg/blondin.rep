SAUVEGARDE 1FICHIER ★ BLONDIN EDITION ★
Version 3.4.7 TEST — complète et autonome — Batocera 44

INSTALLATION
Depuis GitHub, en SSH root :
bash -o pipefail -c 'curl -fsSL https://raw.githubusercontent.com/blondin-svg/blondin.rep/main/Sauvegarde1fichier/install.sh | bash'

Le lanceur télécharge la v3.4.7 dans /tmp, contrôle sa taille,
son empreinte Git et sa syntaxe Bash avant exécution.

Installation locale (copier le fichier dans Installscripts) :
bash /userdata/saves/Installscripts/install-1fichier-v3.4.7-TEST-COMPLET-AUTONOME.sh

Téléchargement direct :
https://raw.githubusercontent.com/blondin-svg/blondin.rep/main/Sauvegarde1fichier/install-1fichier-v3.4.7-TEST-COMPLET-AUTONOME.sh

Ne pas installer pendant une sauvegarde, une vérification ou un
renvoi de media.zip. Sauvegarder ses paramètres avant la mise à jour.
Le kit est conçu pour Batocera 44. Ne pas interrompre l'installation ;
un redémarrage peut être demandé par l'installateur.

FONCTIONS
- Sauvegarde vers 1fichier et interface Web mobile (port 8765).
- Gestion des dossiers, progression, annulation et vérification manuelle.
- Envoi de media.zip et gamelist ; journalisation des contrôles et erreurs.
- Configuration du compte 1fichier et de Rclone.

INTERFACE WEB
http://IP_DU_BATOCERA:8765
À distance, utiliser un VPN (WireGuard Freebox par exemple).
Ne pas exposer directement le port 8765 sur Internet.

VERSIONS CONSERVÉES
v3.4.7 TEST : version actuelle.
v3.4.6 TEST : version de secours.
sources/ : sources historiques conservées ; ce dossier ne constitue
pas nécessairement les sources complètes de la version actuelle.

L'installateur v3.4.7 reste une version TEST. Le nettoyage GitHub
ne modifie pas les fichiers installés sur Batocera ni les sauvegardes.

Archives : https://github.com/blondin-svg/blondin.rep/tree/archives/avant-nettoyage-2026-11-26/Sauvegarde1fichier
