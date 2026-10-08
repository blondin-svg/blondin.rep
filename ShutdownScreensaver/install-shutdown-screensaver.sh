#!/bin/bash
# Installateur de l'extinction automatique par economiseur d'ecran
# Batocera 42 / 43.1 - v1.0
set -euo pipefail

BASE=/userdata/system/configs/emulationstation/scripts
START="$BASE/screensaver-start/shutdown-trigger.sh"
STOP="$BASE/screensaver-stop/shutdown-cancel.sh"
STATE=/tmp/shutdown.screensaver
BACKUPS=/userdata/system/backup_shutdown_screensaver

info() { printf '%s\n' "$*"; }
fail() { info "[ERREUR] $*" >&2; exit 1; }
ask() {
    IFS= read -r REPLY </dev/tty || fail "Saisie interrompue."
}
confirm() {
    printf "%s [o/N] : " "$1"
    ask
    case "$REPLY" in o|O|oui|Oui|OUI) return 0 ;; *) return 1 ;; esac
}
cancel_timer() {
    local pid="" token=""
    if [[ -f "$STATE" ]]; then
        read -r pid token < "$STATE" || true
        rm -f -- "$STATE"
        if [[ "$pid" =~ ^[0-9]+$ && -n "$token" && -r "/proc/$pid/cmdline" ]]; then
            if tr '\0' ' ' < "/proc/$pid/cmdline" | grep -q 'shutdown-trigger.sh --worker'; then
                kill "$pid" 2>/dev/null || true
            fi
        fi
    fi
}

info "======================================================"
info " EXTINCTION AUTOMATIQUE - BATOCERA 42 / 43.1"
info "======================================================"
info "Demarre un compte a rebours quand l'economiseur demarre."
info "Annule l'extinction si l'economiseur est interrompu."
info ""
[[ "$(id -u)" == 0 ]] || fail "Se connecter en root."
[[ -d /userdata/system ]] || fail "Dossier /userdata/system absent."
[[ -r /dev/tty ]] || fail "Une connexion SSH interactive est necessaire."

info "Choisis l'unite du delai :"
info "  1) Minutes"
info "  2) Heures"
while true; do
    printf "Choix [1/2] : "
    ask
    case "$REPLY" in
        1) UNIT="minute(s)"; FACTOR=60; MAX=10080; break ;;
        2) UNIT="heure(s)"; FACTOR=3600; MAX=168; break ;;
        *) info "Saisis 1 ou 2." ;;
    esac
done

