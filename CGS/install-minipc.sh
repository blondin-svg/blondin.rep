#!/bin/bash
set -eu

ZIP_URL="https://raw.githubusercontent.com/blondin-svg/blondin.rep/main/CGS/CGS_MiniPC.zip"
ZIP="/tmp/CGS_MiniPC.zip"
DIR="/tmp/CGS_MiniPC"

rm -rf "$DIR" "$ZIP"
mkdir -p "$DIR"

echo "Téléchargement de l'installateur CGS Mini PC..."
wget -q -O "$ZIP" "$ZIP_URL"
unzip -oq "$ZIP" -d "$DIR"
cd "$DIR/CGS_multisource_persistent"
chmod +x install.sh
./install.sh
status=$?
cd /
rm -rf "$DIR" "$ZIP"
exit $status
