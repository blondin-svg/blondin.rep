# Gestionnaire Batocera ★ BLONDIN EDITION ★ v4.0.1 TEST — version complète

Batocera 44 uniquement (Mini-PC et Steam Deck OLED). Installation directe, même depuis la v3.0.17 ou sur une installation vierge. Aucune installation préalable de la v4.0 nécessaire.

## Installation GitHub (SSH root)

```bash
curl -fsSL https://raw.githubusercontent.com/blondin-svg/blondin.rep/main/GestionnaireBatocera/v4.0.1/install-v4.0.1.sh -o /tmp/install-v4.0.1.sh && bash /tmp/install-v4.0.1.sh --online
```

## Installation locale

Placer les six modules, le manifeste et install-v4.0.1.sh ensemble dans /userdata/saves/Installscripts/gestionnaire-batocera-hors-ligne-v4.0.1, puis :

```bash
bash /userdata/saves/Installscripts/gestionnaire-batocera-hors-ligne-v4.0.1/install-v4.0.1.sh
```

Le kit local ne nécessite pas Internet pour installer le gestionnaire ; certaines fonctions du gestionnaire téléchargent ensuite leurs propres dépendances, comme en v4.0. Les patchs existants ne sont pas désinstallés ou appliqués automatiquement.

## Nouveautés

- Téléchargement 1fichier HTTPS sur 8766, y compris le moteur embarqué et sa vérification d'intégrité.
- Sauvegarde 1fichier HTTP 8765, notifications ntfy 18765 : inchangées.
- Patch LinuxLoader / Lindbergh (Rambo), Sinden Lightgun et ordre des systèmes : conservés.
- Sauvegarde automatique des fichiers remplacés ; jeton Web, clé API, contrôles manette et visuels conservés.
- Le moteur de téléchargement déjà installé est migré seulement s'il correspond à l'empreinte officielle connue.

Quitter le gestionnaire avant l'installation. Relancer depuis Ports ; si l'ancien serveur de téléchargement tournait sur 8765, le redémarrer depuis son menu. Aucun redémarrage de Batocera nécessaire. L'ancien installateur Python de mise à jour ne constitue pas la version complète.

Contrôles syntaxiques et moteur embarqué testés hors Batocera ; validation sur matériel réel à effectuer.
