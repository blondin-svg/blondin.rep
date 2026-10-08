#!/bin/bash
# Installateur AZERTY Batocera 42 - hors ligne
# Services Sway (swaymsg ou sway) / X11 (setxkbmap)
set -euo pipefail

SERVICE_NAME=clavier_fr
SERVICE_PATH=/userdata/system/services/clavier_fr
LOG=/userdata/logs/clavier_fr.log

info() { printf '%s\n' "$*"; }
confirm() {
    local answer
    read -r -p "$1 [o/N] : " answer < /dev/tty || return 1
    case "${answer,,}" in o|oui) return 0 ;; *) return 1 ;; esac
}

if [ "$(id -u)" -ne 0 ]; then
    info '[ERREUR] Connecte-toi en root sur Batocera.'
    exit 1
fi
if ! command -v batocera-services >/dev/null 2>&1; then
    info '[ERREUR] La commande batocera-services est absente.'
    exit 1
fi

if [ "${1:-}" = --uninstall ]; then
    info 'Desinstallation du service clavier_fr.'
    if confirm 'Confirmer la desinstallation ?'; then
        batocera-services stop "$SERVICE_NAME" 2>/dev/null || true
        batocera-services disable "$SERVICE_NAME" 2>/dev/null || true
        rm -f "$SERVICE_PATH"
        info '[OK] Service supprime. Reglages system.kblayout et journal conserves.'
    else
        info 'Annule.'
    fi
    exit 0
