#!/usr/bin/env bash
# Sauvegarde 1fichier ★ BLONDIN EDITION ★ v3.4 COMPLETE — installateur GitHub Batocera 44
# Base v3.3 pinnee + correctif Web v3.4 AVANT le redemarrage final.
set -Eeuo pipefail
[[ "$(id -u)" -eq 0 ]] || { echo '[ERREUR] Executer en root.' >&2; exit 1; }
for c in curl python3 bash; do command -v "$c" >/dev/null || { echo "[ERREUR] $c manquant." >&2; exit 1; }; done
WORK=$(mktemp -d /tmp/blondin-full-v34.XXXXXXXX)
trap 'rm -rf -- "$WORK"' EXIT
BASE_URL='https://raw.githubusercontent.com/blondin-svg/blondin.rep/00a363dd0aaeae1c07a1e7d648a2b8941ae4431f/Sauvegarde1fichier/install-v3.3.sh'
PATCH_URL='https://raw.githubusercontent.com/blondin-svg/blondin.rep/7d612bb96601c039193e9e2d0d4adeb8a91fd59c/Sauvegarde1fichier/install-v3.4.sh'
curl -fLsS --retry 3 --connect-timeout 20 "$BASE_URL" -o "$WORK/v33.sh"
curl -fLsS --retry 3 --connect-timeout 20 "$PATCH_URL" -o "$WORK/v34.sh"
bash "$WORK/v34.sh" --extract "$WORK/patch.py"
python3 - "$WORK/v33.sh" "$WORK/v34-generated.sh" "$WORK/patch.py" <<'PY_MERGE_V34'
from pathlib import Path
import hashlib,sys
src=Path(sys.argv[1]).read_text(encoding='utf-8')
# Verifier le blob Git fige de v3.3 avant toute modification.
b=src.encode('utf-8');blob=hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
if blob!='dd60ead08821bbad79729863e765957da5514894':
    raise SystemExit('[ERREUR] Base v3.3 modifiee : installation annulee.')
import base64,zlib
payload=Path(sys.argv[3]).read_bytes()
if b'BLONDIN-WEB-V34-CAT-SCROLL' not in payload:
    raise SystemExit('[ERREUR] Correctif Web v3.4 invalide.')
packed=base64.b64encode(zlib.compress(payload,9)).decode('ascii')
needle='out=Path(sys.argv[2]);out.write_bytes(source);out.chmod(0o700)'
insertion=(
  "# Web v3.4 : injection apres v3.3, avant demarrage service/reboot.\n"
  "patch=zlib.decompress(base64.b64decode("+repr(packed)+"))\n"
  "key=b'\\nPY_SUBMENU\\n\\n'\n"
  "if source.count(key)!=1: raise SystemExit('[ERREUR] Point Web v3.4 non reconnu.')\n"
  "source=source.replace(key,key+b'python3 - \"$BASE\" <<\\'PY_WEB_V34\\'\\n'+patch+b'\\nPY_WEB_V34\\n\\n',1)\n"
)
if src.count(needle)!=1:raise SystemExit('[ERREUR] Point injection v3.3 non reconnu.')
src=src.replace(needle,insertion+needle,1)
out=Path(sys.argv[2]);out.write_text(src,encoding='utf-8');out.chmod(0o700)
print('[OK] Installateur complet v3.4 assemble et verifie.')
PY_MERGE_V34
bash -n "$WORK/v34-generated.sh"
bash "$WORK/v34-generated.sh"
