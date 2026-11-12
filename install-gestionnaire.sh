#!/bin/bash
# Installation SSH Gestionnaire Batocera ★ BLONDIN EDITION ★
# Version d'installation : v3.0.17 TEST
set -euo pipefail
REPO="https://raw.githubusercontent.com/blondin-svg/blondin.rep/main"
FILENAME="install-gestionnaire-v3.0.17-TEST.sh"
EXPECTED_SHA256="a9882ffabe2bd90dc38e75de8a3989af7e896148d73ccd286e2ff9351d44b6e0"

if [[ "$(id -u)" -ne 0 ]]; then
  echo '[ERREUR] Lancer cette commande en root sur Batocera.' >&2
  exit 1
fi
if [[ ! -r /etc/os-release ]]; then
  echo '[ERREUR] Batocera non détecté.' >&2
  exit 1
fi
if ! grep -qi 'batocera' /etc/os-release; then
  echo '[ERREUR] Ce programme est réservé à Batocera.' >&2
  exit 1
fi
if ! grep -Eq '(^|[^0-9])44([^0-9]|$)' /etc/os-release; then
  echo '[ERREUR] Cette version est prévue pour Batocera 44.' >&2
  exit 1
fi
for cmd in curl sha256sum bash; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "[ERREUR] Commande manquante : $cmd" >&2; exit 1; }
done
TMP="$(mktemp /tmp/gestionnaire-blondin-install.XXXXXX)"
trap 'rm -f -- "$TMP"' EXIT
printf '[INFO] Téléchargement du Gestionnaire v3.0.17 TEST...\n'
curl --fail --location --silent --show-error --retry 2 --connect-timeout 10 --max-time 120 \
  "$REPO/$FILENAME" -o "$TMP"
printf '%s  %s\n' "$EXPECTED_SHA256" "$TMP" | sha256sum -c - >/dev/null || {
  echo '[ERREUR] Empreinte SHA-256 incorrecte. Installation annulée.' >&2
  exit 1
}
bash -n "$TMP"
echo '[OK] Installateur vérifié par empreinte SHA-256 et syntaxe.'
bash "$TMP"
if [[ -s /userdata/system/gestionnaire-batocera.sh ]] &&
   grep -Fq 'v3.0.17 TEST  •  BATOCERA 44' /userdata/system/gestionnaire-batocera.sh; then
  echo '[OK] Installation v3.0.17 TEST confirmée.'
else
  echo '[ERREUR] Le Gestionnaire installé ne correspond pas à la v3.0.17 TEST.' >&2
  exit 1
fi

# Mettre immédiatement la liste Ports à jour après l'installation SSH.
# La commande de redémarrage d'EmulationStation est celle du Gestionnaire.
if command -v batocera-es-swissknife >/dev/null 2>&1; then
  echo '[INFO] Actualisation automatique d’EmulationStation...'
  if batocera-es-swissknife --restart; then
    echo '[OK] Redémarrage d’EmulationStation demandé.'
  else
    echo '[ATTENTION] Impossible d’actualiser automatiquement EmulationStation.'
    echo '[INFO] Tu peux actualiser la liste des jeux manuellement.'
  fi
else
  echo '[ATTENTION] EmulationStation non actualisé : outil de redémarrage absent.'
fi