fi
if [ $# -ne 0 ]; then
    info 'Usage : bash install-clavier-azerty-v2.sh [--uninstall]'
    exit 2
fi

info '=============================================='
info '  CLAVIER AZERTY - BATOCERA 42 (version 2)'
info '=============================================='
info 'Explorateur F1 et applications graphiques'
info 'Aucun fichier de /etc, /boot ou overlay modifie'
info 'Service au demarrage avec journal de diagnostic'
info ''
info '[DIAGNOSTIC] Commandes detectees :'
for cmd in swaymsg sway setxkbmap; do
    if command -v "$cmd" >/dev/null 2>&1; then
        info "  $cmd : $(command -v "$cmd")"
    else
        info "  $cmd : absent"
    fi
done
if ! command -v swaymsg >/dev/null 2>&1 \
   && ! command -v sway >/dev/null 2>&1 \
   && ! command -v setxkbmap >/dev/null 2>&1; then
    info '[ERREUR] Aucune commande graphique utilisable.'
    info 'Aucune modification effectuee.'
    exit 1
fi
info ''
if ! confirm 'Installer le service clavier_fr ?'; then
    info 'Installation annulee.'
    exit 0
fi

info '[1/5] Preparation...'
mkdir -p /userdata/system/services /userdata/logs
if [ -f "$SERVICE_PATH" ]; then
    info '[2/5] Arret et sauvegarde de la version precedente...'
    batocera-services stop "$SERVICE_NAME" >/dev/null 2>&1 || true
    cp -p "$SERVICE_PATH" "/userdata/system/clavier_fr.bak.$(date +%Y%m%d-%H%M%S)"
else
    info '[2/5] Aucune ancienne version presente.'
fi

info '[3/5] Installation du service...'
cat > "$SERVICE_PATH" <<'SERVICE'
#!/bin/bash
# Service clavier_fr pour Batocera 42
LOG=/userdata/logs/clavier_fr.log
PID_FILE=/run/clavier_fr.pid

log() {
    mkdir -p /userdata/logs
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG"
}

get_sway_socket() {
    local sock
    for sock in /run/sway-ipc.*.sock /var/run/sway-ipc.*.sock /run/user/*/sway-ipc.*.sock; do
        if [ -S "$sock" ]; then
            printf '%s\n' "$sock"
            return 0
        fi
    done
    return 1
}

apply_fr_sway() {
    local sock="$1" result
    if command -v swaymsg >/dev/null 2>&1; then
        result="$(SWAYSOCK="$sock" swaymsg -s "$sock" 'input type:keyboard xkb_layout fr' 2>&1)" || {
            log "swaymsg a echoue : ${result:0:240}"
            return 1
        }
    elif command -v sway >/dev/null 2>&1; then
        # Commande de controle disponible sur certaines versions Batocera.
        result="$(SWAYSOCK="$sock" sway input type:keyboard xkb_layout fr 2>&1)" || {
            log "sway a echoue : ${result:0:240}"
            return 1
        }
    else
        return 1
    fi
    if printf '%s' "$result" | grep -Eq '"success"[[:space:]]*:[[:space:]]*true'; then
        log 'AZERTY active via Sway.'
        return 0
    fi
    log "Reponse Sway non confirmee : ${result:0:240}"
    return 1
}

apply_fr_x11() {
    local display result
    command -v setxkbmap >/dev/null 2>&1 || return 1
    for display in "${DISPLAY:-}" :0 :0.0 :1; do
        [ -n "$display" ] || continue
        result="$(DISPLAY="$display" setxkbmap -display "$display" fr 2>&1)" && {
            log "AZERTY active via X11 ($display)."
            return 0
        }
    done
    return 1
}

monitor() {
    local socket previous_socket='' previous_mode='' last_try=0 tick=0 last_error=0
    trap 'rm -f "$PID_FILE"' EXIT
    log 'Demarrage de la surveillance du clavier.'
    while :; do
        socket="$(get_sway_socket || true)"
        # Ne lancer Sway que lorsqu'un socket actif existe.
        if [ -n "$socket" ] && {
             [ "$socket" != "$previous_socket" ] || [ "$previous_mode" != sway ] || [ "$tick" -ge 6 ];
        }; then
            if apply_fr_sway "$socket"; then
                previous_socket="$socket"
                previous_mode=sway
                tick=0
            else
                previous_mode=''
            fi
        elif [ -z "$socket" ] && {
              [ "$previous_mode" != x11 ] || [ "$tick" -ge 6 ];
        }; then
            if apply_fr_x11; then
                previous_mode=x11
                tick=0
            else
                previous_mode=''
                if [ "$last_error" -eq 0 ]; then
                    log 'Session graphique non encore prete ou commande indisponible.'
                    last_error=1
                fi
            fi
        fi
        if [ -n "$previous_mode" ]; then last_error=0; fi
        tick=$((tick + 1))
        sleep 5
    done
}

case "${1:-}" in
    start)
        if [ -s "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            exit 0
        fi
        bash "$0" _monitor </dev/null >/dev/null 2>&1 &
        echo "$!" > "$PID_FILE"
        ;;
    _monitor)
        monitor
        ;;
    stop)
        if [ -s "$PID_FILE" ]; then
            pid="$(cat "$PID_FILE")"
            kill "$pid" 2>/dev/null || true
        fi
        rm -f "$PID_FILE"
        log 'Arret du service.'
        ;;
    status)
        if [ -s "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            printf 'clavier_fr : actif (PID %s)\n' "$(cat "$PID_FILE")"
        else
            echo 'clavier_fr : arrete'
            exit 1
        fi
        ;;
    *)
        echo 'Usage : clavier_fr {start|stop|status}'
        exit 2
        ;;
esac
SERVICE
chmod +x "$SERVICE_PATH"
bash -n "$SERVICE_PATH"

info '[4/5] Configuration de Batocera...'
if command -v batocera-settings-set >/dev/null 2>&1; then
    batocera-settings-set system.kblayout fr || info '[AVERTISSEMENT] system.kblayout non applique.'
fi
batocera-services enable "$SERVICE_NAME"

info '[5/5] Lancement du service...'
if ! batocera-services start "$SERVICE_NAME"; then
    info '[AVERTISSEMENT] Service non demarre immediatement.'
    info "Essai manuel : $SERVICE_PATH start"
fi

info ''
info '=============================================='
info '  INSTALLATION TERMINEE'
info '=============================================='
info "Service : $SERVICE_PATH"
info "Journal : $LOG"
info 'Verification : /userdata/system/services/clavier_fr status'
info 'Diagnostic   : tail -n 20 /userdata/logs/clavier_fr.log'
info 'Test : ouvrir F1 et saisir A Z Q W.'
info 'Un redemarrage est conseille si le clavier reste QWERTY.'
