#!/bin/bash
set -euo pipefail
ROOT=/userdata/system/cgs
CLIENT="$ROOT/app/clients/windows/__main__.py"
PATCH_DST=/userdata/system/cgs-multisource-patch.py
HUB_PATCH=/userdata/system/cgs-minipc-hub-patch.py
HERE="$(cd "$(dirname "$0")" && pwd)"
PATCH_SRC="$HERE/cgs-multisource-patch.py"
ORIGINAL="$CLIENT.official-before-multisource-1793072454.bak"
EXPECTED_ORIGINAL=d54ecb1dcf41760aab6be8bcc001616d22d914d4d48bb2d66651aee473ea00a1
EXPECTED_PATCHED=5c600088b35986e9990a5b653a138d28d9b88c50e23d83b58b9d6abda115c8a4
BACKUP_DIR="$ROOT/backups/multisources-v2"
sha() { sha256sum "$1" | awk '{print $1}'; }
backup() {
  mkdir -p "$BACKUP_DIR"
  local stamp; stamp="$(date +%Y%m%d-%H%M%S)-$$"
  [[ ! -f "$CLIENT" ]] || cp -p "$CLIENT" "$BACKUP_DIR/client-$stamp.py"
  [[ ! -f "$PATCH_DST" ]] || cp -p "$PATCH_DST" "$BACKUP_DIR/patch-$stamp.py"
  [[ ! -f "$HUB_PATCH" ]] || cp -p "$HUB_PATCH" "$BACKUP_DIR/hub-patch-$stamp.py"
  echo "Sauvegarde de sécurité : $BACKUP_DIR"
}
status() {
  [[ -f "$CLIENT" ]] || { echo 'CGS absent'; return; }
  echo "Client : $(sha "$CLIENT")"
  if grep -q 'ROM_SOURCES' "$CLIENT" && grep -q 'cgs-multisource-patch.py' "$CLIENT"; then
    echo 'Multi-sources : présent (signature détectée)'
  else
    echo 'Multi-sources : non détecté'
  fi
  if [[ -f "$PATCH_DST" ]]; then
    if grep -q 'Hub officiel conservé : ancien correctif Mini-PC ignoré' "$PATCH_DST"; then
      echo 'Réapplication : script V2.1 sans correction hub'
    else
      echo 'Réapplication : script présent (version à vérifier)'
    fi
  else
    echo 'Réapplication : script absent'
  fi
  [[ ! -f "$HUB_PATCH" ]] || echo 'Ancien script hub : encore présent (inutilisé par V2.1)'
}
install_patch() {
  [[ -f "$CLIENT" && -f "$PATCH_SRC" ]] || { echo 'Client CGS ou patch V2.1 absent'; return 1; }
  python3 -m py_compile "$PATCH_SRC"
  backup
  if grep -q 'ROM_SOURCES' "$CLIENT" && grep -q 'cgs-multisource-patch.py' "$CLIENT"; then
    echo 'Multi-sources déjà présent : client officiel/hub non modifiés.'
  else
    echo 'Application du patch sur le client Windows...'
    python3 "$PATCH_SRC" "$CLIENT" || { echo 'Échec du patch : vérifier les sauvegardes'; return 1; }
  fi
  python3 -m py_compile "$CLIENT"
  local tmp="$PATCH_DST.tmp.$$"
  cp -p "$PATCH_SRC" "$tmp"
  chmod 755 "$tmp"
  mv -f "$tmp" "$PATCH_DST"
  echo 'OK : patch persistant V2.1 installé, hub officiel préservé.'
  echo 'Ancien script hub laissé en place mais jamais appelé par cette V2.1.'
}
uninstall_patch() {
  [[ -f "$CLIENT" && -f "$ORIGINAL" ]] || { echo 'Client ou sauvegarde d’origine introuvable : arrêt'; return 1; }
  [[ $(sha "$ORIGINAL") == "$EXPECTED_ORIGINAL" ]] || { echo 'Empreinte sauvegarde différente : arrêt'; return 1; }
  [[ $(sha "$CLIENT") == "$EXPECTED_PATCHED" ]] || { echo 'Client différent de la version patchée validée : arrêt sans modification'; return 1; }
  echo 'Retrait du multi-sources et de sa réapplication. CGS officiel reste installé.'
  echo 'Attention : cela remet le client Windows sauvegardé le 26 octobre 2026.'
  read -r -p 'Confirmer (oui/non) : ' confirm
  [[ "$confirm" == oui ]] || { echo 'Annulé'; return 0; }
  backup
  local tmp="$CLIENT.restore.$$"
  cp -p "$ORIGINAL" "$tmp"
  python3 -m py_compile "$tmp" || { rm -f "$tmp"; echo 'Sauvegarde non compilable : arrêt'; return 1; }
  mv -f "$tmp" "$CLIENT"
  rm -f "$PATCH_DST" "$HUB_PATCH"
  echo 'OK : client d’origine restauré, scripts multi-sources et hub retirés.'
  echo 'CGS, comptes, caches, manettes et sauvegardes de jeux conservés.'
}
[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo 'Lancer en root'; exit 1; }
while true; do
  printf '\n=== CGS Multi-sources V2.1 TEST — Batocera 44 ===\n1) Installer / réparer\n2) Désinstaller notre patch\n3) Vérifier l’état\n4) Quitter\n'
  read -r -p 'Votre choix : ' choice || exit 0
  case "$choice" in
    1) install_patch || exit 1;;
    2) uninstall_patch || exit 1;;
    3) status;;
    4) exit 0;;
    *) echo 'Choix invalide';;
  esac
done
