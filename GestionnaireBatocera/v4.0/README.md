# Gestionnaire Batocera ★ Blondin Edition ★ v4.0 TEST

Compatible **Batocera 44** (Mini-PC et Steam Deck OLED). Basé sur v3.0.17 TEST, en conservant ses fonctionnalités.

## Installation depuis GitHub (une seule commande SSH)

```bash
curl -fsSL https://raw.githubusercontent.com/blondin-svg/blondin.rep/main/GestionnaireBatocera/v4.0/install-v4.0.sh -o /tmp/install-blondin-v4.sh && bash /tmp/install-blondin-v4.sh --online
```

L'installateur télécharge `kit-v4.0.zip.b64`, l'extrait et vérifie **SHA-256** de tous les modules. Il sauvegarde les anciens fichiers installés dans `/userdata/system/backup-gestionnaire-ports/` et conserve les commandes manette et visuels existants.

## Installation locale hors ligne

Télécharger et décompresser le kit ZIP complet dans `/userdata/saves/Installscripts/` pour obtenir le dossier `gestionnaire-batocera-hors-ligne-v4.0`, puis :

```bash
bash /userdata/saves/Installscripts/gestionnaire-batocera-hors-ligne-v4.0/install-v4.0.sh
```

## Nouveautés

- **Installation → Patch → Sinden Lightgun** : bouton avant droit + gâchette maintenus **2 secondes** pour quitter le jeu. Installation complète + correctifs hotkeygen, double interface, codes réels ; vérification, restauration et désinstallation. N'altère pas Volume Hotkey.
- **Gestion → Ordre des systèmes** : aperçu et sauvegarde ; `fbneo` / FinalBurn Neo reste au même index, suivi de Neo Geo, Naomi, Lindbergh et TeknoParrot. Les autres systèmes sont groupés par constructeur puis triés par date.
- Si ces contraintes sont incompatibles avec la configuration actuelle, le tri refuse toute modification. Dans EmulationStation, régler le tri automatique des systèmes sur « Aucun ».

**Attention :** des vérifications syntaxiques et des simulations ont été effectuées, mais les nouvelles actions n'ont pas été validées sur le Mini-PC réel. Il est conseillé de commencer par un aperçu avant tout classement. L'installation du Gestionnaire seule ne change pas l'ordre des systèmes.

Les scripts sources sont accessibles dans ce dossier. Le fichier `SHA256SUMS` contient les empreintes des six modules installés.
