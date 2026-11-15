# Sauvegarde 1fichier ★ BLONDIN EDITION ★ — v2.1

Version finale pour **Batocera 44**, avec l'interface Batocera et l'interface Web mobile. Installation ou mise à jour depuis GitHub, sans copier de fichier dans `Installscripts`.

## Installation ou mise à jour depuis GitHub

Ouvrir une session **SSH root** sur le Mini-PC ou Steam Deck sous Batocera 44, puis exécuter cette commande :

```bash
bash -o pipefail -c 'curl -fsSL https://raw.githubusercontent.com/blondin-svg/blondin.rep/main/Sauvegarde1fichier/install.sh | bash'
```

**Prérequis :** la protection d'extinction automatique V3 (scripts `shutdown-trigger.sh` et `shutdown-cancel.sh`) doit déjà être installée et aucune sauvegarde/vérification ne doit être en cours. Si elle est absente, l'installateur refuse toute modification.

Le point d'entrée `install.sh` télécharge automatiquement l'installateur v2.1 dans **`/tmp` uniquement**, vérifie son **SHA-256** et le lance. Il ne faut ni garder le fichier, ni le copier manuellement dans `/userdata/saves/Installscripts`. Aucun transfert vers 1fichier n'est déclenché pendant l'installation.

Le logiciel gère lui-même les services et l'arrêt/relance d'EmulationStation avec les précautions Wayland/labwc validées sur Batocera 44. **Batocera redémarre entièrement uniquement après réussite** ; la connexion SSH se coupe alors. En cas d'erreur, pas de redémarrage automatique et tentative de restauration de l'interface graphique si elle était active.

## Fonctionnalités v2.1

- **Batocera + mobile** : mêmes dossiers de sauvegarde, opérations et état de progression, avec annulation contrôlée.
- **Un seul compte 1fichier**, remplaçable depuis les deux interfaces ; remplacement de la clé API et configuration de Rclone sans passer par SSH.
- **Version Web protégée par mot de passe** : un mot de passe est créé et affiché à la première installation ; une mise à jour conserve le mot de passe existant (elle ne l'affiche pas à nouveau).
- **Entretien automatique des journaux** via le service Web mobile : journaux ordinaires 30 jours, erreurs et rapports de vérification 90 jours, fichiers principaux limités à 5 Mo avec 3 rotations, historique des 300 dernières opérations.
- **Bouton « Nettoyer les anciens journaux »** présent dans l'interface Batocera et dans l'interface mobile.
- Protection contre les opérations concurrentes, contrôle des absents en deux passages et sécurité de l'extinction automatique V3.
- Conservation des configurations existantes : dossiers, Rclone, compte 1fichier, mot de passe Web, ntfy, sauvegardes et journaux conservés selon la politique d'entretien.

## Accès au service Web mobile

Après redémarrage, ouvrir : `http://IP_DU_BATOCERA:8765` (par exemple `http://192.168.1.165:8765` si cette adresse n'a pas changé).

À distance, passer par le **VPN WireGuard de la Freebox**. **Ne pas ouvrir le port 8765 directement sur Internet** : l'interface est en HTTP local.

## Fichiers officiels

- [`install.sh`](install.sh) : commande de démarrage stable à utiliser depuis GitHub ; vérifie le SHA-256 et lance la version finale.
- [`1fichier-blondin-v2.1.sh`](1fichier-blondin-v2.1.sh) : installateur complet autonome, six modules embarqués.
- [`LISEZ-MOI-1fichier-blondin-v2.1.txt`](LISEZ-MOI-1fichier-blondin-v2.1.txt) : documentation de la version 2.1.

Les anciens installateurs v2.0.x et TEST sont conservés dans le dépôt à titre historique. **L'installation GitHub officielle pointe exclusivement vers la v2.1 finale.**

## Contrôle du fichier officiel

Empreinte SHA-256 de `1fichier-blondin-v2.1.sh` :

```text
ac7e016ea1a868bd6b4b463e65af4b4067b3246b07cd7e167913b363b1d8cb0f
```

**Version :** 2.1 — 15 novembre 2026.
