#!/bin/bash
# Sauvegarde 1fichier BLONDIN EDITION v2.0 — installation depuis GitHub
# Met a jour une installation existante. Reboot uniquement apres succes.
set -Eeuo pipefail

BASE_URL='https://raw.githubusercontent.com/blondin-svg/blondin.rep/main/Sauvegarde1fichier'
SHA256='1ad2b9758f6ea39d6a16b522d7a40b9e55b974152b41bd4501ce7183c7b41603'

if [[ "${EUID:-$(id -u)}" != 0 ]]; then
    echo '[ERREUR] Lancer en root sur Batocera 44.' >&2
    exit 1
fi
if [[ ! -f /userdata/system/1fichier-blondin/app.py ]]; then
    echo '[ERREUR] Installation existante introuvable.' >&2
    echo '[INFO] Cet installateur GitHub met a jour une version deja installee.' >&2
    exit 1
fi
for exe in curl sha256sum bash; do
    command -v "$exe" >/dev/null 2>&1 || { echo "[ERREUR] $exe est absent." >&2; exit 1; }
done

tmp=$(mktemp /userdata/.install-sauvegarde-1fichier-v2.0.XXXXXX.sh)
trap 'rm -f "$tmp"' EXIT
printf '%s\n' '[INFO] Telechargement de Sauvegarde 1fichier v2.0 depuis GitHub...'
curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 --max-time 180 \
    "$BASE_URL/install-sauvegarde-1fichier-blondin-v2.0.sh" --output "$tmp"
if ! printf '%s  %s\n' "$SHA256" "$tmp" | sha256sum -c --status; then
    echo '[ERREUR] Controle SHA256 incorrect : installation annulee.' >&2
    exit 1
fi
printf '%s\n' '[OK] Integrite de l installateur verifiee.'
if ! /etc/init.d/S31emulationstation stop; then
    echo '[ERREUR] Impossible d arreter EmulationStation.' >&2
    exit 1
fi
if bash "$tmp"; then
    echo '[OK] Installation v2.0 reussie. Redemarrage complet de Batocera.'
    rm -f "$tmp"
    trap - EXIT
    sync
    reboot
else
    code=$?
    echo '[ERREUR] Installation interrompue : redemarrage d EmulationStation.' >&2
    /etc/init.d/S31emulationstation start || true
    exit "$code"
fi
