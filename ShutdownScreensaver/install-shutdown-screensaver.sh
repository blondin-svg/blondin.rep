#!/bin/bash
# Mise a niveau detection veille V1.6.9 corrigee (Batocera 42 / 43.1)
set -u
START_DIR=/userdata/system/configs/emulationstation/scripts/screensaver-start
STOP_DIR=/userdata/system/configs/emulationstation/scripts/screensaver-stop
TRIGGER="$START_DIR/shutdown-trigger.sh"
CANCEL="$STOP_DIR/shutdown-cancel.sh"
BACKUP=/userdata/system/backup-shutdown
STATE=/tmp/shutdown.screensaver
MARKER=/tmp/batocera-screensaver-active

[[ $EUID -eq 0 ]] || { echo '[ERREUR] Lancer en root.'; exit 1; }

command -v python3 >/dev/null || { echo '[ERREUR] Python3 requis.'; exit 1; }
[[ ! -e "$STATE" ]] || { echo '[ERREUR] Minuteur actif ou etat present : annuler avant installation.'; exit 1; }
if ps -eo args | grep -E '^(/bin/)?bash /userdata/system/configs/emulationstation/scripts/screensaver-start/shutdown-trigger.sh --worker ' | grep -q .; then
  echo '[ERREUR] Worker actif. Annuler avant installation.'; exit 1
fi
if find "$START_DIR" -maxdepth 1 -type f -name 'shutdown-trigger.sh.bak.*' -print -quit | grep -q .; then
  echo '[ERREUR] Deplacer les anciennes sauvegardes hors de screensaver-start.'; exit 1
fi
if [[ -s "$TRIGGER" ]]; then
  DELAY_VALUE="$(sed -nE 's/^[[:space:]]*DELAY=([0-9]+[smh]?)[[:space:]]*(#.*)?$/\1/p' "$TRIGGER")"
  [[ "$DELAY_VALUE" =~ ^[0-9]+[smh]?$ ]] || { echo '[ERREUR] DELAY non reconnu.'; exit 1; }
  [[ $(grep -Ec '^[[:space:]]*DELAY=' "$TRIGGER") -eq 1 ]] || { echo '[ERREUR] Plusieurs DELAY.'; exit 1; }
  bash -n "$TRIGGER" || exit 1
  echo "[DELAI CONSERVE] $DELAY_VALUE"
