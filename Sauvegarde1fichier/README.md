# Sauvegarde 1fichier ★ BLONDIN EDITION ★ — v2.0.1

Outil de sauvegarde manuelle de dossiers Batocera 44 vers un compte **1fichier.com** au moyen de Rclone.

## Installation depuis GitHub

Sur **Batocera 44**, que Sauvegarde 1fichier soit déjà présent ou non, ouvrir une session SSH root et exécuter :

```bash
curl -fsSL https://raw.githubusercontent.com/blondin-svg/blondin.rep/main/Sauvegarde1fichier/install.sh | bash
```

L'installateur télécharge la version **2.0.1** depuis ce dépôt, contrôle son **SHA-256**, arrête EmulationStation, installe le programme ou met à jour l'installation existante **sans écraser les dossiers configurés**, puis lance un **redémarrage complet de Batocera** uniquement en cas de réussite. Si l'installation échoue après l'arrêt d'EmulationStation, celui-ci est relancé.

**Première installation** : le logiciel, le lanceur Ports, les visuels, la configuration manette et un fichier `dossiers.json` vide sont créés. La protection d'extinction V3 et le compte distant Rclone `1fichier:` ne sont **pas** installés ni configurés par ce script. Il faut les préparer séparément **avant la première sauvegarde**. L'application **refuse de lancer un transfert** tant que la garde d'extinction V3 est absente. Aucun transfert n'est lancé pendant l'installation. Ne jamais publier sa clé API.

**Mise à jour** : `dossiers.json`, les journaux, le compte Rclone, les préférences ntfy et les fichiers d'extinction sont conservés. Une installation partielle ou une version inconnue de `app.py` provoque un arrêt de sécurité, sans écrasement.

## Nouveau menu principal v2.0

1. **Sauvegardes** — un dossier ou tous les dossiers, extinction après sauvegarde optionnelle.
2. **Gestion des dossiers** — ajouter, modifier ou retirer une configuration ; `/userdata/roms/` prérempli.
3. **État et progression** — suivi en direct, vitesse, ETA et annulation contrôlée.
4. **Contrôles et journaux** — vérification des noms et tailles, historique et journaux avec bilan coloré.
5. **Compte 1fichier** — abonnement et Cold Storage par consultation de l'API.

L'entrée **9 — Annuler le transfert** apparaît directement à l'accueil uniquement lorsqu'une sauvegarde est en cours. `0` quitte le logiciel ; la navigation manette et clavier est conservée.

## Autres fonctionnalités conservées

- Sauvegardes en arrière-plan, avec verrou empêchant l'extinction programmée pendant un transfert actif.
- Prise en charge des **liens symboliques racine** vers des volumes externes montés, quel que soit leur point de montage autorisé ; contrôle des montages avant et après transfert. Les liens imbriqués restent ignorés.
- Vérification de sauvegarde par noms et tailles (pas de somme de contrôle du contenu).
- Extinction facultative après une sauvegarde réussie, avec compte à rebours annulable de 30 secondes **dans le logiciel** ; fermer ce dernier supprime cette extinction sans interrompre le transfert.
- Transfert Rclone `--ignore-existing` : les fichiers déjà présents sur 1fichier ne sont pas retransférés, même s'ils ont été modifiés localement.
- Sauvegarde locale des fichiers remplacés pendant la mise à jour ; conservation de l'historique, des configurations, des journaux, de Rclone et des paramètres ntfy.

## Fichiers du dépôt

- [`install.sh`](install.sh) : point d'entrée universel à une commande, avec redémarrage.
- [`install-sauvegarde-1fichier-blondin-v2.0.1.sh`](install-sauvegarde-1fichier-blondin-v2.0.1.sh) : installateur complet (première installation et mise à jour), contenant l'application et ses visuels.
- [`install-sauvegarde-1fichier-blondin-v2.0.sh`](install-sauvegarde-1fichier-blondin-v2.0.sh) : ancienne version conservée pour référence.
- [`sources/app.py`](sources/app.py) : source Python lisible du programme avec sécurité d'extinction renforcée.

## Version

**v2.0.1 — 14 novembre 2026** : installateur universel compatible avec Batocera 44 vierge, conservation de la configuration lors des mises à jour et blocage des transferts tant que la protection d'extinction V3 n'est pas présente.

**v2.0 — 14 novembre 2026** : réorganisation de l'accueil en cinq rubriques et accès à l'annulation rapide, à partir de la v1.3.7 validée.
