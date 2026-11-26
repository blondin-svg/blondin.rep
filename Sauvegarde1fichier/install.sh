#!/usr/bin/env bash
# Sauvegarde 1fichier ★ BLONDIN EDITION ★ — v3.4.7 TEST
set -Eeuo pipefail
INSTALL_URL='https://raw.githubusercontent.com/blondin-svg/blondin.rep/main/Sauvegarde1fichier/install-1fichier-v3.4.7-TEST-COMPLET-AUTONOME.sh'
INSTALL_GIT_BLOB='519e32e3c452e03a2ae1d18fca51e817334f55a0'
INSTALL_SIZE=2612568
if [[ "$(id -u)" -ne 0 ]] || ! grep -qi batocera /etc/os-release || ! grep -Eq '(^|[^0-9])44([^0-9]|$)' /etc/os-release; then
  echo '[ERREUR] Batocera 44 et SSH root requis.' >&2
  exit 1
fi
for cmd in curl python3 bash mktemp; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "[ERREUR] Outil absent : $cmd" >&2; exit 1; }
done
INSTALL_TMP=$(mktemp /tmp/1fichier-blondin-v3.4.7.XXXXXXXX.sh)
chmod 600 "$INSTALL_TMP"
trap 'rm -f -- "$INSTALL_TMP"' EXIT
echo '[INFO] Téléchargement v3.4.7 TEST...'
curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 --max-time 240 --output "$INSTALL_TMP" "$INSTALL_URL"
python3 - "$INSTALL_TMP" "$INSTALL_GIT_BLOB" "$INSTALL_SIZE" <<'PY'
import hashlib, pathlib, sys
data = pathlib.Path(sys.argv[1]).read_bytes()
actual = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
if len(data) != int(sys.argv[3]) or actual != sys.argv[2]:
    sys.exit('[ERREUR] Intégrité du fichier Git incorrecte ; installation annulée.')
print('[OK] Taille et empreinte Git vérifiées.')
PY
bash -n "$INSTALL_TMP"
bash "$INSTALL_TMP"
