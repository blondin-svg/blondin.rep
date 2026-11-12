#!/bin/bash
# Gestionnaire Batocera ★ BLONDIN EDITION ★
# LinuxLoader/Lindbergh v1 TEST — uniquement linuxloader.ini
# Hook Batocera : gameStart|gameStop system emulator core rom
set -u

EVENT="${1:-}"
SYSTEM="${2:-}"
ROM="${5:-}"
case "$EVENT" in gameStart|gameStop) ;; *) exit 0 ;; esac
# Système Lindbergh ou ROM explicitement située dans son dossier.
if [[ "$SYSTEM" != 'lindbergh' && "$ROM" != /userdata/roms/lindbergh/* ]]; then
  exit 0
fi

CFG_DIR='/userdata/system/configs/linuxloader'
CFG="$CFG_DIR/linuxloader.ini"
STATE_DIR='/userdata/system/blondin-linuxloader-patch'
STATE="$STATE_DIR/dernier-lindbergh.sha256"
BACKUP_DIR="$STATE_DIR/sauvegardes"
LOG='/userdata/system/logs/correctif-linuxloader-lindbergh.log'

# Refuser les chemins symboliques et inhabituels ; ne jamais suivre un lien.
for d in "$CFG_DIR" "$STATE_DIR" "$BACKUP_DIR" '/userdata/system/logs'; do
  [[ ! -L "$d" ]] || exit 1
done
[[ ! -L "$CFG" && ! -L "$STATE" ]] || exit 1
mkdir -p -- "$STATE_DIR" "$BACKUP_DIR" '/userdata/system/logs' || exit 1
log(){ printf '%s : %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG"; }

if [[ "$EVENT" == 'gameStop' ]]; then
  # Enregistrer la configuration stable à la sortie du jeu Lindbergh.
  [[ -f "$CFG" && ! -L "$CFG" ]] || { log 'Lindbergh quitté : configuration absente, témoin non modifié'; exit 0; }
  sum="$(sha256sum -- "$CFG" | awk '{print $1}')" || exit 1
  [[ "$sum" =~ ^[a-f0-9]{64}$ ]] || exit 1
  tmp="$(mktemp "$STATE_DIR/.etat.XXXXXXXX")" || exit 1
  if ! printf '%s\n' "$sum" > "$tmp" || ! chmod 600 "$tmp" || ! mv -f -- "$tmp" "$STATE"; then
    rm -f -- "$tmp"
    exit 1
  fi
  log "Lindbergh quitté : empreinte mémorisée ($SYSTEM)"
  exit 0
fi

# Au démarrage, si la configuration est inchangée depuis le dernier
# Lindbergh, aucune opération ; si elle a changé, sauvegarde puis effacement.
[[ -f "$CFG" && ! -L "$CFG" ]] || { log 'Lindbergh : linuxloader.ini absent, aucune correction nécessaire'; exit 0; }
current="$(sha256sum -- "$CFG" | awk '{print $1}')" || exit 1
if [[ -f "$STATE" && ! -L "$STATE" ]]; then
  IFS= read -r reference < "$STATE" || reference=''
  if [[ "$reference" =~ ^[a-f0-9]{64}$ && "$current" == "$reference" ]]; then
    log 'Lindbergh : configuration identique, nettoyage évité'
    exit 0
  fi
fi

# Sauvegarder avant toute modification. Ne toucher jamais à controls.ini.
backup="$BACKUP_DIR/linuxloader.ini-$(date '+%Y%m%d-%H%M%S')-$$"
if ! cp -p -- "$CFG" "$backup" || ! cmp -s -- "$CFG" "$backup"; then
  rm -f -- "$backup"
  log 'ERREUR : sauvegarde impossible, configuration préservée'
  exit 1
fi
if ! rm -f -- "$CFG"; then
  log 'ERREUR : impossible de réinitialiser linuxloader.ini'
  exit 1
fi
log "Lindbergh : linuxloader.ini réinitialisé (sauvegarde : $backup)"
# Ne conserver que cinq sauvegardes créées par ce correctif.
mapfile -t old < <(find "$BACKUP_DIR" -maxdepth 1 -type f -name 'linuxloader.ini-*' -printf '%T@ %p\n' | sort -rn | cut -d' ' -f2- | tail -n +6)
for file in "${old[@]}"; do
  [[ "$file" == "$BACKUP_DIR"/linuxloader.ini-* && -f "$file" && ! -L "$file" ]] && rm -f -- "$file"
done
exit 0
