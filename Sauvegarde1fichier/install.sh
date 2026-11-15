#!/usr/bin/env bash
# Sauvegarde 1fichier ★ BLONDIN EDITION ★ v2.1 — installation GitHub officielle.
# Un fichier temporaire dans /tmp est uniquement utilise pendant l'installation.
# Ce point d'entree ne stoppe pas EmulationStation : le moteur v2.1 pilote
# lui-meme les services, la recuperation graphique et le reboot en cas de succes.
set -Eeuo pipefail

INSTALL_URL='https://raw.githubusercontent.com/blondin-svg/blondin.rep/main/Sauvegarde1fichier/1fichier-blondin-v2.1.sh'
INSTALL_SHA256='ac7e016ea1a868bd6b4b463e65af4b4067b3246b07cd7e167913b363b1d8cb0f'

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo '[ERREUR] Lancer cette commande en SSH root sous Batocera 44.' >&2
  exit 1
fi
for cmd in curl sha256sum bash mktemp; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "[ERREUR] Outil indispensable absent : $cmd" >&2
    exit 1
  }
done

INSTALL_TMP=$(mktemp /tmp/1fichier-blondin-v2.1.XXXXXXXX.sh)
chmod 600 "$INSTALL_TMP"
trap 'rm -f -- "$INSTALL_TMP"' EXIT

echo '[INFO] Telechargement de 1fichier-blondin-v2.1 depuis GitHub...'
if ! curl --fail --location --silent --show-error --retry 3 \
    --connect-timeout 20 --max-time 240 \
    --output "$INSTALL_TMP" "$INSTALL_URL"; then
  echo '[ERREUR] Telechargement echoue. Aucune installation lancee.' >&2
  exit 1
fi

if ! printf '%s  %s\n' "$INSTALL_SHA256" "$INSTALL_TMP" | sha256sum --check --status; then
  echo '[ERREUR] SHA256 different de la version officielle. Installation annulee.' >&2
  exit 1
fi

echo '[OK] Integrite SHA256 verifiee. Demarrage de la v2.1...'
bash "$INSTALL_TMP"