else
  echo '[PREMIERE INSTALLATION] Choisir la duree :'
  echo '1) Minutes  2) Heures  3) Heures et minutes'
  read -r -p 'Format [1/2/3] : ' unit || exit 1
  case "$unit" in
    1) read -r -p 'Minutes (1-1440) : ' mins || exit 1
       [[ "$mins" =~ ^[0-9]{1,4}$ ]] || exit 1
       mins=$((10#$mins)); ((mins>=1 && mins<=1440)) || exit 1
       DELAY_VALUE="${mins}m" ;;
    2) read -r -p 'Heures (1-24) : ' hours || exit 1
       [[ "$hours" =~ ^[0-9]{1,2}$ ]] || exit 1
       hours=$((10#$hours)); ((hours>=1 && hours<=24)) || exit 1
       DELAY_VALUE="${hours}h" ;;
    3) read -r -p 'Heures (0-23) : ' hours || exit 1
       read -r -p 'Minutes (0-59) : ' mins || exit 1
       [[ "$hours" =~ ^[0-9]{1,2}$ && "$mins" =~ ^[0-9]{1,2}$ ]] || exit 1
       hours=$((10#$hours)); mins=$((10#$mins))
       ((hours<=23 && mins<=59 && (hours>0 || mins>0))) || exit 1
       DELAY_VALUE="$((hours*60+mins))m" ;;
    *) echo '[ERREUR] Choix invalide.'; exit 1 ;;
  esac
  echo "[NOUVEAU DELAI] $DELAY_VALUE"
fi
[[ ! -f "$CANCEL" ]] || bash -n "$CANCEL" || exit 1
echo '===== INSTALLATION EXTINCTION AUTOMATIQUE CORRIGEE ====='
echo '[INFO] Si la veille est deja active, sortir puis reentrer en veille apres installation.'
read -r -p 'Sauvegarder et installer les deux scripts ? [o/N] : ' ans || exit 0
[[ "$ans" =~ ^[oOyY]$ ]] || { echo '[INFO] Annule.'; exit 0; }
mkdir -p "$BACKUP" "$START_DIR" "$STOP_DIR" || exit 1
stamp="$(date +%Y%m%d-%H%M%S)-$$"
if [[ -f "$TRIGGER" ]]; then cp -p "$TRIGGER" "$BACKUP/shutdown-trigger.sh.bak.$stamp" || exit 1; fi
if [[ -f "$CANCEL" ]]; then cp -p "$CANCEL" "$BACKUP/shutdown-cancel.sh.bak.$stamp" || exit 1; fi
T1="$(mktemp "$BACKUP/.trigger.XXXXXX")" || exit 1
T2="$(mktemp "$BACKUP/.cancel.XXXXXX")" || { rm -f "$T1"; exit 1; }
trap 'rm -f "$T1" "$T2"' EXIT
cat > "$T1" <<'TRIGGER_SCRIPT'
#!/bin/bash
# screensaver-start Batocera 42 / 43.1 - V1.6.9
STATE=/tmp/shutdown.screensaver
MARKER=/tmp/batocera-screensaver-active
DELAY=__DELAY__
SCRIPT=/userdata/system/configs/emulationstation/scripts/screensaver-start/shutdown-trigger.sh
CANCEL=/userdata/system/configs/emulationstation/scripts/screensaver-stop/shutdown-cancel.sh

# Un marqueur est valide seulement pour le meme processus ES et le meme demarrage.
valid_marker(){
  python3 - "$MARKER" <<'PY'
import os,sys
from pathlib import Path
try:
    pid,start,boot=Path(sys.argv[1]).read_text().split()
    if not pid.isdigit() or not start.isdigit(): raise ValueError()
    stat=Path(f'/proc/{pid}/stat').read_text().rsplit(')',1)[1].split()
    argv=Path(f'/proc/{pid}/cmdline').read_bytes().split(b'\0')
    ok=(stat[19]==start and Path('/proc/sys/kernel/random/boot_id').read_text().strip()==boot
        and any(os.path.basename(x.decode(errors='replace'))=='emulationstation' for x in argv if x))
    if not ok: raise ValueError()
except (OSError,ValueError): sys.exit(1)
PY
}
if [[ "${1:-}" == --worker ]]; then
    [[ $# -eq 2 && "$2" =~ ^[0-9]+-[0-9]+-[0-9]+$ ]] || exit 2
    token="$2"
    child=''
    stop_child(){
        trap - TERM INT HUP
        if [[ "$child" =~ ^[0-9]+$ ]]; then
            kill "$child" 2>/dev/null || true
            wait "$child" 2>/dev/null || true
        fi
        exit 0
    }
    trap stop_child TERM INT HUP
    sleep "$DELAY" &
    child=$!
    wait "$child"
    rc=$?
    [[ "$rc" -eq 0 ]] || exit 0
    [[ -f "$STATE" ]] || exit 0
    pid='' active_token=''
    read -r pid active_token < "$STATE" || exit 0
    [[ "$pid" == "$$" && "$active_token" == "$token" ]] || exit 0
    # Ne pas eteindre si ES a redemarre ou si le marqueur est invalide.
    valid_marker || { rm -f -- "$STATE"; exit 0; }
    rm -f -- "$STATE"
    if command -v batocera-es-swissknife >/dev/null 2>&1; then
        batocera-es-swissknife --shutdown && exit 0
    fi
    shutdown -h now
    exit 0
fi
# Appel par EmulationStation : sans argument ou avec le mode random video.
# --manual n enregistre jamais de veille.
if [[ $# -eq 0 || ( $# -eq 1 && "$1" == "random video" ) ]]; then
    python3 - "$MARKER" <<'PY'
import os,sys
from pathlib import Path
matches=[]
for d in os.listdir('/proc'):
    if not d.isdigit(): continue
    try:
        a=Path(f'/proc/{d}/cmdline').read_bytes().split(b'\0')
        if not any(os.path.basename(x.decode(errors='replace'))=='emulationstation' for x in a if x): continue
        st=Path(f'/proc/{d}/stat').read_text().rsplit(')',1)[1].split()[19]
        matches.append((int(d),st))
    except (OSError,ValueError,IndexError): continue
if len(matches)!=1:
    print('[VEILLE] Impossible d identifier une session ES unique.'); sys.exit(1)
pid,start=matches[0]
boot=Path('/proc/sys/kernel/random/boot_id').read_text().strip()
Path(sys.argv[1]).write_text(f'{pid} {start} {boot}\n')
PY
    [[ $? -eq 0 ]] || exit 1
elif [[ "${1:-}" != --manual || $# -ne 1 ]]; then
    exit 2
fi
valid_marker || { echo '[VEILLE] Marqueur non valide : minuteur refuse.'; exit 1; }
if [[ -f "$STATE" ]]; then
    /bin/bash "$CANCEL" --timer-only || exit 1
fi
token="$(date +%s)-$$-$RANDOM"
nohup /bin/bash "$SCRIPT" --worker "$token" </dev/null >/dev/null 2>&1 &
pid=$!
printf '%s %s\n' "$pid" "$token" > "$STATE"
exit 0
TRIGGER_SCRIPT
cat > "$T2" <<'CANCEL_SCRIPT'
#!/bin/bash
# screensaver-stop Batocera 42 / 43.1 - V1.6.9
STATE=/tmp/shutdown.screensaver
MARKER=/tmp/batocera-screensaver-active
SCRIPT=/userdata/system/configs/emulationstation/scripts/screensaver-start/shutdown-trigger.sh
[[ $# -eq 0 || ( $# -eq 1 && ( "$1" == --timer-only || "$1" == "random video" ) ) ]] || exit 2
# Seul l evenement de sortie de veille supprime le marqueur.
if [[ "${1:-}" != --timer-only ]]; then rm -f -- "$MARKER"; fi
pid='' token=''
[[ -f "$STATE" ]] || exit 0
read -r pid token < "$STATE" || exit 1
[[ "$pid" =~ ^[0-9]+$ && "$token" =~ ^[0-9]+-[0-9]+-[0-9]+$ ]] || { echo '[ERREUR] Etat invalide.'; exit 1; }
[[ -r "/proc/$pid/cmdline" ]] || { rm -f -- "$STATE"; exit 0; }
args=()
mapfile -d '' -t args < "/proc/$pid/cmdline" || exit 1
if [[ ${#args[@]} -ne 4 || ( "${args[0]}" != /bin/bash && "${args[0]}" != bash ) || "${args[1]}" != "$SCRIPT" || "${args[2]}" != --worker || "${args[3]}" != "$token" ]]; then
    echo '[ATTENTION] Processus different : aucun signal envoye.'
    exit 1
fi
kill -TERM "$pid" 2>/dev/null || true
for ((i=0;i<20;i++)); do
    [[ -r "/proc/$pid/cmdline" ]] || break
    sleep 0.1
done
if [[ -r "/proc/$pid/cmdline" ]]; then
    echo '[ATTENTION] Worker encore present.'; exit 1
fi
current_pid='' current_token=''
if [[ -f "$STATE" ]]; then
    read -r current_pid current_token < "$STATE" || true
    if [[ "$current_pid" == "$pid" && "$current_token" == "$token" ]]; then
        rm -f -- "$STATE"
    fi
fi
exit 0
CANCEL_SCRIPT
sed -i "s/__DELAY__/$DELAY_VALUE/" "$T1"
chmod 755 "$T1" "$T2"
bash -n "$T1" && bash -n "$T2" || { echo '[ERREUR] Syntaxe invalide.'; exit 1; }
if ! cp -p "$T1" "$TRIGGER"; then echo '[ERREUR] Ecriture trigger impossible.'; exit 1; fi
if ! cp -p "$T2" "$CANCEL"; then
  cp -p "$BACKUP/shutdown-trigger.sh.bak.$stamp" "$TRIGGER" || true
  echo '[ERREUR] Ecriture cancel impossible : trigger restaure.'; exit 1
fi
chmod 755 "$TRIGGER" "$CANCEL" || exit 1
rm -f -- "$MARKER"
# Conserver les 3 dernieres sauvegardes de chaque script apres succes.
limiter_sauvegardes() {
  local prefix="$1" fichier i
  local -a archives=()
  while IFS= read -r fichier; do archives+=("$fichier"); done < <(
    find "$BACKUP" -maxdepth 1 -type f -name "$prefix" -printf '%f\n' | LC_ALL=C sort -r
  )
  for ((i=3; i<${#archives[@]}; i++)); do
    rm -f -- "$BACKUP/${archives[i]}"
  done
}
limiter_sauvegardes 'shutdown-trigger.sh.bak.*'
limiter_sauvegardes 'shutdown-cancel.sh.bak.*'

echo '[OK] Detection automatique installee.'
echo "[OK] DELAY=$DELAY_VALUE conserve."
echo "[SAUVEGARDES] $BACKUP (suffixe $stamp)"
echo '[INFO] Sortir puis reentrer dans l economiseur pour initialiser le marqueur.'
