#!/bin/bash
# Sauvegarde 1fichier BLONDIN EDITION v2.0.1 — installation depuis GitHub
# Installe sur Batocera 44 vierge ou met a jour une version existante.
set -Eeuo pipefail

BASE_URL='https://raw.githubusercontent.com/blondin-svg/blondin.rep/main/Sauvegarde1fichier'
SHA256='154a44b6a22e35dfaf7f44627d8e127acf9c5b82b72f08bed254c7f71a605274'

if [[ "${EUID:-$(id -u)}" != 0 ]]; then
    echo '[ERREUR] Lancer en root sur Batocera 44.' >&2
    exit 1
fi
for exe in curl sha256sum bash; do
    command -v "$exe" >/dev/null 2>&1 || { echo "[ERREUR] $exe est absent." >&2; exit 1; }
done

tmp=$(mktemp /userdata/.install-sauvegarde-1fichier-v2.0.1.XXXXXX.sh)
trap 'rm -f "$tmp"' EXIT
printf '%s\n' '[INFO] Telechargement de Sauvegarde 1fichier v2.0.1 depuis GitHub...'
curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 --max-time 180 \
    "$BASE_URL/install-sauvegarde-1fichier-blondin-v2.0.1.sh" --output "$tmp"
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
    echo '[OK] Installation v2.0.1 reussie. Redemarrage complet de Batocera.'
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
