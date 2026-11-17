#!/usr/bin/env bash
# Sauvegarde 1fichier ★ BLONDIN EDITION ★ v3.1-COMPLET
# Lanceur dedie Batocera 44 ; ne modifie pas l'install.sh historique v2.1.
set -Eeuo pipefail

URL='https://raw.githubusercontent.com/blondin-svg/blondin.rep/main/Sauvegarde1fichier/1fichier-blondin-v3.1-COMPLET.sh'
SHA256='784409dabed7d73cfebdaa47196be33d10cbce42c3c0feacf25c517ece515606'

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo '[ERREUR] Executer cette commande en SSH root sous Batocera 44.' >&2
  exit 1
fi

for cmd in curl sha256sum bash mktemp; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "[ERREUR] Commande indispensable absente : $cmd" >&2
    exit 1
  }
done

TEMP=$(mktemp /tmp/1fichier-blondin-v3.1.XXXXXXXX.sh)
chmod 600 "$TEMP"
trap 'rm -f -- "$TEMP"' EXIT

echo '[INFO] Telechargement de Sauvegarde 1fichier v3.1-COMPLET...'
curl --fail --location --silent --show-error --retry 3 \
  --connect-timeout 20 --max-time 300 \
  --output "$TEMP" "$URL" || {
  echo '[ERREUR] Telechargement impossible ; aucune installation lancee.' >&2
  exit 1
}

if ! printf '%s  %s\n' "$SHA256" "$TEMP" | sha256sum --check --status; then
  echo '[ERREUR] Integrite SHA-256 incorrecte ; installation annulee.' >&2
  exit 1
fi

bash -n "$TEMP" || {
  echo '[ERREUR] Syntaxe du fichier telecharge invalide.' >&2
  exit 1
}
echo '[OK] Telechargement, integrite SHA-256 et syntaxe valides.'
echo '[INFO] Lancement du programme complet v3.1 (aucune sauvegarde automatique).'
bash "$TEMP"
