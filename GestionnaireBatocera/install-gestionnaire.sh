#!/bin/bash
# Gestionnaire Batocera ★ BLONDIN EDITION ★
# Lanceur permanent — version officielle actuelle : v5.0.1.
# Actualiser les trois valeurs du kit à chaque nouvelle version officielle.
set -Eeuo pipefail
VERSION='v5.0.1'
INSTALL_URL='https://raw.githubusercontent.com/blondin-svg/blondin.rep/main/GestionnaireBatocera/v5.0.1/install-gestionnaire-v5.0.1-COMPLET.py'
INSTALL_GIT_BLOB='78a4b1c8cff2e651d554f377cb65374f2e067c53'
INSTALL_SIZE=953782
if [[ "$(id -u)" -ne 0 ]] || ! grep -qi batocera /etc/os-release || ! grep -Eq '(^|[^0-9])44([^0-9]|$)' /etc/os-release; then
  echo '[ERREUR] Batocera 44 et SSH root requis.' >&2
  exit 1
fi
for cmd in curl python3 mktemp; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "[ERREUR] Outil absent : $cmd" >&2; exit 1; }
done
TMP="$(mktemp /tmp/gestionnaire-blondin.XXXXXXXX)"
chmod 600 "$TMP"
trap 'rm -f -- "$TMP"' EXIT
printf '[INFO] Téléchargement du Gestionnaire %s...\n' "$VERSION"
curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 --max-time 240 --output "$TMP" "$INSTALL_URL"
python3 - "$TMP" "$INSTALL_GIT_BLOB" "$INSTALL_SIZE" <<'PY'
import hashlib, pathlib, sys
data = pathlib.Path(sys.argv[1]).read_bytes()
actual = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
if len(data) != int(sys.argv[3]) or actual != sys.argv[2]:
    sys.exit('[ERREUR] Intégrité du fichier Git incorrecte ; installation annulée.')
compile(data, sys.argv[1], 'exec')
print('[OK] Taille, empreinte Git et syntaxe Python vérifiées.')
PY
python3 "$TMP"
