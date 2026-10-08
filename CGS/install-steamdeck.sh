#!/bin/bash
set -eu

ZIP_URL="https://raw.githubusercontent.com/blondin-svg/blondin.rep/main/CGS/CGS_SteamDeck.zip"
ZIP="/tmp/CGS_SteamDeck.zip"
DIR="/tmp/CGS_SteamDeck"

rm -rf "$DIR" "$ZIP"
mkdir -p "$DIR"

echo "Téléchargement de l'installateur CGS Steam Deck..."
wget -q -O "$ZIP" "$ZIP_URL"
unzip -oq "$ZIP" -d "$DIR"
cd "$DIR/CGS_multisource_persistent_system_steamdeck"
chmod +x install.sh
./install.sh
status=$?
cd /
rm -rf "$DIR" "$ZIP"
exit $status
