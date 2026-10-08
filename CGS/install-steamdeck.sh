#!/bin/bash
set -eu

BASE="https://raw.githubusercontent.com/blondin-svg/blondin.rep/main/CGS/assets/steamdeck"
TMP="/tmp/cgs-steamdeck-github"
B64="$TMP/CGS_SteamDeck.zip.b64"
ZIP="$TMP/CGS_SteamDeck.zip"

rm -rf "$TMP"
mkdir -p "$TMP"
: > "$B64"

for p in 00 01 02 03 04 05; do
    echo "Téléchargement CGS Steam Deck - partie $p..."
    wget -q -O- "$BASE/CGS_SteamDeck.zip.b64.part$p" >> "$B64"
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
cd "$TMP/CGS_multisource_persistent_system_steamdeck"
chmod +x install.sh
./install.sh
status=$?
cd /
rm -rf "$TMP"
exit $status
