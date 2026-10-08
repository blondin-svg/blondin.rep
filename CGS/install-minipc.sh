#!/bin/bash
set -eu

BASE="https://raw.githubusercontent.com/blondin-svg/blondin.rep/main/CGS/assets/minipc"
TMP="/tmp/cgs-minipc-github"
B64="$TMP/CGS_MiniPC.zip.b64"
ZIP="$TMP/CGS_MiniPC.zip"

rm -rf "$TMP"
mkdir -p "$TMP"
: > "$B64"

for p in 00 01; do
    echo "Téléchargement CGS Mini PC - partie $p..."
    wget -q -O- "$BASE/CGS_MiniPC.zip.b64.part$p" >> "$B64"
done

python3 - "$B64" "$ZIP" <<'PY'
import base64, sys
src, dst = sys.argv[1:3]
with open(src, 'rb') as f:
    data = base64.b64decode(f.read())
with open(dst, 'wb') as f:
    f.write(data)
PY

unzip -oq "$ZIP" -d "$TMP"
cd "$TMP/CGS_multisource_persistent"
chmod +x install.sh
./install.sh
status=$?
cd /
rm -rf "$TMP"
exit $status