while true; do
    printf "Nombre de %s (1 a %s) : " "$UNIT" "$MAX"
    ask
    if [[ "$REPLY" =~ ^[0-9]{1,5}$ ]]; then
        VALUE=$((10#$REPLY))
        if (( VALUE >= 1 && VALUE <= MAX )); then break; fi
    fi
    info "Saisis un entier valide."
done

SECONDS_DELAY=$((VALUE * FACTOR))
info ""
info "-------------------- RECAPITULATIF --------------------"
info "Delai choisi : $VALUE $UNIT"
info "Installation : $START"
info "               $STOP"
info "Permissions  : chmod 755 sur les deux scripts"
info "Sauvegarde   : anciennes versions conservees"
info "Extinction   : batocera-es-swissknife --shutdown"
info "-------------------------------------------------------"
info ""
if ! confirm "Confirmer l'installation ?"; then
    info "[ANNULE] Aucune modification effectuee."
    exit 0
fi

info ""
info "[1/5] Creation des dossiers..."
mkdir -p "$(dirname "$START")" "$(dirname "$STOP")" "$BACKUPS"

info "[2/5] Sauvegarde des scripts precedents..."
if [[ -e "$START" || -e "$STOP" ]]; then
    DEST="$BACKUPS/$(date +%Y%m%d-%H%M%S)-$$"
    mkdir -p "$DEST"
    if [[ -e "$START" ]]; then cp -p -- "$START" "$DEST/shutdown-trigger.sh"; fi
    if [[ -e "$STOP" ]]; then cp -p -- "$STOP" "$DEST/shutdown-cancel.sh"; fi
    info "  [OK] Sauvegarde : $DEST"
else
    info "  [OK] Premiere installation."
fi

info "[3/5] Annulation du minuteur precedent..."
cancel_timer
info "  [OK] Ancien minuteur annule."

info "[4/5] Ecriture des scripts..."
TMP_START="$(mktemp "$START.tmp.XXXXXX")"
TMP_STOP="$(mktemp "$STOP.tmp.XXXXXX")"
trap 'rm -f -- "$TMP_START" "$TMP_STOP"' EXIT

cat > "$TMP_START" <<'TRIGGER'
#!/bin/bash
# screensaver-start - Batocera 42 / 43.1
STATE=/tmp/shutdown.screensaver
DELAY_SECONDS=__SECONDS__

if [[ "$1" == --worker ]]; then
    [[ $# -eq 2 ]] || exit 2
    token="$2"
    sleep "$DELAY_SECONDS" || exit 0
    [[ -f "$STATE" ]] || exit 0
    pid="" active_token=""
    read -r pid active_token < "$STATE" || exit 0
    [[ "$pid" == "$$" && "$active_token" == "$token" ]] || exit 0
    rm -f -- "$STATE"
    if command -v batocera-es-swissknife >/dev/null 2>&1; then
        batocera-es-swissknife --shutdown && exit 0
    fi
    shutdown -h now
    exit 0
fi

old_pid="" old_token=""
if [[ -f "$STATE" ]]; then
    read -r old_pid old_token < "$STATE" || true
    rm -f -- "$STATE"
    if [[ "$old_pid" =~ ^[0-9]+$ && -n "$old_token" && -r "/proc/$old_pid/cmdline" ]]; then
        if tr '\0' ' ' < "/proc/$old_pid/cmdline" | grep -q 'shutdown-trigger.sh --worker'; then
            kill "$old_pid" 2>/dev/null || true
        fi
    fi
fi

token="$(date +%s)-$$-$RANDOM"
nohup /bin/bash "$0" --worker "$token" </dev/null >/dev/null 2>&1 &
pid=$!
printf '%s %s\n' "$pid" "$token" > "$STATE"
exit 0
TRIGGER

cat > "$TMP_STOP" <<'CANCEL'
#!/bin/bash
# screensaver-stop - Batocera 42 / 43.1
STATE=/tmp/shutdown.screensaver
pid="" token=""
if [[ -f "$STATE" ]]; then
    read -r pid token < "$STATE" || true
    rm -f -- "$STATE"
    if [[ "$pid" =~ ^[0-9]+$ && -n "$token" && -r "/proc/$pid/cmdline" ]]; then
        if tr '\0' ' ' < "/proc/$pid/cmdline" | grep -q 'shutdown-trigger.sh --worker'; then
            kill "$pid" 2>/dev/null || true
        fi
    fi
fi
exit 0
CANCEL

sed -i "s/^DELAY_SECONDS=__SECONDS__$/DELAY_SECONDS=$SECONDS_DELAY/" "$TMP_START"
chmod 755 "$TMP_START" "$TMP_STOP"
mv -f -- "$TMP_START" "$START"
mv -f -- "$TMP_STOP" "$STOP"

info "[5/5] Verification des permissions, du delai et de la syntaxe..."
[[ -x "$START" && -x "$STOP" ]] || fail "Permissions incorrectes."
grep -q "^DELAY_SECONDS=$SECONDS_DELAY$" "$START" || fail "Delai incorrect."
bash -n "$START" "$STOP" || fail "Erreur de syntaxe."
info "  [OK] Scripts executables et delai enregistre."
info ""
info "======================================================"
info " INSTALLATION TERMINEE AVEC SUCCES"
info "======================================================"
info "Delai : $VALUE $UNIT a partir du prochain economiseur."
info "Relance l'installateur pour changer le delai."
