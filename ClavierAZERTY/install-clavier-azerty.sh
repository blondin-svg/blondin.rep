#!/bin/bash
# Installe le service clavier_fr pour Batocera 42 (Sway / AZERTY).
# Aucun fichier de /etc ou de /boot n'est modifie.
set -euo pipefail

SERVICE_NAME="clavier_fr"
SERVICE_DIR="/userdata/system/services"
SERVICE_FILE="$SERVICE_DIR/$SERVICE_NAME"
LOG_FILE="/userdata/logs/clavier_fr.log"
PID_FILE="/run/clavier_fr.pid"

say() { printf '%s\n' "$*"; }
confirm() {
    local answer
    if [ ! -r /dev/tty ]; then
        say "[ERREUR] Confirmation impossible sans terminal interactif."
        exit 1
    fi
    read -r -p "$1 [o/N] : " answer < /dev/tty || true
    case "${answer,,}" in o|oui) return 0 ;; *) return 1 ;; esac
}

uninstall() {
    say "============================================"
    say "  DESINSTALLATION DU CLAVIER AZERTY"
    say "============================================"
    if ! confirm "Supprimer le service $SERVICE_NAME ?"; then
        say "Annule : aucune modification."
        return 0
    fi
    say "[1/3] Arret du service..."
    batocera-services stop "$SERVICE_NAME" 2>/dev/null || true
    say "[2/3] Desactivation du demarrage automatique..."
    batocera-services disable "$SERVICE_NAME" 2>/dev/null || true
    say "[3/3] Suppression du fichier de service..."
    rm -f "$SERVICE_FILE"
    say "Desinstallation terminee. Le journal reste dans $LOG_FILE"
    say "Le clavier actuel reste inchange jusqu'au prochain lancement de Sway."
}

if [ "$(id -u)" -ne 0 ]; then
    say "[ERREUR] Cet installateur doit etre lance en root sur Batocera."
    exit 1
fi

if [ "${1:-}" = "--uninstall" ]; then
    uninstall
    exit 0
fi
if [ "${1:-}" != "" ]; then
    say "Usage : bash install-clavier-azerty.sh [--uninstall]"
    exit 2
fi

say "============================================"
say "  INSTALLATEUR CLAVIER AZERTY - BATOCERA 42"
say "============================================"
say "- Service au demarrage : $SERVICE_NAME"
say "- Clavier graphique : Francais (AZERTY)"
say "- Explorateur F1 et applications sous Sway"
say "- Aucun changement dans /etc ni /boot"
say ""

if ! command -v batocera-services >/dev/null 2>&1; then
    say "[ERREUR] batocera-services est introuvable. Installation annulee."
    exit 1
fi
if ! command -v swaymsg >/dev/null 2>&1; then
    say "[ERREUR] swaymsg est introuvable. La session Sway est necessaire."
    exit 1
fi
if ! confirm "Installer ou mettre a jour le service AZERTY ?"; then
    say "Installation annulee : aucune modification."
    exit 0
fi

say "[1/5] Creation des dossiers..."
mkdir -p "$SERVICE_DIR" "$(dirname "$LOG_FILE")"

say "[2/5] Arret de l'ancienne version, si presente..."
if [ -f "$SERVICE_FILE" ]; then
    batocera-services stop "$SERVICE_NAME" 2>/dev/null || true
    backup="/userdata/system/clavier_fr.backup.$(date +%Y%m%d-%H%M%S)"
    cp -p "$SERVICE_FILE" "$backup"
    say "      Sauvegarde : $backup"
fi

say "[3/5] Installation du service Sway..."
cat > "$SERVICE_FILE" <<'SERVICE'
#!/bin/bash
# Service Batocera : mise en AZERTY des claviers Sway.
# Attend le demarrage de Sway et reapplique le reglages apres relancement.
LOG="/userdata/logs/clavier_fr.log"
PID="/run/clavier_fr.pid"

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG"; }

find_socket() {
    local s
    for s in /run/sway-ipc.*.sock /var/run/sway-ipc.*.sock /run/user/*/sway-ipc.*.sock; do
        if [ -S "$s" ]; then
            printf '%s\n' "$s"
            return 0
        fi
    done
    return 1
}

case "${1:-}" in
    start)
        if [ -s "$PID" ] && kill -0 "$(cat "$PID")" 2>/dev/null; then
            exit 0
        fi
        /bin/bash "$0" _monitor </dev/null >/dev/null 2>&1 &
        echo "$!" > "$PID"
        ;;
    _monitor)
        mkdir -p "$(dirname "$LOG")"
        log "Service demarre : attente de Sway."
        trap 'rm -f "$PID"' EXIT
        last_socket=""
        cycles=6
        error_reported=0
        while :; do
            socket="$(find_socket || true)"
            if [ -n "$socket" ] && { [ "$socket" != "$last_socket" ] || [ "$cycles" -ge 6 ]; }; then
                result="$(SWAYSOCK="$socket" swaymsg -s "$socket" 'input type:keyboard xkb_layout fr' 2>&1)"
                if printf '%s\n' "$result" | grep -Eq '"success"[[:space:]]*:[[:space:]]*true'; then
                    if [ "$socket" != "$last_socket" ] || [ "$error_reported" -eq 1 ]; then
                        log "AZERTY applique (socket : $socket)."
                    fi
                    last_socket="$socket"
                    cycles=0
                    error_reported=0
                else
                    if [ "$error_reported" -eq 0 ]; then
                        log "Echec provisoire Sway : $result"
                    fi
                    last_socket=""
                    cycles=6
                    error_reported=1
                fi
            elif [ -z "$socket" ]; then
                last_socket=""
            fi
            cycles=$((cycles + 1))
            sleep 5
        done
        ;;
    stop)
        if [ -s "$PID" ]; then
            pid="$(cat "$PID")"
            kill "$pid" 2>/dev/null || true
        fi
        rm -f "$PID"
        log "Service arrete (disposition courante non modifiee)."
        ;;
    status)
        if [ -s "$PID" ] && kill -0 "$(cat "$PID")" 2>/dev/null; then
            echo "clavier_fr : actif (PID $(cat "$PID"))"
        else
            echo "clavier_fr : arrete"
            exit 1
        fi
        ;;
    *)
        echo "Usage : $0 {start|stop|status}"
        exit 2
        ;;
esac
SERVICE
chmod +x "$SERVICE_FILE"
bash -n "$SERVICE_FILE"

say "[4/5] Activation au demarrage..."
if ! batocera-services enable "$SERVICE_NAME"; then
    say "[ERREUR] Impossible d'activer le service automatiquement."
    exit 1
fi

say "[5/5] Demarrage immediat du service..."
if ! batocera-services start "$SERVICE_NAME"; then
    say "[AVERTISSEMENT] Demarrage immediat indisponible : reessaie apres redemarrage."
fi

say ""
say "============================================"
say "  INSTALLATION TERMINEE"
say "============================================"
say "Service : $SERVICE_FILE"
say "Journal : $LOG_FILE"
say "Verification : $SERVICE_FILE status"
say "Dernieres lignes du journal : tail -n 20 $LOG_FILE"
say "Desinstallation : bash install-clavier-azerty.sh --uninstall"
say "Pour tester : ouvre F1 et tape a, z, q, w."
say "La prise en compte peut demander quelques secondes."
