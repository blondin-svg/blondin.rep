# Gestionnaire Batocera ★ BLONDIN EDITION ★ v4.0.1 TEST

Batocera 44 uniquement. Mise à jour ciblée de la v4.0 TEST, y compris une installation déjà corrigée manuellement.

- Téléchargement 1fichier : HTTPS sur 8766 (lancement, vérification, liens, moteur embarqué et empreinte).
- Sauvegarde 1fichier : port 8765 inchangé.
- Notifications extinction ntfy : port 18765 inchangé.
- Patch LinuxLoader / Lindbergh, Sinden, ordre des systèmes et autres fonctionnalités conservés.
- Jeton Web, certificats, clé API et réglages existants conservés.
- Sauvegarde des fichiers modifiés et vérification Bash/Python avant remplacement.

## Installation / mise à jour GitHub (SSH, root)

```bash
curl -fsSL https://raw.githubusercontent.com/blondin-svg/blondin.rep/main/GestionnaireBatocera/v4.0.1/install-gestionnaire-v4.0.1-TEST.py -o /tmp/install-gestionnaire-v4.0.1-TEST.py && python3 /tmp/install-gestionnaire-v4.0.1-TEST.py --online
```

L'option --online installe d'abord la base officielle v4.0 seulement si le gestionnaire est absent. Si une version différente est installée, la mise à jour refuse une source non reconnue. Pour une installation hors ligne, installer la base v4.0 depuis son kit local si nécessaire, puis exécuter le fichier Python sans --online.

Quitter le gestionnaire avant l'installation puis le relancer. Aucun service n'est arrêté automatiquement. Si le Web de téléchargement utilisait encore 8765, le redémarrer depuis son menu.

## Vérifications

Sources v4.0 contrôlées : huit références Web et empreinte SHA-256 du moteur d'origine confirmées. Simulations de mise à jour avec ports initiaux 8765 et 8766 réussies ; validation sur matériel réel à effectuer. Le fichier distribué est un installateur de mise à jour, pas un nouveau kit autonome complet.

SHA-256 de l'installateur : `68d9785c8032a96d276f912dbf87bd6f84eeb4adf32a35207331486d69c6a29c`.
