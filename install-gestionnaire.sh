#!/bin/bash
# Installation SSH Gestionnaire Batocera ★ BLONDIN EDITION ★
# Version d'installation figée : v3.0.15 TEST
set -euo pipefail
REPO="https://raw.githubusercontent.com/blondin-svg/blondin.rep/main"
FILENAME="install-gestionnaire-v3.0.15-VISUELS-GITHUB-TEST.sh"
EXPECTED_SHA256="eae277ae7a325c404c154d884ff1425c3f1bd04ab1eb074f797570975557e8d4"

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
printf '[INFO] Téléchargement du Gestionnaire v3.0.15 TEST...\n'
curl --fail --location --silent --show-error --retry 2 --connect-timeout 10 --max-time 120 \
  "$REPO/$FILENAME" -o "$TMP"
printf '%s  %s\n' "$EXPECTED_SHA256" "$TMP" | sha256sum -c - >/dev/null || {
  echo '[ERREUR] Empreinte SHA-256 incorrecte. Installation annulée.' >&2
  exit 1
}
bash -n "$TMP"
echo '[OK] Installateur authentifié par empreinte SHA-256 et syntaxe vérifiée.'
bash "$TMP"
