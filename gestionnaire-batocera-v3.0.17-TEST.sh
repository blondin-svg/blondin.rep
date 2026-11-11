#!/bin/bash
# Gestionnaire Batocera BLONDIN EDITION v3.0.17 TEST - Patch souris et refresh ES
set -u
BASE=/userdata/saves/Installscripts
CACHE="$BASE/cache-gestionnaire"
LOGDIR="$BASE/logs-gestionnaire"
SAVES="$BASE/saves"
REPO=blondin-svg/blondin.rep
API="https://api.github.com/repos/$REPO/git/trees/main?recursive=1"
mkdir -p "$CACHE" "$LOGDIR" "$SAVES" || exit 1
LOG="$LOGDIR/gestionnaire-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1
trap 'echo "[ERREUR] Une commande a échoué (ligne $LINENO)."' ERR

NAMES=('Volume Hotkey' 'Menu Redémarrer' 'Clavier AZERTY' 'CGS Mini-PC' 'Extinction automatique' 'Nettoyage Dernières Parties' 'CGS Steam Deck')
FILES=('install-volume-hotkey.sh' 'install-menu-redemarrer.sh' 'install-clavier-azerty.sh' 'install-minipc.sh' 'install-shutdown-screensaver-v3-TEST.sh' 'installer-nettoyer-jeux-recents-v10.1-github.sh' 'install-steamdeck.sh')
# Plusieurs noms possibles selon les versions publiées
PATTERNS=('install-volume-hotkey.sh' 'install-menu-redemarrer.sh' 'install-clavier-azerty.sh' 'install-minipc.sh' 'install-shutdown-screensaver-v3-TEST.sh' 'installer-nettoyer-jeux-recents-v10.1-github.sh|install-nettoyer-jeux-recents.sh|install-nettoyage-jeux-recents.sh|install-nettoyer-jeux-recents-v10.sh' 'install-steamdeck.sh')

backup_file(){
  local source="$1" folder="$2" prefix="$3" dest
  mkdir -p -- "$folder" || return 1
  dest="$folder/$prefix.bak-$(date +%Y%m%d-%H%M%S)-$$"
  cp -p -- "$source" "$dest" || return 1
  echo "[SAUVEGARDE] $dest"
  # Limite les nouvelles sauvegardes de ce fichier aux trois plus recentes.
  python3 - "$folder" "$prefix" <<'PYLIMIT'
import pathlib,sys
folder=pathlib.Path(sys.argv[1]); prefix=sys.argv[2]+'.bak-'
files=sorted((p for p in folder.iterdir() if p.is_file() and p.name.startswith(prefix)),key=lambda p:p.name,reverse=True)
for p in files[3:]: p.unlink()
PYLIMIT
}
# Configurations de manette fournies par l'utilisateur pour Batocera 44.
# Embarquees dans le SH : aucune archive externe necessaire sur la machine.
# Ne jamais ecraser silencieusement une personnalisation plus recente.
padkeys_install(){
  local app="$1" launcher='' target='' folder='' tmp='' expected='' label=''
  case "$app" in
    f1)      label='F1'; launcher='/userdata/roms/ports/F1.sh' ;;
    firefox) label='Firefox'; launcher='/userdata/roms/ports/Firefox.sh' ;;
    filezilla|peazip)
      if ! launcher="$(flatpak_shortcut "$app")"; then
        echo "[ATTENTION] $app : raccourci Flatpak introuvable, commandes manette non installées."
        return 1
      fi
      case "$launcher" in /userdata/roms/flatpak/*.flatpak) ;; *) echo '[SÉCURITÉ] Chemin Flatpak inattendu.'; return 1 ;; esac
      case "$app" in filezilla) label="FileZilla" ;; peazip) label="PeaZip" ;; esac ;;
    *) echo '[ERREUR] Configuration manette inconnue.'; return 1 ;;
  esac
  if [[ ! -f "$launcher" || -L "$launcher" ]]; then
    echo "[ATTENTION] Lanceur absent ou non ordinaire : $launcher"
    return 1
  fi
  target="${launcher}.keys"
  if [[ -L "$target" ]] || { [[ -e "$target" ]] && [[ ! -f "$target" ]]; }; then
    echo "[SÉCURITÉ] Fichier .keys non ordinaire : $target"
    return 1
  fi
  folder="${target%/*}"
  tmp="$(mktemp "$folder/.keys-blondin.XXXXXX")" || return 1
  case "$app" in
    f1) expected="04e14833e6ac214569e3d1f422276102eb5113166f70e3c6c71555e81d61457e"; cat > "$tmp" <<'BLONDIN_KEYS_F1_2030'
{
    "actions_player1": [
        {
            "trigger": "x",
            "type": "key",
            "target": "BTN_RIGHT"
        },
        {
            "trigger": "b",
            "type": "key",
            "target": "BTN_LEFT"
        },
        {
            "trigger": "joystick2up",
            "type": "key",
            "target": "KEY_UP"
        },
        {
            "trigger": "joystick2down",
            "type": "key",
            "target": "KEY_DOWN"
        },
        {
            "trigger": "joystick1",
            "type": "mouse"
        },
        {
            "trigger": "a",
            "type": "key",
            "target": "KEY_BACKSPACE"
        },
        {
            "trigger": "pageup",
            "type": "key",
            "target": "KEY_LEFTCTRL"
        },
        {
            "trigger": "pagedown",
            "type": "key",
            "target": "KEY_LEFTCTRL"
        }
    ]
}
BLONDIN_KEYS_F1_2030
      ;;
    firefox) expected="fa75f587fc837fe295609947e10fd74d58fee9e9ac0c129798e850f893baae7e"; cat > "$tmp" <<'BLONDIN_KEYS_FIREFOX_2030'
{
    "actions_player1": [
        {
            "trigger": "joystick1",
            "type": "mouse"
        },
        {
            "trigger": "b",
            "type": "key",
            "target": "BTN_LEFT"
        },
        {
            "trigger": "x",
            "type": "key",
            "target": "BTN_RIGHT"
        },
        {
            "trigger": "joystick2up",
            "type": "key",
            "target": "KEY_UP"
        },
        {
            "trigger": "joystick2down",
            "type": "key",
            "target": "KEY_DOWN"
        }
    ]
}
BLONDIN_KEYS_FIREFOX_2030
      ;;
    filezilla) expected="ae12ecaa838cf87c3848285bc570bd0948d34486aff3d879bea02d14efd421a2"; cat > "$tmp" <<'BLONDIN_KEYS_FILEZILLA_2030'
{
    "actions_player1": [
        {
            "trigger": "b",
            "type": "key",
            "target": "BTN_LEFT"
        },
        {
            "trigger": "x",
            "type": "key",
            "target": "BTN_RIGHT"
        },
        {
            "trigger": "a",
            "type": "key",
            "target": "KEY_BACKSPACE"
        },
        {
            "trigger": "joystick1",
            "type": "mouse"
        },
        {
            "trigger": "joystick2up",
            "type": "key",
            "target": "KEY_UP"
        },
        {
            "trigger": "joystick2down",
            "type": "key",
            "target": "KEY_DOWN"
        }
    ]
}
BLONDIN_KEYS_FILEZILLA_2030
      ;;
    peazip) expected="5795a958fd0ca37f471e801cef7a001d1f80784814ce3f2d6f0d93a15441d7e2"; cat > "$tmp" <<'BLONDIN_KEYS_PEAZIP_2030'
{
    "actions_player1": [
        {
            "trigger": "a",
            "type": "key",
            "target": "KEY_BACKSPACE"
        },
        {
            "trigger": "b",
            "type": "key",
            "target": "BTN_LEFT"
        },
        {
            "trigger": "x",
            "type": "key",
            "target": "BTN_RIGHT"
        },
        {
            "trigger": "joystick1",
            "type": "mouse"
        },
        {
            "trigger": "joystick2up",
            "type": "key",
            "target": "KEY_UP"
        },
        {
            "trigger": "joystick2down",
            "type": "key",
            "target": "KEY_DOWN"
        }
    ]
}
BLONDIN_KEYS_PEAZIP_2030
      ;;
  esac
  # Heredoc ajoute un saut de ligne : le retirer pour préserver les octets originaux.
  if ! python3 - "$tmp" <<'PYSTRIPKEYS'
from pathlib import Path
import sys
p=Path(sys.argv[1]); data=p.read_bytes()
if not data.endswith(b'\n'):
    sys.exit(1)
p.write_bytes(data[:-1])
PYSTRIPKEYS
  then
    rm -f -- "$tmp"; return 1
  fi
  if ! python3 - "$tmp" "$expected" <<'PYVALIDPADKEYS'
import hashlib, json, pathlib, sys
p=pathlib.Path(sys.argv[1]); data=p.read_bytes()
if hashlib.sha256(data).hexdigest()!=sys.argv[2]:
    print('[ERREUR] Configuration manette altérée : signature incorrecte.')
    sys.exit(1)
try:
    cfg=json.loads(data)
    actions=cfg['actions_player1']
    if not isinstance(actions,list) or not actions:
        raise ValueError('liste actions vide')
    for item in actions:
        if not isinstance(item,dict) or item.get('type') not in ('mouse','key') or not item.get('trigger'):
            raise ValueError('action invalide')
        if item['type']=='key' and not item.get('target'):
            raise ValueError('touche manquante')
except (KeyError,ValueError,TypeError) as exc:
    print('[ERREUR] Fichier keys invalide :',exc)
    sys.exit(1)
PYVALIDPADKEYS
  then
    rm -f -- "$tmp"
    return 1
  fi
  if [[ -f "$target" ]] && cmp -s -- "$tmp" "$target"; then
    rm -f -- "$tmp"
    echo "[OK] $label : manette OK."
    return 0
  fi
  if [[ -f "$target" ]]; then
    if ! confirm "Remplacer les commandes manette de $label (avec sauvegarde) ?"; then
      rm -f -- "$tmp"
      echo "[INFO] $label : configuration .keys existante conservée."
      return 0
    fi
    if ! backup_file "$target" "$SAVES/CommandesManette/$app" "${target##*/}"; then
      rm -f -- "$tmp"
      echo '[ERREUR] Sauvegarde impossible : configuration conservée.'
      return 1
    fi
  fi
  if ! chmod 644 "$tmp" || ! mv -f -- "$tmp" "$target"; then
    rm -f -- "$tmp"
    echo '[ERREUR] Installation du fichier .keys impossible.'
    return 1
  fi
  echo "[OK] $label : manette installée."
  echo "[FICHIER] $target"
}
# FIN PADKEYS V2.0.30

# Corrige exclusivement les trois anciens chemins de sauvegarde dans les installateurs connus.
# Ne touche jamais aux archives historiques ni aux fichiers installes par Batocera.
normalize_installer(){
  local idx="$1" source="$2" dest="$3"
  case "$idx" in 1|4|5) ;; *) cp -p -- "$source" "$dest"; return $? ;; esac
  python3 - "$idx" "$source" "$dest" "$SAVES" <<'PYNORM'
from pathlib import Path
import sys
idx=int(sys.argv[1]); src=Path(sys.argv[2]); dst=Path(sys.argv[3]); base=Path(sys.argv[4])
paths={
  1: ('/userdata/system/backup-menu-redemarrer',base/'Redemarrer'),
  4: ('/userdata/system/backup-shutdown',base/'ShutdownScreensaver'),
  5: ('/userdata/system/backup-nettoyer-jeux-recents',base/'NettoyageDernieresParties'),
}
try:
    raw=src.read_bytes()
    if b'\0' in raw: raise ValueError('Fichier non textuel')
    old,new=paths[idx]
    result=raw.replace(old.encode(),str(new).encode())
    dst.write_bytes(result)
    if result!=raw: print('[CHEMINS] Sauvegardes redirigees vers',new)
except (OSError,ValueError) as exc:
    print('[ERREUR] Normalisation :',exc)
    sys.exit(1)
PYNORM
}

# Lecture directe d'une touche pour les menus. En Installation, le choix 1
# attend brièvement une seconde touche pour les choix 10 et 11.
# Les champs de durée restent saisis sur une ligne avec Entrée.
# Habillage ANSI : actif uniquement dans un terminal interactif compatible.
# Les sequences de couleurs ne sont pas ecrites dans les journaux.
# Batocera : le menu est interactif meme si TERM=dumb ou stdin redirige.
# Les couleurs ANSI ont ete validees directement dans le terminal SSH.
# NO_COLOR=1 reste disponible pour desactiver explicitement les couleurs.
UI_COLOR=1
if [[ -n "${NO_COLOR:-}" ]]; then UI_COLOR=0; fi
ui_print(){
  local role="$1" message="$2" color='' reset=''
  if (( UI_COLOR )); then
    case "$role" in
      title|section) color=$'\033[1;96m' ;;
      gold) color=$'\033[1;33m' ;;
      menu) color=$'\033[0;37m' ;;
      info) color=$'\033[0;36m' ;;
      success) color=$'\033[1;32m' ;;
      error) color=$'\033[1;31m' ;;
      warning) color=$'\033[1;33m' ;;
    esac
    reset=$'\033[0m'
  fi
  printf '%s%s%s\n' "$color" "$message" "$reset"
}
ui_section(){
  local heading="$1" inner_width=34 rule
  # Bandeau compact et constant, aucune bordure longue qui se replie.
  (( ${#heading} + 4 > inner_width )) && inner_width=$(( ${#heading} + 4 ))
  (( inner_width > 58 )) && inner_width=58
  printf -v rule '%*s' "$inner_width" ''
  rule="${rule// /─}"
  echo
  if (( UI_COLOR )); then
    printf '  \033[1;36m%s\033[0m\n' "$rule"
    printf '  \033[1;96m%s\033[0m\n' "$heading"
    printf '  \033[0;36m%s\033[0m\n' "$rule"
  else
    printf '  %s\n  %s\n  %s\n' "$rule" "$heading" "$rule"
  fi
}

ui_menu_index(){
  local number="$1"
  case "$number" in
    0) printf '0 ‹' ;;
    Q|q) printf 'Q ×' ;;
    *) printf '%02d ▸' "$((10#$number))" ;;
  esac
}
# Liste des choix du menu courant, reconstruite à chaque rafraîchissement.
# Les données sont héritées dans $(read_key), sans changer les autres menus.
UI_MENU_NUMBERS=()
UI_MENU_LABELS=()
ui_item(){
  local item="$1" number='' label='' marker=''
  if [[ "$item" =~ ^([0-9]+)\)[[:space:]]*(.*)$ ]]; then
    number="${BASH_REMATCH[1]}"; label="${BASH_REMATCH[2]}"
  elif [[ "$item" =~ ^\[([0-9]+)\][[:space:]]*(.*)$ ]]; then
    number="${BASH_REMATCH[1]}"; label="${BASH_REMATCH[2]}"
  elif [[ "$item" =~ ^([Qq])\)[[:space:]]*(.*)$ ]]; then
    number="Q"; label="${BASH_REMATCH[2]}"
  elif [[ "$item" =~ ^\[([Qq])\][[:space:]]*(.*)$ ]]; then
    number="Q"; label="${BASH_REMATCH[2]}"
  fi
  if [[ -n "$number" ]]; then
    # Le bouton Retour est associé à 0 ; Q reste accessible au clavier.
    UI_MENU_NUMBERS+=("$number")
    UI_MENU_LABELS+=("$label")
    if [[ "${BLONDIN_PORTS_PAD:-0}" == 1 ]]; then
      return 0  # Menu affiché et surligné une fois dans manager_menu_navigation
    fi
    marker="$(ui_menu_index "$number")"
    [[ "$number" == 0 && "$label" == Quitter* ]] && marker="0 ×"
    if (( UI_COLOR )); then
      printf '  \033[1;33m%s\033[0m  \033[0;37m%s\033[0m\n' "$marker" "$label"
    else
      printf '  %s  %s\n' "$marker" "$label"
    fi
  else
    ui_print menu "  $item"
  fi
}
# Ligne compacte : option [1] et version/état sur une même ligne.
ui_software_status(){
  local label="$1" value="$2" installed="$3" color
  if (( UI_COLOR )); then
    if [[ "$installed" == 1 ]]; then color=$'\033[1;32m'; else color=$'\033[1;33m'; fi
    printf '  \033[1;33m01 ▸\033[0m  \033[0;37m%s\033[0m  %s%s\033[0m\n' "$label" "$color" "$value"
  else
    printf '  01 ▸  %s  %s\n' "$label" "$value"
  fi
}
ui_banner(){
  echo
  if (( UI_COLOR )); then
    printf '  \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n'
    printf '  \033[1;97m  GESTIONNAIRE BATOCERA\033[0m\n'
    printf '  \033[1;33m  ★ BLONDIN EDITION ★\033[0m\n'
    printf '  \033[0;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n'
  else
    printf '  ----------------------------------\n  GESTIONNAIRE BATOCERA\n  * BLONDIN EDITION *\n  ----------------------------------\n'
  fi
  ui_print gold '  v3.0.16 TEST  •  BATOCERA 44'
  ui_print success '  ● SYSTÈME PRÊT'
  echo
}

ui_prompt(){
  local prompt="$1"
  [[ "$prompt" == 'Votre choix : ' ]] && prompt='  CHOIX › '
  if (( UI_COLOR )); then
    printf '\033[1;36m%s\033[0m' "$prompt" >&2
  else
    printf '%s' "$prompt" >&2
  fi
}
# Signal de sortie globale : fonctionne aussi depuis les sous-menus exécutés
# dans une substitution de commande $(read_key ...).
MANAGER_MAIN_PID=$$
trap 'exit 0' USR1
manager_closed_message(){ echo 'Gestionnaire fermé.'; }
trap manager_closed_message EXIT
manager_quit_key(){
  [[ "$1" == q || "$1" == Q ]] || return 1
  if [[ "$BASHPID" == "$MANAGER_MAIN_PID" ]]; then
    exit 0
  fi
  kill -USR1 "$MANAGER_MAIN_PID" 2>/dev/null
  # Laisser le processus principal traiter le signal.
  sleep 0.1
  return 0
}
# Mode navigation uniquement pour les prompts de sélection et en session
# graphique Ports. Le clavier numérique reste fonctionnel partout.
manager_menu_navigation(){
  local mode="${1:-single}" index=0 key='' second='' seq='' tail='' selected=''
  local n=${#UI_MENU_NUMBERS[@]} i label number maxcols
  (( n > 0 )) || return 2
  # Les lignes de ui_item sont collectées sans impression en mode Ports.
  # Une seule liste est dessinée, et le curseur est deplacé dans celle-ci.
  maxcols="$(stty size 2>/dev/null | awk '{print $2}')"
  [[ "$maxcols" =~ ^[0-9]+$ ]] || maxcols=48
  (( maxcols > 12 )) || maxcols=48
  (( maxcols > 72 )) && maxcols=72
  manager_draw_menu(){
    local i label number width=$(( maxcols - 13 )) state='' line=''
    (( width > 49 )) && width=49
    (( width < 14 )) && width=14
    for ((i=0;i<n;i++)); do
      label="${UI_MENU_LABELS[$i]:0:$width}"
      number="${UI_MENU_NUMBERS[$i]}"
      if [[ "$number" == Q ]]; then
        line="Q  $label"
      else
        line="$(printf '%02d' "$((10#$number))")  $label"
      fi
      if (( i == index )); then
        # Surbrillance pleine ligne, sans ajouter de nouvelle ligne à chaque touche.
        printf '  \033[1;30;47m ▸ %-*s\033[0m\033[K\n' "$((width+4))" "$line" >&2
      else
        case "$label" in
          '✓ '*) state=$'\033[1;32m' ;;
          '✗ '*) state=$'\033[1;31m' ;;
          '◆ '*) state=$'\033[1;33m' ;;
          *) state=$'\033[0;37m' ;;
        esac
        printf '    \033[0;33m%s\033[0m  %s%s\033[0m\033[K\n' "${line%%  *}" "$state" "$label" >&2
      fi
    done
  }

  # Le prompt vient d'être imprimé : l'effacer, puis afficher la liste.
  printf '\r\033[2K' >&2
  manager_draw_menu
  while IFS= read -r -s -n 1 key; do
    case "$key" in
      $'\033')
        seq=''
        if IFS= read -r -s -n 1 -t 0.18 second; then
          seq="$second"
          if [[ "$second" == '[' || "$second" == 'O' ]]; then
            while IFS= read -r -s -n 1 -t 0.06 tail; do
              seq+="$tail"
              [[ "$tail" =~ [A-Za-z~] || ${#seq} -gt 28 ]] && break
            done
          fi
        fi
        case "$seq" in
          *A) index=$(( (index + n - 1) % n )) ;;
          *B) index=$(( (index + 1) % n )) ;;
          '') printf '%s' 0; return 0 ;;
          *) continue ;;
        esac
        ;;
      '')
        selected="${UI_MENU_NUMBERS[$index]}"
        [[ "$selected" == Q ]] && selected=q
        printf '%s' "$selected"; return 0
        ;;
      q|Q|0)
        manager_quit_key "$key" && return 1
        printf '%s' "$key"; return 0
        ;;
      [1-9])
        if [[ "$mode" == ten && "$key" == 1 ]]; then
          if IFS= read -r -s -n 1 -t 0.8 second; then
            [[ "$second" == 0 || "$second" == 1 ]] && key="1$second"
          fi
        fi
        printf '%s' "$key"; return 0
        ;;
      *) continue ;;
    esac
    # Retour au début de la liste et réécriture en place : pas de répétitions.
    printf '\033[%dA\r' "$n" >&2
    manager_draw_menu
  done
  return 1
}
read_key(){
  local prompt="$1" mode="${2:-single}" key='' second=''
  ui_prompt "$prompt"
  if [[ ! -t 0 ]]; then
    IFS= read -r key || return 1
    manager_quit_key "$key" && return 1
    printf '%s' "$key"
    return 0
  fi
  # Flèches/validation à la manette uniquement depuis le lanceur Ports.
  # Les saisies de confirmation restent des saisies ordinaires.
  if [[ "${BLONDIN_PORTS_PAD:-0}" == 1 && ${#UI_MENU_NUMBERS[@]} -gt 0 && ( "$prompt" == 'Votre choix : ' || "$prompt" == 'CHOIX : ' ) ]]; then
    manager_menu_navigation "$mode"
    return $?
  fi
  IFS= read -r -s -n 1 key || return 1
  if [[ "$key" == $'\033' ]]; then
    # Certains terminaux SSH Android émettent ESC[OP ou ESC[A.
    # Absorber la séquence entière : ne pas laisser [OP au choix suivant.
    local part='' seq=''
    while IFS= read -r -s -n 1 -t 0.08 part; do
      seq+="$part"
      (( ${#seq} < 20 )) || break
    done
    # xterm local : clic gauche sur la ligne Interface Web (SGR mouse).
    if [[ "${ONEF_HOME_MOUSE_ENABLED:-0}" == 1 && "$seq" =~ ^\[\<0\;([0-9]+)\;([0-9]+)M$ ]]; then
      local mouse_col="${BASH_REMATCH[1]}" mouse_row="${BASH_REMATCH[2]}"
      if [[ "${ONEF_HOME_WEB_ROW:-0}" -gt 0 && "$mouse_row" -eq "$ONEF_HOME_WEB_ROW" && "$mouse_col" -ge 5 && "$mouse_col" -le 38 ]]; then
        printf '__WEB_CLICK__'
        return 0
      fi
    fi
    printf '\n' >&2
    printf '__ESC__'
    return 0
  fi
  if [[ "$mode" == ten && "$key" == 1 ]]; then
    # Un bref délai permet de taper 10 sans déclencher immédiatement 1.
    if IFS= read -r -s -n 1 -t 0.8 second; then
      if [[ "$second" == 0 || "$second" == 1 ]]; then
        key="1$second"
      elif [[ -n "$second" ]]; then
        # On ne déclenche pas une autre option à la place de 1.
        printf '\n[INFO] Saisie non reconnue : 1%s\n' "$second" >&2
        return 1
      fi
    fi
  fi
  printf '%s\n' "$key" >&2
  manager_quit_key "$key" && return 1
  printf '%s' "$key"
}
# Rafraichit uniquement l'affichage interactif, sans effacer les journaux.
# Les messages des operations restent visibles jusqu'a leur pause.
refresh_screen(){
  UI_MENU_NUMBERS=()
  UI_MENU_LABELS=()
  # Le terminal SSH peut avoir stdin redirige alors que /dev/tty est disponible.
  # Efface l'ecran complet sans supprimer les journaux ni les fichiers.
  if [[ -w /dev/tty ]]; then
    printf '\033[2J\033[H' > /dev/tty 2>/dev/null || true
  elif [[ -t 2 ]]; then
    printf '\033[2J\033[H' >&2
  fi
}
pause(){
  local _
  printf 'Une touche pour continuer...' >&2
  if [[ -t 0 ]]; then IFS= read -r -s -n 1 _ || true
  else IFS= read -r _ || true; fi
  printf '\n' >&2
}
confirm(){ local ans; ans="$(read_key "$1 [o/N] : ")" || return 1; [[ "$ans" =~ ^[oOyY]$ ]]; }
version(){ if [[ -r /etc/os-release ]]; then . /etc/os-release; printf '%s' "${PRETTY_NAME:-${VERSION:-inconnue}}"; else echo 'inconnue'; fi; }
fetch_tree(){
  [[ ! -L "$CACHE" && ! -L "$CACHE/tree.json" ]] || return 1
  if ! command -v curl >/dev/null 2>&1; then echo '[INFO] GitHub indisponible.'; return 1; fi
  curl -fLsS --connect-timeout 5 --max-time 20 -H 'Accept: application/vnd.github+json' "$API" -o "$CACHE/tree.tmp" || { rm -f "$CACHE/tree.tmp"; return 1; }
  if ! grep -q '"tree"' "$CACHE/tree.tmp"; then rm -f "$CACHE/tree.tmp"; return 1; fi
  mv -f "$CACHE/tree.tmp" "$CACHE/tree.json"
}
find_remote(){
  local idx="$1" filename path
  [[ -f "$CACHE/tree.json" ]] || return 1
  # Parser JSON via Python, pas de jq requis; filtre sur les chemins du depot.
  command -v python3 >/dev/null 2>&1 || return 1
  python3 - "$CACHE/tree.json" "${PATTERNS[$idx]}" <<'PY'
import json,sys,os
try:
    data=json.load(open(sys.argv[1],encoding='utf-8'))
    names=sys.argv[2].split('|')
    paths=[x['path'] for x in data.get('tree',[]) if x.get('type')=='blob' and os.path.basename(x.get('path','')).lower() in names]
    if names[0] in ('install-minipc.sh','install-steamdeck.sh'):
        paths=[p for p in paths if p.startswith('CGS/')]
    paths.sort(key=lambda p:(names.index(os.path.basename(p).lower()),len(p),p))
    if paths: print(paths[0])
except (ValueError,OSError,KeyError): pass
PY
}
# Vérifie que la copie V3 contient bien la correction des différents modes de veille.
# Un ancien installateur V2, même renommé, ne doit pas remplacer la V3.
shutdown_v3_valid(){
  local file="$1" mode
  [[ -s "$file" ]] && bash -n "$file" || return 1
  grep -Fq '# Extinction automatique V3 TEST' "$file" || return 1
  for mode in 'random video' 'black' 'dim' 'slideshow'; do
    # Les modes doivent etre acceptes aussi bien au demarrage qu'a la sortie.
    [[ $(grep -Fc '"$1" == "'"$mode"'"' "$file") -ge 2 ]] || return 1
  done
}
# Installateurs uniquement depuis le cache ; jamais depuis Installscripts.
local_file(){
  local idx="$1" f
  if [[ "$idx" == 4 ]]; then
    f="$CACHE/install-shutdown-screensaver-v3-TEST.sh"
    if [[ -f "$f" && ! -L "$f" ]] && shutdown_v3_valid "$f"; then printf '%s\n' "$f"; return 0; fi
    return 1
  fi
  local -a options=()
  IFS='|' read -r -a options <<< "${PATTERNS[$idx]}"
  for f in "${options[@]}"; do
    if [[ -f "$CACHE/$f" && ! -L "$CACHE/$f" && -s "$CACHE/$f" ]] && bash -n "$CACHE/$f"; then
      printf '%s\n' "$CACHE/$f"; return 0
    fi
  done
  return 1
}

download_one(){
  local idx="$1" path url dest tmp
  echo; echo "===== Téléchargement : ${NAMES[$idx]} ====="
  if ! fetch_tree; then echo '[ATTENTION] GitHub inaccessible : cache conservé.'; return 1; fi
  # Chemin fixe de la V3 : ne jamais choisir une copie portant le meme nom ailleurs.
  if [[ "$idx" == 4 ]]; then
    path='ShutdownScreensaver/install-shutdown-screensaver-v3-TEST.sh'
    if ! python3 - "$CACHE/tree.json" "$path" <<'PYCHECK'
import json,sys
try:
    tree=json.load(open(sys.argv[1],encoding='utf-8')).get('tree',[])
    sys.exit(0 if any(x.get('type')=='blob' and x.get('path')==sys.argv[2] for x in tree) else 1)
except (OSError,ValueError): sys.exit(1)
PYCHECK
    then
      echo '[ATTENTION] V3 absente du dossier ShutdownScreensaver sur GitHub.'
      return 1
    fi
  else
    path="$(find_remote "$idx")"
  fi
  if [[ -z "$path" ]]; then echo '[ATTENTION] Installateur introuvable dans le dépôt.'; return 1; fi
  url="https://raw.githubusercontent.com/$REPO/main/$path"
  dest="$CACHE/${FILES[$idx]}"
  tmp="$(mktemp "$CACHE/.telechargement.XXXXXX")" || return 1
  if ! curl -fLsS --connect-timeout 5 --max-time 40 "$url" -o "$tmp" || [[ ! -s "$tmp" ]]; then
    rm -f "$tmp"; echo '[ERREUR] Téléchargement impossible.'; return 1
  fi
  if ! bash -n "$tmp"; then rm -f "$tmp"; echo '[ERREUR] Syntaxe invalide : ancienne copie conservée.'; return 1; fi
  if [[ "$idx" == 4 ]] && ! shutdown_v3_valid "$tmp"; then
    rm -f "$tmp"
    echo '[ERREUR] Installateur extinction non conforme à la V3 : cache précédent conservé.'
    return 1
  fi
  if [[ "$idx" == 1 || "$idx" == 4 || "$idx" == 5 ]]; then
    local norm
    norm="$(mktemp "$CACHE/.normalisation.XXXXXX")" || { rm -f "$tmp"; return 1; }
    if ! normalize_installer "$idx" "$tmp" "$norm" || ! bash -n "$norm"; then
      rm -f "$tmp" "$norm"; echo '[ERREUR] Correction des chemins impossible.'; return 1
    fi
    mv -f "$norm" "$tmp" || { rm -f "$tmp" "$norm"; return 1; }
  fi
  if [[ -f "$dest" ]] && cmp -s "$tmp" "$dest"; then
    rm -f "$tmp"; echo '[OK] Fichier déjà à jour.'; return 0
  fi
  if [[ -f "$dest" ]]; then
    if ! backup_file "$dest" "$SAVES/Cache" "$(basename "$dest")"; then rm -f "$tmp"; echo '[ERREUR] Sauvegarde impossible.'; return 1; fi
  fi
  if ! chmod 700 "$tmp" || ! mv -f "$tmp" "$dest"; then rm -f "$tmp"; echo '[ERREUR] Mise en cache impossible.'; return 1; fi
  echo "[OK] Téléchargement réussi."
  echo "[FICHIER] $dest"
}
# Compatibilite par version uniquement. Aucun blocage lie au materiel.
# Les versions inconnues exigent une confirmation supplementaire.
detect_batocera_version(){
  local value=''
  if [[ -r /etc/os-release ]]; then
    value="$(sed -nE 's/^VERSION="?([0-9]+(\.[0-9]+)?)"?.*/\1/p' /etc/os-release | head -n 1)"
  fi
  [[ -n "$value" ]] || return 1
  printf '%s\n' "$value"
}
check_compatibility(){
  local idx="$1" os_version=''
  os_version="$(detect_batocera_version)" || true
  case "$idx" in
    0)
      if [[ "$os_version" == 42 || "$os_version" == 42.* ]]; then
        echo '[OK] Volume Hotkey : installateur historique Batocera 42.'
      elif [[ "$os_version" == 44 || "$os_version" == 44.* ]]; then
        echo '[OK] Volume Hotkey prêt.'
      else
        echo '[SÉCURITÉ] Volume Hotkey testé ici uniquement pour Batocera 42 et 44.'
        return 1
      fi ;;
    1|2|3)
      if [[ "$os_version" == 42 || "$os_version" == 42.* ]]; then
        echo '[OK] Compatible Batocera 42.'
      elif [[ "$os_version" == 43.1 || "$os_version" == 43.1.* ]]; then
        echo "[SÉCURITÉ] ${NAMES[$idx]} réservé a Batocera 42. Installation refusée."
        return 1
      else
        echo "[ATTENTION] ${NAMES[$idx]} est prévu pour Batocera 42."
        confirm 'Version non reconnue ou non prise en charge. Continuer a vos risques ?' || return 1
      fi ;;
    4|5|6)
      if [[ "$os_version" == 42 || "$os_version" == 42.* || "$os_version" == 43.1 || "$os_version" == 43.1.* ]]; then
        echo '[OK] Version reconnue.'
        echo '[INFO] Fonctionnement à vérifier.'
      elif [[ "$idx" == 4 && ( "$os_version" == 44 || "$os_version" == 44.* ) ]]; then
        echo '[OK] Extinction V3 : validée.'
      else
        echo '[ATTENTION] Version Batocera non reconnue ou non prise en charge.'
        confirm 'Continuer a vos risques ?' || return 1
      fi ;;
    *) echo '[SÉCURITÉ] Choix inconnu.'; return 1 ;;
  esac
  case "$idx" in
    3) echo '[INFO] CGS Mini-PC : vérifiez que cet outil convient a votre configuration.' ;;
    6) echo '[INFO] CGS Steam Deck : vérifiez que cet outil convient a votre configuration.' ;;
  esac
  return 0
}
# Recharge la liste des jeux sans redemarrer EmulationStation.
# L'API locale /reloadgames a ete testee sur Batocera 42.
reload_es_games(){
  local url='http://127.0.0.1:1234/reloadgames' status
  if ! command -v curl >/dev/null 2>&1; then
    echo '[ATTENTION] curl absent : actualiser les listes de jeux manuellement.'
    return 0
  fi
  status="$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 2 --max-time 5 "$url")" || {
    echo '[ATTENTION] API EmulationStation inaccessible : actualiser manuellement.'
    return 0
  }
  if [[ "$status" == 200 ]]; then
    echo '[OK] Actualisation ES demandée.'
  else
    echo "[ATTENTION] Actualisation refusée (HTTP $status) : actualiser manuellement."
  fi
  return 0
}

# Images des lanceurs Ports : GitHub prioritaire, cache hors ligne en secours.
install_ports_artwork(){
  local idx="$1" zip='' cached='' archive_name='' 
  local path='' url='' tmp=''
  local key launcher target_root="${2:-/userdata/roms/ports}"
  case "$idx" in
    1) key=Redemarrer; launcher=Redemarrer.sh ;;
    5) key=Nettoyage_Dernieres_Parties; launcher=nettoyer-jeux-recents.sh ;;
    7) key=Explorateur_Fichiers; launcher=F1.sh ;;
    8) key=Kodi; launcher=kodi.sh ;;
    10) key=Firefox; launcher=Firefox.sh ;;
    11) key=FileZilla; launcher=FileZilla.sh ;;
    12) key=PeaZip; launcher=PeaZip.sh ;;
    *) return 0 ;;
  esac
  case "$key" in
    Firefox|FileZilla|PeaZip) archive_name=visuels_ports_batocera_logiciels.zip ;;
    *) archive_name=visuels_ports_batocera_principaux.zip ;;
  esac
  cached="$CACHE/$archive_name"
  # Une archive valide en cache évite tout accès réseau.
  if [[ -f "$cached" && ! -L "$cached" ]] && python3 - "$cached" "$key" <<'PYCACHED'
import sys, zipfile
try:
    with zipfile.ZipFile(sys.argv[1]) as z:
        names=set(z.namelist())
        prefixes=('', 'visuels_ports_batocera_covers_definitifs/', 'visuels_ports_batocera_logiciels/')
        ok=any(all(f'{prefix}{sys.argv[2]}/{kind}.png' in names and z.read(f'{prefix}{sys.argv[2]}/{kind}.png').startswith(b'\x89PNG\r\n\x1a\n') for kind in ('cover','logo','fanart')) for prefix in prefixes)
        if not ok: raise ValueError()
except (OSError, ValueError, zipfile.BadZipFile, RuntimeError, KeyError): sys.exit(1)
PYCACHED
  then
    echo '[SOURCE] Visuels : cache.'
  else
  echo "[VISUELS] Cache absent : GitHub pour $launcher..."
  if fetch_tree; then
    path="$(python3 - "$CACHE/tree.json" "$archive_name" <<'PYTREE'
import json,sys
try:
    entries=json.load(open(sys.argv[1],encoding='utf-8'))['tree']
    matches=[e['path'] for e in entries if e.get('type')=='blob' and e['path'].split('/')[-1]==sys.argv[2]]
    if matches: print(sorted(matches,key=lambda p:(len(p),p))[0])
except (OSError,KeyError,ValueError,UnicodeError): pass
PYTREE
)"
    if [[ -n "$path" ]]; then
      url="https://raw.githubusercontent.com/$REPO/main/$path"
      tmp="$(mktemp "$CACHE/.visuels.XXXXXX")" || return 1
      if curl -fLsS --connect-timeout 5 --max-time 90 "$url" -o "$tmp" && [[ -s "$tmp" ]] && \
        python3 - "$tmp" "$key" <<'PYZIP'
import sys,zipfile
try:
    with zipfile.ZipFile(sys.argv[1]) as z:
        prefixes=('', 'visuels_ports_batocera_covers_definitifs/', 'visuels_ports_batocera_logiciels/')
        valid=any(all(z.read(f'{prefix}{sys.argv[2]}/{kind}.png').startswith(b'\x89PNG\r\n\x1a\n') for kind in ('cover','logo','fanart')) for prefix in prefixes if all(f'{prefix}{sys.argv[2]}/{kind}.png' in z.namelist() for kind in ('cover','logo','fanart')))
        if not valid: raise ValueError('Images PNG absentes ou invalides')
except (OSError,zipfile.BadZipFile,KeyError,AssertionError,ValueError,RuntimeError):
    sys.exit(1)
PYZIP
      then
        if [[ -f "$cached" ]] && cmp -s "$tmp" "$cached"; then
          rm -f "$tmp"
          echo '[VISUELS] Archive GitHub déjà à jour.'
        else
          if [[ -f "$cached" ]]; then backup_file "$cached" "$SAVES/Cache" "$(basename "$cached")" || return 1; fi
          mv -f "$tmp" "$cached" || return 1
          echo '[VISUELS] Archive telechargee depuis GitHub et mise en cache.'
        fi
      else
        rm -f "$tmp"
        echo '[ATTENTION] Téléchargement GitHub impossible ou archive invalide.'
      fi
    else
      echo '[ATTENTION] Archive introuvable dans le dépôt GitHub.'
    fi
  else
    echo '[ATTENTION] GitHub indisponible.'
  fi
  fi # fin recherche GitHub si cache invalide
  # Ne jamais reutiliser un cache ZIP qui ne contient pas les 3 PNG du lanceur.
  local candidate
  for candidate in "$cached"; do
    [[ -f "$candidate" && ! -L "$candidate" && -s "$candidate" ]] || continue
    if python3 - "$candidate" "$key" <<'PYVALID'
import sys, zipfile
try:
    with zipfile.ZipFile(sys.argv[1]) as z:
        prefixes=('', 'visuels_ports_batocera_covers_definitifs/', 'visuels_ports_batocera_logiciels/')
        prefix=next((p for p in prefixes if all(f'{p}{sys.argv[2]}/{k}.png' in z.namelist() for k in ('cover','logo','fanart'))), None)
        if prefix is None: raise ValueError('Images absentes')
        for kind in ('cover','logo','fanart'):
            with z.open(f'{prefix}{sys.argv[2]}/{kind}.png') as f:
                if f.read(8) != b'\x89PNG\r\n\x1a\n': raise ValueError('PNG invalide')
except (OSError,zipfile.BadZipFile,KeyError,ValueError,RuntimeError):
    sys.exit(1)
PYVALID
    then
      zip="$candidate"
      echo "[VISUELS] Archive valide utilisée : $candidate"
      break
    else
      echo "[ATTENTION] Archive ignorée (images absentes) : $candidate"
    fi
  done
  if [[ -z "$zip" ]]; then
    echo "[ERREUR] Aucun ZIP valide pour $key. Installer le ZIP complet dans $BASE ou le publier sur GitHub."
    return 1
  fi
  python3 - "$zip" "$target_root" "$key" "${3:-$launcher}" <<'PYART'
import datetime, os, shutil, sys, tempfile, zipfile
from pathlib import Path
import xml.etree.ElementTree as ET
archive, root, key, filename = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3], sys.argv[4]
launcher = root / filename
if not launcher.is_file():
    print('[ATTENTION] Lanceur introuvable, images non installées :', launcher)
    sys.exit(1)
prefixes = ('', 'visuels_ports_batocera_covers_definitifs/', 'visuels_ports_batocera_logiciels/')
try:
    with zipfile.ZipFile(archive) as z:
        prefix = next((p for p in prefixes if all(f'{p}{key}/{k}.png' in z.namelist() for k in ('cover','logo','fanart'))), None)
        if prefix is None: raise ValueError('Images absentes pour '+key)
        required = [f'{prefix}{key}/{kind}.png' for kind in ('cover','logo','fanart')]
        for name in required:
            with z.open(name) as f:
                if f.read(8) != b'\x89PNG\r\n\x1a\n': raise ValueError('PNG invalide : '+name)
except (OSError,zipfile.BadZipFile,KeyError,ValueError) as exc:
    print('[ATTENTION] Archive des visuels invalide :',exc)
    sys.exit(1)
gamelist=root/'gamelist.xml'
try:
    tree=ET.parse(gamelist) if gamelist.exists() else ET.ElementTree(ET.Element('gameList'))
    xmlroot=tree.getroot()
    if xmlroot.tag!='gameList': raise ValueError('Racine XML inattendue')
except (ET.ParseError,ValueError) as exc:
    print('[ATTENTION] gamelist.xml non modifie :',exc)
    sys.exit(1)
media=root/'images'/'gestionnaire-ports'
backup=Path('/userdata/saves/Installscripts/saves/VisuelsPorts')/(datetime.datetime.now().strftime('%Y%m%d-%H%M%S')+'-'+str(os.getpid()))
backup.mkdir(parents=True,exist_ok=False)
if gamelist.exists(): shutil.copy2(gamelist,backup/'gamelist.xml')
for kind in ('cover','logo','fanart'):
    old=media/f'{key}-{kind}.png'
    if old.exists(): shutil.copy2(old,backup/old.name)
print('[SAUVEGARDE]',backup)
# Ne conserver que trois lots de sauvegarde des visuels.
parent=backup.parent
folders=sorted((p for p in parent.iterdir() if p.is_dir()),key=lambda p:p.name,reverse=True)
for old in folders[3:]: shutil.rmtree(old)
entry=None
for game in xmlroot.findall('game'):
    path=game.findtext('path','').strip()
    if os.path.normpath(path.removeprefix('./'))==filename:
        entry=game; break
if entry is None:
    entry=ET.SubElement(xmlroot,'game')
    ET.SubElement(entry,'path').text='./'+filename
    ET.SubElement(entry,'name').text={'Redemarrer':'Redemarrer','Nettoyage_Dernieres_Parties':'Nettoyage Dernieres Parties','Explorateur_Fichiers':'Explorateur de fichiers','Kodi':'Kodi','Firefox':'Firefox','FileZilla':'FileZilla','PeaZip':'PeaZip'}.get(key,key)
details={
 'Firefox': ('Mozilla', 'Navigateur web Mozilla Firefox.'),
 'FileZilla': ('FileZilla Project', 'Client FTP, FTPS et SFTP pour transferer des fichiers.'),
 'PeaZip': ('Giorgio Tani', 'Gestionnaire d archives et outil de compression et extraction.'),
 'Kodi': ('Team Kodi / XBMC Foundation', "Kodi est un centre multimédia gratuit et open source permettant de lire et d'organiser vos films, séries, musiques et photos. Il propose une interface adaptée à la télévision, compatible avec de nombreux formats multimédias, ainsi que des extensions pour enrichir ses fonctionnalités."),
 'Explorateur_Fichiers': ('Équipe Batocera', "Raccourci permettant d'ouvrir l'explorateur de fichiers de Batocera. Il facilite la navigation dans les dossiers, la copie, le déplacement, le renommage et la suppression de fichiers. Pratique pour gérer les ROMs, les sauvegardes, les configurations et les fichiers personnels directement depuis Batocera."),
 'Redemarrer': ('Blondin@ChatGpt', "Utilitaire permettant de redémarrer Batocera directement depuis le système Ports. Il utilise la commande système de redémarrage afin de relancer correctement le mini-PC, notamment lorsque l'option de redémarrage du menu principal d'EmulationStation ne fonctionne pas comme prévu."),
 'Nettoyage_Dernieres_Parties': ('Blondin@ChatGpt', "Utilitaire de gestion de l'historique des dernières parties de Batocera. Il permet de consulter les jeux récemment lancés, de sélectionner les entrées à retirer et de nettoyer l'historique sans supprimer les ROMs ni les sauvegardes des jeux. Il propose une interface graphique utilisable à la manette, avec des fonctions de sélection multiple et de sauvegarde de sécurité.")
}
developer, description=details[key]
# Les fiches Flatpak possedent parfois un nom de developpeur comme titre.
# Pour FileZilla et PeaZip, normaliser les metadonnees de la fiche,
# meme si des valeurs automatiques sont deja presentes.
flatpak_metadata = root.name.lower() == 'flatpak' and key in ('FileZilla', 'PeaZip')
if flatpak_metadata:
    title = entry.find('name')
    if title is None: title = ET.SubElement(entry, 'name')
    title.text = key
for tag,value in (('developer',developer),('desc',description)):
    node=entry.find(tag)
    if node is None: node=ET.SubElement(entry,tag)
    if flatpak_metadata or not (node.text or '').strip(): node.text=value
for tag,kind in (('image','fanart'),('marquee','logo'),('fanart','fanart'),('thumbnail','cover')):
    node=entry.find(tag)
    if node is None: node=ET.SubElement(entry,tag)
    node.text=f'./images/gestionnaire-ports/{key}-{kind}.png'
media.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(archive) as z:
    for kind in ('cover','logo','fanart'):
        dest=media/f'{key}-{kind}.png'
        fd,temp=tempfile.mkstemp(prefix='.visuel-',dir=media)
        try:
            with os.fdopen(fd,'wb') as out, z.open(f'{prefix}{key}/{kind}.png') as src: shutil.copyfileobj(src,out)
            os.replace(temp,dest)
        finally:
            if os.path.exists(temp): os.unlink(temp)
fd,temp=tempfile.mkstemp(prefix='.gamelist-',suffix='.xml',dir=root)
os.close(fd)
try:
    tree.write(temp,encoding='utf-8',xml_declaration=True)
    ET.parse(temp)
    os.replace(temp,gamelist)
finally:
    if os.path.exists(temp): os.unlink(temp)
print('[OK] Visuels et XML installés.')
print('[FICHIER]',filename)
PYART
  local rc=$?
  if (( rc == 0 )); then reload_es_games; fi
  return "$rc"
}

# Verifie les visuels et l'entree gamelist d'un lanceur Ports deja installe.
# Ne touche pas au lanceur ni aux profils : reparer seulement si incomplet.
# Une reparation passe par install_ports_artwork (sauvegarde XML/visuels).
ensure_ports_artwork(){
  local idx="$1" key='' launcher='' root='/userdata/roms/ports'
  case "$idx" in
    7) key=Explorateur_Fichiers; launcher=F1.sh ;;
    8) key=Kodi; launcher=kodi.sh ;;
    10) key=Firefox; launcher=Firefox.sh ;;
    *) echo '[ERREUR] Visuels : application inconnue.'; return 1 ;;
  esac
  if [[ ! -f "$root/$launcher" || -L "$root/$launcher" ]]; then
    echo "[ATTENTION] Lanceur Ports absent ou non ordinaire : $root/$launcher"
    return 1
  fi
  if python3 - "$root" "$launcher" "$key" <<'PYCHECKVISUAL'
import os, sys
from pathlib import Path
import xml.etree.ElementTree as ET
root, filename, key = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
media = root / 'images' / 'gestionnaire-ports'
for kind in ('cover', 'logo', 'fanart'):
    image = media / f'{key}-{kind}.png'
    try:
        with image.open('rb') as f:
            if f.read(8) != b'\x89PNG\r\n\x1a\n': sys.exit(1)
    except OSError:
        sys.exit(1)
try:
    tree = ET.parse(root / 'gamelist.xml')
    if tree.getroot().tag != 'gameList': sys.exit(1)
except (OSError, ET.ParseError):
    sys.exit(1)
expected = {
    'image': 'fanart',
    'marquee': 'logo',
    'fanart': 'fanart',
    'thumbnail': 'cover',
}
for game in tree.getroot().findall('game'):
    path = (game.findtext('path') or '').strip()
    if os.path.normpath(path.removeprefix('./')) != filename:
        continue
    if all((game.findtext(tag) or '').strip() == f'./images/gestionnaire-ports/{key}-{kind}.png'
           for tag, kind in expected.items()):
        sys.exit(0)
sys.exit(1)
PYCHECKVISUAL
  then
    echo "[OK] Visuels et XML OK."
    echo "[FICHIER] $launcher"
    return 0
  fi
  echo "[VISUELS] $launcher : illustrations ou gamelist incomplets ; réparation..."
  install_ports_artwork "$idx"
}


# Volume Hotkey Batocera 44 : installateur TEST embarque dans le gestionnaire.
# La version GitHub historique (Batocera 42) ne doit pas etre appliquee sur 44.
# Les autres pilotes et mappings de manettes de l'installateur sont conserves.

# Sur une installation existante, greffer seulement la prise en charge Steam Deck.
# Ne jamais remplacer les mappages des manettes externes ou le service personnalisé.
# Volume Hotkey : toutes les manettes utilisees par notre service = 2%.
# Fonctionne pour Batocera 42 et 44, y compris apres mise a jour de V2.0.37.
# Une version personnalisee ou une structure inconnue n'est pas modifiee.
volume_hotkey_set_all_step(){
  local script='/userdata/system/volume-hotkey.py'
  if [[ -L "$script" || ! -f "$script" ]]; then
    echo '[SECURITE] Script Volume Hotkey absent ou lien symbolique.'
    return 1
  fi
  # Controle complet avant la sauvegarde et toute ecriture.
  if ! python3 - "$script" check <<'PYALLSTEP'
import ast, pathlib, re, sys
p=pathlib.Path(sys.argv[1])
try:
    src=p.read_text(encoding='utf-8')
    ast.parse(src)
    if 'import evdev' not in src or 'def volume_up():' not in src or 'def volume_down():' not in src:
        raise ValueError('Version non reconnue')
    values=re.findall(r'^VOLUME_STEP\s*=\s*(\d+)\s*$',src,re.M)
    if len(values)!=1 or values[0] not in ('2','5'):
        raise ValueError('Pas de volume personnalise ou non reconnu')
    steam=re.findall(r'^STEAM_DECK_VOLUME_STEP\s*=\s*(\d+)\s*$',src,re.M)
    if steam and (len(steam)!=1 or steam[0]!='2'):
        raise ValueError('Pas Steam Deck personnalise, conserve')
    print('[INFO] Volume Hotkey : pas actuel '+values[0]+'%.')
except (OSError,SyntaxError,ValueError) as e:
    print('[SECURITE] '+str(e),file=sys.stderr)
    sys.exit(1)
PYALLSTEP
  then
    return 1
  fi
  if grep -Eq '^VOLUME_STEP[[:space:]]*=[[:space:]]*2[[:space:]]*$' "$script"; then
    echo '[OK] Toutes les manettes : pas de 2% deja applique.'
    return 0
  fi
  backup_file "$script" "$SAVES/VolumeHotkeyStep" 'volume-hotkey.py' || {
    echo '[SECURITE] Sauvegarde impossible : aucun changement.'
    return 1
  }
  python3 - "$script" write <<'PYALLWRITE'
import ast, os, pathlib, re, sys, tempfile
p=pathlib.Path(sys.argv[1])
try:
    src=p.read_text(encoding='utf-8')
    ast.parse(src)
    if not all(x in src for x in ('import evdev','def volume_down():','def volume_up():')):
        raise ValueError('Structure inattendue')
    if re.findall(r'^STEAM_DECK_VOLUME_STEP\s*=\s*(\d+)\s*$',src,re.M) not in ([],['2']):
        raise ValueError('Reglage Steam Deck personnalise')
    new,count=re.subn(r'^VOLUME_STEP\s*=\s*5\s*$', 'VOLUME_STEP = 2', src, count=1,flags=re.M)
    if count!=1 or len(re.findall(r'^VOLUME_STEP\s*=',src,re.M))!=1:
        raise ValueError('Ancien pas non reconnu : fichier conserve')
    ast.parse(new)
    fd,tmp=tempfile.mkstemp(prefix='.volume-hotkey-allstep.',dir=str(p.parent))
    try:
        with os.fdopen(fd,'w',encoding='utf-8') as f: f.write(new)
        os.chmod(tmp,p.stat().st_mode & 0o777)
        os.replace(tmp,p)
    finally:
        if os.path.exists(tmp): os.unlink(tmp)
    print('[OK] Pas de 2% applique a toutes les manettes.')
except (OSError,SyntaxError,ValueError) as e:
    print('[SECURITE] '+str(e),file=sys.stderr)
    sys.exit(1)
PYALLWRITE
}

# Batocera 42 : preparer une COPIE temporaire de l'installateur officiel.
# L'installateur GitHub et les fichiers caches restent inchanges.
volume_hotkey_prepare_legacy_installer(){
  local source="$1" dest="$2"
  python3 - "$source" "$dest" <<'PYLEGACY'
import ast, pathlib, re, sys
source,dest=map(pathlib.Path,sys.argv[1:3])
try:
    text=source.read_text(encoding='utf-8')
    begin='cat > "$PYTHON_FILE" <<\'PYTHON_EOF\''
    if text.count(begin)!=1: raise ValueError('Installateur Volume Hotkey inconnu')
    head,rest=text.split(begin,1)
    if rest.count('\nPYTHON_EOF')!=1: raise ValueError('Bloc Python ambigu')
    py,tail=rest.split('\nPYTHON_EOF',1)
    ast.parse(py)
    if 'def volume_up():' not in py or 'def volume_down():' not in py:
        raise ValueError('Fonctions Volume Hotkey absentes')
    new,count=re.subn(r'^VOLUME_STEP\s*=\s*5\s*$', 'VOLUME_STEP = 2', py, count=1,flags=re.M)
    if count!=1 or len(re.findall(r'^VOLUME_STEP\s*=',py,re.M))!=1:
        raise ValueError('Pas de volume non reconnu')
    ast.parse(new)
    tail=tail.replace('Pas volume : 5 %','Pas volume : 2 %')
    dest.write_text(head+begin+new+'\nPYTHON_EOF'+tail,encoding='utf-8')
    print('[OK] Installateur temporaire : pas de 2% pour toutes les manettes.')
except (OSError,SyntaxError,ValueError) as e:
    print('[SECURITE] '+str(e),file=sys.stderr)
    sys.exit(1)
PYLEGACY
}

# Volume Hotkey V44 : mettre le pas de volume Steam Deck a 2%, sans
# conserver le comportement Steam Deck existant. Autres manettes gerees a part.
volume_hotkey_v44_adjust_steam_step(){
  local script='/userdata/system/volume-hotkey.py'
  [[ -f "$script" && ! -L "$script" ]] || {
    echo '[SECURITE] Volume Hotkey absent ou lien : operation annulee.'
    return 1
  }
  python3 - "$script" <<'PYSTEP44'
import ast, os, pathlib, re, sys, tempfile
p=pathlib.Path(sys.argv[1])
helper='''# STEAM DECK OLED : pas plus fin, sans changement pour les manettes externes.
STEAM_DECK_VOLUME_STEP = 2

def steam_deck_volume_down():
    if game_running():
        subprocess.run(["batocera-audio", "setSystemVolume", "-{}".format(STEAM_DECK_VOLUME_STEP)])
        print("Steam Deck volume -{}%".format(STEAM_DECK_VOLUME_STEP), flush=True)

def steam_deck_volume_up():
    if game_running():
        subprocess.run(["batocera-audio", "setSystemVolume", "+{}".format(STEAM_DECK_VOLUME_STEP)])
        print("Steam Deck volume +{}%".format(STEAM_DECK_VOLUME_STEP), flush=True)

'''
try:
    src=p.read_text(encoding='utf-8')
    ast.parse(src)
    if 'STEAM_DECK_VOLUME_STEP = 2' in src and 'steam_deck_volume_down, stop_event' in src and 'steam_deck_volume_up, stop_event' in src:
        print('[OK] Steam Deck : pas de 2% deja configure.')
        sys.exit(0)
    if 'STEAM_DECK_VOLUME_STEP' in src or 'steam_deck_volume_down' in src or 'steam_deck_volume_up' in src:
        raise ValueError('Reglage Steam Deck different : version personnalisee preservee.')
    if src.count('def run_steam_deck():') != 1:
        raise ValueError('Routine Steam Deck absente ou inattendue.')
    start=src.index('def run_steam_deck():')
    end=src.index('\n# ============================================================\n# LANCEMENT',start)
    worker=src[start:end]
    worker,n1=re.subn(r'\bvolume_down(?=\s*,\s*stop_event)', 'steam_deck_volume_down',worker)
    worker,n2=re.subn(r'\bvolume_up(?=\s*,\s*stop_event)', 'steam_deck_volume_up',worker)
    if n1 != 1 or n2 != 1 or 'def game_running():' not in src or 'import subprocess' not in src:
        raise ValueError('Structure inconnue : aucune modification.')
    new=src[:start]+helper+worker+src[end:]
    ast.parse(new)
    fd,tmp=tempfile.mkstemp(prefix='.volume-hotkey-step.',dir=p.parent)
    try:
        with os.fdopen(fd,'w',encoding='utf-8') as f:
            f.write(new)
        os.chmod(tmp,p.stat().st_mode & 0o777)
        os.replace(tmp,p)
    finally:
        if os.path.exists(tmp): os.unlink(tmp)
    print('[OK] Steam Deck : pas reduit a 2%, autres manettes conservees.')
except (OSError,SyntaxError,ValueError) as exc:
    print('[SECURITE] ' + str(exc),file=sys.stderr)
    sys.exit(1)
PYSTEP44
}

# Batocera 44 : certains jeux TeknoParrot retournent --emupid=0 / code 21.
# Extension limitee aux evenements de jeu Batocera ; pas de simple test Wine.
volume_hotkey_v44_teknoparrot_patch(){
  local script='/userdata/system/volume-hotkey.py'
  local hook='/userdata/system/scripts/volume-hotkey-teknoparrot.sh'
  [[ -s "$script" && -f "$script" && ! -L "$script" ]] || { echo '[SECURITE] Script Hotkey invalide.'; return 1; }
  [[ ! -L "$hook" && ( ! -e "$hook" || -f "$hook" ) ]] || { echo '[SECURITE] Hook invalide.'; return 1; }
  # Ne remplacer aucun hook personnel inconnu.
  if [[ -f "$hook" ]] && ! grep -Fq 'BLONDIN_VOLUME_TEKNOPARROT_V1' "$hook"; then
    echo '[SECURITE] Hook existant inconnu : aucune modification.'
    return 1
  fi
  if ! python3 - "$script" check <<'PYHOTKEY106'
import ast, pathlib, re, sys
p=pathlib.Path(sys.argv[1]); src=p.read_text(encoding='utf-8'); ast.parse(src)
if src.count('def game_running():')!=1 or 'batocera-es-swissknife' not in src:
    raise SystemExit('[SECURITE] game_running inconnu')
if 'BLONDIN_VOLUME_TEKNOPARROT_V1' not in src:
    pattern=r'(?ms)^def game_running\(\):\s*\n.*?(?=^# ={10,}\n# VOLUME\n)'
    matches=re.findall(pattern,src)
    if len(matches)!=1 or 'result.stdout.strip() not in ("", "0")' not in matches[0]:
        raise SystemExit('[SECURITE] Fonction game_running differente')
PYHOTKEY106
  then return 1; fi
  mkdir -p /userdata/system/scripts || return 1
  if ! grep -Fq 'BLONDIN_VOLUME_TEKNOPARROT_V1' "$script"; then
    backup_file "$script" "$SAVES/VolumeHotkeyV44" 'volume-hotkey.py' || return 1
    if ! python3 - "$script" <<'PYHOTKEY106WRITE'
import ast,os,pathlib,re,sys,tempfile
p=pathlib.Path(sys.argv[1]); src=p.read_text(encoding='utf-8')
pattern=r'(?ms)^def game_running\(\):\s*\n.*?(?=^# ={10,}\n# VOLUME\n)'
matches=re.findall(pattern,src)
if len(matches)!=1: raise SystemExit(1)
replacement="""def game_running():
    # BLONDIN_VOLUME_TEKNOPARROT_V1
    result = subprocess.run(
        ["batocera-es-swissknife", "--emupid"],
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True
    )
    if result.returncode == 0 and result.stdout.strip() not in ("", "0"):
        return True
    # Exception stricte : marqueur pose par gameStart TeknoParrot.
    # Timeout de securite en cas de fermeture anormale sans gameStop.
    try:
        import os
        marker = "/run/blondin-volume-teknoparrot.active"
        return os.path.isfile(marker) and 0 <= time.time() - os.stat(marker).st_mtime < 28800
    except OSError:
        return False


"""
new,count=re.subn(pattern,lambda _:replacement,src,count=1)
if count!=1: raise SystemExit(1)
ast.parse(new)
fd,tmp=tempfile.mkstemp(prefix='.volume-hotkey-tekno.',dir=str(p.parent))
try:
    with os.fdopen(fd,'w',encoding='utf-8') as f: f.write(new)
    os.chmod(tmp,p.stat().st_mode & 0o777)
    os.replace(tmp,p)
finally:
    if os.path.exists(tmp): os.unlink(tmp)
print('[OK] Detection TeknoParrot ajoutee.')
PYHOTKEY106WRITE
    then echo '[ERREUR] Patch TeknoParrot non applique.'; return 1; fi
  else
    echo '[OK] Patch TeknoParrot deja present.'
  fi
  local tmp
  tmp="$(mktemp /userdata/system/scripts/.volume-tekno.XXXXXX)" || return 1
  cat > "$tmp" <<'HOOK106'
#!/bin/bash
# BLONDIN_VOLUME_TEKNOPARROT_V1
# Hook global Batocera : gameStart / gameStop, system en argument 2.
marker='/run/blondin-volume-teknoparrot.active'
case "$1" in
  gameStart)
    if [[ "${2:-}" == 'teknoparrot' ]]; then
      printf '%s\n' 'teknoparrot' > "$marker"
    else
      rm -f -- "$marker"
    fi ;;
  gameStop) rm -f -- "$marker" ;;
esac
exit 0
HOOK106
  chmod 755 "$tmp" || { rm -f -- "$tmp"; return 1; }
  if ! bash -n "$tmp"; then rm -f -- "$tmp"; return 1; fi
  mv -f -- "$tmp" "$hook" || { rm -f -- "$tmp"; return 1; }
  rm -f -- /run/blondin-volume-teknoparrot.active
  if command -v batocera-services >/dev/null 2>&1; then
    batocera-services restart volume_hotkey || { echo '[ATTENTION] Redemarrage Volume Hotkey non confirme.'; return 1; }
  else
    echo '[ATTENTION] Relancer Volume Hotkey manuellement.'
    return 1
  fi
  echo '[OK] TeknoParrot : detection debut/fin de jeu active.'
}

# Logitech G502 X PLUS : clic central maintenu + molette (2% par cran).
# Seule la logique du service Python est etendue, aucun profil souris modifie.
volume_hotkey_v44_mouse_patch(){
  local script='/userdata/system/volume-hotkey.py'
  [[ -s "$script" && -f "$script" && ! -L "$script" ]] || {
    echo '[SECURITE] Script Volume Hotkey absent ou invalide.'; return 1;
  }
  if ! python3 - "$script" check <<'PYMOUSE107CHECK'
import ast, pathlib, sys
p=pathlib.Path(sys.argv[1]); src=p.read_text(encoding='utf-8'); ast.parse(src)
if 'BLONDIN_VOLUME_MOUSE_G502_V1' in src:
    if src.count('BLONDIN_VOLUME_MOUSE_G502_V1')!=1 or 'thread_mouse_g502.start()' not in src:
        raise SystemExit('[SECURITE] Patch souris incomplet')
else:
    marker='# ============================================================\n# LANCEMENT\n# ============================================================'
    if src.count(marker)!=1 or src.count('thread_ultimate.join()')!=1:
        raise SystemExit('[SECURITE] Point insertion non reconnu')
    for need in ('import evdev','import threading','import time','def game_running():','def volume_down(', 'def volume_up('):
        if need not in src: raise SystemExit('[SECURITE] Script non reconnu : '+need)
PYMOUSE107CHECK
  then return 1; fi
  if grep -Fq 'BLONDIN_VOLUME_MOUSE_G502_V1' "$script"; then
    echo '[OK] Controle souris deja present.'
    return 0
  fi
  backup_file "$script" "$SAVES/VolumeHotkeyV44" 'volume-hotkey.py' || return 1
  if ! python3 - "$script" <<'PYMOUSE107WRITE'
import ast, os, pathlib, sys, tempfile
p=pathlib.Path(sys.argv[1]); src=p.read_text(encoding='utf-8')
marker='# ============================================================\n# LANCEMENT\n# ============================================================'
worker="""# BLONDIN_VOLUME_MOUSE_G502_V1
# G502 X PLUS : BTN_MIDDLE (274) maintenu + REL_WHEEL (8).
# La molette est traitee une fois par cran, pas de repete auto.
def find_mouse_g502():
    for path in evdev.list_devices():
        device = None
        try:
            device = evdev.InputDevice(path)
            name = device.name.lower()
            caps = device.capabilities()
            if ("g502" in name and "logitech" in name
                and evdev.ecodes.BTN_MIDDLE in caps.get(evdev.ecodes.EV_KEY, [])
                and evdev.ecodes.REL_WHEEL in caps.get(evdev.ecodes.EV_REL, [])):
                print("Souris G502 detectee :", device.path, flush=True)
                return device
        except (OSError, ValueError):
            pass
        if device is not None:
            device.close()
    return None


def run_mouse_g502():
    while True:
        device = find_mouse_g502()
        if device is None:
            time.sleep(2)
            continue
        middle_pressed = False
        try:
            for event in device.read_loop():
                if event.type == evdev.ecodes.EV_KEY and event.code == evdev.ecodes.BTN_MIDDLE:
                    middle_pressed = event.value != 0
                elif (event.type == evdev.ecodes.EV_REL
                      and event.code == evdev.ecodes.REL_WHEEL
                      and middle_pressed):
                    # Les fonctions existantes verifieront game_running().
                    if event.value > 0:
                        for _ in range(min(event.value, 10)):
                            volume_up()
                    elif event.value < 0:
                        for _ in range(min(-event.value, 10)):
                            volume_down()
        except (OSError, ValueError) as exc:
            print("Souris G502 deconnectee :", exc, flush=True)
        finally:
            device.close()
        time.sleep(2)

"""
thread="""\nthread_mouse_g502 = threading.Thread(target=run_mouse_g502, daemon=True)
thread_mouse_g502.start()
\n"""
if src.count(marker)!=1 or src.count('thread_ultimate.join()')!=1: raise SystemExit(1)
new=src.replace(marker,worker+marker,1).replace('thread_ultimate.join()',thread+'thread_ultimate.join()',1)
ast.parse(new)
fd,tmp=tempfile.mkstemp(prefix='.volume-hotkey-mouse.',dir=str(p.parent))
try:
    with os.fdopen(fd,'w',encoding='utf-8') as f: f.write(new)
    os.chmod(tmp,p.stat().st_mode & 0o777)
    os.replace(tmp,p)
finally:
    if os.path.exists(tmp): os.unlink(tmp)
print('[OK] G502 : clic central + molette, pas 2%.')
PYMOUSE107WRITE
  then echo '[ERREUR] Ajout souris non applique.'; return 1; fi
  if command -v batocera-services >/dev/null 2>&1; then
    batocera-services restart volume_hotkey || {
      echo '[ATTENTION] Redemarrage du service non confirme.'; return 1;
    }
  else
    echo '[ATTENTION] Redemarrer le service Volume Hotkey manuellement.'
    return 1
  fi
  echo '[OK] Souris G502 activee pour les jeux.'
}

# Sinden Lightgun Batocera 44 : KEY_1 + Haut/Bas sur l'interface clavier HID.
# Met a jour uniquement les deux fonctions Sinden dans le service existant.
volume_hotkey_v44_sinden_patch(){
  local script='/userdata/system/volume-hotkey.py'
  [[ -s "$script" && -f "$script" && ! -L "$script" ]] || {
    echo '[SECURITE] Service Volume Hotkey absent ou invalide.'; return 1;
  }
  # Validation prealable sans toucher aux fichiers.
  if ! python3 - "$script" check <<'PYSINDEN305'
import ast, pathlib, sys
p=pathlib.Path(sys.argv[1]); mode=sys.argv[2]
try:
    src=p.read_text(encoding='utf-8'); tree=ast.parse(src)
    functions={n.name:n for n in tree.body if isinstance(n,ast.FunctionDef)}
    for name in ('find_sinden','run_sinden','repeat_action','volume_up','volume_down','game_running'):
        if name not in functions: raise ValueError('Fonction manquante : '+name)
    for name in ('find_sinden','run_sinden'):
        if sum(isinstance(n,ast.FunctionDef) and n.name==name for n in tree.body)!=1:
            raise ValueError('Fonction Sinden dupliquee : '+name)
    if 'import evdev' not in src or 'import threading' not in src:
        raise ValueError('Dependances evdev absentes')
    if 'BLONDIN_SINDEN_KEY1_DPAD_V1' in src:
        if src.count('BLONDIN_SINDEN_KEY1_DPAD_V1')!=1:
            raise ValueError('Marqueur Sinden incoherent')
        code=ast.get_source_segment(src,functions['run_sinden']) or ''
        finder=ast.get_source_segment(src,functions['find_sinden']) or ''
        if 'event.code == 2' not in code or 'event.code == 103' not in code or 'event.code == 108' not in code or 'required.issubset' not in finder:
            raise ValueError('Patch Sinden incomplet')
        print('[OK] Sinden : KEY_1 + Haut/Bas deja configure.')
        sys.exit(20)
    code=ast.get_source_segment(src,functions['run_sinden']) or ''
    if not all(x in code for x in ('repeat_action','volume_down','volume_up')):
        raise ValueError('Routine Sinden personnalisee : pas de modification automatique')
    print('[OK] Sinden : structure reconnue, modification possible.')
except (OSError,SyntaxError,ValueError) as exc:
    print('[SECURITE] '+str(exc),file=sys.stderr); sys.exit(1)
PYSINDEN305
  then
    local rc=$?
    # Le code 20 (deja configure) est gere ci-dessous, sans sauvegarde ni redemarrage.
    if grep -Fq 'BLONDIN_SINDEN_KEY1_DPAD_V1' "$script"; then
      echo '[OK] Sinden : configuration deja presente.'
      return 0
    fi
    echo '[SECURITE] Verification Sinden echouee.'
    return 1
  fi
  # Le controle ci-dessus retourne 20 si deja applique : aucun ecrasement.
  if grep -Fq 'BLONDIN_SINDEN_KEY1_DPAD_V1' "$script"; then
    echo '[OK] Sinden : configuration deja presente.'
    return 0
  fi
  backup_file "$script" "$SAVES/VolumeHotkeyV44" 'volume-hotkey.py' || return 1
  if ! python3 - "$script" <<'PYSINDEN305WRITE'
import ast, os, pathlib, sys, tempfile
p=pathlib.Path(sys.argv[1]); src=p.read_text(encoding='utf-8'); tree=ast.parse(src)
functions={n.name:n for n in tree.body if isinstance(n,ast.FunctionDef)}
find_code='''def find_sinden():
    # BLONDIN_SINDEN_KEY1_DPAD_V1
    # L'interface souris Sinden n'a pas les touches KEY_1 / KEY_UP / KEY_DOWN.
    required = {2, 103, 108}
    while True:
        for path in evdev.list_devices():
            device = None
            try:
                device = evdev.InputDevice(path)
                keys = set(device.capabilities().get(evdev.ecodes.EV_KEY, []))
                name = device.name.lower().replace(' ', '')
                if 'sinden' in name and required.issubset(keys):
                    print('Sinden clavier detecte :', device.path, flush=True)
                    return device
            except (OSError, ValueError):
                pass
            if device is not None:
                device.close()
        time.sleep(2)
'''
run_code='''def run_sinden():
    # KEY_1 maintenu + Haut = +2%, KEY_1 maintenu + Bas = -2%.
    # Les fonctions volume_up/down existantes filtrent hors jeu.
    while True:
        device = find_sinden()
        stop_event = threading.Event()
        modifier = False
        up_pressed = False
        down_pressed = False
        try:
            threading.Thread(
                target=repeat_action,
                args=(lambda: modifier, lambda: up_pressed and not down_pressed,
                      volume_up, stop_event), daemon=True
            ).start()
            threading.Thread(
                target=repeat_action,
                args=(lambda: modifier, lambda: down_pressed and not up_pressed,
                      volume_down, stop_event), daemon=True
            ).start()
            for event in device.read_loop():
                if event.type != evdev.ecodes.EV_KEY or event.value not in (0, 1):
                    continue
                if event.code == 2:
                    modifier = event.value == 1
                elif event.code == 103:
                    up_pressed = event.value == 1
                elif event.code == 108:
                    down_pressed = event.value == 1
        except (OSError, ValueError) as exc:
            print('Sinden clavier deconnecte :', exc, flush=True)
        finally:
            stop_event.set()
            device.close()
        time.sleep(2)
'''
changes=[]
for name, replacement in (('find_sinden',find_code),('run_sinden',run_code)):
    n=functions[name]
    if n.col_offset!=0: raise SystemExit('[SECURITE] Fonction Sinden imbriquee')
    lines=src.splitlines(keepends=True)
    start=sum(len(x) for x in lines[:n.lineno-1]); end=sum(len(x) for x in lines[:n.end_lineno])
    changes.append((start,end,replacement))
for start,end,replacement in sorted(changes,reverse=True):
    src=src[:start]+replacement+src[end:]
ast.parse(src)
fd,tmp=tempfile.mkstemp(prefix='.volume-hotkey-sinden.',dir=str(p.parent))
try:
    with os.fdopen(fd,'w',encoding='utf-8') as f: f.write(src)
    os.chmod(tmp,p.stat().st_mode & 0o777)
    os.replace(tmp,p)
finally:
    if os.path.exists(tmp): os.unlink(tmp)
print('[OK] Sinden : KEY_1 + Haut/Bas, pas de volume conserve.')
PYSINDEN305WRITE
  then
    echo '[ERREUR] Patch Sinden non applique.'; return 1
  fi
  if command -v batocera-services >/dev/null 2>&1; then
    batocera-services restart volume_hotkey || {
      echo '[ATTENTION] Service a redemarrer manuellement.'; return 1;
    }
  else
    echo '[ATTENTION] Service a redemarrer manuellement.'; return 1
  fi
  echo '[OK] Volume Hotkey Sinden actualise.'
}

volume_hotkey_v44_patch_existing(){
  local script='/userdata/system/volume-hotkey.py' rc
  [[ -f "$script" && ! -L "$script" ]] || return 1
  if grep -Fq 'def run_steam_deck():' "$script"; then
    echo '[INFO] Steam Deck deja gere : ajustement du pas de volume.'
    volume_hotkey_v44_adjust_steam_step || return 1
    volume_hotkey_set_all_step || return 1
    if ! command -v batocera-services >/dev/null 2>&1; then
      echo '[ATTENTION] batocera-services absent : redemarrage manuel necessaire.'
      return 1
    fi
    batocera-services restart volume_hotkey || {
      echo '[ATTENTION] Reglage applique, redemarrage du service non confirme.'
      return 1
    }
    echo '[OK] Volume Hotkey : pas 2% pour toutes les manettes.'
    return 0
  fi
  if ! python3 - "$script" <<'PYV44PATCH'
import ast, os, pathlib, sys, tempfile
source = pathlib.Path(sys.argv[1])
try:
    text = source.read_text(encoding='utf-8')
    ast.parse(text)
    # Compatibilite uniquement avec la structure connue de Volume Hotkey.
    if any(x not in text for x in
           ('import evdev', 'import threading', 'import time',
            'def repeat_action(', 'def volume_down(', 'def volume_up(',
            'thread_ultimate.join()')):
        raise ValueError('Version Volume Hotkey inconnue : aucune modification.')
    marker = '# ============================================================\n# LANCEMENT\n# ============================================================'
    if text.count(marker) != 1 or text.count('thread_ultimate.join()') != 1:
        raise ValueError('Structure Volume Hotkey differente : aucune modification.')
    worker = '''# ============================================================
# STEAM DECK OLED - BATOCERA 44 (mappage valide par evdev)
# SELECT 314, L2 312, R2 313 sur le peripherique Steam Deck 28de:1205.
# ============================================================
def find_steam_deck():
    required = {314, 312, 313}
    while True:
        for path in evdev.list_devices():
            device = None
            try:
                device = evdev.InputDevice(path)
                if (device.name == "Steam Deck"
                    and device.info.vendor == 0x28de
                    and device.info.product == 0x1205
                    and required.issubset(set(device.capabilities().get(evdev.ecodes.EV_KEY, [])))):
                    print("Steam Deck OLED detecte :", device.path, flush=True)
                    return device
            except (OSError, ValueError):
                pass
            if device is not None:
                device.close()
        time.sleep(2)

def run_steam_deck():
    while True:
        device = find_steam_deck()
        stop_event = threading.Event()
        try:
            select_pressed = False
            l2_pressed = False
            r2_pressed = False
            threading.Thread(target=repeat_action,
                             args=(lambda: select_pressed, lambda: l2_pressed,
                                   volume_down, stop_event), daemon=True).start()
            threading.Thread(target=repeat_action,
                             args=(lambda: select_pressed, lambda: r2_pressed,
                                   volume_up, stop_event), daemon=True).start()
            for event in device.read_loop():
                if event.type != evdev.ecodes.EV_KEY:
                    continue
                if event.code == 314:
                    select_pressed = event.value != 0
                elif event.code == 312:
                    l2_pressed = event.value != 0
                elif event.code == 313:
                    r2_pressed = event.value != 0
        except (OSError, ValueError) as e:
            print("Steam Deck deconnecte :", e, flush=True)
        finally:
            stop_event.set()
            device.close()
        time.sleep(2)
'''
    # Garder la boucle Steam Deck independante des quatre autres manettes.
    text = text.replace(marker, worker + '\n' + marker, 1)
    thread = '''\nthread_steam_deck = threading.Thread(\n    target=run_steam_deck, daemon=True\n)\nthread_steam_deck.start()\n\n'''
    text = text.replace('thread_ultimate.join()',
                        thread + 'thread_ultimate.join()', 1)
    ast.parse(text)
    fd, temp = tempfile.mkstemp(prefix='.volume-hotkey-v44.', dir=source.parent)
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as f:
            f.write(text)
        os.chmod(temp, source.stat().st_mode & 0o777)
        os.replace(temp, source)
    finally:
        if os.path.exists(temp): os.unlink(temp)
    print('[OK] Manette Steam Deck ajoutee : anciennes commandes conservees.')
except (OSError, SyntaxError, ValueError) as exc:
    print('[SECURITE] ' + str(exc), file=sys.stderr)
    sys.exit(1)
PYV44PATCH
  then
    echo '[SECURITE] Script existant conserve.'
    return 1
  fi
  # Apres l'ajout de la manette, appliquer aussi son pas de 2%.
  volume_hotkey_v44_adjust_steam_step || return 1
  volume_hotkey_set_all_step || return 1
  if command -v batocera-services >/dev/null 2>&1; then
    if ! batocera-services restart volume_hotkey; then
      echo '[ATTENTION] Fichier adapte, mais redemarrage du service non confirme.'
      echo '[INFO] Consulter /userdata/system/volume-hotkey.log.'
      return 1
    fi
  else
    echo '[ATTENTION] batocera-services indisponible : redemarrer le service manuellement.'
    return 1
  fi
  echo '[OK] Service Volume Hotkey redemarre.'
  return 0
}

volume_hotkey_v44_install(){
  local target='' sha='' file=''
  if ! confirm 'Installer Volume Hotkey ?'; then
    echo '[INFO] Annule.'
    return 0
  fi
  # Bloquer toute anomalie de type avant de sauvegarder/remplacer.
  for file in /userdata/system/volume-hotkey.py /userdata/system/services/volume_hotkey; do
    if [[ -L "$file" || ( -e "$file" && ! -f "$file" ) ]]; then
      echo "[SECURITE] Fichier non ordinaire : $file"
      return 1
    fi
  done
  # Backup avant execution : protege toutes les personnalisations existantes.
  for file in /userdata/system/volume-hotkey.py /userdata/system/services/volume_hotkey; do
    if [[ -f "$file" ]]; then
      backup_file "$file" "$SAVES/VolumeHotkeyV44" "${file##*/}" || {
        echo '[SECURITE] Sauvegarde impossible : installation annulee.'
        return 1
      }
    fi
  done
  # Priorite a une installation existante : greffe non destructive.
  if [[ -s /userdata/system/volume-hotkey.py &&
        -f /userdata/system/services/volume_hotkey ]]; then
    volume_hotkey_v44_patch_existing || return 1
    volume_hotkey_v44_teknoparrot_patch || return 1
    volume_hotkey_v44_mouse_patch || return 1
    volume_hotkey_v44_sinden_patch || return 1
    return 0
  fi
  # Installation neuve uniquement : installateur adapte inclus et verifie.
  target="$(mktemp "$CACHE/.volume-hotkey-v44.XXXXXX")" || return 1
  if ! python3 - "$target" <<'PYVOLUME44'
import base64, gzip, hashlib, pathlib, sys
s='''H4sIAAAAAAAC/+1da1vbuBL+nl+hut0lOSUBAt32YZfuExJDsw0JJwmc7fbw5DGOAm4d2yvLFHa7//2MJF8kX0Ju9HaaD8VxpJFGmnnnHV+mjx9tXVrO1qXhX5dKj9HBCh/oft7rnJ3o6FVv+Fp/g6qo3R0MG51OY6if9dFgqDdOUEtvvka9jt5Ch41hr6n3G2hvDw31wbD0GCToU882TDzFDkX78H0r8DEZG9TY8o0b7G+1HZ8atu2bxPKov2WJr9Ub1w6muHrt0vf4rga6rKhK6fTN8FWvOzpqd/QDTZrEnU/xdEsdzrvTSgO9f95u6kUd4OuNZcL8Rc+R6KmVOr3j+caw3SutdNpuRa1vDLJFAic9E2usldawj42jo3bzVeNYh43pn7S7jc7KC2ra2CBsakcuMTHy6dgNKMKUHWFC0A0mPrIxophMLcewkWFSa1IrWRP0FlU/oK0xvtmi9A5d/IzoNXZKCD74FpvoZfJb/eWPO6WJtY4lONf7bViExrDd64LRDlCr32sP4Y+OOhuyXa+8MqEwvX+gPSkTbIxty3mPqhOkPdnWKrCf2Lx2+T9IW0y2FvZC8Ud10HhkbQXxYde37e5R7wKdY2JNLNOgluugMUb2RuiiBsUBqdVqoA/f0keoegsaJlOIN1bsrCy0gxHIvLYwQc4G9inyDJ/vfUCNSxuDzEyXpksINvksjIC6U5jQnwEW47PG5vXUHaOnqSnUX3JTcgLbFs2E9RVMNFrUcODe6wvUIq5F0XhDTI6P/g7sPJ6i7eN0t8ZwqHeZlV2g9tRzfd8ClUCE6EiYT4yZVC3VURkkvc6iMfMEPmQpNc221FZdyIfwnn6vN1zZS+41NV8sk4+MMQCI5VOSNjlwL2uMqkFFQ48OkLadY3LSQi3qC0lPpHz0fh9QQluDZElEJ9lurj2zOkwJ+JvhmBgj7CDiurSW6szQBVUJqnpIa3hecIf/Qj6YABhgX9eR58KxAGDMFw6NQpgF8TvCNiQr0mP7S4Zbg+00e92jdv+E2846zWYl7IwRnxm0gqJrwM4mhEHZfdGNgfaVFoxLiQaACOc85qNXIYeIW/SxIE8EBQ5GioHADsI3h2KpeZPgEF4Y6MBhRFKQbyEHw4FvWETu0QBAvRF9wrYoxWfipi08NQCBiYy+nNQlfUMFS7JRFiiJfkVv3S1AyH0Q3tdPe92BDpTC8DE4dfhdA42FI7sfex/dwPrYO2t/7AVWpaQgZx5st+W1Ml1nYpEpjkA70/Hnn4XEf82WvIyb54GIYnqNbveso+vaGsdKiWoEJjMfCI9KIE8ZndrH2TAAfgB2JhMIukHx0i0JQDEIbSubgH3DXAfi7DDbBpgewvI223q3q7MANlgX/iCtutAncqO3O1s/XaAGuBGjFGxTANwt7MABY8vcr2/ApwIMHsPj3HKjlS4N6gJsGNUEAajrqb6NEmokaLb33oJDRlPvT48UYkWmgtxG2QxMwLcx9liEkXyyEenKgQyiGmKAQrltCeBYfePrDKl6g0Fbh/RUZHCDz7vldbblKrMJMgC9yl4LRjtGxTlqPhPn7DYdKMb4nYE8gn2wQhb8M2RTMLVMP+My7JHl7YAQEeQUzjCh8dP3Y4ujSWFbmccvoPV9mpuEG2LC6tO9BO1TOT3m3QiL7Wrr4lk9DIzulOL8IOJ063CnXcYq+nqUM6M0Dnxe19plrqVE+jHOTHEV1wKHRS8ZsCXXjjT0yy8b4Xe9d7RRevwI9prwa27YuUHeHb12nV1wSzATAhz+BmAy+uIHlx5xGQ+LzlBriuPja2YFlnO1jp3r68edxvEawE9Q49FgqJ+iA1QvATkDexi19E7jDZzYru2uPb3cR2dd9Jt+hvTBsNruoA4EcR39urIqYzxBVwYEQBI4DqxzubJfCrMoP7ApaJNsUA3alGMfe6vFERX7Vf+D5fvvHWuCtU1mVXgasOt0F5txe3Ex7EASd9o+1ZXfMSHy7y39HHhgJ2lC8S09GJJAXF6oRBOlAXFQWcINNvOaOG+6YP8HBxKnMpxx1ERMCf4QyytXkOOyDAWVNabCtlaJRlnXJeO1bFbIVwIv3imrYAf5ohZsHt/AEkp9kh01grHlapvZFj6mA47egirnNXn69z9abeISSIjKkqdUlJYX8Tcpv/CI5VB1klpIyUHoD7lS1QlM7MC/Tkwk2kBp4cbuB+eLXbrqQyxddaWlWwPqnurDtsjrzoY9dsnj32fr8QWCPSBSI4NfAhXK+9iG5GwE8Y9iod9lQKnryGdEe3HMcoARTzBK0eZ/uLaAxzAwSH6sWf4I9k8xEDAeeTQAEAYt8nBK82Tksrqf0igfDIuW5WgiJ99AwFLi0j23a9u7a9mzF4ftYauHzjrDNuyXDiGO3bY6tANMXZde85tWXXcK0eHFoUVbLjqzIWqDxpBs/McisCoQzh9DttHRm0NotbuzB187dX5YZ0YhDne53HptDx2/+kuSeoyB01km+r166N4izxgXCGscDkZ/IB6DQ5nsTP8POHi2soVF2o8OO2f6sNcbvgKxWrHCWtKjvnfM2mbU0EIsmljOeBSEIsqq4TEPlPYZ/BZ6wppbjiBONdvy6QgOGHXOWBgld6kz7CNaw5SEhLbjBbTFz5WZ7Eq2Bxi36FRzACB5WMy0YZ/sIm3ObgdLk2lQyZlyAagpAJfdizHkziakz5B9bBb2kxS7txFbnuJGOZip6JWvVshYxAhqE3xrYo/uZ7p5hu8nLRlDrvHLCeV6FN4gRs1pUbExpKywlIUVaBQz8JrOzpQlnbK2FuIhS5Z9PIbeR4Z8M4h97PrMn0n2Z+X3yxiDDnIsUjZZIH1Z4yzN2J4Ca9NOGIXMsyctBkSN+UsyNQbVSAthLadjgdmk5iNWnhMWZR+G/Cg7UWqQK0wPlKCYHRsa+Qf5PmUb08uxsZ/axc2ZbZPtzG8nsa78BlIAzrhPtsfYwFPXmXfpAu/LXTgy38IF3qdfNrZZkBQZhKaYSrys8a8qg4RQJWDDitCtxjvYruuV80Be4hR5ESj2qIL4AE0E+6F3Hma3O0V4wyzp82v6+ei1/ma/ELxN16GWE+B82RHhmD1wlF4CJykeKIOKou+NAeqxWW8XzaBTz/0B2znj14vHVyB33rH7C4y9Wzw2WWzsmAyWsgNn6G++GRwUmEHhFGfu9OK7vcKOS4tbpArw25mqFJhMrhr12UoUms3LovnPtJwC63k2exJkrkkI2oR0/oc/K+KjtLUUhfc8EgnQ4BTzSLxMRJ+w573su+IMjqeXxRxv5ZzutN9jTx0M+z32gA9PvObJz1Z9xLDfGyWjsqTolLioCdBLXHYLXMmIPOKOzPinryEvAgNWNVwyk1EXZaE05qvKUBbZYTVPSff8KrKV7xT+O4X/xin88hy8mH/PT7iWIFqLsOcFmfMi5HhOYrwKs8kElW+R1oSXqhv9ZqOlo8Gw3Xydx212t5/DcXRHhJ94kZx4ujLPEeOP+PjSZeIGMQ0whAG1zPcK1TH4DyOf/fCVEB1ZxdUu2MqrEnGdb47qzL/DKtFR+30amsPCxcwGgfcNEB1Zy+9UZ6GlS/b/O9X5uqnO9vN88SkIWFL4i3zhCnw8DNnJDy0R4/mGCM+g3W3pXdRpH78aHp91VbJTf16PLuTUn+9GF3Lqz/dWJjhi2FE0LOM4AwhX2EG2dXVNrwJH4Tc+/+0rYTYp3ZYkN+FydMLl+GaJzTxbq1KaqMf3azbfr9l8v2bzf0JkIBQ9JJGB8PZQ12wgXH62azbZIPLlUZg1cJhUlYyqXCcDfm+FoTPnvcrL6IWw31HZweidMTUsH1S6xaEX7OxUaiCi3UL1F2O8v1PffrYJnkExmRgQkrQBxcYURjDfayhwItG1mEUdAAPfBAoFf+ubwJ/g7y4qC6fgkjvYR+JOLKpvPUMwCR+8Qryub7LX2X1kTJgrboAvipfbfaDXwaXtOn5tLQ++iqjKFAG2JF1eIPjPwCLcPP/manAdQIF/VqJhuXyr6zo4y88Wpmc5OJKP9inOJu9jbnv2MG7Yx3Imbg1sYwyasncBbpllzNXJI+44MKnoxUypsFe09DXL94NL5kEzngeh5XAQ0/CMS8u2qMVWugbxsJyDxZvo7UWlUkD+ch6mXIq9xsspXPLTsdf7yWuWu6Jyb6AT4pJNdM4QmB9XChhtLvlHgBrsGW9mxkVmWzNt18ezs7k0lO1zIPBAaealm8g3HB+Z14ZzJSCMv7bGEGFqOJgysMC3ABIObHaJyxoxWaP0K0bc7ROPH6XeZghVS7/MEFuc+i7D28zbCjlvJ6hvI+RPrXJRSb2BINvRTc77BwVyNiUzqRQpK955eRBVn65H1afLqcqzqiyay2hdkFhJnZZLrr6d3KogG5g7ZUIF7rUpLehCHP/TZEb3qU2WUBuynzUq/WB5zQOkNQ95efbhbkR/uvvQuWE3zG+ybENGSDWRgcRFgcFMajIzM1kuUq+Ys/A3bk/07upVniQqpokSMsYVZiUQrrDPXN1hFWmS97ZDAibxKKZP5DzRY4tFuBJhifR6iJAn+3Allgexcx5R6tNYswSK25nzyJRvfM6SKK4mziNRtJwpK8a+ueTFrXNlpvckhrVkbdOnhM7ps2LembPx6AleZoZ851qOOqJ6JhxQPRmOlzqZDBf+kLziX4pKbEzSlQCKqmqkSxBElZtwbkWNqK6Ebl5jMywpUVzN4GHqf60DM/aUWhFnUfmVz1siYi9bIiLIL3W1jjoRcs1QXigiOhFVikgqs4alrnaSIlfczivKK7feFdCieSvyJAV5UtUM4w3flkKP9Da1qFiB7h0C/VcR+RLdX+GUFxZCP6ZqqTx5xDoXFjxVKkLFLy6rK8PdsVhEtvQL+5y2W6wiJ9ut4q4VTe3EiyLx2kY51SRjYjGdPR/1zebU1dFlyy7Ju5lZMqA5KXtixUf5Skqv/UdVmlJtoGO2LJdkywokqkZfhImDPJ9bGhhjH/6C8fAZ4OEpK7Y7YHXHPnMVqme88Jjn2XJ5TY8thM/Kjq1UgEqqvCqHR/m8YiOR8dwWxdP7wqlS3zSuwJqymkwvh1dNlHqyzU5mkm/Gc1nxXPPJ75o7qXVZ4E+sCl5z2D4XMVkfopZ+0uj3G8efOSr/xK2R1Z4Mi1lSsEcpN4ice7WqaNkieNhhqzy7DN49+GXwipnICJIZzwQvtQJwptzmA+CXWlNXyrnyCE9OpcAwctxTLDCs8Fdfe/GnI1acXP+cZWJLKzOv3NLBStVPMA5WpHDNRYRnZx/aYjFZW8AFZrXlxSz57QDRHOdOfVEHz1th9mn2Tk4a3ZY+0NYgXBIRPnX2VDxvFj1br+W16EstnuYKOzX86Cr6PqqjH1CZinup8r2Siiy8jz1MLQ6W+6zmGuCH6UIim19LOqnmGy45MdK3l2Xhxg3wq8MQCPLQTF3iB6l/HQNmp7AUcdKYVadld55C7Wq5EptAawKbYoa27wA3+X9BwDTdz23OsoIn0f/eoElQuko16CXgnPX7H8pV+HPEYwAA'''
try:
    content = gzip.decompress(base64.b64decode(s, validate=True))
    assert hashlib.sha256(content).hexdigest() == 'fe786469fab023b952ec13693d382a5731353980bec9157908fb8ebebf07b01f'
    pathlib.Path(sys.argv[1]).write_bytes(content)
except (OSError, ValueError, AssertionError):
    sys.exit(1)
PYVOLUME44
  then
    rm -f -- "$target"
    echo '[SECURITE] Installateur embarque invalide.'
    return 1
  fi
  if ! bash -n "$target"; then
    rm -f -- "$target"
    echo '[SECURITE] Syntaxe de l installateur invalide.'
    return 1
  fi
  echo '[INFO] Volume Hotkey : installateur vérifié.'
  echo '[INFO] Le service existant sera arrete puis remplace apres confirmation.'
  bash "$target"
  local result=$?
  rm -f -- "$target"
  [[ "$result" -eq 0 ]] || return "$result"
  # Le nouvel installateur peut reposer le script de base : appliquer le patch apres.
  if [[ -s /userdata/system/volume-hotkey.py ]]; then
    volume_hotkey_v44_teknoparrot_patch || return 1
    volume_hotkey_v44_mouse_patch || return 1
    volume_hotkey_v44_sinden_patch || return 1
  else
    echo '[ERREUR] Volume Hotkey non installe : patch TeknoParrot ignore.'
    return 1
  fi
  return 0
}

install_one(){
  local idx="$1" src='' rc
  case "$idx" in
    0|4|5) ;;
    *) echo '[SÉCURITÉ] Ancien installateur non pris en charge.'; return 1 ;;
  esac
  echo; echo "===== ${NAMES[$idx]} ====="
  check_compatibility "$idx" || return 1
  if [[ "$idx" == 0 ]]; then
    local detected=''
    detected="$(detect_batocera_version)" || true
    if [[ "$detected" == 44 || "$detected" == 44.* ]]; then
      volume_hotkey_v44_install
      return $?
    fi
  fi
  src="$(local_file "$idx")"
  if [[ -z "$src" ]]; then
    echo '[INFO] Cache absent : essai GitHub.'
    download_one "$idx" || true
    src="$(local_file "$idx")"
  fi
  if [[ -z "$src" ]]; then echo '[ERREUR] Aucun installateur disponible.'; return 1; fi
  echo "[SOURCE] $src"
  if ! bash -n "$src"; then echo '[ERREUR] Syntaxe invalide.'; return 1; fi
  if ! confirm 'Confirmer exécution avec les droits administrateur ?'; then echo '[INFO] Annulé.'; return 0; fi
  chmod u+rx "$src" || return 1
  local runfile="$src" temporary=''
  if [[ "$idx" == 0 ]]; then
    temporary="$(mktemp "$CACHE/.volume-legacy.XXXXXX")" || return 1
    if ! volume_hotkey_prepare_legacy_installer "$src" "$temporary" || ! bash -n "$temporary"; then
      rm -f -- "$temporary"
      echo '[SECURITE] Installateur Volume Hotkey non reconnu : operation annulee.'
      return 1
    fi
    # L'installateur historique peut remplacer les fichiers actifs.
    local f=''
    for f in /userdata/system/volume-hotkey.py /userdata/system/services/volume_hotkey; do
      if [[ -L "$f" || ( -e "$f" && ! -f "$f" ) ]]; then
        rm -f -- "$temporary"
        echo "[SECURITE] Fichier non ordinaire : $f"
        return 1
      fi
      if [[ -f "$f" ]]; then
        if ! backup_file "$f" "$SAVES/VolumeHotkeyLegacy" "${f##*/}"; then
          rm -f -- "$temporary"
          echo '[SECURITE] Sauvegarde impossible, aucune reinstallation.'
          return 1
        fi
      fi
    done
    runfile="$temporary"
  fi
  if [[ "$idx" == 1 || "$idx" == 4 || "$idx" == 5 ]]; then
    temporary="$(mktemp "$CACHE/.execution.XXXXXX")" || return 1
    if ! normalize_installer "$idx" "$src" "$temporary" || ! bash -n "$temporary"; then
      rm -f "$temporary"; echo '[ERREUR] Préparation de l installateur impossible.'; return 1
    fi
    runfile="$temporary"
  fi
  bash "$runfile"; rc=$?
  [[ -z "$temporary" ]] || rm -f -- "$temporary"
  echo "[RESULTAT] Code de sortie : $rc"
  if (( rc == 0 )) && [[ "$idx" == 1 || "$idx" == 5 ]]; then
    install_ports_artwork "$idx" || echo "[ATTENTION] Installation du lanceur réussie, illustrations non installées."
    reload_es_games
  fi
  return "$rc"
}


# Catalogue du comparateur : uniquement les modules réellement utilisés en V44.
# Un SHA Git blob vérifie l'égalité exacte du fichier sans téléchargement.
# Les scripts adaptables (extinction et nettoyage) sont normalisés avant comparaison.
# Aucun effacement, aucune installation, aucune réécriture du cache ici.
check_local_updates(){
  local i state checked=0 ok=0 missing=0 different=0 unavailable=0
  local -a results=()
  echo; echo '===== GITHUB / CACHE ====='
  if ! fetch_tree; then
    echo '[ATTENTION] GitHub inaccessible.'
    echo '[INFO] Cache conservé.'
    return 0
  fi
  local result=''
  # Le comparateur externe lit exclusivement le manifeste ci-dessous.
  # Chemins explicites : éviter les anciens ZIP CGS 42/43 et les alias homonymes.
  result="$(python3 - "$CACHE/tree.json" "$CACHE" <<'PYCOMPARE'
import hashlib, json, pathlib, stat, sys
root=pathlib.Path(sys.argv[2])
try:
    tree=json.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'))
    if tree.get('truncated'): raise ValueError('arbre incomplet')
    blobs={e['path']:e['sha'] for e in tree['tree'] if e.get('type')=='blob'}
except (OSError,ValueError,KeyError,TypeError):
    print('ERREUR|Arbre GitHub incomplet')
    sys.exit(1)
# Les fichiers absents ne sont jamais considérés "à jour".
groups = [
 ('CGS Multi-sources', [
  ('CGS/MultiSources/gestion-cgs-multisources-v2.1-TEST.sh','CGS-V2.1/gestion-cgs-multisources-v2.1-TEST.sh'),
  ('CGS/MultiSources/cgs-multisource-patch.py','CGS-V2.1/cgs-multisource-patch.py'),
  ('CGS/MultiSources/cgs-artwork.py','CGS-V2.1/cgs-artwork.py'),
  ('CGS/MultiSources/artwork/CGS-fanart.png','CGS-V2.1/artwork/CGS-fanart.png'),
  ('CGS/MultiSources/artwork/CGS-logo.png','CGS-V2.1/artwork/CGS-logo.png'),
  ('CGS/MultiSources/artwork/CGS-thumb.png','CGS-V2.1/artwork/CGS-thumb.png')]),
 ('Rambo', [('Rambo/nettoyage-rambo.sh','Rambo/nettoyage-rambo.sh')]),
 ('Kodi', [('Kodi/kodi.sh','Kodi/kodi.sh')]),
 ('Extinction automatique', [('ShutdownScreensaver/install-shutdown-screensaver-v3-TEST.sh','install-shutdown-screensaver-v3-TEST.sh')]),
 ('Nettoyage des jeux récents', [('NettoyageDernieresParties/installer-nettoyer-jeux-recents-v10.1-github.sh','installer-nettoyer-jeux-recents-v10.1-github.sh')]),
 ('Visuels principaux', [('visuels_ports_batocera_principaux.zip','visuels_ports_batocera_principaux.zip')]),
 ('Visuels logiciels', [('visuels_ports_batocera_logiciels.zip','visuels_ports_batocera_logiciels.zip')]),
]
def blob_sha(p):
    st=p.lstat()
    if not stat.S_ISREG(st.st_mode): return None
    h=hashlib.sha1()
    h.update(f'blob {st.st_size}\0'.encode())
    with p.open('rb') as f:
        for chunk in iter(lambda:f.read(1024*1024),b''): h.update(chunk)
    return h.hexdigest()
for label, entries in groups:
    if any(r not in blobs for r,c in entries):
        status='INDISPONIBLE'
    else:
        states=[]
        for remote, local in entries:
            p=root/local
            try:
                if not p.exists() or p.is_symlink():
                    states.append('ABSENT')
                elif blob_sha(p)==blobs[remote]:
                    states.append('OK')
                else:
                    states.append('DIFFÉRENT')
            except (OSError,ValueError):
                states.append('DIFFÉRENT')
        if 'DIFFÉRENT' in states: status='DIFFÉRENT'
        elif 'ABSENT' in states: status='ABSENT'
        else: status='OK'
    print(status+'|'+label)
PYCOMPARE
)" || { echo '[ATTENTION] Comparaison impossible.'; return 1; }
  while IFS='|' read -r state i; do
    [[ -n "$i" ]] || continue
    case "$state" in
      OK) echo "[OK] $i"; ((ok+=1)) ;;
      ABSENT) echo "[ABSENT] $i"; ((missing+=1)) ;;
      DIFFÉRENT) echo "[DIFFÉRENT] $i"; ((different+=1)) ;;
      INDISPONIBLE) echo "[INDISPONIBLE] $i"; ((unavailable+=1)) ;;
      ERREUR) echo "[ERREUR] $i"; return 1 ;;
    esac
    ((checked+=1))
  done <<< "$result"
  echo
  echo "[BILAN] $ok OK | $missing absents"
  echo "[BILAN] $different différents | $unavailable indisponibles"
  echo '[INFO] Contrôle lecture seule.'
  echo '[INFO] Mise à jour : menu Télécharger.'
  echo '[INFO] Les scripts adaptés peuvent'
  echo '       différer de GitHub.'
}

# Téléchargement : modules Batocera 44 existants, pas d'anciens CGS 42/43.
# L'installation n'est jamais déclenchée depuis ce menu.
cache_download_archive(){
  local name="$1" dest="$CACHE/$1" tmp
  [[ "$name" == visuels_ports_batocera_principaux.zip || "$name" == visuels_ports_batocera_logiciels.zip ]] || return 1
  [[ ! -L "$dest" && ! -L "$CACHE" ]] || return 1
  if [[ -s "$dest" ]] && python3 - "$dest" <<'PYZIPCHECK'
import sys, zipfile
try:
    with zipfile.ZipFile(sys.argv[1]) as f:
        assert f.testzip() is None
except (OSError, zipfile.BadZipFile, AssertionError): sys.exit(1)
PYZIPCHECK
  then echo '[OK] Archive en cache.'; return 0; fi
  tmp="$(mktemp "$CACHE/.archive.XXXXXX")" || return 1
  if curl -fLsS --connect-timeout 5 --max-time 120 "https://raw.githubusercontent.com/$REPO/main/$name" -o "$tmp" &&
     python3 - "$tmp" <<'PYZIPCHECK'
import sys,zipfile
try:
    with zipfile.ZipFile(sys.argv[1]) as f: assert f.testzip() is None
except (OSError,zipfile.BadZipFile,AssertionError): sys.exit(1)
PYZIPCHECK
  then mv -f -- "$tmp" "$dest" && echo '[OK] Archive téléchargée.'
  else rm -f -- "$tmp"; echo '[ATTENTION] Archive indisponible.'; return 1; fi
}
download_menu(){
  local choice
  while :; do
    refresh_screen
    ui_section 'TÉLÉCHARGEMENTS'
    ui_item '1) CGS Multi-sources'
    ui_item '2) Rambo'
    ui_item '3) Kodi'
    ui_item '4) Extinction automatique'
    ui_item '5) Jeux récents'
    ui_item '6) Visuels principaux'
    ui_item '7) Visuels logiciels'
    echo
    ui_item '0) Retour'
    ui_item 'Q) Quitter le gestionnaire'
    choice="$(read_key 'CHOIX : ')" || return 0
    case "$choice" in
      1) cgs44_prepare ;;
      2) rambo_prepare ;;
      3) kodi44_prepare ;;
      4) if [[ -n "$(local_file 4)" ]]; then echo '[OK] Cache extinction prêt.'; else download_one 4; fi ;;
      5) if [[ -n "$(local_file 5)" ]]; then echo '[OK] Cache jeux récents prêt.'; else download_one 5; fi ;;
      6) cache_download_archive visuels_ports_batocera_principaux.zip ;;
      7) cache_download_archive visuels_ports_batocera_logiciels.zip ;;
      0) return 0 ;;
      Q|q) exit 0 ;;
      *) echo 'Choix invalide.' ;;
    esac
    pause
  done
}

status(){
  local i src
  echo "Système : $(version)"
  echo "Depot : https://github.com/$REPO"
  echo 'Fichiers en cache :'
  for i in "${!NAMES[@]}"; do
    src="$(local_file "$i")"
    if [[ -n "$src" ]]; then
      echo "  [OK] ${NAMES[$i]} : présent"
      echo "  [FICHIER] $src"
    else echo "  [--] ${NAMES[$i]} : absente"; fi
  done
  echo 'Note : la présence du fichier ne garantit pas que le service est installé.'
}
# Lit uniquement les affectations explicites de duree dans le script actif.
# Ne lance jamais le script d'extinction et n'evalue jamais son contenu.
show_shutdown_delay(){
  local script="$1" result
  if [[ ! -r "$script" ]]; then
    echo '  [DÉLAI] Inconnu : script de déclenchement inaccessible.'
    return 0
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    echo '  [DÉLAI] Inconnu : Python 3 indisponible.'
    return 0
  fi
  result="$(python3 - "$script" <<'PYDELAY'
import re, sys
try:
    lines = open(sys.argv[1], encoding='utf-8').readlines()
except (OSError, UnicodeError):
    print('Inconnu : lecture impossible.')
    sys.exit(0)
# Seules les constantes explicites sont reconnues ; pas de substitution ou calcul shell.
keys = ('DELAY', 'TIMEOUT', 'SHUTDOWN_DELAY', 'SHUTDOWN_TIMEOUT', 'DELAI', 'DELAI_SECONDES', 'DELAY_SECONDS', 'SECONDS')
values = {}
for line in lines:
    m = re.match(r'^\s*(?:export\s+)?([A-Za-z_][A-Za-z_0-9]*)\s*=\s*["\']?([0-9]+)([smh]?)\s*["\']?(?:\s*(?:#.*)?)?$', line)
    if m and m.group(1).upper() in keys:
        name, number, unit = m.group(1).upper(), int(m.group(2)), m.group(3)
        values[name] = (number, unit)
if len(values) != 1:
    print('Inconnu : duree non reconnue de maniere certaine.')
else:
    name, (n, unit) = next(iter(values.items()))
    if unit == 'h': n *= 3600
    elif unit == 'm': n *= 60
    hours, rem = divmod(n, 3600)
    mins, secs = divmod(rem, 60)
    parts = []
    if hours: parts.append(f'{hours} h')
    if mins: parts.append(f'{mins} min')
    if secs or not parts: parts.append(f'{secs} s')
    print(' '.join(parts) + f' (valeur {name})')
PYDELAY
)"
  echo "  [DÉLAI] $result"
}
# Diagnostic strictement en lecture seule : ne confond pas cache, sauvegarde et installation.
show_matches(){
  local root="$1" pattern="$2" label="$3" result
  [[ -d "$root" ]] || return 1
  result="$(find "$root" -maxdepth 5 -type f -iname "$pattern" \
    ! -path '*/Installscripts/*' ! -path '*/backup*/*' \
    ! -path '*/.local/share/Trash/*' -print 2>/dev/null | head -n 8)"
  if [[ -n "$result" ]]; then
    echo "  [INDICE] $label :"
    printf '    %s\n' "$result"
    return 0
  fi
  return 1
}
check_installations_raw(){
  echo; echo '===== VÉRIFICATION DES INSTALLATIONS ====='
  echo "Système : $(version)"
  echo '[INFO] Contrôle des fichiers actifs.'
  echo
  echo '[1] Volume Hotkey'
  if [[ -s /userdata/system/volume-hotkey.py && -f /userdata/system/services/volume_hotkey ]]; then
    echo '  [PRÉSENT] Script et service trouvés.'
    if command -v pgrep >/dev/null 2>&1 && pgrep -f '[v]olume-hotkey.py' >/dev/null 2>&1; then
      echo '  [ACTIF] Processus détecté (touches non testees).'
    else
      echo '  [PROBLÈME POSSIBLE] Processus non détecté.'
    fi
  else
    echo '  [ABSENT DES CHEMINS CONNUS] Script et/ou service non trouves.'
  fi
  echo
  echo '[2] Extinction automatique'
  local trigger='/userdata/system/configs/emulationstation/scripts/screensaver-start/shutdown-trigger.sh'
  local cancel='/userdata/system/configs/emulationstation/scripts/screensaver-stop/shutdown-cancel.sh'
  local shutdown_ok=1 f
  for f in "$trigger" "$cancel"; do
    if [[ -s "$f" && -x "$f" ]]; then
      echo "  [OK] Script exécutable."
      echo "  [FICHIER] $f"
    elif [[ -f "$f" ]]; then
      echo "  [INCOMPLET] Fichier present mais vide ou non executable : $f"
      shutdown_ok=0
    else
      echo "  [ABSENT] $f"
      shutdown_ok=0
    fi
  done
  if (( shutdown_ok )); then
    echo '  [INSTALLE] Les deux scripts de veille sont presents et executables.'
  else
    echo '  [A VERIFIER] Installation absente ou incomplete.'
  fi
  show_shutdown_delay "$trigger"
  echo '  [INFO] Declenchement du minuteur non teste.'
  echo
  echo '[3] Nettoyage Dernières Parties'
  if [[ -f /userdata/system/nettoyer-jeux-recents-controller.json ]]; then
    echo '  [INDICE] Configuration manette presente (ne prouve pas installation).'
  fi
  found=0
  show_matches /userdata/roms/ports '*nettoy*' 'Lanceur possible' && found=1
  show_matches /userdata/system '*nettoy*' 'Script possible' && found=1
  if [[ "$found" == 0 ]]; then echo '  [ABSENT DES CHEMINS CONNUS] Aucun script ou lanceur identifie.'; fi
  echo
  echo '[4] CGS Multi-sources'
  local client='/userdata/system/cgs/app/clients/windows/__main__.py'
  local patch='/userdata/system/cgs-multisource-patch.py'
  if [[ -s "$client" ]] && grep -Fq 'ROM_SOURCES' "$client" &&
     grep -Fq '# DOSSIERS DE JEUX WINDOWS GERES PAR CGS' "$client"; then
    echo '  [PRÉSENT] Patch CGS détecté.'
    if [[ -s "$patch" ]]; then
      echo '  [OK] Réapplication disponible.'
    else
      echo '  [INFO] Réapplication absente.'
    fi
  elif [[ -e "$client" || -e /userdata/system/cgs ]]; then
    echo '  [A VÉRIFIER] CGS présent, patch non détecté.'
  else
    echo '  [ABSENT] CGS non détecté.'
  fi
  echo
  echo '[5] Rambo'
  local rambo='/userdata/system/configs/emulationstation/scripts/game-start/nettoyage-rambo.sh'
  local rambo_alt='/userdata/system/configs/emulationstation/scripts/gameStart/nettoyage-rambo.sh'
  if [[ -s "$rambo" && -x "$rambo" ]] || [[ -s "$rambo_alt" && -x "$rambo_alt" ]]; then
    echo '  [PRÉSENT] Nettoyage installé.'
    echo '  [INFO] Déclenchement non testé.'
  elif [[ -e "$rambo" || -e "$rambo_alt" ]]; then
    echo '  [A VÉRIFIER] Script non exécutable ou vide.'
  else
    echo '  [ABSENT] Nettoyage non détecté.'
  fi
  echo
  echo
  echo '===== APPLICATIONS ====='
  echo '[6] Firefox'
  if [[ -x /userdata/system/firefox-mozilla/firefox &&
        -s /userdata/roms/ports/Firefox.sh ]]; then
    echo '  [INSTALLÉ] Firefox et lanceur.'
  elif [[ -e /userdata/system/firefox-mozilla/firefox ||
          -e /userdata/roms/ports/Firefox.sh ]]; then
    echo '  [INCOMPLET] Firefox ou lanceur.'
  else echo '  [ABSENT] Firefox officiel.'; fi
  echo
  echo '[7] FileZilla'
  if command -v flatpak >/dev/null 2>&1 &&
     flatpak_app_installed 'org.filezillaproject.Filezilla'; then
    if [[ -s '/userdata/roms/flatpak/FileZilla.flatpak' ||
          -s '/userdata/roms/flatpak/Tim Kosse.flatpak' ]]; then
      echo '  [INSTALLÉ] Flatpak et lanceur.'
    else echo '  [INCOMPLET] Lanceur non trouvé.'; fi
  else echo '  [ABSENT] Flatpak non détecté.'; fi
  echo
  echo '[8] PeaZip'
  if command -v flatpak >/dev/null 2>&1 &&
     flatpak_app_installed 'io.github.peazip.PeaZip'; then
    if [[ -s '/userdata/roms/flatpak/PeaZip.flatpak' ||
          -s '/userdata/roms/flatpak/Giorgio Tani.flatpak' ||
          -s '/userdata/roms/flatpak/Giorgo Tani.flatpak' ]]; then
      echo '  [INSTALLÉ] Flatpak et lanceur.'
    else echo '  [INCOMPLET] Lanceur non trouvé.'; fi
  else echo '  [ABSENT] Flatpak non détecté.'; fi
  echo
  echo '[9] Kodi'
  if [[ -s /userdata/roms/ports/kodi.sh && -x /userdata/roms/ports/kodi.sh ]]; then
    echo '  [PRÉSENT] Lanceur exécutable.'
  elif [[ -e /userdata/roms/ports/kodi.sh ]]; then
    echo '  [INCOMPLET] Lanceur non exécutable.'
  else echo '  [ABSENT] Lanceur Kodi.'; fi
  echo
  echo '[10] RGSX'
  local rgsx='/userdata/roms/ports/RGSX'
  if [[ -d "$rgsx" ]] &&
     { [[ -s /userdata/roms/ports/RGSX.sh ]] ||
       [[ -s "$rgsx/RGSX.sh" ]]; }; then
    echo '  [PRÉSENT] Dossier et lanceur.'
  elif [[ -e "$rgsx" || -e /userdata/roms/ports/RGSX.sh ]]; then
    echo '  [INCOMPLET] Éléments à vérifier.'
  else echo '  [ABSENT] RGSX non détecté.'; fi
  echo
  echo '[11] BUA'
  echo '  [INDÉTERMINÉ] Pas de signature fiable.'
  echo
  echo '===== OUTILS ====='
  echo '[12] Explorateur F1'
  if [[ -s /userdata/roms/ports/F1.sh && -x /userdata/roms/ports/F1.sh ]]; then
    echo '  [PRÉSENT] Lanceur exécutable.'
  elif [[ -e /userdata/roms/ports/F1.sh ]]; then
    echo '  [INCOMPLET] Lanceur non exécutable.'
  else echo '  [ABSENT] Lanceur F1.'; fi
  echo
  echo '[13] Linux Loader'
  local ll='/userdata/system/dcg/emulators/linuxloader'
  local llpack='/userdata/system/dcg/emulators/windows-arcade-loader/wine-prefix/full.tar.gz'
  if [[ -d "$ll" && -s "$llpack" ]]; then
    echo '  [PRÉSENT] Loader et préfixe.'
    echo '  [INFO] Exécution non testée.'
  elif [[ -e "$ll" || -e "$llpack" ]]; then
    echo '  [INCOMPLET] Composants manquants.'
  else echo '  [ABSENT] Linux Loader.'; fi
  echo
  echo '[14] Syncthing'
  if [[ -f /usr/share/batocera/services/syncthing ]]; then
    if command -v pgrep >/dev/null 2>&1 &&
       pgrep -x syncthing >/dev/null 2>&1; then
      echo '  [ACTIF] Processus détecté.'
    else echo '  [PRÉSENT] Service installé, non actif.'; fi
    if [[ -f /userdata/system/configs/syncthing/config.xml ]]; then
      echo '  [PRÉSENT] Configuration.'
    else echo '  [INFO] Configuration non détectée.'; fi
  else echo '  [ABSENT] Service Syncthing.'; fi
  echo
  echo '[INFO] Diagnostic uniquement : aucun fichier ou service modifie.'
}

# Mise en couleur des vérifications, sans changer les contrôles.
# Les chemins et messages complets restent accessibles dans les détails.
check_installations(){
  local line role
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      '===== VÉRIFICATION'*|'['[1-9]'] '*|'[10] '*|'[11] '*|'[12] '*|'[13] '*|'[14] '*) role=title ;;
      *'[ACTIF]'*|*'[OK]'*|*'[PRÉSENT]'*|*'[INSTALLE]'*|*'[INSTALLÉ]'*) role=success ;;
      *'[ABSENT]'*|*'[ABSENT DES CHEMINS CONNUS]'*|*'[INCOMPLET]'*) role=error ;;
      *'[PROBLÈME POSSIBLE]'*|*'[A VERIFIER]'*|*'[A VÉRIFIER]'*|*'[INDÉTERMINÉ]'*) role=warning ;;
      *'[INFO]'*|*'[CONFIGURATION]'*|*'[ETAT]'*|*'[INDICE]'*) role=info ;;
      *) role=menu ;;
    esac
    ui_print "$role" "$line"
  done < <(check_installations_raw)
}

# Diagnostic pagine : navigation directe avec la manette depuis Ports.
# N'utilise pas le scrollback xterm (la croix envoie des fleches simples).
manager_paged_output(){
  local producer="$1" row_count=30 page_size=18 start=0 total i key second tail seq
  local -a lines=()
  mapfile -t lines < <("$producer")
  total=${#lines[@]}
  if [[ ! -t 0 ]]; then
    printf '%s\n' "${lines[@]}"
    pause
    return 0
  fi
  row_count="$(stty size 2>/dev/null | awk '{print $1}')"
  [[ "$row_count" =~ ^[0-9]+$ ]] || row_count=30
  page_size=$((row_count - 9))
  (( page_size < 8 )) && page_size=8
  (( page_size > 28 )) && page_size=28
  while :; do
    refresh_screen
    ui_section 'DIAGNOSTIC - LECTURE'
    for ((i=start; i<total && i<start+page_size; i++)); do
      printf '%s\n' "${lines[i]}"
    done
    printf '\n\033[1;36mLignes %d-%d / %d\033[0m\n' \
      "$((start+1))" "$(( (start+page_size<total) ? start+page_size : total ))" "$total"
    printf '\033[0;37mHaut/Bas : defiler  |  Gauche/Droite : page  |  B/Entree : retour\033[0m\n'
    IFS= read -r -s -n 1 key || break
    case "$key" in
      $'\033')
        seq=''
        if IFS= read -r -s -n 1 -t 0.18 second; then
          seq="$second"
          if [[ "$second" == '[' || "$second" == 'O' ]]; then
            while IFS= read -r -s -n 1 -t 0.06 tail; do
              seq+="$tail"
              [[ "$tail" =~ [A-Za-z~] || ${#seq} -gt 28 ]] && break
            done
          fi
        fi
        case "$seq" in
          *A) (( start > 0 )) && start=$((start-1)) ;;
          *B) (( start+page_size < total )) && start=$((start+1)) ;;
          *C|*6~) start=$((start+page_size)); ((start>=total)) && start=$(( ((total-1)/page_size)*page_size ));;
          *D|*5~) start=$((start-page_size)); ((start<0)) && start=0 ;;
          '') break ;;
        esac
        ;;
      ''|q|Q|0) break ;;
      *) : ;;
    esac
  done
}

# Modifie uniquement une affectation DELAY litterale et non ambigue.
change_shutdown_delay(){
  refresh_screen
  local target='/userdata/system/configs/emulationstation/scripts/screensaver-start/shutdown-trigger.sh'
  local seconds backup tmp rc hh mm
  ui_section 'DÉLAI D EXTINCTION'
  [[ -f "$target" && -r "$target" && -w "$target" ]] || { echo '[ERREUR] Script actif absent ou non accessible.'; return 1; }
  command -v python3 >/dev/null 2>&1 || { echo '[ERREUR] Python 3 requis.'; return 1; }
  show_shutdown_delay "$target"
  echo
  ui_print menu '  Entrée = 0'
  ui_print menu '  Minimum : 1 min'
  echo
  printf '\033[1;36m  Heures (0-24) : \033[0m' >&2
  IFS= read -r hh || return 1
  printf '\033[1;36m  Minutes (0-59) : \033[0m' >&2
  IFS= read -r mm || return 1
  hh="${hh:-0}"
  mm="${mm:-0}"
  [[ "$hh" =~ ^[0-9]{1,2}$ && "$mm" =~ ^[0-9]{1,2}$ ]] || { ui_print error '[ERREUR] Valeurs invalides.'; return 1; }
  hh=$((10#$hh)); mm=$((10#$mm))
  (( hh <= 24 && mm <= 59 && (hh > 0 || mm > 0) && (hh < 24 || mm == 0) )) || {
    ui_print error '[ERREUR] Délai autorisé : de 1 minute à 24 heures.'
    return 1
  }
  seconds=$((hh*3600+mm*60))
  ui_print info "[NOUVEAU] $((seconds/3600)) h $(((seconds%3600)/60)) min ($seconds secondes)"
  ui_print warning '  Confirmer le nouveau délai ?'
  confirm 'Confirmer la modification et la sauvegarde ?' || { echo '[INFO] Annulé.'; return 0; }
  local backupdir="$SAVES/Shutdown"
  mkdir -p -- "$backupdir" || { echo "[ERREUR] Dossier de sauvegarde inaccessible."; return 1; }
  backup="$backupdir/shutdown-trigger.sh.bak.$(date +%Y%m%d-%H%M%S)-$$"
  cp -p -- "$target" "$backup" || { echo '[ERREUR] Sauvegarde impossible.'; return 1; }
  tmp="$(mktemp "$backupdir/.shutdown-trigger.tmp.XXXXXX")" || return 1
  # Ecriture atomique : une seule variable DELAY litterale, en conservant le suffixe original.
  if ! python3 - "$target" "$tmp" "$seconds" <<'PYCHANGE'
import pathlib, re, sys
src, dest, seconds = sys.argv[1], sys.argv[2], int(sys.argv[3])
try:
    content = pathlib.Path(src).read_text(encoding='utf-8')
    lines = content.splitlines(keepends=True)
    pattern = re.compile(r'^(\s*(?:export\s+)?DELAY\s*=\s*)(["\']?)(\d+)([smh]?)(["\']?)(\s*(?:\#.*)?)(\r?\n?)$')
    matches = [(i, pattern.match(line)) for i, line in enumerate(lines)]
    matches = [(i, m) for i, m in matches if m and m.group(2) == m.group(5)]
    if len(matches) != 1:
        raise ValueError('Il faut exactement une affectation DELAY numerique simple.')
    i, m = matches[0]
    # Utiliser un format simple reconnu par le script existant.
    # 2 h 30 est stocke sous la forme 150m, jamais 2h30.
    oldunit = m.group(4)
    factor = {'h':3600,'m':60,'s':1,'':1}[oldunit]
    if seconds % factor == 0:
        newunit, value = oldunit, seconds // factor
    else:
        newunit, value = 'm', seconds // 60
    lines[i] = m.group(1)+m.group(2)+str(value)+newunit+m.group(5)+m.group(6)+m.group(7)
    pathlib.Path(dest).write_text(''.join(lines), encoding='utf-8')
except (OSError, UnicodeError, ValueError) as e:
    print('[ERREUR]', e)
    sys.exit(1)
PYCHANGE
  then rm -f -- "$tmp"; echo "[INFO] Sauvegarde : $backup"; return 1; fi
  chmod --reference="$target" "$tmp" 2>/dev/null || chmod 755 "$tmp"
  chown --reference="$target" "$tmp" 2>/dev/null || true
  if ! bash -n "$tmp"; then rm -f -- "$tmp"; echo '[ERREUR] Syntaxe invalide, original conserve.'; return 1; fi
  if ! mv -f -- "$tmp" "$target"; then rm -f -- "$tmp"; echo '[ERREUR] Remplacement impossible.'; return 1; fi
  echo "[OK] Délai enregistré."
  echo "[SAUVEGARDE] $backup"
  show_shutdown_delay "$target"
  # V1.6.107 : si la veille est active et le worker reconnu, repartir
  # immediatement sur le nouveau delai sans reveiller EmulationStation.
  # Hors veille : conserver le delai et attendre le prochain ecran de veille.
  local workers count wp wt wpath active_pid='' active_token='' active_path=''
  workers="$(shutdown_workers list)" || { echo '[ATTENTION] Vérification du minuteur impossible : aucune relance automatique.'; return 0; }
  count=0
  if [[ -n "$workers" ]]; then
    while IFS=' ' read -r wp wt wpath; do
      [[ -n "$wp" ]] || continue
      ((count+=1))
      active_pid="$wp"; active_token="$wt"; active_path="$wpath"
    done <<< "$workers"
  fi
  if (( count > 1 )); then
    echo '[SÉCURITÉ] Plusieurs minuteurs : relance automatique ignorée.'
  elif (( count == 1 )) && [[ "$active_path" == "$target" ]]; then
    local state_pid='' state_token='' new_pid='' new_token=''
    if [[ -r /tmp/shutdown.screensaver ]]; then
      read -r state_pid state_token </tmp/shutdown.screensaver || true
    fi
    if [[ "$state_pid" != "$active_pid" || "$state_token" != "$active_token" ]]; then
      echo '[SÉCURITÉ] État du minuteur incoherent : relance ignorée.'
    elif screensaver_active; then
      echo '[ACTION] Nouveau délai enregistre : relance du minuteur actif...'
      if /bin/bash "$target" --manual; then
        if [[ -r /tmp/shutdown.screensaver ]]; then
          read -r new_pid new_token </tmp/shutdown.screensaver || true
        fi
        if [[ "$new_pid" =~ ^[0-9]+$ && "$new_token" =~ ^[0-9]+-[0-9]+-[0-9]+$ && "$new_token" != "$active_token" ]]; then
          echo "[OK] Minuteur relancé."
          echo "[DÉLAI] $(shutdown_remaining "$target" "$new_token")"
        else
          echo '[ATTENTION] Relance demandée, nouvel etat non confirmé.'
        fi
      else
        echo '[ATTENTION] Relance automatique echouee ; vérifier le minuteur.'
      fi
    else
      echo '[INFO] Veille inactive : nouveau délai en attente du prochain ecran de veille.'
    fi
  else
    echo '[INFO] Aucun minuteur actif : nouveau délai applique a la prochaine veille.'
  fi
}


# Detection stricte des travailleurs d extinction, avec PID et jeton.
# Cette routine ne modifie rien sauf sur demande explicite (stop).
shutdown_workers(){
  local action="${1:-list}" expected_pid="${2:-}" expected_token="${3:-}"
  python3 - "$action" "$expected_pid" "$expected_token" <<'PYWORKERS'
import os, re, signal, sys, time
from pathlib import Path
mode, expected_pid, expected_token = sys.argv[1:]
prefix = '/userdata/system/configs/emulationstation/scripts/screensaver-start/shutdown-trigger.sh'
backupdirs = ('/userdata/system/backup-shutdown/', '/userdata/saves/Installscripts/saves/Shutdown/')
pattern = re.compile(r'\d+-\d+-\d+\Z')

def argv(pid):
    try:
        return [x.decode() for x in Path(f'/proc/{pid}/cmdline').read_bytes().split(b'\0') if x]
    except (OSError, UnicodeError):
        return []

def valid_worker(pid):
    args = argv(pid)
    if len(args) != 4 or args[0] not in ('/bin/bash','bash') or args[2] != '--worker' or not pattern.fullmatch(args[3]):
        return None
    path = args[1]
    is_active = path == prefix
    is_old = bool(re.fullmatch(re.escape(prefix)+r'\.bak\.\d{8}-\d{6}(?:-\d+)?', path))
    is_saved = any(path.startswith(d) and bool(re.fullmatch(r'shutdown-trigger\.sh\.bak[-.]\d{8}-\d{6}(?:-\d+)?', path[len(d):])) for d in backupdirs)
    if not (is_active or is_old or is_saved):
        return None
    return (pid, args[3], path)

workers = []
for name in os.listdir('/proc'):
    if name.isdigit():
        item = valid_worker(int(name))
        if item:
            workers.append(item)
workers.sort()
if mode == 'list':
    for pid, token, path in workers:
        print(f'{pid} {token} {path}')
    sys.exit(0)
if mode != 'stop':
    sys.exit(2)
if expected_pid and not any(str(p)==expected_pid and t==expected_token for p,t,_ in workers):
    print('[ATTENTION] Le minuteur selectionne a change : aucune annulation.')
    sys.exit(3)
# Lors d une annulation, on arrete les descendants avant leur parent Bash.
# Ne jamais tuer un sleep arbitraire : seulement un enfant du worker valide.
def ppid_of(pid):
    try:
        tail = Path(f'/proc/{pid}/stat').read_text().rsplit(')',1)[1].split()
        return int(tail[1])
    except (OSError, ValueError, IndexError):
        return -1

def children_of(parent):
    result=[]
    for name in os.listdir('/proc'):
        if name.isdigit() and ppid_of(int(name)) == parent:
            result.append(int(name))
    return result

for pid, token, path in workers:
    if valid_worker(pid) != (pid, token, path):
        continue
    children = children_of(pid)
    for child in children:
        # Notre worker n attend normalement que la commande sleep.
        args = argv(child)
        if len(args) == 2 and args[0] in ('sleep','/bin/sleep','/usr/bin/sleep') and re.fullmatch(r'\d+[smh]?', args[1]):
            try: os.kill(child, signal.SIGTERM)
            except ProcessLookupError: pass
    if valid_worker(pid) == (pid, token, path):
        try:
            os.kill(pid, signal.SIGTERM)
            print(f'[OK] Minuteur arrêté : PID {pid}')
        except ProcessLookupError:
            pass
        except PermissionError:
            print(f'[ERREUR] Autorisation refusée : PID {pid}')
            sys.exit(4)
# Supprimer l etat seulement si celui-ci correspond a un travailleur traite.
state=Path('/tmp/shutdown.screensaver')
try:
    current=state.read_text().split()
    if len(current)==2 and any(str(p)==current[0] and t==current[1] for p,t,_ in workers):
        state.unlink(missing_ok=True)
        print('[OK] État minuteur effacé.')
except OSError:
    pass
PYWORKERS
}

shutdown_remaining(){
  local worker_path="$1" token="$2"
  python3 - "$worker_path" "$token" <<'PYREMAIN'
import re, sys, time
from pathlib import Path
try:
    worker_path, token = sys.argv[1:]
    state = Path('/tmp/shutdown.screensaver').read_text().split()
    if len(state) != 2 or state[1] != token:
        raise ValueError('etat different')
    pid = int(state[0])
    args = Path(f'/proc/{pid}/cmdline').read_bytes().split(b'\0')
    args = [x.decode() for x in args if x]
    if len(args) != 4 or args[1] != worker_path or args[2] != '--worker' or args[3] != token:
        raise ValueError('processus non confirme')
    start = int(token.split('-')[0])
    source = Path(worker_path).read_text(encoding='utf-8')
    matches = re.findall(r'^\s*DELAY\s*=\s*["\']?(\d+)([smh]?)["\']?\s*(?:#.*)?$', source, re.M)
    if len(matches) != 1:
        raise ValueError('delai ambigu')
    amount, unit = matches[0]
    seconds = int(amount) * {'s': 1, 'm': 60, 'h': 3600, '': 1}[unit]
    remaining = max(0, start + seconds - int(time.time()))
    hours, remainder = divmod(remaining, 3600)
    minutes, secs = divmod(remainder, 60)
    print(f'{hours:02d}:{minutes:02d}:{secs:02d}')
except (OSError, ValueError, KeyError, IndexError, UnicodeError):
    print('indisponible')
PYREMAIN
}

# Un seul point d entree pour l annulation et la remise a zero.
# Verification independante du minuteur : etat cree par screensaver-start.
screensaver_active(){
  local marker=/tmp/batocera-screensaver-active
  [[ -r "$marker" ]] || { echo '[VEILLE] Etat absent : attendre une nouvelle activation de l economiseur.'; return 1; }
  python3 - "$marker" <<'PYCHECKVEILLE'
import os,sys
from pathlib import Path
try:
    lines=Path(sys.argv[1]).read_text().split()
    if len(lines)!=3: raise ValueError('marqueur invalide')
    pid,start,boot=lines
    if not pid.isdigit() or not start.isdigit(): raise ValueError('marqueur invalide')
    actual_boot=Path('/proc/sys/kernel/random/boot_id').read_text().strip()
    stat=Path(f'/proc/{pid}/stat').read_text().rsplit(')',1)[1].split()
    actual_start=stat[19]
    args=Path(f'/proc/{pid}/cmdline').read_bytes().split(b'\0')
    if boot!=actual_boot or start!=actual_start or not any(os.path.basename(a.decode(errors='replace'))=='emulationstation' for a in args if a):
        raise ValueError('session EmulationStation differente')
except (OSError,ValueError) as e:
    print('[VEILLE] Etat non fiable : '+str(e))
    sys.exit(1)
print('[VEILLE] Economiseur actif selon les evenements de cette session.')
PYCHECKVEILLE
}

manage_shutdown_timer(){
  local state=/tmp/shutdown.screensaver
  local trigger=/userdata/system/configs/emulationstation/scripts/screensaver-start/shutdown-trigger.sh
  local workers='' count=0 pid='' token='' path='' choice='' registered_pid='' registered_token=''
  ui_section 'GESTION DE L EXTINCTION'
  show_shutdown_delay "$trigger"
  if ! workers="$(shutdown_workers list)"; then
    echo '[ERREUR] Vérification des processus impossible.'; return 0
  fi
  if [[ -n "$workers" ]]; then
    while IFS=' ' read -r pid token path; do
      [[ -n "$pid" ]] || continue
      ((count+=1))
      echo "[MINUTEUR $count] PID $pid"
      echo "  [TEMPS RESTANT ESTIME] $(shutdown_remaining "$path" "$token")"
      if [[ "$path" != "$trigger" ]]; then echo '  [INFO] Ancienne version du script.'; fi
    done <<< "$workers"
  else
    echo '[INFO] Aucun minuteur actif détecté.'
  fi
  if [[ -r "$state" ]]; then
    read -r registered_pid registered_token < "$state" || true
  fi
  if (( count > 1 )); then
    echo '[ATTENTION] Plusieurs minuteurs detectes !'
    ui_item '1) Annuler TOUS les minuteurs reconnus'
    echo
    ui_item '0) Retour'
    ui_item 'Q) Quitter le gestionnaire'
    choice="$(read_key 'Votre choix : ')" || return 0
    if [[ "$choice" == 1 ]] && confirm 'Confirmer l arrêt de tous les minuteurs ?'; then
      shutdown_workers stop || echo '[ATTENTION] Nettoyage incomplet.'
    fi
    return 0
  fi
  if (( count == 1 )); then
    ui_item '1) Annuler le minuteur'
    ui_item '2) Recommencer le délai depuis maintenant'
  else
    ui_item '1) Demarrer un nouveau minuteur'
  fi
  ui_item '0) Retour'
    ui_item 'Q) Quitter le gestionnaire'
  choice="$(read_key 'Votre choix : ')" || return 0
  case "$choice" in
    0) return 0 ;;
    1)
      if (( count == 1 )); then
        if confirm 'Annuler le minuteur maintenant ?'; then
          shutdown_workers stop "$pid" "$token" || echo '[ATTENTION] Annulation non confirmée.'
        else echo '[INFO] Aucune annulation.'; fi
      else
        start_shutdown_timer
      fi ;;
    2)
      if (( count != 1 )); then echo '[INFO] Choix invalide.'; return 0; fi
      echo '[ATTENTION] Cette operation arrêté le minuteur actuel avant d en lancer un nouveau.'
      if ! confirm 'Confirmer la remise a zero ?'; then return 0; fi
      screensaver_active || { echo '[SÉCURITÉ] Remise a zero refusée.'; return 0; }
      if ! shutdown_workers stop "$pid" "$token"; then
        echo '[ERREUR] Arret non confirmé. Relance interdite.'; return 0
      fi
      start_shutdown_timer confirmed
      ;;
    *) echo '[INFO] Choix invalide.' ;;
  esac
  return 0
}

start_shutdown_timer(){
  local trigger=/userdata/system/configs/emulationstation/scripts/screensaver-start/shutdown-trigger.sh
  local state=/tmp/shutdown.screensaver
  local workers='' pid='' token=''
  if [[ ! -s "$trigger" ]] || ! bash -n "$trigger"; then
    echo '[ERREUR] Script de déclenchement absent ou invalide.'; return 0
  fi
  workers="$(shutdown_workers list)" || { echo '[ERREUR] Controle des processus impossible.'; return 0; }
  if [[ -n "$workers" ]]; then
    echo '[ATTENTION] Un minuteur existe déjà. Demarrage refuse.'; return 0
  fi
  echo '[ATTENTION] Un vrai compte a rebours d extinction va etre programme.'
  screensaver_active || { echo '[SÉCURITÉ] Demarrage refuse.'; return 0; }
  if ! /bin/bash "$trigger" --manual; then
    echo '[ERREUR] Impossible de demarrer le minuteur.'; return 0
  fi
  if [[ -f "$state" ]]; then read -r pid token < "$state" || true; fi
  workers="$(shutdown_workers list)" || true
  if [[ "$pid" =~ ^[0-9]+$ && "$token" =~ ^[0-9]+-[0-9]+-[0-9]+$ && "$workers" == *"$pid $token "* ]]; then
    echo "[OK] Minuteur programmé."
    echo "[PID] $pid"
  else
    echo '[ATTENTION] Le lancement a ete demandé mais son etat reste a vérifier.'
  fi
  return 0
}

install_shutdown_fix(){
  local v target backup tmp
  v="$(detect_batocera_version)" || true
  echo "[Batocera] Version : ${v:-inconnue}"
  if [[ "$v" != 42 && "$v" != 42.* ]]; then echo '[SÉCURITÉ] Reserve a Batocera 42.'; return 1; fi
  target=/userdata/system/custom.sh
  confirm 'Installer la correction extinction PC ?' || { echo '[INFO] Annulé.'; return 0; }
  if [[ -L "$target" ]] || { [[ -e "$target" ]] && [[ ! -f "$target" ]]; }; then echo '[ERREUR] Fichier cible non ordinaire.'; return 1; fi
  if [[ -f "$target" ]] && grep -Eq '^[[:space:]]*batocera-es-swissknife[[:space:]]+--shutdown([[:space:]]|$)' "$target"; then
    echo '[OK] Commande déjà presente.'; chmod u+x "$target"; return 0
  fi
  mkdir -p /userdata/system || return 1
  if [[ -f "$target" ]]; then
    backup_file "$target" "$SAVES/Shutdown" "custom.sh" || return 1
    echo "[SAUVEGARDE] $backup"
  fi
  tmp="$(mktemp /userdata/system/.custom.sh.XXXXXX)" || return 1
  if [[ -f "$target" ]]; then
    # Insertion avant la premiere instruction exit pour rendre la correction accessible.
    awk 'BEGIN{added=0} !added && /^[[:space:]]*exit[[:space:]]/ {print "# Correction extinction mini-PC Batocera 42"; print "if [ \"${1:-}\" = \"stop\" ]; then"; print "    batocera-es-swissknife --shutdown"; print "fi"; added=1} {print} END{if (!added) {print "# Correction extinction mini-PC Batocera 42"; print "if [ \"${1:-}\" = \"stop\" ]; then"; print "    batocera-es-swissknife --shutdown"; print "fi"}}' "$target" > "$tmp" || { rm -f "$tmp"; return 1; }
  else
    printf '%s\n' '#!/bin/bash' '# Correction extinction mini-PC Batocera 42' 'if [ "${1:-}" = "stop" ]; then' '    batocera-es-swissknife --shutdown' 'fi' 'exit 0' > "$tmp"
  fi
  bash -n "$tmp" || { rm -f "$tmp"; echo '[ERREUR] Syntaxe incorrecte.'; return 1; }
  chmod 755 "$tmp" || { rm -f "$tmp"; return 1; }
  mv -f "$tmp" "$target" || { rm -f "$tmp"; return 1; }
  echo '[OK] Correction installée.'
  ui_print warning '  Attention : custom.sh stop'
  ui_print warning '  éteint le PC !'
}


# Kodi Batocera 44 : lanceur autonome valide, GitHub prioritaire,
# et cache-gestionnaire/Kodi comme secours hors ligne. Aucun second script requis.
KODI44_REMOTE="https://raw.githubusercontent.com/$REPO/main/Kodi/kodi.sh"
KODI44_CACHE="$CACHE/Kodi/kodi.sh"
KODI44_SHA256='66afd1b3bd2a84559e93af2befc1fde83d6ff7897e4403d32df70c46def65ccd'
KODI44_SOURCE=''
kodi44_validate(){
  local f="$1" actual
  [[ -f "$f" && ! -L "$f" && -s "$f" ]] || return 1
  actual="$(sha256sum "$f" | cut -d' ' -f1)" || return 1
  [[ "$actual" == "$KODI44_SHA256" ]] && bash -n "$f"
}
kodi44_prepare(){
  local tmp
  KODI44_SOURCE=''
  if [[ -L "$CACHE" || -L "$CACHE/Kodi" || -L "$KODI44_CACHE" ]]; then
    echo '[SÉCURITÉ] Lien symbolique dans le cache Kodi : opération refusée.'
    return 1
  fi
  mkdir -p -- "$CACHE/Kodi" || return 1
  if kodi44_validate "$KODI44_CACHE"; then
    KODI44_SOURCE="$KODI44_CACHE"
    echo '[SOURCE] KODI : cache.'
    return 0
  fi
  tmp="$(mktemp "$CACHE/Kodi/.kodi-download.XXXXXX")" || return 1
  if command -v curl >/dev/null 2>&1 &&
     curl -fLsS --connect-timeout 5 --max-time 40 "$KODI44_REMOTE" -o "$tmp" 2>/dev/null &&
     kodi44_validate "$tmp"; then
    if ! mv -f -- "$tmp" "$KODI44_CACHE"; then
      rm -f -- "$tmp"
      return 1
    fi
    KODI44_SOURCE="$KODI44_CACHE"
    echo '[KODI] GitHub OK ; cache Kodi prêt.'
    return 0
  fi
  rm -f -- "$tmp"
  echo '[KODI] GitHub indisponible ou version différente : vérification du cache local.'
  if kodi44_validate "$KODI44_CACHE"; then
    KODI44_SOURCE="$KODI44_CACHE"
    echo '[KODI] Secours local dans cache-gestionnaire/Kodi fonctionnel.'
    return 0
  fi
  echo '[ERREUR] Kodi : cache et GitHub indisponibles.'
  return 1
}
kodi44_install(){
  local v target='/userdata/roms/ports/kodi.sh' tmp
  v="$(detect_batocera_version)" || v=''
  case "$v" in
    44|44.*) ;;
    *) echo "[SÉCURITÉ] Lanceur Kodi autonome réservé à Batocera 44 (détecté : ${v:-inconnu})."; return 1 ;;
  esac
  echo; echo '===== Kodi dans Ports ====='
  confirm 'Installer le lanceur Kodi ?' || { echo '[INFO] Annulé.'; return 0; }
  kodi44_prepare || return 1
  mkdir -p /userdata/roms/ports || return 1
  if [[ -L "$target" ]] || { [[ -e "$target" ]] && [[ ! -f "$target" ]]; }; then
    echo '[SÉCURITÉ] Cible Kodi non ordinaire : installation refusée.'
    return 1
  fi
  if [[ -f "$target" ]] && cmp -s "$KODI44_SOURCE" "$target" && [[ -x "$target" ]]; then
    echo '[OK] Kodi : lanceur OK.'
    ensure_ports_artwork 8
    return $?
  fi
  confirm 'Copier le lanceur Kodi autonome dans Ports ?' || { echo '[INFO] Annulé.'; return 0; }
  # La copie est prête et validée avant toute modification de la cible.
  tmp="$(mktemp /userdata/roms/ports/.kodi-install.XXXXXX)" || return 1
  if ! cp -p -- "$KODI44_SOURCE" "$tmp" || ! kodi44_validate "$tmp" || ! chmod 755 "$tmp"; then
    rm -f -- "$tmp"
    echo '[ERREUR] Préparation du lanceur Kodi impossible.'
    return 1
  fi
  if [[ -f "$target" ]]; then
    if ! backup_file "$target" "$SAVES/Kodi" 'kodi.sh'; then
      rm -f -- "$tmp"
      return 1
    fi
  fi
  if ! mv -f -- "$tmp" "$target"; then
    rm -f -- "$tmp"
    echo '[ERREUR] Installation Kodi impossible ; ancien lanceur préservé.'
    return 1
  fi
  echo "[OK] Kodi : lanceur installé."
  echo "[FICHIER] $target"
  echo '[INFO] Aucun kodi-detache-TEST.sh nécessaire.'
  ensure_ports_artwork 8 || echo '[ATTENTION] Lanceur installé, illustrations non installées.'
}

# Raccourci F1 Batocera 44 : comportement de la V2.0.11 conservé.
install_launcher_44(){
  local choice="$1" target tmp
  if [[ "$choice" == 8 ]]; then
    kodi44_install
    return $?
  fi
  [[ "$choice" == 7 ]] || return 1
  echo; echo '===== F1 dans Ports ====='
  confirm 'Installer F1 dans Ports ?' || { echo '[INFO] Annulé.'; return 0; }
  target='/userdata/roms/ports/F1.sh'
  mkdir -p /userdata/roms/ports "$BASE" || return 1
  if [[ -L "$target" ]] || { [[ -e "$target" ]] && [[ ! -f "$target" ]]; }; then
    echo '[ERREUR] Cible non ordinaire.'; return 1
  fi
  tmp="$(mktemp /userdata/roms/ports/.launcher44.XXXXXX)" || return 1
  cat > "$tmp" <<'F1_44'
#!/bin/bash
export XDG_MENU_PREFIX=batocera-
export XDG_CONFIG_DIRS=/etc/xdg
export XDG_CACHE_HOME=/tmp/xdg_cache
batocera-mouse show
pcmanfm /userdata
batocera-mouse hide
F1_44
  if ! bash -n "$tmp"; then rm -f "$tmp"; return 1; fi
  if [[ -f "$target" && -x "$target" ]] && cmp -s "$tmp" "$target"; then
    rm -f -- "$tmp"
    echo '[OK] F1 : lanceur OK.'
    ensure_ports_artwork 7
    local art_rc=$?
    padkeys_install f1 || echo '[ATTENTION] Commandes manette F1 non installées.'
    return "$art_rc"
  fi
  if [[ -f "$target" ]]; then
    backup_file "$target" "$SAVES/Fichier" 'F1.sh' || { rm -f "$tmp"; return 1; }
  fi
  chmod 755 "$tmp" && mv -f "$tmp" "$target" || { rm -f "$tmp"; return 1; }
  echo "[OK] Raccourci installé."
  echo "[FICHIER] $target"
  ensure_ports_artwork 7 || echo '[ATTENTION] Raccourci installé, illustrations non installées.'
  padkeys_install f1 || echo '[ATTENTION] Commandes manette F1 non installées.'
}

# Installation des lanceurs F1 et Kodi : GitHub en priorite, copie locale en secours.
install_simple_launcher(){
  local choice="$1" filename='' label='' expected='' remote='' url='' tmp='' source='' target='' backup=''
  case "$choice" in
    7) filename=F1.sh; label='Explorateur de fichiers'; expected='/usr/bin/filemanagerlauncher' ;;
    8) filename=kodi.sh; label='Kodi'; expected=$'#!/bin/sh\nbatocera-kodi\nkillall kodi.bin' ;;
    *) return 1 ;;
  esac
  local detected_version=''
  detected_version="$(detect_batocera_version)" || true
  if [[ "$detected_version" == 44 || "$detected_version" == 44.* ]]; then
    install_launcher_44 "$choice"
    return $?
  fi
  echo; echo "===== $label ====="
  check_simple_compatibility || return 1
  confirm "Installer $filename depuis GitHub (secours local si nécessaire) ?" || { echo '[INFO] Annulé.'; return 0; }
  if fetch_tree; then
    remote="$(python3 - "$CACHE/tree.json" "$filename" <<'PYFIND'
import json,sys,os
try:
    entries=json.load(open(sys.argv[1],encoding='utf-8')).get('tree',[])
    matches=[e['path'] for e in entries if e.get('type')=='blob' and os.path.basename(e.get('path','')).lower()==sys.argv[2].lower()]
    if matches: print(sorted(matches,key=lambda p:(len(p),p))[0])
except (OSError,ValueError,KeyError): pass
PYFIND
)"
  fi
  source="$CACHE/$filename"
  if [[ -n "$remote" ]]; then
    url="https://raw.githubusercontent.com/$REPO/main/$remote"
    tmp="$(mktemp "$CACHE/.launcher.XXXXXX")" || return 1
    if curl -fLsS --connect-timeout 5 --max-time 40 "$url" -o "$tmp" && [[ -s "$tmp" ]] && bash -n "$tmp"; then
      if [[ -f "$source" ]] && cmp -s "$source" "$tmp"; then rm -f "$tmp"; else
        [[ ! -f "$source" ]] || backup_file "$source" "$SAVES/Cache" "$filename" || return 1
        mv -f "$tmp" "$source" || return 1
      fi
      echo '[SOURCE] GitHub (copie en cache).'
    else
      rm -f "$tmp"
      echo '[ATTENTION] GitHub inaccessible ou script invalide.'
    fi
  else
    echo '[ATTENTION] Lanceur non trouvé sur GitHub.'
  fi
  if [[ ! -s "$source" ]]; then
    echo '[ERREUR] Aucun lanceur en cache.'
    return 1
  fi
  bash -n "$source" || { echo '[ERREUR] Syntaxe du lanceur invalide.'; return 1; }
  target="/userdata/roms/ports/$filename"
  # Sur Batocera 42/43.1 : ne pas recopier un lanceur déjà identique.
  if [[ -f "$target" && ! -L "$target" && -x "$target" ]]; then
    if { [[ "$(head -c 2 "$source")" == '#!' ]] && cmp -s "$source" "$target"; } || \
       { [[ "$(head -c 2 "$source")" != '#!' ]] && cmp -s <(printf '#!/bin/sh\n'; cat "$source") "$target"; }; then
      echo "[OK] Lanceur déjà conforme."
    echo "[FICHIER] $filename"
      ensure_ports_artwork "$choice"
      local art_rc=$?
      if [[ "$choice" == 7 ]]; then
        padkeys_install f1 || echo '[ATTENTION] Commandes manette F1 non installées.'
      fi
      return "$art_rc"
    fi
  fi
  confirm "Confirmer la copie de $filename dans Ports ?" || { echo '[INFO] Annulé.'; return 0; }
  mkdir -p /userdata/roms/ports || return 1
  if [[ -e "$target" ]]; then
    backup_file "$target" "$SAVES/$([[ "$choice" == 7 ]] && echo Fichier || echo Kodi)" "$filename" || return 1
    echo "[SAUVEGARDE] $backup"
  fi
  tmp="$(mktemp /userdata/roms/ports/.launcher.XXXXXX)" || return 1
  if [[ "$(head -c 2 "$source")" == "#!" ]]; then
    cp "$source" "$tmp" || { rm -f "$tmp"; return 1; }
  else
    { printf '#!/bin/sh\n'; cat "$source"; } > "$tmp" || { rm -f "$tmp"; return 1; }
  fi
  chmod 755 "$tmp" && mv -f "$tmp" "$target" || { rm -f "$tmp"; return 1; }
  echo "[OK] Lanceur installé."
  echo "[FICHIER] $target"
  ensure_ports_artwork "$choice" || echo '[ATTENTION] Lanceur installé, illustrations non installées.'
  if [[ "$choice" == 7 ]]; then
    padkeys_install f1 || echo '[ATTENTION] Commandes manette F1 non installées.'
  fi
}
check_simple_compatibility(){
  local v
  v="$(detect_batocera_version)" || true
  echo "[Batocera] Version : ${v:-inconnue}"
  if [[ "$v" == 42 || "$v" == 42.* || "$v" == 43.1 || "$v" == 43.1.* ]]; then return 0; fi
  confirm 'Version non reconnue : poursuivre ?'
}

# Profils locaux : FileZilla Flatpak et Firefox Mozilla natif (pas Firefox Flatpak).
# Les sauvegardes sont des dossiers complets, conserves hors du profil actif.
profile_source(){
  case "$1" in
    filezilla) printf '%s\n' '/userdata/saves/flatpak/data/.var/app/org.filezillaproject.Filezilla/config/filezilla' ;;
    peazip) printf '%s\n' '/userdata/saves/flatpak/data/.var/app/io.github.peazip.PeaZip/config/peazip' ;;
    firefox) printf '%s\n' '/userdata/system/.config/mozilla/firefox' ;;
    kodi) printf '%s\n' '/userdata/system/.kodi' ;;
    *) return 1 ;;
  esac
}
profile_folder(){
  case "$1" in
    filezilla) printf '%s\n' "$SAVES/FileZilla/Profils" ;;
    peazip) printf '%s\n' "$SAVES/PeaZip/Profils" ;;
    firefox) printf '%s\n' "$SAVES/Firefox/Profils" ;;
    kodi) printf '%s\n' "$SAVES/Kodi/Profils" ;;
    *) return 1 ;;
  esac
}
profile_app_running(){
  python3 - "$1" <<'PYCHECKAPP'
import os,sys
app=sys.argv[1]
for pid in os.listdir('/proc'):
    if not pid.isdigit(): continue
    try:
        args=[a.decode(errors='replace') for a in open('/proc/'+pid+'/cmdline','rb').read().split(b'\0') if a]
    except OSError: continue
    if not args: continue
    exe=os.path.basename(args[0]).lower()
    # Le processus Firefox lanceur et les processus enfants sont detectes.
    if app=='firefox' and (exe in ('firefox','firefox-bin') or '/firefox-mozilla/firefox' in args[0]): sys.exit(0)
    if app=='kodi' and (exe in ('kodi','kodi.bin','kodi-x11','kodi-wayland') or any('/kodi/' in a for a in args[:2])): sys.exit(0)
    if app=='filezilla' and (exe=='filezilla' or any('/org.filezillaproject.Filezilla/' in a for a in args[:2])): sys.exit(0)
    if app=='peazip' and (exe in ('peazip','peazip.bin') or any('/io.github.peazip.PeaZip/' in a for a in args[:2])): sys.exit(0)
sys.exit(1)
PYCHECKAPP
}
profile_latest(){
  local folder latest
  folder="$(profile_folder "$1")" || return 1
  [[ -d "$folder" ]] || return 1
  latest="$(find "$folder" -mindepth 1 -maxdepth 1 -type d -name 'profil-*' -printf '%f\n' 2>/dev/null | sort -r | head -n 1)"
  [[ -n "$latest" && -d "$folder/$latest/data" ]] || return 1
  printf '%s\n' "$folder/$latest"
}
profile_backup(){
  local app="$1" src folder dest tmp
  src="$(profile_source "$app")" || return 1
  folder="$(profile_folder "$app")" || return 1
  if profile_app_running "$app"; then echo "[ERREUR] Fermer $app avant la sauvegarde."; return 1; fi
  [[ -d "$src" ]] || { echo "[ERREUR] Aucun profil $app a sauvegarder : $src"; return 1; }
  if [[ "$app" == filezilla && ! -f "$src/filezilla.xml" && ! -f "$src/sitemanager.xml" ]]; then
    echo '[ERREUR] Configuration FileZilla vide ou non reconnue.'; return 1
  fi
  if [[ "$app" == peazip && ! -f "$src/conf.txt" && ! -f "$src/Profiles/profile.profile.7z" ]]; then
    echo '[ERREUR] Configuration PeaZip non reconnue.'; return 1
  fi
  if [[ "$app" == kodi && ! -d "$src/userdata" ]]; then
    echo '[ERREUR] Profil Kodi non reconnu : dossier userdata absent.'; return 1
  fi
  if [[ "$app" == firefox ]] && ! find "$src" -type f \( -name prefs.js -o -name profiles.ini \) -print -quit 2>/dev/null | grep -q .; then
    echo '[ERREUR] Aucun profil Firefox utilisable trouvé.'; return 1
  fi
  mkdir -p -m 700 -- "$folder" || return 1
  chmod 700 -- "$folder" || return 1
  dest="$folder/profil-$(date +%Y%m%d-%H%M%S)-$$"
  tmp="$(mktemp -d "$folder/.sauvegarde.XXXXXX")" || return 1
  if ! cp -a -- "$src/." "$tmp/"; then
    rm -rf -- "$tmp"; echo '[ERREUR] Copie incomplete : sauvegarde abandonnee.'; return 1
  fi
  # Les sauvegardes Firefox excluent uniquement les caches temporaires du profil.
  if [[ "$app" == kodi ]]; then
    find "$tmp" -type d \( -name cache -o -name temp \) -prune -exec rm -rf -- {} + 2>/dev/null || true
  fi
  if [[ "$app" == firefox ]]; then
    find "$tmp" -type d \( -name cache2 -o -name startupCache \) -prune -exec rm -rf -- {} + 2>/dev/null || true
    # Exclure les verrous du profil Firefox (fichiers et liens symboliques).
    find "$tmp" \( -type f -o -type l \) \( -name lock -o -name .parentlock \) -delete || {
      rm -rf -- "$tmp"; echo '[ERREUR] Exclusion des verrous Firefox impossible.'; return 1;
    }
  fi
  mkdir -m 700 -- "$dest" || { rm -rf -- "$tmp"; return 1; }
  mv -- "$tmp" "$dest/data" || { rm -rf -- "$tmp" "$dest"; return 1; }
  chmod -R go-rwx -- "$dest" || true
  echo "[SAUVEGARDE] $dest"
  # Rotation uniquement apres sauvegarde reussie.
  python3 - "$folder" <<'PYROTATE'
from pathlib import Path
import shutil,sys
root=Path(sys.argv[1])
items=sorted((x for x in root.iterdir() if x.is_dir() and x.name.startswith('profil-') and (x/'data').is_dir()),reverse=True)
for old in items[3:]: shutil.rmtree(old)
PYROTATE
}
profile_restore(){
  local app="$1" selected="${2:-}" src folder latest old='' staging=''
  src="$(profile_source "$app")" || return 1
  folder="$(profile_folder "$app")" || return 1
  if [[ -n "$selected" ]]; then
    # Uniquement un dossier de sauvegarde existant et valide dans le repertoire de l'application.
    [[ "$selected" =~ ^profil-[0-9]{8}-[0-9]{6}-[0-9]+$ && -d "$folder/$selected/data" && ! -L "$folder/$selected" && ! -L "$folder/$selected/data" ]] || {
      echo '[ERREUR] Sauvegarde selectionnee invalide ou absente.'; return 1;
    }
    latest="$folder/$selected"
  else
    latest="$(profile_latest "$app")" || { echo "[INFO] Aucune sauvegarde $app a restaurer."; return 1; }
  fi
  if profile_app_running "$app"; then echo "[ERREUR] Fermer $app avant la restauration."; return 1; fi
  echo "[RESTAURATION] Source : $latest"
  mkdir -p -- "$(dirname "$src")" || return 1
  staging="$(mktemp -d "$(dirname "$src")/.restauration.XXXXXX")" || return 1
  if ! cp -a -- "$latest/data/." "$staging/"; then
    rm -rf -- "$staging"; echo '[ERREUR] Copie de restauration incomplete.'; return 1
  fi
  if [[ "$app" == firefox ]]; then
    # Ignorer aussi les verrous presents dans les anciennes sauvegardes.
    find "$staging" \( -type f -o -type l \) \( -name lock -o -name .parentlock \) -delete || {
      rm -rf -- "$staging"; echo '[ERREUR] Nettoyage des verrous Firefox impossible.'; return 1;
    }
  fi
  if [[ -e "$src" ]]; then
    old="${src}.avant-restauration-$(date +%Y%m%d-%H%M%S)-$$"
    mv -- "$src" "$old" || { rm -rf -- "$staging"; return 1; }
  fi
  if ! mv -- "$staging" "$src"; then
    rm -rf -- "$staging"
    [[ -z "$old" ]] || mv -- "$old" "$src"
    echo '[ERREUR] Restauration echouee, ancien profil remis en place.'; return 1
  fi
  chmod -R go-rwx -- "$src" || true
  echo '[OK] Profil restaure.'
  [[ -z "$old" ]] || echo "[SÉCURITÉ] Ancien profil conserve : $old"
}
# Choix explicite d'une sauvegarde Firefox ou FileZilla.
# Restauration choisie par l'utilisateur, y compris apres installation.
profile_select_restore(){
  local app="$1" name folder choice selected i label
  local -a backups=()
  case "$app" in firefox) name=Firefox ;; filezilla) name=FileZilla ;; peazip) name=PeaZip ;; *) return 1 ;; esac
  folder="$(profile_folder "$app")" || return 1
  while :; do
    backups=()
    if [[ -d "$folder" && ! -L "$folder" ]]; then
      while IFS= read -r label; do
        [[ "$label" =~ ^profil-[0-9]{8}-[0-9]{6}-[0-9]+$ && -d "$folder/$label/data" && ! -L "$folder/$label" && ! -L "$folder/$label/data" ]] && backups+=("$label")
      done < <(find "$folder" -mindepth 1 -maxdepth 1 -type d -name 'profil-*' -printf '%f\n' 2>/dev/null | sort -r)
    fi
    refresh_screen
    ui_section "PROFILS $name"
    if (( ${#backups[@]} == 0 )); then
      echo '[INFO] Aucune sauvegarde disponible.'
      pause
      return 0
    fi
    for i in "${!backups[@]}"; do
      label="${backups[$i]}"
      if [[ "$label" =~ ^profil-([0-9]{4})([0-9]{2})([0-9]{2})-([0-9]{2})([0-9]{2})([0-9]{2})-[0-9]+$ ]]; then
        ui_item "$((i+1))) ${BASH_REMATCH[3]}/${BASH_REMATCH[2]}/${BASH_REMATCH[1]} - ${BASH_REMATCH[4]}:${BASH_REMATCH[5]}"
      else
        ui_item "$((i+1))) $label"
      fi
    done
    echo
    ui_item '0) Retour'
    ui_item 'Q) Quitter le gestionnaire'
    choice="$(read_key 'Votre choix : ')" || return 0
    [[ "$choice" =~ ^[0-9]+$ ]] || { echo '[INFO] Choix invalide.'; pause; continue; }
    (( 10#$choice == 0 )) && return 0
    (( 10#$choice >= 1 && 10#$choice <= ${#backups[@]} )) || { echo '[INFO] Choix invalide.'; pause; continue; }
    selected="${backups[$((10#$choice-1))]}"
    if confirm "Restaurer ce profil $name ? (profil actuel conservé)"; then
      profile_restore "$app" "$selected" || true
      pause
      return 0
    fi
  done
}
profile_manual_menu(){
  local app="$1" name choice
  case "$app" in filezilla) name=FileZilla ;; firefox) name=Firefox ;; kodi) name=Kodi ;; peazip) name=PeaZip ;; *) return 1 ;; esac
  while :; do
    refresh_screen
    ui_section "SAUVEGARDES $name"
    ui_item '1) Sauvegarder le profil'
    ui_item '2) Restaurer un profil'
    echo
    ui_item '0) Retour'
    ui_item 'Q) Quitter le gestionnaire'
    choice="$(read_key 'Votre choix : ')" || return 0
    case "$choice" in
      1) if confirm "Sauvegarder le profil $name ?"; then profile_backup "$app" || true; fi; pause ;;
      2) profile_select_restore "$app" ;;
      0) refresh_screen; return 0 ;;
      *) echo '[INFO] Choix invalide.'; pause ;;
    esac
  done
}

# Installation Firefox Mozilla sans Flatpak, indépendante des installateurs GitHub.
install_firefox_mozilla(){
  local root='/userdata/system/firefox-mozilla' archive='' tmpdir='' target='' launcher='' url='' rc=0
  local -a missing=()
  local firefox_fresh=0
  [[ -x /userdata/system/firefox-mozilla/firefox ]] || firefox_fresh=1
  echo; echo '===== FIREFOX MOZILLA (SANS FLATPAK) ====='
  check_simple_compatibility || return 1
  [[ "$(uname -m)" == x86_64 ]] || { echo '[ERREUR] Archive prévue pour x86_64 uniquement.'; return 1; }
  command -v curl >/dev/null 2>&1 || { echo '[ERREUR] curl absent.'; return 1; }
  command -v tar >/dev/null 2>&1 || { echo '[ERREUR] tar absent.'; return 1; }
  command -v python3 >/dev/null 2>&1 || { echo '[ERREUR] python3 absent.'; return 1; }
  if ! command -v ldd >/dev/null 2>&1; then
    echo '[ATTENTION] ldd absent : bibliothèques à vérifier après extraction.'
  fi
  echo '[INFO] Source : archive officielle Mozilla, édition française Linux 64 bits.'
  echo "[INFO] Destination : $root"
  echo '[INFO] Le profil Firefox existant et Flatpak ne seront pas modifiés.'
  confirm 'Télécharger et installer Firefox Mozilla ?' || { echo '[INFO] Annulé.'; return 0; }
  mkdir -p /userdata/system /userdata/roms/ports "$SAVES/Firefox" || return 1
  tmpdir="$(mktemp -d /userdata/system/.firefox-install.XXXXXX)" || return 1
  # L'URL Mozilla fournit la dernière version stable en français pour Linux 64 bits.
  url='https://download.mozilla.org/?product=firefox-latest&os=linux64&lang=fr'
  archive="$tmpdir/firefox.tar"
  echo '[INFO] Téléchargement de Firefox (peut prendre quelques minutes)...'
  if ! curl -fLsS --retry 2 --connect-timeout 15 --max-time 600 "$url" -o "$archive"; then
    echo '[ERREUR] Téléchargement impossible.'; rm -rf -- "$tmpdir"; return 1
  fi
  # Vérifier l'archive et éviter les chemins traversants avant extraction.
  if ! python3 - "$archive" <<'PYCHECK'
import sys,tarfile,pathlib
p=sys.argv[1]
try:
 with tarfile.open(p,'r:*') as t:
  members=t.getmembers()
  if not members or not any(m.name.rstrip('/')=='firefox/firefox' for m in members): raise ValueError('exécutable Firefox absent')
  for m in members:
   path=pathlib.PurePosixPath(m.name)
   if path.is_absolute() or '..' in path.parts or not path.parts or path.parts[0]!='firefox': raise ValueError('chemin non autorisé')
   if m.issym() or m.islnk():
    dest=pathlib.PurePosixPath(m.linkname)
    if dest.is_absolute() or '..' in dest.parts: raise ValueError('lien non autorisé')
 print('[OK] Archive Mozilla vérifiée.')
except Exception as e:
 print('[ERREUR] Archive non valide :',e);sys.exit(1)
PYCHECK
  then rm -rf -- "$tmpdir"; return 1; fi
  if ! tar -xf "$archive" -C "$tmpdir"; then
    echo '[ERREUR] Extraction impossible.'; rm -rf -- "$tmpdir"; return 1
  fi
  rm -f -- "$archive"
  [[ -x "$tmpdir/firefox/firefox" ]] || { echo '[ERREUR] Exécutable absent.'; rm -rf -- "$tmpdir"; return 1; }
  if command -v ldd >/dev/null 2>&1; then
    local deps
    deps="$(ldd "$tmpdir/firefox/firefox-bin" 2>&1 || true)"
    if grep -q 'not found' <<< "$deps"; then
      echo '[ERREUR] Bibliothèques manquantes :'
      grep 'not found' <<< "$deps"
      echo '[INFO] Installation annulée, version précédente préservée.'
      rm -rf -- "$tmpdir"; return 1
    fi
  fi
  # Installer sans effacer la version existante avant d'avoir extrait la nouvelle.
  target="$root"
  if [[ -e "$target" ]]; then
    local old="$SAVES/Firefox/firefox-precedent-$(date +%Y%m%d-%H%M%S)-$$"
    mv -- "$target" "$old" || { rm -rf -- "$tmpdir"; return 1; }
    echo "[SAUVEGARDE] Ancienne version : $old"
  fi
  if ! mv -- "$tmpdir/firefox" "$target"; then
    echo '[ERREUR] Impossible de placer Firefox.'
    rm -rf -- "$tmpdir"; return 1
  fi
  rm -rf -- "$tmpdir"
  launcher='/userdata/roms/ports/Firefox.sh'
  if [[ -f "$launcher" ]]; then
    backup_file "$launcher" "$SAVES/Firefox" 'Firefox.sh' || return 1
  fi
  local launcher_tmp
  launcher_tmp="$(mktemp /userdata/roms/ports/.firefox-launcher.XXXXXX)" || return 1
  cat > "$launcher_tmp" <<'FIREFOXLAUNCH'
#!/bin/bash
# Firefox Mozilla sans Flatpak - gestionnaire Batocera
export HOME=/userdata/system
export MOZ_DISABLE_AUTO_SAFE_MODE=1
cd /userdata/system/firefox-mozilla || exit 1
exec ./firefox --no-remote
FIREFOXLAUNCH
  chmod 755 "$launcher_tmp" && mv -f "$launcher_tmp" "$launcher" || { rm -f "$launcher_tmp"; return 1; }
  echo "[OK] Firefox installé."
  echo "[FICHIER] $target"
  echo "[OK] Lanceur Ports installé."
  echo "[FICHIER] $launcher"
  if (( firefox_fresh )) && profile_latest firefox >/dev/null 2>&1; then
    echo '[INFO] Sauvegardes Firefox disponibles : choix du profil.'
    profile_select_restore firefox
  fi
  install_ports_artwork 10 || echo '[ATTENTION] Illustrations Firefox non installées.'
  padkeys_install firefox || echo '[ATTENTION] Commandes manette Firefox non installées.'
  reload_es_games
  echo '[INFO] Vérifier le lancement depuis Ports. Si Firefox ne démarre pas, contrôler les bibliothèques et le serveur graphique.'
}

# Catalogues par version et categorie. Les outils communs peuvent etre repetes.
# Les protections de compatibilite des installateurs restent actives.
# CGS Multi-sources V2.1 : Batocera 44 uniquement.
# GitHub prioritaire ; cache valide utilise aussi comme secours hors ligne.
# L'ancien dossier CGS-V2.1 reste intact et n'est utilise que pour migration.
CGS44_LEGACY="$BASE/CGS-V2.1"
CGS44_REMOTE="https://raw.githubusercontent.com/$REPO/main/CGS/MultiSources"
CGS44_CACHE="$CACHE/CGS-V2.1"
CGS44_NAMES=(
  'gestion-cgs-multisources-v2.1-TEST.sh'
  'cgs-multisource-patch.py'
  'cgs-artwork.py'
  'artwork/CGS-fanart.png'
  'artwork/CGS-logo.png'
  'artwork/CGS-thumb.png'
)
CGS44_HASHES=(
  '04e4bb6c37063bcf7bb5890fe185d7ca6cdf0a8872f88eee1b28810c8e12db59'
  '670da88fb7e448489f56c1858f7aee6843ce5265e7a7406107785396e2d01af4'
  '2c5180c5819790080e876ec2da93536cbf4c0349eb60c62f4d5bceb05e6ec837'
)
cgs44_verify(){
  local dir="$1" i rel f actual
  [[ -d "$dir" && ! -L "$dir" ]] || return 1
  for i in "${!CGS44_NAMES[@]}"; do
    rel="${CGS44_NAMES[$i]}"
    f="$dir/$rel"
    [[ -s "$f" && -f "$f" && ! -L "$f" ]] || return 1
    if (( i < 3 )); then
      actual="$(sha256sum "$f" | cut -d' ' -f1)" || return 1
      [[ "$actual" == "${CGS44_HASHES[$i]}" ]] || return 1
    else
      python3 - "$f" <<'PYCHECKPNG'
import sys,struct
try:
    with open(sys.argv[1],'rb') as f: h=f.read(26)
    assert h[:8]==b'\x89PNG\r\n\x1a\n' and len(h)==26
    assert struct.unpack('>II',h[16:24])[0]>0 and struct.unpack('>II',h[16:24])[1]>0
except (OSError,AssertionError,ValueError): sys.exit(1)
PYCHECKPNG
      [[ $? == 0 ]] || return 1
    fi
  done
  bash -n "$dir/gestion-cgs-multisources-v2.1-TEST.sh" || return 1
  return 0
}
cgs44_copy_tree(){
  local from="$1" to="$2" rel dest tmp
  cgs44_verify "$from" || return 1
  [[ ! -L "$to" && ! -L "$to/artwork" ]] || { echo '[SÉCURITÉ] Cache CGS symbolique refusé.'; return 1; }
  mkdir -p "$to/artwork" || return 1
  for rel in "${CGS44_NAMES[@]}"; do
    dest="$to/$rel"
    [[ ! -L "$dest" ]] || { echo "[SÉCURITÉ] Lien symbolique interdit : $dest"; return 1; }
    if [[ -f "$dest" ]] && cmp -s "$from/$rel" "$dest"; then continue; fi
    tmp="$(mktemp "$(dirname "$dest")/.cgs-update.XXXXXX")" || return 1
    if ! cp -p -- "$from/$rel" "$tmp" || ! mv -f -- "$tmp" "$dest"; then
      rm -f -- "$tmp"
      return 1
    fi
  done
  cgs44_verify "$to"
}
cgs44_prepare(){
  local stage rel download_ok=1
  CGS44_ACTIVE=''
  [[ ! -L "$CGS44_CACHE" ]] || { echo '[SÉCURITÉ] Cache CGS symbolique refusé.'; return 1; }
  mkdir -p "$CACHE" || return 1
  if cgs44_verify "$CGS44_CACHE"; then
    CGS44_ACTIVE="$CGS44_CACHE"
    echo '[SOURCE] CGS : cache.'
    return 0
  fi
  stage="$(mktemp -d "$CACHE/.cgs-github.XXXXXX")" || return 1
  mkdir -p "$stage/artwork" || { rm -rf -- "$stage"; return 1; }
  for rel in "${CGS44_NAMES[@]}"; do
    if ! command -v curl >/dev/null 2>&1 ||
       ! curl -fLsS --connect-timeout 5 --max-time 60 "$CGS44_REMOTE/$rel" -o "$stage/$rel" 2>/dev/null ||
       [[ ! -s "$stage/$rel" ]]; then
      download_ok=0
      break
    fi
  done
  if (( download_ok )) && cgs44_verify "$stage"; then
    if ! cgs44_copy_tree "$stage" "$CGS44_CACHE"; then
      rm -rf -- "$stage"
      echo '[ERREUR] Impossible de mettre à jour le cache CGS.'
      return 1
    fi
    rm -rf -- "$stage"
    CGS44_ACTIVE="$CGS44_CACHE"
    echo '[CGS] GitHub OK ; cache CGS prêt.'
    return 0
  fi
  rm -rf -- "$stage"
  echo '[CGS] GitHub indisponible ou contenu invalide : utilisation du cache local.'
  if cgs44_verify "$CGS44_CACHE"; then
    CGS44_ACTIVE="$CGS44_CACHE"
    echo '[CGS] Secours local dans cache-gestionnaire fonctionnel.'
    return 0
  fi
  echo '[ERREUR] CGS : cache et GitHub indisponibles.'
  return 1
}
cgs44_script(){
  local script="$CGS44_ACTIVE/gestion-cgs-multisources-v2.1-TEST.sh"
  [[ -s "$script" ]] || return 1
  printf '%s\n' "$script"
}
cgs44_action(){
  local action="$1" script rc
  cgs44_prepare || return 1
  script="$(cgs44_script)" || return 1
  if [[ "$action" == 1 ]]; then
    confirm 'Installer / réparer CGS ?' || { echo '[INFO] Annulé.'; return 0; }
    printf '1\n4\n' | bash "$script"; rc=$?
    if (( rc != 0 )); then ui_print error '[ERREUR] Installation CGS échouée : illustrations non modifiées.'; return "$rc"; fi
    ui_print success '[OK] CGS : patch OK.'
    if confirm 'Installer les visuels CGS ?'; then
      python3 "$CGS44_ACTIVE/cgs-artwork.py" install "$CGS44_ACTIVE/artwork" || return 1
      reload_es_games
    fi
  elif [[ "$action" == 2 ]]; then
    ui_print warning '  La désinstallation remet le client Windows sauvegardé le 26 octobre.'
    ui_print warning '  Elle est réservée à la version exacte contrôlée par la V2.1.'
    confirm 'Désinstaller uniquement notre patch CGS ?' || { echo '[INFO] Annulé.'; return 0; }
    printf '2\noui\n4\n' | bash "$script"; rc=$?
    if (( rc != 0 )); then ui_print error '[ERREUR] Désinstallation CGS interrompue.'; return "$rc"; fi
    ui_print success '[OK] Patch CGS désinstallé.'
    ui_print info '  Les illustrations restent en place ; restauration séparée disponible.'
  elif [[ "$action" == 3 ]]; then
    # Le script CGS tiers produit un long diagnostic avec SHA et son menu.
    # Conserver la sortie complete dans un journal, mais rendre le resultat
    # lisible dans les terminaux etroits (SSH Android compris).
    local cgs_out cgs_log
    cgs_out="$(mktemp)" || return 1
    cgs_log="$LOGDIR/cgs-verification-$(date +%Y%m%d-%H%M%S).log"
    printf '3\n4\n' | bash "$script" > "$cgs_out" 2>&1
    rc=$?
    cp -- "$cgs_out" "$cgs_log" || true
    ui_print info '  CGS - VERIFICATION'
    if grep -qiE 'Multi-sources[[:space:]]*:[[:space:]]*pr.sent' "$cgs_out"; then
      ui_print success '  ✓ Multi-sources présent'
    elif grep -qiE 'Multi-sources[[:space:]]*:[[:space:]]*absent' "$cgs_out"; then
      ui_print warning '  ◆ Multi-sources absent'
    else
      ui_print warning '  ◆ État à consulter au journal'
    fi
    if grep -qi 'Réapplication' "$cgs_out"; then
      ui_print info '  Réapplication : informations au journal'
    fi
    if grep -qEi '\[ERREUR\]|ERREUR|ÉCHEC|ECHEC' "$cgs_out" || (( rc != 0 )); then
      ui_print error '  ✗ CGS : erreur détectée'
      ui_print warning "  Détails dans les journaux"
      rm -f -- "$cgs_out"
      return 1
    fi
    ui_print success '  ✓ Contrôle terminé'
    ui_print info "  Détails dans les journaux"
    rm -f -- "$cgs_out"
  elif [[ "$action" == 4 ]]; then
    confirm 'Restaurer les visuels CGS ?' || { echo '[INFO] Annulé.'; return 0; }
    python3 "$CGS44_ACTIVE/cgs-artwork.py" restore "$CGS44_ACTIVE/artwork" || return 1
    reload_es_games
  fi
}
cgs44_menu(){
  local choice
  while :; do
    refresh_screen
    ui_section 'CGS MULTI-SOURCES V2.1'
    ui_print info '  Réglages préservés'
    ui_item '1) Installer / Réparer CGS'
    ui_item '2) Désinstaller notre patch'
    ui_item '3) Vérifier l’état'
    ui_item '4) Restaurer les visuels'
    echo
    ui_item '0) Retour'
    ui_item 'Q) Quitter le gestionnaire'
    choice="$(read_key 'Votre choix : ')" || return 0
    case "$choice" in
      1|2|3|4) cgs44_action "$choice" || ui_print warning '[ATTENTION] Vérifier le résultat ci-dessus.'; pause ;;
      0) return 0 ;;
      *) ui_print warning 'Choix invalide.'; pause ;;
    esac
  done
}

# V2.0.35 TEST - Désinstallation sur sélection explicite (ntfy V7 ajouté).
# Archives historiques et configurations utilisateur non ciblées préservées.
# Deux phases : sauvegarde de TOUS les fichiers, puis arrêt éventuel du service et suppression.
# Aucun mode de simulation ajouté au gestionnaire.
uninstall_bundle(){
  local phase="$1" item="$2" archive="${3:-}"
  python3 - "$phase" "$item" "$archive" "$SAVES/Desinstallations" <<'PYUNINSTALL34'
import hashlib, json, os, shutil, sys, tempfile
from datetime import datetime
from pathlib import Path
from xml.etree import ElementTree as ET

phase, item, archive, base = sys.argv[1:]
base = Path(base)
ports = Path('/userdata/roms/ports')
files = {
    'volume': ['/userdata/system/volume-hotkey.py', '/userdata/system/services/volume_hotkey'],
    'shutdown': ['/userdata/system/configs/emulationstation/scripts/screensaver-start/shutdown-trigger.sh',
                 '/userdata/system/configs/emulationstation/scripts/screensaver-stop/shutdown-cancel.sh'],
    'recents': ['/userdata/roms/ports/nettoyer-jeux-recents.py',
                '/userdata/roms/ports/nettoyer-jeux-recents.sh',
                '/userdata/roms/ports/nettoyer-jeux-recents.sh.keys'],
    'f1': ['/userdata/roms/ports/F1.sh', '/userdata/roms/ports/F1.sh.keys'],
    'kodi': ['/userdata/roms/ports/kodi.sh', '/userdata/roms/ports/kodi.sh.keys'],
    'ntfy': ['/userdata/system/services/notifications_extinction_ntfy',
             '/userdata/system/notifications-extinction-ntfy/watch.py',
             '/userdata/system/notifications-extinction-ntfy/config'],
}
launchers = {'recents': 'nettoyer-jeux-recents.sh', 'f1': 'F1.sh', 'kodi': 'kodi.sh'}
artwork = {'recents': 'Nettoyage_Dernieres_Parties', 'f1': 'Explorateur_Fichiers', 'kodi': 'Kodi'}
if item not in files or phase not in ('stage', 'commit'):
    sys.exit('[SÉCURITÉ] Opération inconnue.')

def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024*1024), b''):
            h.update(chunk)
    return h.hexdigest()

def safe_regular(path):
    if path.is_symlink():
        raise ValueError('Lien symbolique refusé : '+str(path))
    if path.exists() and not path.is_file():
        raise ValueError('Fichier non ordinaire refusé : '+str(path))

def metadata():
    targets = [Path(p) for p in files[item]]
    for p in targets:
        safe_regular(p)
    present = [p for p in targets if p.is_file()]
    if not present:
        raise ValueError('Aucun élément actif du script détecté.')
    def has(p, *signs):
        return not p.exists() or all(s in p.read_text(encoding='utf-8', errors='replace') for s in signs)
    if item == 'volume':
        if not has(Path(files[item][1]), 'volume-hotkey.py') or not has(Path(files[item][0]), 'batocera-audio'):
            raise ValueError('Volume Hotkey non reconnu : aucun fichier supprimé.')
    elif item == 'shutdown':
        if not has(Path(files[item][0]), 'shutdown.screensaver', '--worker') or not has(Path(files[item][1]), 'shutdown.screensaver'):
            raise ValueError('Scripts de veille non reconnus : aucun fichier supprimé.')
    elif item == 'ntfy':
        # Autoriser une installation partielle tout en protégeant les fichiers personnels.
        if not has(Path(files[item][0]), 'notifications-extinction-ntfy/watch.py'):
            raise ValueError('Service ntfy non reconnu : aucun fichier supprimé.')
        if not has(Path(files[item][1]), 'Batocera ntfy: alerts and local authenticated timer restart.'):
            raise ValueError('Script ntfy non reconnu : aucun fichier supprimé.')
        config = Path(files[item][2])
        if config.is_file():
            lines = config.read_text(encoding='utf-8', errors='replace').splitlines()
            if not any(line.startswith('TOPIC=') for line in lines) or not any(line.startswith('DEVICE=') for line in lines):
                raise ValueError('Configuration ntfy non reconnue : aucun fichier supprimé.')
        # py_compile de l'installateur produit aussi un cache watch.cpython-*.pyc.
        # Sauvegarder et retirer uniquement celui-ci, jamais les autres caches.
        pycache = Path('/userdata/system/notifications-extinction-ntfy/__pycache__')
        if pycache.is_symlink() or (pycache.exists() and not pycache.is_dir()):
            raise ValueError('Cache ntfy inattendu : aucun fichier supprimé.')
        if pycache.is_dir():
            for cached in sorted(pycache.glob('watch.cpython-*.pyc')):
                safe_regular(cached)
                if cached.is_file():
                    present.append(cached)
    elif item == 'recents':
        if not has(Path(files[item][0]), 'pygame'):
            raise ValueError('Script Python Dernières Parties différent : aucun fichier supprimé.')
    elif item == 'f1':
        if not (not targets[0].exists() or any(s in targets[0].read_text(encoding='utf-8',errors='replace') for s in ('pcmanfm', 'filemanagerlauncher'))):
            raise ValueError('Lanceur F1 non reconnu : aucun fichier supprimé.')
    elif item == 'kodi':
        if not (not targets[0].exists() or any(s in targets[0].read_text(encoding='utf-8',errors='replace') for s in ('batocera-kodi', '--kodi'))):
            raise ValueError('Lanceur Kodi non reconnu : aucun fichier supprimé.')
    # Ne nettoyer que l'entrée XML correspondant au lanceur choisi.
    xml = ports/'gamelist.xml'
    entry_count = 0
    if item in launchers and xml.exists():
        safe_regular(xml)
        tree = ET.parse(xml)
        if tree.getroot().tag != 'gameList':
            raise ValueError('gamelist.xml inattendu : opération annulée.')
        entry_count = sum((n.findtext('path','').strip().removeprefix('./') == launchers[item]) for n in tree.getroot().findall('game'))
        if entry_count:
            present.append(xml)
    if item in artwork:
        media = ports/'images'/'gestionnaire-ports'
        for kind in ('cover', 'logo', 'fanart'):
            path = media/(artwork[item]+'-'+kind+'.png')
            safe_regular(path)
            if path.is_file():
                # Préserver les images encore référencées par une autre entrée du gamelist.
                if xml.exists():
                    root = ET.parse(xml).getroot()
                    shared = any(
                        game.findtext('path','').strip().removeprefix('./') != launchers[item]
                        and any((node.text or '').strip().endswith('/'+path.name)
                                for node in game if node.tag in ('image','marquee','fanart','thumbnail'))
                        for game in root.findall('game')
                    )
                    if shared:
                        print('[INFO] Illustration partagée conservée : '+path.name, file=sys.stderr)
                        continue
                present.append(path)
    return present

try:
    if phase == 'stage':
        to_copy = metadata()
        base.mkdir(parents=True, exist_ok=True)
        if base.is_symlink():
            raise ValueError('Dossier de sauvegarde symbolique refusé.')
        folder = Path(tempfile.mkdtemp(prefix=item+'-'+datetime.now().strftime('%Y%m%d-%H%M%S')+'-', dir=base))
        entries=[]
        try:
            for p in to_copy:
                dest = folder/'files'/p.relative_to('/')
                dest.parent.mkdir(parents=True,exist_ok=True)
                shutil.copy2(p,dest)
                if digest(dest) != digest(p):
                    raise OSError('Copie non conforme : '+str(p))
                entries.append({'path':str(p), 'sha256':digest(dest)})
            (folder/'manifest.json').write_text(json.dumps({'item':item,'files':entries},indent=2),encoding='utf-8')
        except Exception:
            shutil.rmtree(folder)
            raise
        print(folder)
    else:
        folder = Path(archive)
        # Le répertoire doit être un fils direct de notre dossier de sauvegarde.
        if folder.is_symlink() or folder.parent != base or not folder.is_dir():
            raise ValueError('Chemin de sauvegarde non autorisé.')
        manifest_file = folder/'manifest.json'
        if manifest_file.is_symlink() or not manifest_file.is_file():
            raise ValueError('Manifeste absent ou non ordinaire.')
        man = json.loads(manifest_file.read_text(encoding='utf-8'))
        if man.get('item') != item:
            raise ValueError('Manifeste incompatible.')
        expected = set(str(p) for p in metadata())
        recorded = set(e['path'] for e in man['files'])
        if expected != recorded:
            raise ValueError('Les fichiers ont changé depuis la sauvegarde.')
        for entry in man['files']:
            p=Path(entry['path'])
            copy=folder/'files'/p.relative_to('/')
            if not p.is_file() or p.is_symlink() or not copy.is_file() or copy.is_symlink() or digest(p)!=entry['sha256'] or digest(copy)!=entry['sha256']:
                raise ValueError('Fichier modifié ou sauvegarde invalide : '+str(p))
        # Mise à jour XML préparée avant de commencer toute suppression.
        xml=ports/'gamelist.xml'
        modified_xml=False
        if str(xml) in recorded:
            tree=ET.parse(xml)
            root=tree.getroot()
            for game in list(root.findall('game')):
                if game.findtext('path','').strip().removeprefix('./') == launchers[item]:
                    root.remove(game)
                    modified_xml=True
        for entry in man['files']:
            p=Path(entry['path'])
            if p == xml:
                continue
            p.unlink()
            print('[SUPPRIMÉ] '+str(p))
        if modified_xml:
            fd, temp = tempfile.mkstemp(prefix='.gamelist-blondin-',suffix='.xml',dir=ports)
            os.close(fd)
            try:
                tree.write(temp,encoding='utf-8',xml_declaration=True)
                ET.parse(temp)
                shutil.copymode(xml,temp)
                os.replace(temp,xml)
            finally:
                if os.path.exists(temp): os.unlink(temp)
            print('[OK] Entrée de Ports retirée du gamelist.xml.')
        print('[SAUVEGARDE] '+str(folder))
        print('[OK] Désinstallation des fichiers ciblés terminée.')
except (OSError, ValueError, KeyError, ET.ParseError, json.JSONDecodeError) as exc:
    print('[SÉCURITÉ] '+str(exc), file=sys.stderr)
    sys.exit(1)
PYUNINSTALL34
}

uninstall_present(){
  case "$1" in
    volume) [[ -f /userdata/system/volume-hotkey.py || -f /userdata/system/services/volume_hotkey ]] ;;
    shutdown) [[ -f /userdata/system/configs/emulationstation/scripts/screensaver-start/shutdown-trigger.sh || -f /userdata/system/configs/emulationstation/scripts/screensaver-stop/shutdown-cancel.sh ]] ;;
    recents) [[ -f /userdata/roms/ports/nettoyer-jeux-recents.py || -f /userdata/roms/ports/nettoyer-jeux-recents.sh ]] ;;
    f1) [[ -f /userdata/roms/ports/F1.sh ]] ;;
    kodi) [[ -f /userdata/roms/ports/kodi.sh ]] ;;
    ntfy) [[ -f /userdata/system/services/notifications_extinction_ntfy ||
             -f /userdata/system/notifications-extinction-ntfy/watch.py ||
             -f /userdata/system/notifications-extinction-ntfy/config ]] ;;
    *) return 1 ;;
  esac
}

uninstall_selected(){
  local item="$1" label='' backup='' workers=''
  case "$item" in
    volume) label='Volume Hotkey' ;;
    shutdown) label='Extinction automatique' ;;
    recents) label='Nettoyage Dernières Parties' ;;
    f1) label='Fichier dans Ports' ;;
    kodi) label='Kodi dans Ports' ;;
    ntfy) label='Notifications ntfy V7' ;;
    *) echo '[SÉCURITÉ] Désinstallation non autorisée.'; return 1 ;;
  esac
  uninstall_present "$item" || { echo '[INFO] Script absent.'; return 0; }
  echo "===== DÉSINSTALLER : $label ====="
  echo '[INFO] Sauvegarde conservée, ainsi que les configurations personnelles.'
  [[ "$item" != shutdown ]] || echo '[INFO] Notifications ntfy V7 conservées (désinstallation séparée).'
  [[ "$item" != ntfy ]] || echo '[INFO] Minuteur et scripts d extinction conservés.'
  confirm "Désinstaller $label ?" || { echo '[INFO] Annulé.'; return 0; }
  confirm 'Confirmer définitivement ?' || { echo '[INFO] Annulé.'; return 0; }
  backup="$(uninstall_bundle stage "$item")" || { echo '[SÉCURITÉ] Sauvegarde impossible : annulation.'; return 1; }
  echo "[SAUVEGARDE] $backup"
  if [[ "$item" == volume ]]; then
    if [[ -f /userdata/system/services/volume_hotkey ]]; then
      if ! command -v batocera-services >/dev/null 2>&1 ||
         ! batocera-services disable volume_hotkey; then
        echo '[SÉCURITÉ] Désactivation du service impossible ; fichiers conservés.'
        return 1
      fi
      if ! batocera-services stop volume_hotkey; then
        echo '[SÉCURITÉ] Arrêt du service impossible ; fichiers conservés.'
        return 1
      fi
    fi
    if command -v pgrep >/dev/null 2>&1 && pgrep -f '[/]userdata/system/volume-hotkey.py' >/dev/null 2>&1; then
      echo '[SÉCURITÉ] Service encore actif ; fichiers conservés.'
      return 1
    fi
  elif [[ "$item" == ntfy ]]; then
    # Désactiver AVANT de retirer le service ; l'arrêter AVANT de retirer watch.py.
    # Ne toucher ni aux scripts de veille, ni au sujet ntfy distant/au téléphone.
    if [[ -f /userdata/system/services/notifications_extinction_ntfy ]]; then
      if ! command -v batocera-services >/dev/null 2>&1 ||
         ! batocera-services disable notifications_extinction_ntfy; then
        echo '[SÉCURITÉ] Désactivation ntfy impossible ; fichiers conservés.'
        return 1
      fi
      if ! batocera-services stop notifications_extinction_ntfy; then
        echo '[SÉCURITÉ] Arrêt du service ntfy impossible ; fichiers conservés.'
        return 1
      fi
    fi
    if command -v pgrep >/dev/null 2>&1 &&
       pgrep -f '[/]userdata/system/notifications-extinction-ntfy/watch.py' >/dev/null 2>&1; then
      echo '[SÉCURITÉ] Processus ntfy encore actif ; fichiers conservés.'
      return 1
    fi
  elif [[ "$item" == recents ]]; then
    if command -v pgrep >/dev/null 2>&1 && pgrep -f '[/]userdata/roms/ports/nettoyer-jeux-recents.py' >/dev/null 2>&1; then
      echo '[SÉCURITÉ] Fermer Nettoyage Dernières Parties avant la désinstallation.'
      return 1
    fi
  elif [[ "$item" == shutdown ]]; then
    workers="$(shutdown_workers list)" || { echo '[SÉCURITÉ] Contrôle du minuteur impossible.'; return 1; }
    if [[ -n "$workers" ]]; then
      shutdown_workers stop || { echo '[SÉCURITÉ] Arrêt minuteur impossible ; fichiers conservés.'; return 1; }
      sleep 1
      workers="$(shutdown_workers list)" || return 1
      [[ -z "$workers" ]] || { echo '[SÉCURITÉ] Minuteur encore actif : fichiers conservés.'; return 1; }
    fi
    # L'état temporaire potentiellement résiduel est conservé en cas d'incertitude.
  fi
  if uninstall_bundle commit "$item" "$backup"; then
    if [[ "$item" == volume ]]; then
      # Uniquement notre hook identifie. Ne toucher a aucun autre script.
      local hook='/userdata/system/scripts/volume-hotkey-teknoparrot.sh'
      if [[ -f "$hook" && ! -L "$hook" ]] &&
         grep -Fq 'BLONDIN_VOLUME_TEKNOPARROT_V1' "$hook"; then
        rm -f -- "$hook" || echo '[ATTENTION] Hook TeknoParrot non supprime.'
      fi
      rm -f -- /run/blondin-volume-teknoparrot.active
    fi
    if [[ "$item" == shutdown ]]; then
      # Marqueur temporaire spécifique à l'extinction (pas de données utilisateur).
      if [[ -f /tmp/batocera-screensaver-active && ! -L /tmp/batocera-screensaver-active ]]; then
        rm -f -- /tmp/batocera-screensaver-active || true
      fi
    fi
    case "$item" in recents|f1|kodi) reload_es_games ;; esac
    if [[ "$item" == ntfy ]]; then
      # Ne retirer le dossier que s'il est vide ; conserver les anciennes
      # configurations .bak et les fichiers inattendus sans y toucher.
      rmdir /userdata/system/notifications-extinction-ntfy/__pycache__ 2>/dev/null || true
      rmdir /userdata/system/notifications-extinction-ntfy 2>/dev/null || true
      echo '[OK] Service ntfy désinstallé ; sauvegardes conservées.'
    fi
    return 0
  fi
  echo '[ATTENTION] Nettoyage incomplet. Fichiers sauvegardés :'
  echo "$backup"
  return 1
}

selected_script_menu(){
  local item="$1" choice='' label=''
  case "$item" in
    volume) label='VOLUME HOTKEY' ;;
    shutdown) label='EXTINCTION AUTOMATIQUE' ;;
    recents) label='NETTOYAGE DERNIÈRES PARTIES' ;;
    f1) label='FICHIER DANS PORTS' ;;
    kodi) label='KODI DANS PORTS' ;;
    *) return 1 ;;
  esac
  while :; do
    refresh_screen
    ui_section "$label"
    if uninstall_present "$item"; then
      ui_print success '  État : INSTALLÉ'
    else
      ui_print warning '  État : ABSENT'
    fi
    ui_item '1) Installer / Réinstaller'
    if uninstall_present "$item"; then
      ui_item '2) Désinstaller'
    fi
    echo
    ui_item '0) Retour'
    ui_item 'Q) Quitter le gestionnaire'
    choice="$(read_key 'Votre choix : ')" || return 0
    case "$choice" in
      1) case "$item" in
           volume) install_one 0 ;;
           shutdown) install_one 4 ;;
           recents) install_one 5 ;;
           f1) install_simple_launcher 7 ;;
           kodi) install_simple_launcher 8 ;;
         esac
         pause ;;
      2) if uninstall_present "$item"; then
           uninstall_selected "$item"
         else
           ui_print warning '[INFO] Script déjà absent.'
         fi
         pause ;;
      0) return 0 ;;
      *) ui_print warning 'Choix invalide.'; pause ;;
    esac
  done
}

# V2.0.51 TEST : etats des installations, controles strictement en lecture seule.
# Codes : X=confirmé, ?=absent sur chemins connus, !=identité/install non prouvées.
# Ne jamais confondre un cache/Installscripts et une installation active.
installation_status(){
  local key="$1" a='' b='' c=''
  case "$key" in
    i0)
      a='/userdata/system/volume-hotkey.py'
      b='/userdata/system/services/volume_hotkey'
      if [[ -s "$a" && -f "$b" && ! -L "$a" && ! -L "$b" ]]; then echo X
      elif [[ ! -e "$a" && ! -L "$a" && ! -e "$b" && ! -L "$b" ]]; then echo '?'
      else echo '!'; fi ;;
    i4)
      a='/userdata/system/configs/emulationstation/scripts/screensaver-start/shutdown-trigger.sh'
      b='/userdata/system/configs/emulationstation/scripts/screensaver-stop/shutdown-cancel.sh'
      if [[ -s "$a" && -x "$a" && -s "$b" && -x "$b" && ! -L "$a" && ! -L "$b" ]]; then echo X
      elif [[ ! -e "$a" && ! -L "$a" && ! -e "$b" && ! -L "$b" ]]; then echo '?'
      else echo '!'; fi ;;
    i5)
      a='/userdata/roms/ports/nettoyer-jeux-recents.py'
      b='/userdata/roms/ports/nettoyer-jeux-recents.sh'
      if [[ -s "$a" && -s "$b" && ! -L "$a" && ! -L "$b" ]]; then
        echo X
      elif [[ -e "$a" || -L "$a" || -e "$b" || -L "$b" ]]; then
        echo '!'
      else
        # Certaines éditions anciennes ont un nom de lanceur différent.
        # Ne pas les certifier comme installées sans la paire connue.
        if compgen -G '/userdata/roms/ports/*nettoy*recent*' >/dev/null ||
           compgen -G '/userdata/roms/ports/*derniere*partie*' >/dev/null ||
           compgen -G '/userdata/roms/ports/*Nettoy*Recent*' >/dev/null; then
          echo '!'
        else
          echo '?'
        fi
      fi ;;
    f1|kodi)
      if [[ "$key" == f1 ]]; then a='/userdata/roms/ports/F1.sh'; else a='/userdata/roms/ports/kodi.sh'; fi
      if [[ -s "$a" && ! -L "$a" ]]; then echo X
      elif [[ ! -e "$a" && ! -L "$a" ]]; then echo '?'
      else echo '!'; fi ;;
    rgsx)
      # RGSX : le lanceur principal est normalement DANS le répertoire RGSX.
      # Un lanceur directement dans Ports est aussi possible selon l'installation.
      a='/userdata/roms/ports/RGSX'
      b='/userdata/roms/ports/RGSX.sh'
      c='/userdata/roms/ports/RGSX/RGSX.sh'
      if [[ -d "$a" && ! -L "$a" ]] &&
         { [[ -s "$b" && ! -L "$b" ]] || [[ -s "$c" && ! -L "$c" ]]; }; then
        echo X
      elif [[ ! -e "$a" && ! -L "$a" && ! -e "$b" && ! -L "$b" ]]; then
        echo '?'
      else
        echo '!'
      fi ;;
    rambo)
      # Tenir compte de l'ancien hook gameStart fonctionnel de Rambo,
      # sans le déplacer ni installer un doublon.
      local legacy_rambo='/userdata/system/configs/emulationstation/scripts/gameStart/nettoyage-rambo.sh'
      if [[ -f "$rambo_script_path" && ! -L "$rambo_script_path" ]] &&
         rambo_validate "$rambo_script_path" && [[ -x "$rambo_script_path" ]]; then echo X
      elif [[ -f "$legacy_rambo" && ! -L "$legacy_rambo" && -x "$legacy_rambo" ]] &&
           bash -n "$legacy_rambo"; then echo X
      elif [[ ! -e "$rambo_script_path" && ! -L "$rambo_script_path" &&
              ! -e "$legacy_rambo" && ! -L "$legacy_rambo" ]]; then echo '?'
      else echo '!'; fi ;;
    cgs-app)
      # Emplacements connus du client CGS, nouvelle architecture ou ancienne.
      a='/userdata/system/cgs/app/clients/windows/__main__.py'
      b='/userdata/roms/ports/CGS/__main__.py'
      if [[ -s "$a" && ! -L "$a" ]] || [[ -s "$b" && ! -L "$b" ]]; then
        echo X
      elif [[ -e /userdata/system/cgs || -L /userdata/system/cgs ||
              -e /userdata/roms/ports/CGS || -L /userdata/roms/ports/CGS ||
              -e "$a" || -L "$a" || -e "$b" || -L "$b" ]]; then
        echo '!'
      else
        echo '?'
      fi ;;
    cgs44)
      # Signature fonctionnelle vérifiée par le patch officiel lui-même :
      # MARKER et ROM_SOURCES. L'absence du script de maintenance ne retire
      # pas le patch déjà appliqué au client actif.
      a='/userdata/system/cgs/app/clients/windows/__main__.py'
      b='/userdata/roms/ports/CGS/__main__.py'
      local candidate='' marker=0
      for candidate in "$a" "$b"; do
        if [[ -s "$candidate" && ! -L "$candidate" ]] &&
           grep -Fq '# DOSSIERS DE JEUX WINDOWS GERES PAR CGS' "$candidate" &&
           grep -Fq 'ROM_SOURCES' "$candidate"; then
          marker=1
          break
        fi
      done
      if (( marker == 1 )); then
        echo X
      elif [[ -e "$a" || -L "$a" || -e "$b" || -L "$b" ||
              -e /userdata/system/cgs-multisource-patch.py ||
              -e /userdata/system/cgs || -L /userdata/system/cgs ||
              -e /userdata/roms/ports/CGS || -L /userdata/roms/ports/CGS ]]; then
        # Une base CGS ou un script de patch peut être présent sans que
        # la version active porte la signature : état à vérifier.
        echo '!'
      else
        echo '?'
      fi ;;
    linuxloader)
      # Le pack DreamerCG inclut le loader, le préfixe Windows Arcade
      # et un runner Proton. Vérifier plusieurs composants distincts.
      a='/userdata/system/dcg/emulators/linuxloader'
      b='/userdata/system/dcg/emulators/windows-arcade-loader/wine-prefix/full.tar.gz'
      c='/userdata/system/wine/custom/GE-Proton11-10-x86_64/bin/wine'
      if [[ -d "$a" && ! -L "$a" && -s "$b" && -x "$c" && ! -L "$b" ]]; then echo X
      elif [[ ! -e "$a" && ! -L "$a" && ! -e "$b" && ! -L "$b" && ! -e "$c" && ! -L "$c" ]]; then echo '?'
      else echo '!'; fi ;;
    dreamercg)
      a='/userdata/DreamerCGToolBox/BSA.sh'
      b='/userdata/roms/ports/DreamerCGToolBox.sh'
      if [[ -s "$a" && -s "$b" && ! -L "$a" && ! -L "$b" ]]; then echo X
      elif [[ ! -e "$a" && ! -L "$a" && ! -e "$b" && ! -L "$b" ]]; then echo '?'
      else echo '!'; fi ;;
    thomsonito)
      a='/userdata/system/ultimate-wine-toolbox/toolbox/ultimate-wine-toolbox.sh'
      b='/userdata/roms/ports/Ultimate Wine Toolbox.sh'
      if [[ -s "$a" && -s "$b" && ! -L "$a" && ! -L "$b" ]]; then echo X
      elif [[ ! -e "$a" && ! -L "$a" && ! -e "$b" && ! -L "$b" ]]; then echo '?'
      else echo '!'; fi ;;
    bua|foclabroc)
      # L'installateur tiers peut ouvrir un menu plutôt qu'installer une
      # application persistante. Sans signature fiable, rester prudent.
      echo '!' ;;
    *) echo '!' ;;
  esac
}

# V2.0.52 TEST : symboles courts avant les noms (✓ / ✗ / ◆).
# Les trois états sont calculés en lecture seule par installation_status.
# Sur un terminal SSH étroit, raccourcir la fin du libellé plutôt que
# d'afficher le symbole seul sur la ligne suivante.
ui_installation_cols(){
  local dim='' cols=''
  if [[ -t 0 && -r /dev/tty ]]; then
    dim="$(stty size 2>/dev/null < /dev/tty)" || dim=''
    cols="${dim##* }"
  fi
  if [[ ! "$cols" =~ ^[0-9]+$ ]] || (( cols < 10 )); then
    cols="${COLUMNS:-80}"
  fi
  if [[ ! "$cols" =~ ^[0-9]+$ ]] || (( cols < 10 )); then cols=80; fi
  printf '%s' "$cols"
}
ui_installation_item(){
  local index="$1" label="$2" status="$3" width="$4"
  local cols available glyph='' color='' display='' marker=''
  cols="$(ui_installation_cols)"
  case "$status" in
    X)   glyph='✓'; color=$'\033[1;32m' ;;
    '?') glyph='✗'; color=$'\033[1;31m' ;;
    '!') glyph='◆'; color=$'\033[1;38;5;208m' ;;
    *)   glyph='◆'; color=$'\033[1;38;5;208m' ;;
  esac
  marker="$(ui_menu_index "$index")"
  # En mode Ports, les éléments avec état doivent être navigables comme
  # les éléments ui_item. Ils ne doivent pas être imprimés en double.
  if [[ "${BLONDIN_PORTS_PAD:-0}" == 1 ]]; then
    UI_MENU_NUMBERS+=("$index")
    UI_MENU_LABELS+=("$glyph $label")
    return 0
  fi
  # Préserver un espace avant le pictogramme et raccourcir seulement le nom.
  available=$((cols - (2 + ${#marker} + 1 + 1 + 1)))
  display="$label"
  if (( available < 4 )); then
    display='...'
  elif (( ${#display} > available )); then
    display="${display:0:available-3}..."
  fi
  if (( UI_COLOR )); then
    printf '  \033[1;33m%s\033[0m %s%s\033[0m \033[0;37m%s\033[0m\n' \
      "$marker" "$color" "$glyph" "$display"
  else
    printf '  %s %s %s\n' "$marker" "$glyph" "$display"
  fi
}
ui_installation_legend(){
  if (( UI_COLOR )); then
    printf '  \033[1;32m✓\033[0m installé  \033[1;31m✗\033[0m absent\n'
    printf '  \033[1;38;5;208m◆\033[0m à vérifier\n'
  else
    printf '  ✓ installé  ✗ absent\n  ◆ à vérifier\n'
  fi
}

# Le menu parent "Volume" est une rubrique de navigation : aucun état
# d'installation n'est associé à cette rubrique.
installation_volume_menu(){
  local choice='' service_status='?'
  while :; do
    refresh_screen
    ui_section 'INSTALLATION - SYSTÈME - VOLUME'
    service_status='?'
    if [[ -f /userdata/system/services/volume_demarrage && ! -L /userdata/system/services/volume_demarrage ]]; then
      service_status='X'
    fi
    ui_installation_item 1 'Volume Hotkey' "$(installation_status i0)" 24
    ui_installation_item 2 'Volume auto-démarrage' "$service_status" 24
    echo
    if [[ "$service_status" == X ]]; then
      ui_print info "  Volume programmé : $(startvol_current) %"
    fi
    ui_installation_legend
    echo
    ui_item '0) Retour'
    ui_item 'Q) Quitter le gestionnaire'
    choice="$(read_key 'Votre choix : ')" || return 0
    [[ "$choice" == __ESC__ ]] && continue
    case "$choice" in
      1) selected_script_menu volume ;;
      2) startvol_menu ;;
      0) return 0 ;;
      *) ui_print warning '  Choix invalide.'; sleep 1 ;;
    esac
  done
}

installation_category_menu(){
  local target="$1" category="$2" choice='' action='' n
  local -a labels=() actions=()
  # Le menu d'installation n'expose que Batocera 44.
  [[ "$target" == 44 ]] || {
    ui_print error '[SÉCURITÉ] Batocera 44 requis.'
    return 1
  }
  if [[ "$category" == systeme ]]; then
    labels=('Volume' 'Extinction automatique' 'Linux Loader')
    actions=('volume-menu' 'i4' 'linuxloader')
  else
    labels=('Community Game Scraper' 'RGSX' 'BUA'
            'Nettoyage Dernières Parties' 'Fichier dans Ports' 'Kodi dans Ports')
    actions=('cgs-app' 'rgsx' 'bua' 'i5' 'f1' 'kodi')
  fi
  while :; do
    refresh_screen
    if [[ "$category" == systeme ]]; then
      ui_section 'INSTALLATION - SYSTÈME'
    else
      ui_section 'INSTALLATION - APPLICATIONS'
    fi
    local width=0
    for ((n=0; n<${#labels[@]}; n++)); do
      if (( ${#labels[$n]} > width )); then width=${#labels[$n]}; fi
    done
    for ((n=0; n<${#labels[@]}; n++)); do
      if [[ "${actions[$n]}" == volume-menu ]]; then
        ui_item "$((n+1))) Volume"
      else
        ui_installation_item "$((n+1))" "${labels[$n]}" "$(installation_status "${actions[$n]}")" "$width"
      fi
    done
    echo
    ui_installation_legend
    echo
    ui_item '0) Retour'
    ui_item 'Q) Quitter le gestionnaire'
    choice="$(read_key 'Votre choix : ')" || return 0
    [[ "$choice" == __ESC__ ]] && continue
    if [[ "$choice" == 0 ]]; then return 0; fi
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( 10#$choice < 1 || 10#$choice > ${#actions[@]} )); then
      echo 'Choix invalide.'
      continue
    fi
    action="${actions[$((10#$choice-1))]}"
    case "$action" in
      i0) selected_script_menu volume ;;
      volume-menu) installation_volume_menu; continue ;;
      i4) selected_script_menu shutdown ;;
      i5) selected_script_menu recents ;;
      i[0-6]) install_one "${action#i}" || echo '[ATTENTION] Operation non terminee correctement.' ;;
      fix) install_shutdown_fix || echo '[ATTENTION] Correction non installée.' ;;
      f1) selected_script_menu f1 ;;
      cgs44) cgs44_menu || echo '[ATTENTION] Opération CGS non terminée.' ;;
      linuxloader|cgs-app|rgsx|bua) thirdparty_install "$action" ;;
      kodi) selected_script_menu kodi ;;
    esac
    pause
  done
}

# Toolbox tierces : téléchargement au choix puis confirmation explicite.
# Jamais de "curl | bash" : le fichier est d'abord contrôlé localement.
# Le téléchargement est temporaire ; le gestionnaire ne prétend pas
# vérifier le contenu métier des scripts fournis par des tiers.
thirdparty_install(){
  local key="$1" label='' url='' tmp='' code=0 bytes='' fingerprint='' group='TOOLBOX' runner='bash'
  case "$key" in
    dreamercg)
      label='DreamerCG'
      url='https://dreamercg.s.gy/switch' ;;
    foclabroc)
      label='Foclabroc'
      url='https://foclabroc.short.gy/toolbox' ;;
    thomsonito)
      label='Thomsonito'
      url='https://raw.githubusercontent.com/Thomson67/ultimate-wine-toolbox/main/install.sh' ;;
    linuxloader)
      label='Linux Loader'
      group='SYSTÈME'
      url='https://raw.githubusercontent.com/DreamerCG/linuxloader/main/install.sh' ;;
    cgs-app)
      label='Community Game Scraper'
      group='APPLICATIONS'
      url='https://games.evolink.be/api/teknoparrot/client/unified/install.sh' ;;
    rgsx)
      label='RGSX'
      group='APPLICATIONS'
      url='https://bit.ly/rgsx-install'
      runner='sh' ;;
    bua)
      label='BUA'
      group='APPLICATIONS'
      url='https://install.batoaddons.app' ;;
    *) ui_print error '  [ERREUR] Installateur inconnu.'; return 1 ;;
  esac
  refresh_screen
  ui_section "$group - $label"
  ui_print menu "  Projet : $label"
  ui_print warning '  Script tiers (droits root).'
  ui_print warning '  Peut modifier Batocera.'
  echo
  if ! command -v curl >/dev/null 2>&1; then
    ui_print error '  [ERREUR] curl introuvable.'
    return 1
  fi
  if ! command -v "$runner" >/dev/null 2>&1; then
    ui_print error "  [ERREUR] Interpréteur $runner introuvable."
    return 1
  fi
  if ! mkdir -p -- "$CACHE"; then
    ui_print error '  [ERREUR] Cache inaccessible.'
    return 1
  fi
  tmp="$(mktemp "$CACHE/.install-${key}.XXXXXX")" || return 1
  ui_print info '  Telechargement HTTPS...'
  # Les liens courts peuvent rediriger : seules des destinations HTTPS
  # sont autorisees, et les codes HTTP en erreur sont refusés.
  if curl -fsSL --proto '=https' --proto-redir '=https' \
    --connect-timeout 15 --max-time 120 --max-redirs 8 \
    --max-filesize 4194304 "$url" -o "$tmp"; then
    code=0
  else
    code=$?
  fi
  # La commande officielle DreamerCG utilise -k. Ne contourner le
  # certificat qu'apres un echec TLS precis et une seconde approbation.
  if (( code == 60 || code == 51 )) && [[ "$key" == dreamercg ]]; then
    ui_print warning '  [ATTENTION] Certificat HTTPS non verifie par curl.'
    if confirm '  Utiliser -k (certificat non verifie) pour DreamerCG ?'; then
      if curl -k -fsSL --proto '=https' --proto-redir '=https' \
        --connect-timeout 15 --max-time 120 --max-redirs 8 \
        --max-filesize 4194304 "$url" -o "$tmp"; then
        code=0
      else
        code=$?
      fi
    fi
  fi
  if (( code != 0 )); then
    ui_print error "  [ERREUR] Telechargement echoue (curl : $code)."
    rm -f -- "$tmp"
    return 1
  fi
  bytes="$(wc -c < "$tmp")"
  if (( bytes < 16 || bytes > 4194304 )); then
    ui_print error '  [ERREUR] Fichier vide, trop court ou trop volumineux.'
    rm -f -- "$tmp"
    return 1
  fi
  if LC_ALL=C grep -aqiE '^[[:space:]]*<(html|!doctype[[:space:]]+html)' "$tmp"; then
    ui_print error '  [ERREUR] Une page HTML a ete recue, pas un installateur.'
    rm -f -- "$tmp"
    return 1
  fi
  if ! "$runner" -n "$tmp"; then
    ui_print error "  [ERREUR] Script telecharge non valide pour $runner."
    rm -f -- "$tmp"
    return 1
  fi
  ui_print success "  [OK] Script valide ($runner -n)."
  ui_print menu "  Taille : $bytes octets"
  if command -v sha256sum >/dev/null 2>&1; then
    fingerprint="$(sha256sum "$tmp")"
    fingerprint="${fingerprint%% *}"
    ui_print info "  SHA-256 : ${fingerprint:0:16}..."
  fi
  ui_print warning '  Attention : script non audite.'
  echo
  local prompt_label="$label"
  [[ "$key" == cgs-app ]] && prompt_label='CGS'
  if ! confirm "  Lancer $prompt_label ?"; then
    ui_print warning '  [INFO] Installation annulee.'
    rm -f -- "$tmp"
    return 0
  fi
  ui_print info "  Lancement $label..."
  echo
  # Conserver stdin et la session terminal : l'outil tiers peut etre
  # interactif (dialog/read) et doit garder les touches utilisateur.
  if "$runner" "$tmp"; then
    ui_print success "  [OK] $label termine (code 0)."
    code=0
  else
    code=$?
    ui_print error "  [ERREUR] $label : code $code."
  fi
  rm -f -- "$tmp"
  return "$code"
}

# Compatibilité de la fonction précédente et du menu Toolbox.
toolbox_install(){ thirdparty_install "$1"; }

toolbox_menu(){
  local choice=''
  while :; do
    refresh_screen
    ui_section 'INSTALLATION - TOOLBOX'
    ui_installation_item 1 'DreamerCG' "$(installation_status dreamercg)" 10
    ui_installation_item 2 'Foclabroc' "$(installation_status foclabroc)" 10
    ui_installation_item 3 'Thomsonito' "$(installation_status thomsonito)" 10
    echo
    ui_installation_legend
    echo
    ui_item '0) Retour'
    ui_item 'Q) Quitter le gestionnaire'
    choice="$(read_key 'Votre choix : ')" || return 0
    [[ "$choice" == __ESC__ ]] && continue
    case "$choice" in
      1) toolbox_install dreamercg; pause ;;
      2) toolbox_install foclabroc; pause ;;
      3) toolbox_install thomsonito; pause ;;
      0) return 0 ;;
      *) ui_print warning '  Choix invalide.'; sleep 1 ;;
    esac
  done
}

# Patchs existants déplacés dans Installation, sans modifier leur comportement.
installation_patch_menu(){
  local choice=''
  while :; do
    refresh_screen
    ui_section 'INSTALLATION - PATCH'
    ui_item '1) Patchs jeux'
    ui_installation_item 2 'CGS Multi-sources V2.1' "$(installation_status cgs44)" 23
    ui_item '3) Correction souris / double écran'
    echo
    ui_installation_legend
    echo
    ui_item '0) Retour'
    ui_item 'Q) Quitter le gestionnaire'
    choice="$(read_key 'Votre choix : ')" || return 0
    [[ "$choice" == __ESC__ ]] && continue
    case "$choice" in
      1) patchs_jeux_menu ;;
      2) cgs44_menu ;;
      3) souris_menu ;;
      0) return 0 ;;
      *) ui_print warning '  Choix invalide.'; sleep 1 ;;
    esac
  done
}

installation_version_menu(){
  local target="$1" choice=''
  while :; do
    refresh_screen
    ui_section 'INSTALLATION'
    ui_item '1) Système'
    ui_item '2) Applications'
    ui_item '3) Toolbox'
    ui_item '4) Patch'
    echo
    echo
    ui_item '0) Retour'
    ui_item 'Q) Quitter le gestionnaire'
    choice="$(read_key 'Votre choix : ')" || return 0
    [[ "$choice" == __ESC__ ]] && continue
    case "$choice" in
      1) installation_category_menu "$target" systeme ;;
      2) installation_category_menu "$target" applications ;;
      3) toolbox_menu ;;
      4) installation_patch_menu ;;
      0) return 0 ;;
      *) echo 'Choix invalide.' ;;
    esac
  done
}

installation_menu(){
  # Seule Batocera 44 est proposée : les contrôles de compatibilité restent
  # actifs dans chaque installateur. Pas d'étape de choix de version.
  local detected=''
  detected="$(detect_batocera_version)" || detected=''
  case "$detected" in
    44|44.*) installation_version_menu 44 ;;
    *)
      refresh_screen
      ui_section 'INSTALLATION'
      ui_print error "  [SÉCURITÉ] Batocera 44 attendu (détecté : ${detected:-inconnu})."
      ui_print warning '  Aucune installation proposée sur cette version.'
      pause
      ;;
  esac
}


# Firefox Mozilla natif et applications Flatpak.
FF_ROOT='/userdata/system/firefox-mozilla'
FF_REMOTE=''
UPDATES_CHECKED=0
firefox_installed_version(){
  local ini="$FF_ROOT/application.ini" ver=''
  if [[ -f "$ini" ]]; then
    ver="$(sed -n '/^\[App\]/,/^\[/{s/^Version=//p;}' "$ini" | head -n 1)"
  fi
  if [[ -z "$ver" && -x "$FF_ROOT/firefox" ]]; then
    ver="$("$FF_ROOT/firefox" --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)+' | head -n 1)"
  fi
  printf '%s' "${ver:-inconnue}"
}
# Comparaison numérique de versions, sans dépendance pip.
version_status(){
  python3 - "$1" "$2" <<'PYVERS'
import sys,re
local,remote=sys.argv[1:]
try:
 a=tuple(map(int,re.findall(r'\d+',local)))
 b=tuple(map(int,re.findall(r'\d+',remote)))
 if not a or not b: raise ValueError()
 print('MISE À JOUR DISPONIBLE' if a<b else 'À JOUR')
except ValueError: print('INDETERMINE')
PYVERS
}

# Vérifie les mises à jour Flatpak sans installer ni modifier les applications.
# flatpak remote-ls --updates utilise les commits/branches du dépôt,
# plus fiables qu'une simple comparaison des numéros de version.
check_flatpak_update_status(){
  local app="$1" id scope pending
  id="$(flatpak_app_id "$app")" || return 1
  scope="$(flatpak_app_scope "$id")"
  echo
  echo "$(flatpak_app_name "$app" | tr '[:lower:]' '[:upper:]')"
  if [[ "$scope" == absent ]]; then
    echo '  Installation : NON INSTALLE'
    return 0
  fi
  echo "  Version      : $(flatpak_app_version "$id")"
  if ! command -v flatpak >/dev/null 2>&1; then
    echo '  Mise à jour  : vérification impossible (Flatpak absent)'
    return 1
  fi
  # Rafraîchit les métadonnées du dépôt, sans appliquer de mise à jour.
  if ! flatpak update "--$scope" --appstream -y >/dev/null 2>&1; then
    echo '  Mise à jour  : vérification impossible (metadonnees)'
    return 1
  fi
  if ! pending="$(flatpak remote-ls "--$scope" --updates --columns=application 2>/dev/null)"; then
    echo '  Mise à jour  : vérification impossible (depot)'
    return 1
  fi
  if printf '%s\n' "$pending" | grep -Fxq "$id"; then
    echo '  Mise à jour  : MISE À JOUR DISPONIBLE'
  else
    echo '  Mise à jour  : À JOUR'
  fi
}

check_browser_updates(){
  local raw localver
  echo '===== MISE À JOUR LOGICIELS ====='
  echo '[INFO] Consultation de la version officielle Mozilla...'
  command -v curl >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1 || {
    echo '[ERREUR] curl ou python3 manquant.'; return 1;
  }
  FF_REMOTE=''; UPDATES_CHECKED=1
  raw="$(curl -fLsS --connect-timeout 8 --max-time 18 'https://product-details.mozilla.org/1.0/firefox_versions.json' 2>/dev/null)" || raw=''
  if [[ -n "$raw" ]]; then
    FF_REMOTE="$(printf '%s' "$raw" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("LATEST_FIREFOX_VERSION",""))' 2>/dev/null)" || FF_REMOTE=''
  fi
  localver='non installe'
  [[ -x "$FF_ROOT/firefox" ]] && localver="$(firefox_installed_version)"
  browser_state 'FIREFOX' "$localver" "$FF_REMOTE"
  echo
  echo '[INFO] Vérification des mises à jour Flatpak (sans installation)...'
  check_flatpak_update_status filezilla || true
  check_flatpak_update_status peazip || true
  [[ -n "$FF_REMOTE" ]]
}

browser_state(){
  local name="$1" localver="$2" remote="$3"
  echo
  echo "$name"
  if [[ "$localver" == 'non installe' ]]; then
    echo '  Installation : NON INSTALLE'
  else
    echo '  Installation : INSTALLE'
    echo "  Version      : $localver"
  fi
  if (( UPDATES_CHECKED )); then
    if [[ -z "$remote" ]]; then
      echo '  Mise à jour  : vérification impossible'
    elif [[ "$localver" == 'non installe' ]]; then
      echo "  Version disponible : $remote"
    else
      echo "  Mise à jour  : $(version_status "$localver" "$remote") (derniere : $remote)"
    fi
  else
    echo '  Mise à jour  : non verifiee (option 3)'
  fi
}

uninstall_firefox_mozilla(){
  local launcher='/userdata/roms/ports/Firefox.sh' path
  local keys="${launcher}.keys"
  echo '[INFO] Désinstallation Firefox Mozilla natif uniquement (Firefox Flatpak preserve).'
  echo '[INFO] Le profil sera sauvegardé avant la désinstallation.'
  confirm 'Confirmer la désinstallation de Firefox ?' || { echo '[INFO] Annulé.'; return 0; }
  if [[ -d "$(profile_source firefox)" ]]; then
    profile_backup firefox || { echo '[SÉCURITÉ] Désinstallation annulée : sauvegarde impossible.'; return 1; }
  fi
  # Sauvegarde du .keys avant toute suppression ; ne pas suivre les liens symboliques.
  if [[ -L "$keys" ]] || { [[ -e "$keys" ]] && [[ ! -f "$keys" ]]; }; then
    echo '[SÉCURITÉ] Fichier Firefox.sh.keys non ordinaire : désinstallation annulée.'
    return 1
  fi
  if [[ -f "$keys" ]]; then
    backup_file "$keys" "$SAVES/CommandesManette/firefox" 'Firefox.sh.keys' || {
      echo '[SÉCURITÉ] Sauvegarde des commandes manette impossible : désinstallation annulée.'
      return 1
    }
  fi
  for path in "$FF_ROOT" '/userdata/system/.config/mozilla/firefox' '/userdata/system/.cache/mozilla/firefox'; do
    if [[ -e "$path" ]]; then
      rm -rf -- "$path" || { echo "[ERREUR] Impossible de supprimer : $path"; return 1; }
      echo "[OK] Fichier supprimé."
      echo "[FICHIER] $path"
    fi
  done
  if [[ -f "$launcher" ]]; then rm -f -- "$launcher" || return 1; fi
  # Retire les commandes manette devenues orphelines (déjà sauvegardées).
  if [[ -f "$keys" ]]; then
    rm -f -- "$keys" || return 1
    echo '[OK] Commandes manette Firefox supprimées.'
  fi
  flatpak_remove_ports_entry Firefox || return 1
  reload_es_games
  FF_REMOTE=''; UPDATES_CHECKED=0
  echo '[OK] Firefox désinstallé.'
  echo '[INFO] Sauvegardes conservées.'
}

manage_firefox(){
  local ver choice
  while :; do
    refresh_screen
    ver='Absent'
    [[ -x "$FF_ROOT/firefox" ]] && ver="$(firefox_installed_version)"
    ui_section 'FIREFOX'
    if [[ -x "$FF_ROOT/firefox" ]]; then
      ui_software_status 'Firefox' "$ver" 1
    else
      ui_software_status 'Installer Firefox' 'Absent' 0
    fi
    ui_item '2) Illustrations'
    ui_item '3) Sauvegardes'
    if [[ -x "$FF_ROOT/firefox" ]]; then ui_item '4) Désinstaller'; fi
    ui_item '5) Commandes manette'
    echo
    ui_item '0) Retour'
    ui_item 'Q) Quitter le gestionnaire'
    choice="$(read_key 'Votre choix : ')" || return 0
    case "$choice" in
      1)
        if [[ -x "$FF_ROOT/firefox" ]]; then
          echo '[INFO] Firefox Mozilla est déjà installé : aucune réinstallation.'
          ensure_ports_artwork 10 || echo '[ATTENTION] Vérifier le lanceur et les illustrations Firefox.'
          padkeys_install firefox || echo '[ATTENTION] Commandes manette Firefox non installées.'
        else
          install_firefox_mozilla
          UPDATES_CHECKED=0
        fi
        pause ;;
      2)
        if [[ ! -f /userdata/roms/ports/Firefox.sh ]]; then
          echo '[INFO] Lanceur Firefox absent : illustrations indisponibles.'
        elif confirm 'Installer les illustrations Firefox ?'; then
          install_ports_artwork 10 && reload_es_games
        fi
        pause ;;
      3) profile_manual_menu firefox ;;
      4) if [[ -x "$FF_ROOT/firefox" ]]; then uninstall_firefox_mozilla; else echo '[INFO] Firefox absent.'; fi; pause ;;
      5) padkeys_install firefox; pause ;;
      0) refresh_screen; return 0 ;;
      *) echo '[INFO] Choix invalide.'; pause ;;
    esac
  done
}
# Taille reelle occupee sur disque, en lecture seule (sans suivre les liens symboliques).
kodi_profile_size(){
  local path="$1" result
  if [[ ! -d "$path" || -L "$path" ]]; then
    printf '%s' 'indisponible'
    return 0
  fi
  result="$(du -sh -- "$path" 2>/dev/null)" || { printf '%s' 'indisponible'; return 0; }
  printf '%s' "${result%%[[:space:]]*}"
}
# Compare le contenu des profils (fichiers, liens, tailles et octets), sans rien modifier.
# Si Kodi a change depuis la sauvegarde, aucun profil n'est marque actif.
kodi_backup_matches_active(){
  local saved="$1" active='/userdata/system/.kodi'
  [[ -d "$saved" && ! -L "$saved" && -d "$active" && ! -L "$active" ]] || return 1
  command -v python3 >/dev/null 2>&1 || return 1
  python3 - "$saved" "$active" <<'PYKODICMP'
import os, sys, stat, hashlib

def snapshot(root):
    result = {}
    for base, dirs, files in os.walk(root, topdown=True, followlinks=False):
        # Comme lors de la sauvegarde Kodi, ignorer les dossiers
        # temporaires nommes cache ou temp, a toute profondeur.
        dirs[:] = [d for d in dirs if d not in ('cache', 'temp')]
        names = dirs + files
        for name in names:
            path = os.path.join(base, name)
            rel = os.path.relpath(path, root)
            st = os.lstat(path)
            if stat.S_ISLNK(st.st_mode):
                result[rel] = ('link', os.readlink(path))
            elif stat.S_ISDIR(st.st_mode):
                result[rel] = ('dir',)
            elif stat.S_ISREG(st.st_mode):
                h = hashlib.sha256()
                with open(path, 'rb') as f:
                    for chunk in iter(lambda: f.read(1024 * 1024), b''):
                        h.update(chunk)
                result[rel] = ('file', st.st_size, h.digest())
            else:
                result[rel] = ('other', st.st_mode, st.st_size)
        dirs[:] = [d for d in dirs if not os.path.islink(os.path.join(base, d))]
    return result

try:
    sys.exit(0 if snapshot(sys.argv[1]) == snapshot(sys.argv[2]) else 1)
except (OSError, ValueError):
    sys.exit(1)
PYKODICMP
}

# Consultation des sauvegardes Kodi : restauration ou suppression avec confirmation.
kodi_select_restore(){
  local folder="$SAVES/Kodi/Profils" choice i label selected action backup_size
  local -a backups=()
  if [[ -d "$folder" && ! -L "$folder" ]]; then
    while IFS= read -r label; do
      [[ -d "$folder/$label/data" && ! -L "$folder/$label" && ! -L "$folder/$label/data" ]] && backups+=("$label")
    done < <(find "$folder" -mindepth 1 -maxdepth 1 -type d -name 'profil-*' -printf '%f\n' 2>/dev/null | sort -r)
  fi
  if (( ${#backups[@]} == 0 )); then
    echo '[INFO] Aucune sauvegarde Kodi disponible.'
    return 0
  fi
  while :; do
    refresh_screen
    ui_section 'SAUVEGARDES KODI'
    ui_print success "  Taille du profil actif : $(kodi_profile_size /userdata/system/.kodi)"
    for i in "${!backups[@]}"; do
      label="${backups[$i]}"
      backup_size="$(kodi_profile_size "$folder/$label/data")"
      if [[ "$label" =~ ^profil-([0-9]{4})([0-9]{2})([0-9]{2})-([0-9]{2})([0-9]{2})([0-9]{2})-[0-9]+$ ]]; then
        ui_item "$((i+1))) ${BASH_REMATCH[3]}/${BASH_REMATCH[2]}/${BASH_REMATCH[1]} - ${BASH_REMATCH[4]}:${BASH_REMATCH[5]}:${BASH_REMATCH[6]}"
      else
        ui_item "$((i+1))) $label"
      fi
      if kodi_backup_matches_active "$folder/$label/data"; then
        ui_print success "      $backup_size - ● PROFIL ACTIF"
      else
        ui_print info "      $backup_size"
      fi
    done
    echo
    ui_item '0) Retour'
    ui_item 'Q) Quitter le gestionnaire'
    choice="$(read_key 'Votre choix : ')" || return 0
    [[ "$choice" =~ ^[0-9]+$ ]] || { echo '[INFO] Choix invalide.'; continue; }
    (( 10#$choice == 0 )) && { refresh_screen; return 0; }
    (( 10#$choice >= 1 && 10#$choice <= ${#backups[@]} )) || { echo '[INFO] Choix invalide.'; continue; }
    selected="${backups[$((10#$choice-1))]}"
    [[ "$selected" =~ ^profil-[0-9]{8}-[0-9]{6}-[0-9]+$ && -d "$folder/$selected/data" && ! -L "$folder/$selected" && ! -L "$folder/$selected/data" ]] || { echo '[ERREUR] Sauvegarde invalide.'; continue; }
    refresh_screen
    ui_section 'ACTIONS SUR LA SAUVEGARDE'
    ui_item '1) Restaurer cette sauvegarde'
    ui_item '2) Supprimer cette sauvegarde'
    ui_item '0) Retour aux sauvegardes'
    action="$(read_key 'Votre choix : ')" || return 0
    case "$action" in
      1)
        if confirm 'Restaurer ce profil Kodi et conserver le profil actuel en sécurité ?'; then
          profile_restore kodi "$selected" || true
          return 0
        else
          echo '[INFO] Restauration annulée.'
        fi
        ;;
      2)
        if confirm "Supprimer definitivement la sauvegarde $selected (le profil Kodi actif sera preserve) ?"; then
          # Le chemin est limite au dossier de sauvegarde selectionne, jamais au profil actif.
          if [[ "$folder/$selected" != '/userdata/system/.kodi' && -d "$folder/$selected/data" && ! -L "$folder/$selected" && ! -L "$folder/$selected/data" ]]; then
            if rm -rf -- "$folder/$selected"; then
              echo '[OK] Sauvegarde supprimée.'
              echo '[INFO] Profil Kodi inchangé.'
              backups=()
              while IFS= read -r label; do
                [[ -d "$folder/$label/data" && ! -L "$folder/$label" && ! -L "$folder/$label/data" ]] && backups+=("$label")
              done < <(find "$folder" -mindepth 1 -maxdepth 1 -type d -name 'profil-*' -printf '%f\n' 2>/dev/null | sort -r)
              (( ${#backups[@]} )) || { echo '[INFO] Aucune sauvegarde restante.'; return 0; }
            else
              echo '[ERREUR] Suppression impossible.'
            fi
          else
            echo '[ERREUR] Sauvegarde introuvable ou invalide.'
          fi
        else
          echo '[INFO] Suppression annulée.'
        fi
        ;;
      0) ;;
      *) echo '[INFO] Choix invalide.' ;;
    esac
  done
}
manage_kodi(){
  local choice
  while :; do
    refresh_screen
    ui_section 'KODI (INTEGRE A BATOCERA)'
    echo 'Profil : /userdata/system/.kodi'
    ui_print success "Taille du profil actif : $(kodi_profile_size /userdata/system/.kodi)"
    ui_item '1) Sauvegarder le profil'
    ui_item '2) Consulter les sauvegardes'
    echo
    ui_item '0) Retour'
    ui_item 'Q) Quitter le gestionnaire'
    choice="$(read_key 'Votre choix : ')" || return 0
    case "$choice" in
      1) if confirm 'Sauvegarder le profil Kodi (Kodi doit etre ferme) ?'; then profile_backup kodi || true; fi; pause ;;
      2) kodi_select_restore ;;
      0) refresh_screen; return 0 ;;
      *) echo '[INFO] Choix invalide.'; pause ;;
    esac
  done
}
# Sauvegarde PeaZip historique manuelle : jamais effacee ni modifiee.
# Lors d'une nouvelle installation, restaurer seulement si aucun profil actif n'existe.
peazip_restore_after_install(){
  local src rescue folder latest
  src="$(profile_source peazip)" || return 1
  folder="$(profile_folder peazip)" || return 1
  rescue="$SAVES/PeaZip/profil-secours"
  if [[ -d "$src" ]] && find "$src" -type f -print -quit 2>/dev/null | grep -q .; then
    echo '[INFO] Profil PeaZip deja present : restauration automatique ignoree.'
    return 0
  fi
  latest="$(profile_latest peazip)" || latest=''
  if [[ -n "$latest" ]]; then
    echo '[INFO] Restauration du dernier profil PeaZip sauvegarde.'
    profile_restore peazip || return 1
  elif [[ -d "$rescue" && ! -L "$rescue" && -f "$rescue/Profiles/profile.profile.7z" ]]; then
    echo '[INFO] Restauration de la sauvegarde de secours PeaZip.'
    mkdir -p -- "$(dirname "$src")" || return 1
    local staging
    staging="$(mktemp -d "$(dirname "$src")/.peazip-restore.XXXXXX")" || return 1
    if ! cp -a -- "$rescue/." "$staging/"; then rm -rf -- "$staging"; return 1; fi
    if [[ -e "$src" ]]; then
      local old="${src}.avant-restauration-$(date +%Y%m%d-%H%M%S)-$$"
      mv -- "$src" "$old" || { rm -rf -- "$staging"; return 1; }
      if ! mv -- "$staging" "$src"; then mv -- "$old" "$src"; return 1; fi
      echo "[SECURITE] Ancien profil conserve : $old"
    else
      mv -- "$staging" "$src" || { rm -rf -- "$staging"; return 1; }
    fi
    echo '[OK] Profil PeaZip restauré.'
  else
    echo '[INFO] Aucune sauvegarde PeaZip reconnue.'
  fi
}
# Applications Flatpak : installation, mise a jour, suppression et lanceurs Ports.
# Ne jamais effacer les donnees utilisateur sans une confirmation distincte.
flatpak_app_id(){
  case "$1" in
    filezilla) printf '%s' 'org.filezillaproject.Filezilla' ;;
    peazip) printf '%s' 'io.github.peazip.PeaZip' ;;
    *) return 1 ;;
  esac
}
flatpak_app_name(){
  case "$1" in
    filezilla) printf '%s' 'FileZilla' ;;
    peazip) printf '%s' 'PeaZip' ;;
    *) return 1 ;;
  esac
}
flatpak_app_installed(){
  local id="$1"
  flatpak info --system "$id" >/dev/null 2>&1 || flatpak info --user "$id" >/dev/null 2>&1
}
flatpak_app_scope(){
  local id="$1"
  if flatpak info --system "$id" >/dev/null 2>&1; then echo system
  elif flatpak info --user "$id" >/dev/null 2>&1; then echo user
  else echo absent
  fi
}
flatpak_app_version(){
  local id="$1" scope
  scope="$(flatpak_app_scope "$id")"
  if [[ "$scope" == absent ]]; then echo 'non installé'; return; fi
  # Batocera utilise parfois une version de Flatpak sans --show-version.
  # Lire le champ Version de flatpak info, compatible avec cette version.
  local info version
  info="$(LC_ALL=C flatpak info "--$scope" "$id" 2>/dev/null)" || { echo 'version inconnue'; return; }
  version="$(printf '%s\n' "$info" | sed -nE 's/^[[:space:]]*Version:[[:space:]]*([^[:space:]]+).*$/\1/p' | head -n 1)"
  printf '%s\n' "${version:-version inconnue}"
}
# Retrouve le raccourci Flatpak genere par Batocera, sans le modifier.
# Les noms de developpeurs peuvent varier selon les versions.
flatpak_shortcut(){
  local app="$1" dir=/userdata/roms/flatpak candidate
  [[ -d "$dir" ]] || { echo '[ERREUR] Dossier roms/flatpak absent.' >&2; return 1; }
  case "$app" in
    filezilla)
      for candidate in 'Tim Kosse.flatpak' 'FileZilla.flatpak'; do
        [[ -f "$dir/$candidate" ]] && { printf '%s\n' "$dir/$candidate"; return 0; }
      done ;;
    peazip)
      for candidate in 'Giorgo Tani.flatpak' 'Giorgio Tani.flatpak' 'PeaZip.flatpak'; do
        [[ -f "$dir/$candidate" ]] && { printf '%s\n' "$dir/$candidate"; return 0; }
      done ;;
    *) return 1 ;;
  esac
  # Secours : les noms des raccourcis Batocera peuvent varier.
  # Recherche uniquement des fichiers .flatpak du dossier natif, sans rien creer.
  python3 - "$dir" "$app" <<'PYSHORTCUT'
from pathlib import Path
import sys, unicodedata
folder, app = Path(sys.argv[1]), sys.argv[2]
def norm(s):
    s = unicodedata.normalize('NFKD', s).casefold()
    return ''.join(c for c in s if c.isalnum())
matches = []
for p in folder.iterdir():
    if not p.is_file() or p.suffix.casefold() != '.flatpak':
        continue
    n = norm(p.stem)
    if app == 'peazip' and ('peazip' in n or ('tani' in n and ('giorg' in n or 'gior' in n))):
        matches.append(p)
    elif app == 'filezilla' and ('filezilla' in n or 'timkosse' in n):
        matches.append(p)
if len(matches) == 1:
    print(matches[0])
elif len(matches) > 1:
    print('[ATTENTION] Plusieurs raccourcis possibles : ' + ', '.join(p.name for p in matches), file=sys.stderr)
    sys.exit(1)
else:
    sys.exit(1)
PYSHORTCUT
  local rc=$?
  if (( rc != 0 )); then
    echo "[ATTENTION] Raccourci $app non trouvé sans ambiguite dans $dir." >&2
  fi
  return "$rc"
}
# Batocera peut creer le fichier .flatpak quelques secondes apres la fin
# de flatpak install. Attendre au maximum 5 secondes, sans rien supprimer.
wait_flatpak_shortcut(){
  local app="$1" attempt shortcut=''
  for ((attempt=1; attempt<=5; attempt++)); do
    shortcut="$(flatpak_shortcut "$app" 2>/dev/null)" && {
      printf '%s\n' "$shortcut"
      return 0
    }
    sleep 1
  done
  echo "[ATTENTION] Raccourci $app toujours absent après 5 secondes." >&2
  return 1
}

# Ajoute les visuels au systeme Flatpak lui-meme, pas au systeme Ports.
flatpak_artwork(){
  local app="$1" shortcut idx
  shortcut="$(wait_flatpak_shortcut "$app")" || return 1
  case "$app" in
    filezilla) idx=11 ;;
    peazip) idx=12 ;;
    *) return 1 ;;
  esac
  echo "[INFO] Illustrations pour : $shortcut"
  install_ports_artwork "$idx" /userdata/roms/flatpak "$(basename "$shortcut")"
}

# Metadonnees Flatpak : meme methode XML que le test manuel valide.
# Ne touche ni aux sauvegardes de jeu, ni aux autres entrees du gamelist.
flatpak_fix_metadata(){
  local app="$1" shortcut name
  shortcut="$(flatpak_shortcut "$app")" || return 1
  name="$(flatpak_app_name "$app")" || return 1
  python3 - /userdata/roms/flatpak/gamelist.xml "$(basename "$shortcut")" "$name" <<'PYFLATMETA'
from pathlib import Path
import sys, os, tempfile, shutil
import xml.etree.ElementTree as ET
p=Path(sys.argv[1]); filename=sys.argv[2]; name=sys.argv[3]
info={
 'FileZilla': ('FileZilla Project', 'Client FTP, FTPS et SFTP pour transferer des fichiers.'),
 'PeaZip': ('Giorgio Tani', 'Gestionnaire d archives et outil de compression et extraction.'),
}
if name not in info or not p.is_file():
    print('[ERREUR] Fiche Flatpak absente ou application inconnue.')
    sys.exit(1)
try:
    tree=ET.parse(p); root=tree.getroot()
    if root.tag!='gameList': raise ValueError('Racine XML invalide')
    entries=[g for g in root.findall('game') if (g.findtext('path') or '').strip().removeprefix('./')==filename]
    if len(entries)!=1: raise ValueError('Entree Flatpak absente ou ambigue : '+filename)
    media=p.parent/'images'/'gestionnaire-ports'
    for kind in ('cover','logo','fanart'):
        if not (media/f'{name}-{kind}.png').is_file():
            raise ValueError('Illustration absente : '+kind)
    game=entries[0]
    developer,description=info[name]
    fields={'name':name,'developer':developer,'desc':description,
      'image':f'./images/gestionnaire-ports/{name}-fanart.png',
      'thumbnail':f'./images/gestionnaire-ports/{name}-cover.png',
      'marquee':f'./images/gestionnaire-ports/{name}-logo.png',
      'fanart':f'./images/gestionnaire-ports/{name}-fanart.png'}
    for tag,value in fields.items():
        node=game.find(tag)
        if node is None: node=ET.SubElement(game,tag)
        node.text=value
    shutil.copy2(p,str(p)+'.bak-gestionnaire-'+name.lower())
    fd,tmp=tempfile.mkstemp(prefix='.gamelist-flatpak-',suffix='.xml',dir=p.parent)
    try:
        with os.fdopen(fd,'wb') as f: tree.write(f,encoding='utf-8',xml_declaration=True)
        ET.parse(tmp)
        shutil.copymode(p,tmp)
        os.replace(tmp,p)
    finally:
        if os.path.exists(tmp): os.unlink(tmp)
    print('[OK] Fiche Flatpak mise à jour.')
    print('[FICHIER]',filename)
except (OSError,ValueError,ET.ParseError) as exc:
    print('[ERREUR] Métadonnées Flatpak :',exc)
    sys.exit(1)
PYFLATMETA
}

# Actualise l'interface apres l'ecriture des informations, puis verifie le XML.
flatpak_finish_artwork(){
  local app="$1"
  flatpak_fix_metadata "$app" || return 1
  reload_es_games
  # Certaines operations Flatpak peuvent re-ecrire le gamelist lors du rechargement.
  # Reappliquer la fiche comme lors du test manuel reussi.
  sleep 1
  flatpak_fix_metadata "$app" || return 1
  reload_es_games
}

# Migration facultative des anciens lanceurs Ports, sauvegardes avant suppression.
flatpak_cleanup_old_ports(){
  local app="$1" name launcher
  name="$(flatpak_app_name "$app")" || return 1
  launcher="/userdata/roms/ports/$name.sh"
  [[ -f "$launcher" ]] || return 0
  echo "[INFO] Ancien lanceur Ports détecté : $launcher"
  if confirm "Supprimer cet ancien lanceur Ports (après sauvegarde) pour eviter le doublon ?"; then
    backup_file "$launcher" "$SAVES/$name/AnciensLanceurs" "$name.sh" || return 1
    rm -f -- "$launcher" || return 1
    flatpak_remove_ports_entry "$name" || return 1
    echo '[OK] Ancien lanceur supprimé.'
    echo '[INFO] Raccourci Flatpak conservé.'
    reload_es_games
  else
    echo '[INFO] Ancien lanceur Ports conserve.'
  fi
}
flatpak_remove_ports_entry(){
  local name="$1"
  python3 - "$name" <<'PYREMOVE'
import sys,os,shutil,xml.etree.ElementTree as ET
p='/userdata/roms/ports/gamelist.xml'
if not os.path.isfile(p): sys.exit(0)
try:
    tree=ET.parse(p)
    root=tree.getroot()
    filename=sys.argv[1]+'.sh'
    matches=[node for node in root.findall('game') if (node.findtext('path') or '').removeprefix('./')==filename]
    if matches:
        shutil.copy2(p,p+'.bak-'+sys.argv[1].lower())
        for node in matches: root.remove(node)
        tree.write(p,encoding='utf-8',xml_declaration=True)
        print('[OK] Entrée Ports retirée.')
        print('[FICHIER]',filename)
except (OSError,ET.ParseError) as exc:
    print('[ATTENTION] gamelist.xml non modifie :',exc)
    sys.exit(1)
PYREMOVE
}
# Nettoyage cible des raccourcis et visuels Flatpak apres desinstallation reussie.
# Conserve toutes les sauvegardes et n'efface aucun autre logiciel.
flatpak_cleanup_uninstalled(){
  local app="$1" id
  id="$(flatpak_app_id "$app")" || return 1
  if flatpak_app_installed "$id"; then
    echo '[SÉCURITÉ] Application encore installée : nettoyage annulé.'
    return 1
  fi
  python3 - "$app" "$SAVES" <<'PYCLEANUNINSTALL'
import os,sys,shutil,tempfile,datetime,xml.etree.ElementTree as ET
from pathlib import Path
app, saves = sys.argv[1], Path(sys.argv[2])
config = {
 'filezilla': ('FileZilla', {'Tim Kosse.flatpak','FileZilla.flatpak'}),
 'peazip': ('PeaZip', {'Giorgo Tani.flatpak','Giorgio Tani.flatpak','PeaZip.flatpak'})
}
if app not in config: sys.exit(1)
key, names = config[app]
root=Path('/userdata/roms/flatpak')
xml=root/'gamelist.xml'
media=root/'images'/'gestionnaire-ports'
shortcuts=[root/n for n in sorted(names) if (root/n).is_file()]
images=[media/f'{key}-{kind}.png' for kind in ('cover','logo','fanart') if (media/f'{key}-{kind}.png').is_file()]
# Les .keys peuvent subsister même si Flatpak a déjà effacé les raccourcis.
# Seuls les noms connus de CETTE application sont concernés.
keys_candidates=[root/(n+'.keys') for n in sorted(names)]
try:
    unsafe=[p for p in keys_candidates if p.is_symlink() or (p.exists() and not p.is_file())]
    if unsafe:
        raise ValueError('Fichier .keys non ordinaire : '+', '.join(p.name for p in unsafe))
    keys=[p for p in keys_candidates if p.is_file()]
    tree=ET.parse(xml) if xml.exists() else None
    if tree is not None and tree.getroot().tag!='gameList':
        raise ValueError('Racine XML inattendue')
    entries=[]
    if tree is not None:
        entries=[e for e in tree.getroot().findall('game') if Path((e.findtext('path') or '').replace('\\','/')).name in names]
    if not (shortcuts or images or entries or keys):
        print('[INFO] Aucun raccourci, .keys ni visuel orphelin pour',key)
        sys.exit(0)
    # Copie de securite avant toute modification.
    dest=saves/'NettoyageFlatpak'/key/(datetime.datetime.now().strftime('%Y%m%d-%H%M%S')+'-'+str(os.getpid()))
    dest.mkdir(parents=True,exist_ok=False)
    if xml.exists(): shutil.copy2(xml,dest/'gamelist.xml')
    for path in shortcuts+images+keys: shutil.copy2(path,dest/path.name)
    if tree is not None and entries:
        for e in entries: tree.getroot().remove(e)
        fd,tmp=tempfile.mkstemp(prefix='.gamelist-clean-',suffix='.xml',dir=root)
        try:
            with os.fdopen(fd,'wb') as f: tree.write(f,encoding='utf-8',xml_declaration=True)
            ET.parse(tmp)
            os.replace(tmp,xml)
        finally:
            if os.path.exists(tmp): os.unlink(tmp)
    for path in shortcuts: path.unlink()
    for path in keys:
        path.unlink()
        print('[OK] Commandes manette supprimées :',path.name)
    # Les illustrations sont reservees a cette application dans ce repertoire.
    for path in images: path.unlink()
    # Nettoyage des illustrations residuelles dans Ports (sans toucher au gamelist Ports).
    ports_media=Path('/userdata/roms/ports/images/gestionnaire-ports')
    ports_images=[ports_media/f'{key}-{kind}.png' for kind in ('cover','logo','fanart') if (ports_media/f'{key}-{kind}.png').is_file()]
    # Ne jamais effacer les images Ports si un ancien lanceur y est encore present.
    if (Path('/userdata/roms/ports')/f'{key}.sh').exists():
        print('[ATTENTION] Lanceur Ports encore present : images Ports conservees.')
    else:
        for path in ports_images:
            shutil.copy2(path,dest/('ports-'+path.name))
            path.unlink()
        print('[OK] Visuels Ports supprimés.')
        print('[NOMBRE]',len(ports_images))
    # Anciennes illustrations generees par Batocera avec le nom du developpeur.
    legacy_names = ('Tim Kosse',) if app=='filezilla' else ('Giorgio Tani','Giorgo Tani')
    flat_media=root/'images'
    legacy=[flat_media/f'{n}-{kind}.png' for n in legacy_names for kind in ('image','thumbnail','marquee','fanart') if (flat_media/f'{n}-{kind}.png').is_file()]
    # Conserver tout fichier encore reference dans le gamelist Flatpak.
    xml_text=xml.read_text(encoding='utf-8') if xml.exists() else ''
    for path in legacy:
        if path.name in xml_text:
            print('[ATTENTION] Image toujours referencee :',path.name)
            continue
        shutil.copy2(path,dest/('ancien-'+path.name))
        path.unlink()
        print('[OK] Ancien visuel supprimé.')
        print('[FICHIER]',path.name)
    print('[OK]',key,': nettoyage terminé.')
    print('[DÉTAILS]',len(shortcuts),'raccourci(s),',len(keys),'fichier(s) .keys,',len(entries),'entrée(s) XML,',len(images),'image(s).')
    print('[SAUVEGARDE SÉCURITÉ]',dest)
except (OSError,ET.ParseError,ValueError) as exc:
    print('[ERREUR] Nettoyage incomplet :',exc)
    sys.exit(1)
PYCLEANUNINSTALL
}

ensure_flathub(){
  if flatpak remotes --system --columns=name 2>/dev/null | grep -Fxq flathub; then
    return 0
  fi

  echo '[INFO] Le dépôt Flathub est absent.'
  if ! confirm 'Ajouter le dépôt officiel Flathub (système) ?'; then
    echo '[INFO] Installation annulée.'
    return 1
  fi

  if ! flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo; then
    echo '[ERREUR] Impossible de configurer Flathub.'
    return 1
  fi

  if ! flatpak remotes --system --columns=name 2>/dev/null | grep -Fxq flathub; then
    echo '[ERREUR] Flathub non détecté après son ajout.'
    return 1
  fi

  echo '[OK] Flathub configuré.'
  return 0
}

manage_flatpak_app(){
  local app="$1" id name choice scope
  id="$(flatpak_app_id "$app")" || return 1
  name="$(flatpak_app_name "$app")" || return 1
  command -v flatpak >/dev/null 2>&1 || { echo '[ERREUR] Flatpak introuvable.'; return 1; }
  while :; do
    scope="$(flatpak_app_scope "$id")"
    refresh_screen
    ui_section "$name (FLATPAK)"
    if [[ "$scope" == absent ]]; then
      ui_software_status "Installer $name" 'Absent' 0
    else
      local installed_version
      installed_version="$(flatpak_app_version "$id")"
      [[ -n "$installed_version" ]] || installed_version='Version inconnue'
      ui_software_status "$name" "$installed_version" 1
    fi
    ui_item '2) Illustrations'
    if [[ "$app" == filezilla || "$app" == peazip ]]; then ui_item '3) Sauvegardes'; fi
    if [[ "$scope" != absent ]]; then ui_item '4) Désinstaller'; fi
    ui_item '5) Commandes manette'
    echo
    ui_item '0) Retour'
    ui_item 'Q) Quitter le gestionnaire'
    choice="$(read_key 'Votre choix : ')" || return 0
    case "$choice" in
      1)
        if [[ "$scope" != absent ]]; then echo "[INFO] $name est déjà installé."; pause; continue; fi
        if confirm "Installer $name depuis Flathub (système) ?"; then
          local fresh=0
          [[ "$scope" == absent ]] && fresh=1
          if ensure_flathub && flatpak install --system -y flathub "$id"; then
            if [[ "$app" == peazip ]] && (( fresh )); then
              peazip_restore_after_install || echo '[ATTENTION] Restauration PeaZip non effectuee ; sauvegardes preservees.'
            fi
            if [[ "$app" == filezilla ]] && (( fresh )) && profile_latest filezilla >/dev/null 2>&1; then
              echo '[INFO] Choisir une sauvegarde FileZilla (ou 0 pour ignorer).'
              profile_select_restore filezilla
            fi
            # FileZilla et PeaZip : Batocera ne cree pas toujours le raccourci
            # .flatpak au moment ou la commande flatpak install se termine.
            # L'API /reloadgames actualise ES mais NE genere pas ce raccourci.
            # Synchroniser les raccourcis avant l'installation des visuels/XML.
            # Aucun raccourci Ports n'est cree et les profils sont conserves.
            if [[ "$app" == filezilla || "$app" == peazip ]]; then
              echo "[$name] Synchronisation officielle des raccourcis Flatpak..."
              if command -v batocera-flatpak-update >/dev/null 2>&1; then
                if ! batocera-flatpak-update; then
                  echo '[ATTENTION] Synchronisation Flatpak incomplète ; vérifier le raccourci.'
                fi
              else
                echo '[ATTENTION] batocera-flatpak-update absent ; contrôle du raccourci existant.'
              fi
            fi
            echo '[INFO] Actualisation Flatpak avant installation des illustrations...'
            reload_es_games
            if flatpak_artwork "$app" && flatpak_finish_artwork "$app"; then
              echo "[OK] $name : visuels et XML OK."
            else
              echo "[ATTENTION] $name : illustrations non finalisées ; option 2 (Illustrations) disponible."
            fi
            padkeys_install "$app" || echo "[ATTENTION] Commandes manette $name non installées."
            flatpak_cleanup_old_ports "$app" || true
            reload_es_games
          fi
        fi; pause ;;
      2)
        if [[ "$scope" == absent ]]; then echo '[INFO] Application absente.'
        elif confirm "Associer les illustrations a $name dans roms/flatpak ?"; then
          if flatpak_artwork "$app" && flatpak_finish_artwork "$app"; then
            flatpak_cleanup_old_ports "$app" || true
            reload_es_games
          else
            echo '[ATTENTION] Reparation incomplete : voir les messages ci-dessus.'
          fi
        fi
        pause ;;
      4)
        if [[ "$scope" == absent ]]; then echo '[INFO] Application déjà absente.'
        else
          if [[ "$app" == filezilla || "$app" == peazip ]]; then
            echo '[INFO] Le profil sera sauvegardé avant la désinstallation.'
          fi
          if ! confirm "Désinstaller $name ($scope) et effacer ses données actives ?" || ! confirm 'Confirmer la désinstallation ?'; then
            pause
            continue
          fi
          if [[ "$app" == filezilla || "$app" == peazip ]]; then
            if [[ -d "$(profile_source "$app")" ]]; then
              if ! profile_backup "$app"; then
                echo '[SÉCURITÉ] Désinstallation annulée : sauvegarde impossible.'
                pause
                continue
              fi
            else
              echo "[INFO] Aucun dossier de configuration $name a sauvegarder."
            fi
          fi
          if flatpak uninstall "--$scope" -y --delete-data "$id"; then
            echo '[OK] Application désinstallée.'
            flatpak_cleanup_uninstalled "$app" || echo '[ATTENTION] Nettoyage incomplet : voir les messages ci-dessus.'
            reload_es_games
          fi
        fi
        pause ;;
      3) if [[ "$app" == filezilla || "$app" == peazip ]]; then profile_manual_menu "$app"; else echo '[INFO] Choix invalide.'; pause; fi ;;
      5) if [[ "$scope" == absent ]]; then
           echo "[INFO] $name absent : installer l'application avant les commandes manette."
         else
           padkeys_install "$app"
         fi; pause ;;
      0) return 0 ;;
      *) echo '[INFO] Choix invalide.'; pause ;;
    esac
  done
}
# Kodi est integre a Batocera : lecture locale uniquement.
kodi_installed_version(){
  local exe='' ver=''
  for exe in /usr/bin/kodi /usr/bin/kodi.bin /usr/lib/kodi/kodi.bin; do
    if [[ -x "$exe" ]]; then
      ver="$("$exe" --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)+' | head -n 1)"
      [[ -n "$ver" ]] && { printf '%s' "$ver"; return; }
    fi
  done
  if command -v kodi >/dev/null 2>&1; then
    ver="$(kodi --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)+' | head -n 1)"
    [[ -n "$ver" ]] && { printf '%s' "$ver"; return; }
  fi
  # Certains builds Batocera fournissent les metadonnees sans executable kodi.
  for exe in /usr/share/kodi/version.txt /usr/share/kodi/system/version.txt; do
    if [[ -r "$exe" ]]; then
      ver="$(grep -oE '[0-9]+(\.[0-9]+)+' "$exe" | head -n 1)"
      [[ -n "$ver" ]] && { printf '%s' "$ver"; return; }
    fi
  done
  if command -v batocera-kodi >/dev/null 2>&1 || [[ -d /usr/share/kodi ]]; then
    printf '%s' 'Version inconnue'
  else
    printf '%s' 'Non installé'
  fi
}

# Consultation seule : les applications ne sont pas modifiees ici.
# Chaque resultat est l'un de : A JOUR, MAJ DISPONIBLE, Verification impossible.
logiciels_flatpak_status(){
  local app="$1" id="$2" scope="$3" pending=''
  [[ "$scope" != absent ]] || { printf '%s' 'Non installé'; return; }
  if ! command -v flatpak >/dev/null 2>&1; then
    printf '%s' 'Vérification impossible'; return
  fi
  if ! flatpak update "--$scope" --appstream -y >/dev/null 2>&1; then
    printf '%s' 'Vérification impossible'; return
  fi
  if ! pending="$(flatpak remote-ls "--$scope" --updates --columns=application 2>/dev/null)"; then
    printf '%s' 'Vérification impossible'; return
  fi
  if printf '%s\n' "$pending" | grep -Fxq "$id"; then
    printf '%s' 'MAJ DISPONIBLE'
  else
    printf '%s' 'À JOUR'
  fi
}

logiciels_firefox_remote(){
  local raw=''
  command -v curl >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1 || return 1
  raw="$(curl -fLsS --connect-timeout 5 --max-time 12 'https://product-details.mozilla.org/1.0/firefox_versions.json' 2>/dev/null)" || return 1
  printf '%s' "$raw" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("LATEST_FIREFOX_VERSION",""))' 2>/dev/null
}

# Cache quotidien des resultats : une verification reseau par jour et par
# application/version installee. Un changement de version invalide le cache.
logiciels_cached_status(){
  local app="$1" installed="$2" scope="$3" today cache dir old_day old_ver old_scope old_status status
  shift 3
  today="$(date +%Y-%m-%d)"
  dir='/userdata/saves/Installscripts/cache-gestionnaire'
  cache="$dir/maj-logiciels-$app.cache"
  if [[ -r "$cache" ]]; then
    IFS='|' read -r old_day old_ver old_scope old_status < "$cache" || true
    if [[ "$old_day" == "$today" && "$old_ver" == "$installed" && "$old_scope" == "$scope" && -n "$old_status" ]]; then
      printf '%s' "$old_status"
      return 0
    fi
  fi
  status="$("$@")"
  [[ -n "$status" ]] || status='Vérification impossible'
  if mkdir -p "$dir" 2>/dev/null; then
    printf '%s|%s|%s|%s\n' "$today" "$installed" "$scope" "$status" > "$cache.tmp.$$" 2>/dev/null && mv -f "$cache.tmp.$$" "$cache" 2>/dev/null || true
  fi
  printf '%s' "$status"
}

logiciels_firefox_status(){
  local installed="$1" remote result
  remote="$(logiciels_firefox_remote)" || remote=''
  if [[ -z "$remote" ]]; then
    printf '%s' 'Vérification impossible'
  else
    result="$(version_status "$installed" "$remote")"
    case "$result" in
      'MISE À JOUR DISPONIBLE') printf '%s' 'MAJ DISPONIBLE' ;;
      'INDETERMINE') printf '%s' 'Vérification impossible' ;;
      *) printf '%s' "$result" ;;
    esac
  fi
}

logiciels_apply_updates(){
  local ff="$1" fz="$2" pz="$3" scope id failed=0
  if [[ "$ff" == 'MAJ DISPONIBLE' ]]; then
    echo; echo '[FIREFOX] Mise à jour officielle Mozilla...'
    install_firefox_mozilla || failed=1
  fi
  if [[ "$fz" == 'MAJ DISPONIBLE' ]]; then
    id="$(flatpak_app_id filezilla)"
    scope="$(flatpak_app_scope "$id")"
    if [[ "$scope" != absent ]] && flatpak update "--$scope" -y "$id"; then
      reload_es_games
      if flatpak_artwork filezilla; then flatpak_finish_artwork filezilla || true; fi
    else
      echo '[ATTENTION] Mise à jour FileZilla non terminee.'; failed=1
    fi
  fi
  if [[ "$pz" == 'MAJ DISPONIBLE' ]]; then
    id="$(flatpak_app_id peazip)"
    scope="$(flatpak_app_scope "$id")"
    if [[ "$scope" != absent ]] && flatpak update "--$scope" -y "$id"; then
      reload_es_games
      if flatpak_artwork peazip; then flatpak_finish_artwork peazip || true; fi
    else
      echo '[ATTENTION] Mise à jour PeaZip non terminee.'; failed=1
    fi
  fi
  # Forcer une nouvelle verification apres une tentative de mise a jour.
  rm -f /userdata/saves/Installscripts/cache-gestionnaire/maj-logiciels-{firefox,filezilla,peazip}.cache 2>/dev/null || true
  (( failed == 0 )) && echo '[INFO] Traitement des mises à jour termine.'
  pause
}

# V2.0.53 TEST : meme legende que les menus Installation, sans changer les
# contrôles de mises à jour. Les indicateurs dépendent de l'installation locale :
# X = logiciel identifié, ? = absent, ! = état incertain (version ou outil inconnu).
# Ne pas confondre un état MAJ avec l'état de présence du logiciel.
logiciels_installation_state(){
  local app="$1" vers="$2"
  case "$vers" in
    'Non installé'|'non installe'|'Absent'|'')
      case "$app" in
        firefox)
          if [[ -d "$FF_ROOT" || -L "$FF_ROOT" ]]; then printf '!'; else printf '?'; fi ;;
        filezilla|peazip)
          if command -v flatpak >/dev/null 2>&1; then printf '?'; else printf '!'; fi ;;
        kodi) printf '?' ;;
        *) printf '!' ;;
      esac ;;
    'inconnue'|'version inconnue'|'Version inconnue'|'Vérification impossible'|'INDETERMINE')
      printf '!' ;;
    *) printf X ;;
  esac
}
logiciels_menu_item(){
  local num="$1" name="$2" installed="$3" status="$4" app="$5"
  local state glyph color yellow='' white='' reset='' green='' red='' orange=''
  local version_color='' update_color='' update_label='' version_label='' details=''
  local cols head max_width marker
  state="$(logiciels_installation_state "$app" "$installed")"
  case "$state" in
    X) glyph='✓'; color=$'\033[1;32m' ;;
    '?') glyph='✗'; color=$'\033[1;31m' ;;
    *) glyph='◆'; color=$'\033[1;38;5;208m' ;;
  esac
  if (( UI_COLOR )); then
    yellow=$'\033[1;33m'; green=$'\033[1;32m'
    white=$'\033[0;37m'; reset=$'\033[0m'
    red=$'\033[1;31m'; orange=$'\033[1;38;5;208m'
  else
    color=''
  fi
  version_label="$installed"
  if [[ "$state" == '?' ]]; then
    version_label='Absent'; version_color="$red"
  elif [[ "$state" == '!' ]]; then
    [[ "$installed" == 'Non installé' || "$installed" == 'non installe' ]] && version_label='À vérifier'
    version_color="$orange"
  else
    version_color="$green"
  fi
  case "$status" in
    'MAJ DISPONIBLE') update_label='MAJ'; update_color="$yellow" ;;
    'À JOUR'|'A JOUR') update_label='À JOUR'; update_color="$green" ;;
  esac
  # Les longues versions vont sur une seconde ligne plutôt que de faire
  # basculer le pictogramme (ou le découper) sur les petits écrans SSH.
  cols="$(ui_installation_cols)"
  marker="$(ui_menu_index "$num")"
  head="  $marker $glyph $name"
  details="${version_label}"
  [[ -n "$update_label" ]] && details+="  $update_label"
  if (( ${#head} + 2 + ${#details} <= cols )); then
    if (( UI_COLOR )); then
      printf '  %s%s%s %s%s%s %s%s%s  %s%s%s' \
        "$yellow" "$marker" "$reset" "$color" "$glyph" "$reset" "$white" "$name" "$reset" \
        "$version_color" "$version_label" "$reset"
      [[ -z "$update_label" ]] || printf '  %s%s%s' "$update_color" "$update_label" "$reset"
      printf '\n'
    else
      printf '  %s %s %s  %s' "$marker" "$glyph" "$name" "$version_label"
      [[ -z "$update_label" ]] || printf '  %s' "$update_label"
      printf '\n'
    fi
  else
    # Garder le nom entier sauf s'il dépasse à lui seul la largeur disponible.
    max_width=$((cols - (2 + ${#marker} + 1 + 1 + 1)))
    if (( max_width < 4 )); then max_width=4; fi
    if (( ${#name} > max_width )); then name="${name:0:max_width-3}..."; fi
    if (( UI_COLOR )); then
      printf '  %s%s%s %s%s%s %s%s%s\n' \
        "$yellow" "$marker" "$reset" "$color" "$glyph" "$reset" "$white" "$name" "$reset"
      printf '      %s%s%s' "$version_color" "$version_label" "$reset"
      [[ -z "$update_label" ]] || printf '  %s%s%s' "$update_color" "$update_label" "$reset"
      printf '\n'
    else
      printf '  %s %s %s\n' "$marker" "$glyph" "$name"
      printf '      %s' "$version_label"
      [[ -z "$update_label" ]] || printf '  %s' "$update_label"
      printf '\n'
    fi
  fi
}

# Afficher le message de verification uniquement si le cache du jour manque.
logiciels_cache_needs_check(){
  local app="$1" installed="$2" scope="$3" cache old_day old_ver old_scope old_status
  cache="/userdata/saves/Installscripts/cache-gestionnaire/maj-logiciels-$app.cache"
  if [[ -r "$cache" ]]; then
    IFS='|' read -r old_day old_ver old_scope old_status < "$cache" || true
    [[ "$old_day" == "$(date +%Y-%m-%d)" && "$old_ver" == "$installed" && "$old_scope" == "$scope" && -n "$old_status" ]] && return 1
  fi
  return 0
}

# Affichage homogène : numéro jaune, nom blanc et statut coloré.
logiciels_update_item(){
  local number="$1" name="$2" state="$3" status color marker
  marker="$(ui_menu_index "$number")"
  if [[ "$state" == 'MAJ DISPONIBLE' ]]; then
    status='MAJ'; color=$'\033[1;33m'
  else
    status='À JOUR'; color=$'\033[1;32m'
  fi
  if (( UI_COLOR )); then
    printf '  \033[1;33m%s\033[0m  \033[0;37m%s — \033[0m%s%s\033[0m\n' "$marker" "$name" "$color" "$status"
  else
    printf '  %s  %s — %s\n' "$marker" "$name" "$status"
  fi
}

logiciels_choose_updates(){
  local ff="$1" fz="$2" pz="$3" choice
  while :; do
    refresh_screen
    ui_section 'MISES À JOUR DISPONIBLES'
    logiciels_update_item 1 Firefox "$ff"
    logiciels_update_item 2 FileZilla "$fz"
    logiciels_update_item 3 PeaZip "$pz"
    echo
    ui_item '4) Tout mettre à jour'
    echo
    ui_item '0) Retour'
    ui_item 'Q) Quitter le gestionnaire'
    choice="$(read_key 'Votre choix : ')" || return 0
    case "$choice" in
      1) if [[ "$ff" == 'MAJ DISPONIBLE' ]]; then
           if confirm 'Mettre à jour Firefox ?'; then logiciels_apply_updates "$ff" '' ''; return 0; fi
         else echo '[INFO] Firefox est déjà à jour.'; pause; fi ;;
      2) if [[ "$fz" == 'MAJ DISPONIBLE' ]]; then
           if confirm 'Mettre à jour FileZilla ?'; then logiciels_apply_updates '' "$fz" ''; return 0; fi
         else echo '[INFO] FileZilla est déjà à jour.'; pause; fi ;;
      3) if [[ "$pz" == 'MAJ DISPONIBLE' ]]; then
           if confirm 'Mettre à jour PeaZip ?'; then logiciels_apply_updates '' '' "$pz"; return 0; fi
         else echo '[INFO] PeaZip est déjà à jour.'; pause; fi ;;
      4) if [[ "$ff$fz$pz" != *'MAJ DISPONIBLE'* ]]; then echo '[INFO] Aucune mise à jour disponible.'; pause;
         elif confirm 'Appliquer toutes les mises à jour disponibles ?'; then logiciels_apply_updates "$ff" "$fz" "$pz"; return 0; fi ;;
      0) return 0 ;;
      *) echo '[INFO] Choix invalide.'; pause ;;
    esac
  done
}

logiciels_menu(){
  local choice fv fzv pzv kv ffstatus fzstatus pzstatus remote scope
  local updates=0 needs_check=0 fzscope pzscope
  while :; do
    refresh_screen
    ui_section 'LOGICIELS'
    fv='Non installé'; ffstatus=''
    if [[ -x "$FF_ROOT/firefox" ]]; then
      fv="$(firefox_installed_version)"
    fi
    fzv="$(flatpak_app_version 'org.filezillaproject.Filezilla')"
    pzv="$(flatpak_app_version 'io.github.peazip.PeaZip')"
    [[ "$fzv" == 'non installe' ]] && fzv='Non installé'
    [[ "$pzv" == 'non installe' ]] && pzv='Non installé'
    fzscope='absent'; pzscope='absent'
    [[ "$fzv" == 'Non installé' ]] || fzscope="$(flatpak_app_scope 'org.filezillaproject.Filezilla')"
    [[ "$pzv" == 'Non installé' ]] || pzscope="$(flatpak_app_scope 'io.github.peazip.PeaZip')"
    needs_check=0
    if [[ "$fv" != 'Non installé' ]] && logiciels_cache_needs_check firefox "$fv" local; then needs_check=1; fi
    if [[ "$fzv" != 'Non installé' ]] && logiciels_cache_needs_check filezilla "$fzv" "$fzscope"; then needs_check=1; fi
    if [[ "$pzv" != 'Non installé' ]] && logiciels_cache_needs_check peazip "$pzv" "$pzscope"; then needs_check=1; fi
    if (( needs_check )); then
      ui_print info '  Vérification des mises à jour...'
    fi
    if [[ "$fv" != 'Non installé' ]]; then
      ffstatus="$(logiciels_cached_status firefox "$fv" local logiciels_firefox_status "$fv")"
    fi
    fzstatus=''; pzstatus=''
    if [[ "$fzv" != 'Non installé' ]]; then
      fzstatus="$(logiciels_cached_status filezilla "$fzv" "$fzscope" logiciels_flatpak_status filezilla org.filezillaproject.Filezilla "$fzscope")"
    fi
    if [[ "$pzv" != 'Non installé' ]]; then
      pzstatus="$(logiciels_cached_status peazip "$pzv" "$pzscope" logiciels_flatpak_status peazip io.github.peazip.PeaZip "$pzscope")"
    fi
    kv="$(kodi_installed_version)"
    updates=0
    [[ "$ffstatus" == 'MAJ DISPONIBLE' ]] && updates=1
    [[ "$fzstatus" == 'MAJ DISPONIBLE' ]] && updates=1
    [[ "$pzstatus" == 'MAJ DISPONIBLE' ]] && updates=1
    refresh_screen
    ui_section 'LOGICIELS'
    logiciels_menu_item 1 Firefox "$fv" "$ffstatus" firefox
    logiciels_menu_item 2 FileZilla "$fzv" "$fzstatus" filezilla
    logiciels_menu_item 3 PeaZip "$pzv" "$pzstatus" peazip
    logiciels_menu_item 4 Kodi "$kv" '' kodi
    echo
    ui_installation_legend
    echo
    ui_item '5) Mises à jour'
    echo
    ui_item '0) Retour'
    ui_item 'Q) Quitter le gestionnaire'
    echo
    choice="$(read_key 'Votre choix : ')" || return 0
    case "$choice" in
      1) manage_firefox || { echo '[ATTENTION] Operation Firefox non terminee.'; pause; } ;;
      2) manage_flatpak_app filezilla ;;
      3) manage_flatpak_app peazip ;;
      4) manage_kodi ;;
      5) logiciels_choose_updates "$ffstatus" "$fzstatus" "$pzstatus" ;;
      0) return 0 ;;
      *) echo '[INFO] Choix invalide.'; pause ;;
    esac
  done
}

# Lecture sure du journal : ne transmet jamais les commandes de controle au terminal.
# Les fichiers historiques restent intacts.
show_safe_journal(){
  local source="$LOG"
  [[ -f "$source" ]] || { echo '[INFO] Aucun journal pour cette session.'; return 0; }
  python3 - "$source" <<'PYSAFELOG'
import pathlib, re, sys
source = pathlib.Path(sys.argv[1])
try:
    raw = source.read_bytes()
except OSError as exc:
    print('[ERREUR] Lecture du journal impossible :', exc)
    sys.exit(0)
# Supprimer d abord les sequences d echappement completes, avant le decodage.
raw = re.sub(rb'\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)', b'', raw)
raw = re.sub(rb'\x1b[P_X^][\s\S]*?\x1b\\', b'', raw)
raw = re.sub(rb'\x1b\[[0-?]*[ -/]*[@-~]', b'', raw)
raw = re.sub(rb'\x1b[@-_]', b'', raw)
text = raw.decode('utf-8', errors='replace')
# Eliminer toutes les commandes de controle restantes (CR, effacement, etc.).
text = ''.join(ch for ch in text if ch == '\n' or ch == '\t' or (ch.isprintable() and ch != '\x7f'))
lines = []
for line in text.splitlines():
    line = line.strip()
    if not line:
        continue
    # Le journal doit montrer les operations, pas les cadres et menus.
    if any(x in line for x in ('╔', '╗', '╚', '╝', '═', '║', '─')):
        continue
    if line.startswith(('★', '* BLONDIN EDITION', '● GESTIONNAIRE PRET', '● PRÊT', 'VERSION 1.6.', 'VERSION 2.', 'GESTIONNAIRE BATOCERA')):
        continue
    if re.match(r'^\[\d+\]\s', line) or re.match(r'^\d{2}\s+▸', line) or line.startswith(('CHOIX ›', 'Appuyer sur une touche', 'Une touche pour continuer', 'pour acceder au menu')):
        continue
    # Affichage ASCII uniquement pour eviter les problemes d encodage SSH.
    line = line.encode('ascii', errors='replace').decode('ascii')
    lines.append(line)
print('===== JOURNAL DE LA SESSION =====')
print('Fichier :', source)
if lines:
    print('\n'.join(lines[-60:]))
else:
    print('[INFO] Aucune operation enregistree pour le moment.')
PYSAFELOG
}

# Diagnostic des services V1.6.117 TEST : lecture seule par defaut.
# Verifie les arguments exacts des processus dans /proc (pas de pgrep -f ambigu).
diag_process(){
  python3 - "$1" <<'PYDIAGPROC'
import os,sys
needle=sys.argv[1]
found=[]
for entry in os.scandir('/proc'):
    if not entry.name.isdigit(): continue
    try:
        raw=open(f'/proc/{entry.name}/cmdline','rb').read()
        args=[x.decode('utf-8','replace') for x in raw.split(b'\0') if x]
        if needle in args and any('python' in os.path.basename(a) for a in args[:2]):
            found.append(entry.name)
    except (OSError,PermissionError): pass
print(', '.join(found) if found else '-')
PYDIAGPROC
}
diag_enabled(){
  local enabled
  enabled="$(batocera-settings-get system.services 2>/dev/null || true)"
  [[ " $enabled " == *" $1 "* ]]
}
# Couleurs ANSI via ui_print : aucun code couleur dans les journaux.
diag_line(){
  local label="$1" role="$2" state="$3"
  ui_print "$role" "  $(printf '%-22s' "$label") ● $state"
}
diag_service(){
  local id="$1" label="$2" script="$3" process="$4" pids
  if [[ ! -s "/userdata/system/services/$id" || ! -s "$script" ]]; then
    diag_line "$label" warning 'INCOMPLET'; return
  fi
  pids="$(diag_process "$process")"
  if diag_enabled "$id"; then
    if [[ "$pids" != '-' ]]; then diag_line "$label" success 'ACTIF'
    else diag_line "$label" error 'ARRÊTÉ'; fi
  elif [[ "$pids" != '-' ]]; then
    diag_line "$label" warning 'À VÉRIFIER'
  else
    diag_line "$label" menu 'DÉSACTIVÉ'
  fi
}
diag_overview(){
  local trigger='/userdata/system/configs/emulationstation/scripts/screensaver-start/shutdown-trigger.sh'
  local cancel='/userdata/system/configs/emulationstation/scripts/screensaver-stop/shutdown-cancel.sh'
  local workers count
  ui_section 'ÉTAT DES SERVICES'
  diag_service notifications_extinction_ntfy 'Notifications ntfy' /userdata/system/notifications-extinction-ntfy/watch.py /userdata/system/notifications-extinction-ntfy/watch.py
  diag_service volume_hotkey 'Volume Hotkey' /userdata/system/volume-hotkey.py /userdata/system/volume-hotkey.py
  if [[ ! -s "$trigger" || ! -s "$cancel" || ! -x "$trigger" || ! -x "$cancel" ]]; then
    diag_line "Minuteur d'extinction" warning 'INCOMPLET'
  else
    workers="$(shutdown_workers list 2>/dev/null)"
    if [[ -z "$workers" ]]; then
      if [[ -e /tmp/shutdown.screensaver ]]; then diag_line "Minuteur d'extinction" warning 'À VÉRIFIER'
      else diag_line "Minuteur d'extinction" warning 'EN ATTENTE'; fi
    else
      count="$(printf '%s\n' "$workers" | grep -c .)"
      if [[ "$count" -eq 1 ]]; then diag_line "Minuteur d'extinction" success 'EN COURS'
      else diag_line "Minuteur d'extinction" error 'PLUSIEURS MINUTEURS'; fi
    fi
  fi
  if diag_enabled syncthing; then
    diag_line Syncthing info 'ACTIVÉ (non testé)'
  else
    diag_line Syncthing menu 'DÉSACTIVÉ'
  fi
  echo
  ui_print info '  Lecture seule : aucun service modifié.'
}
diag_restart(){
  local name="$1" label="$2" service="/userdata/system/services/$1"
  [[ -x "$service" ]] || { echo '[ERREUR] Service absent ou non executable.'; return 1; }
  diag_enabled "$name" || { echo '[ATTENTION] Service non active dans Batocera.'; return 1; }
  confirm "Confirmer le redemarrage de $label ?" || { echo '[INFO] Annule.'; return 0; }
  echo "[ACTION] Arret de $label..."
  if ! "$service" stop; then echo '[ERREUR] Arret impossible.'; return 1; fi
  sleep 1
  echo "[ACTION] Demarrage de $label..."
  if ! "$service" start; then echo '[ERREUR] Demarrage impossible.'; return 1; fi
  sleep 1
  diag_overview
}
diag_restart_menu(){
  local choice
  while :; do
    refresh_screen
    ui_section 'REDÉMARRER UN SERVICE'
    ui_item '1) Notifications ntfy'
    ui_item '2) Volume Hotkey'
    echo
    ui_item '0) Retour'
    ui_item 'Q) Quitter le gestionnaire'
    choice="$(read_key 'Votre choix : ')" || return 0
    case "$choice" in
      1) diag_restart notifications_extinction_ntfy ntfy; pause ;;
      2) diag_restart volume_hotkey 'Volume Hotkey'; pause ;;
      0) return 0 ;;
      *) echo 'Choix invalide.'; pause ;;
    esac
  done
}

diag_menu(){
  local choice
  while :; do
    refresh_screen
    ui_section 'DIAGNOSTIC DU SYSTÈME'
    ui_item '1) Vérifier les installations'
    ui_item '2) État des services'
    ui_item '3) Redémarrer un service'
    echo
    ui_item '0) Retour'
    ui_item 'Q) Quitter le gestionnaire'
    choice="$(read_key 'Votre choix : ')" || return 0
    case "$choice" in
      1) if [[ "${BLONDIN_PORTS_PAD:-0}" == 1 ]]; then manager_paged_output check_installations; else refresh_screen; check_installations; pause; fi ;;
      2) if [[ "${BLONDIN_PORTS_PAD:-0}" == 1 ]]; then manager_paged_output diag_overview; else refresh_screen; diag_overview; pause; fi ;;
      3) diag_restart_menu ;;
      0) return 0 ;;
      *) echo 'Choix invalide.'; pause ;;
    esac
  done
}

# Syncthing : configuration locale via API REST, sans installation automatique.
syncthing_menu(){
  python3 - <<'PYSYN'
import json, os, pathlib, shutil, sys, urllib.request, urllib.error, urllib.parse, xml.etree.ElementTree as ET, datetime, ipaddress, subprocess, time, re, builtins
T = os.fdopen(os.open('/dev/tty', os.O_RDONLY), 'r', encoding='utf-8') if os.path.exists('/dev/tty') else sys.stdin
BASE=pathlib.Path('/userdata/saves/Installscripts/saves/Syncthing')
# Affichage cohérent, compatible terminaux SSH Android étroits.
_CYAN='\033[1;96m'; _GOLD='\033[1;33m'; _WHITE='\033[0;37m'
_GREEN='\033[1;32m'; _RED='\033[1;31m'; _ORANGE='\033[1;38;5;208m'; _RESET='\033[0m'
_raw_print=builtins.print
def menu_marker(number):
    code=str(number).upper()
    if code=='0': return '0 ‹'
    if code=='Q': return 'Q ×'
    if code.isdigit(): return f'{int(code):02d} ▸'
    return code+' ▸'
def print(*args, **kwargs):
    # Ne reformater que les lignes simples de menus historiques.
    if len(args)==1 and isinstance(args[0],str) and '\033[' not in args[0]:
        lines=[]
        for line in args[0].split('\n'):
            m=re.fullmatch(r'\s*\[([0-9]+|[QqAaMmSsVv])\]\s+(.+)',line)
            if m:
                line=f'  {_GOLD}{menu_marker(m.group(1))}{_RESET}  {_WHITE}{m.group(2)}{_RESET}'
            elif re.fullmatch(r'\s*={3,}.*={3,}\s*',line):
                title=line.strip(' =')
                line=f'{_CYAN}  --- {title} ---{_RESET}'
            lines.append(line)
        args=('\n'.join(lines),)
    _raw_print(*args,**kwargs)
def clear_menu():
    if os.isatty(T.fileno()):
        _raw_print('\033[H\033[2J',end='',flush=True)
def menu_option(number,label):
    _raw_print(f'  {_GOLD}{menu_marker(number)}{_RESET}  {_WHITE}{label}{_RESET}')

def ask(prompt):
    print(prompt,end='',flush=True)
    return T.readline().strip()
def menu_key(prompt='Votre choix : ', multi=False):
    # Menus : une touche sans Entrée ; 0,8 s pour composer 10/11.
    # Les champs de texte et confirmations restent saisis avec Entrée.
    import select, termios, tty
    if not os.isatty(T.fileno()):
        return ask(prompt).lower()
    fd=T.fileno()
    print('  CHOIX › ',end='',flush=True)
    previous=termios.tcgetattr(fd)
    try:
        tty.setcbreak(fd)
        first=os.read(fd,1).decode('utf-8','ignore')
        if first=='\x03': raise KeyboardInterrupt
        if first=='\r' or first=='\n': return ''
        result=first
        if multi and first=='1':
            ready,_,_=select.select([fd],[],[],0.8)
            if ready:
                second=os.read(fd,1).decode('utf-8','ignore')
                if second in ('0','1'): result+=second
                elif second not in ('\r','\n'): result='?'
        return result.lower()
    finally:
        termios.tcsetattr(fd,termios.TCSADRAIN,previous)
        print(result if 'result' in locals() else '',flush=True)
def confirm(message): return ask(message+' [o/N] : ').lower() in ('o','oui')
def pause(): ask('Entrée pour continuer... ')
def locate():
    candidates=[pathlib.Path('/userdata/system/configs/syncthing/config.xml'),pathlib.Path('/userdata/system/configs/syncthing/config/config.xml'),pathlib.Path('/userdata/system/.config/syncthing/config.xml'),pathlib.Path('/userdata/system/.local/state/syncthing/config.xml')]
    for p in candidates:
        if p.is_file(): return p
    for root in ('/userdata/system/configs/syncthing','/userdata/system/.config/syncthing'):
        if pathlib.Path(root).is_dir():
            for p in pathlib.Path(root).glob('*/config.xml'):
                if p.is_file(): return p
    return None
class Client:
    def __init__(self):
        p=locate()
        if not p: raise RuntimeError('Syncthing non initialisé : démarrez le service avec [1], après confirmation.')
        self.xml=p
        tree=ET.parse(p); gui=tree.getroot().find('gui')
        if gui is None: raise RuntimeError('Paramètres API absents du fichier Syncthing.')
        self.key=(gui.findtext('apikey') or '').strip()
        addr=(gui.findtext('address') or '127.0.0.1:8384').strip()
        if not self.key: raise RuntimeError('Clé API Syncthing introuvable.')
        if addr.startswith('unix://'): raise RuntimeError('Interface API Unix non prise en charge.')
        if addr.startswith('['):
            host,_,port=addr[1:].partition(']:')
            if host in ('::','::1'): host='127.0.0.1'
        else:
            host,sep,port=addr.rpartition(':')
            if not sep: host,port=addr,'8384'
            if host in ('0.0.0.0','::','localhost',''): host='127.0.0.1'
        try:
            ip=ipaddress.ip_address(host)
            if not ip.is_loopback: host='127.0.0.1'
        except ValueError:
            if host!='127.0.0.1': raise RuntimeError('Adresse API non locale, opération refusée.')
        if not port.isdigit(): raise RuntimeError('Port API invalide.')
        self.base='http://127.0.0.1:'+port
    def req(self,method,path,data=None):
        body=None if data is None else json.dumps(data).encode()
        req=urllib.request.Request(self.base+'/rest/'+path, data=body, method=method,headers={'X-API-Key':self.key,'Content-Type':'application/json'})
        with urllib.request.urlopen(req,timeout=6) as r:
            raw=r.read()
        return json.loads(raw) if raw else {}
    def get(self,path): return self.req('GET',path)
    def put(self,path,data): return self.req('PUT',path,data)
    def backup(self):
        BASE.mkdir(parents=True,exist_ok=True)
        dest=BASE/('config-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')+'-'+syncthing_local_label()+'.json')
        with dest.open('x') as f: json.dump(self.get('config'),f,indent=2)
        os.chmod(dest,0o600)
        print('Sauvegarde configuration :',dest)
    def edit(self,config):
        self.backup()
        self.put('config',config)
        print('Configuration enregistrée. Syncthing appliquera les modifications nécessaires.')
# Archives locales : hors du dossier de synchronisation Saves.
ARCHIVES=pathlib.Path('/userdata/saves/Installscripts/saves/Syncthing/ArchivesConfiguration')
CONFIG_DIR=pathlib.Path('/userdata/system/configs/syncthing')
# Les noms locaux dans config.xml peuvent être identiques ("BATOCERA").
# Identification à partir de l'identité Syncthing, jamais du nom réseau.
SYNCTHING_DEVICE_LABELS={
    '2OEH6G3-H53N4DI-OW6TDFD-Y2IANWF-4Q22456-HCYWPQ2-SJ52RLF-W5APQAE':'Minisforum',
    'GVQLCSP-XN6PSFB-E5QO2CN-TMBYW5T-EMNWSOY-WPVUDJ2-MVJUL7U-JITLTQW':'Steamdeck',
}
# Empreintes SHA256 des certificats actuels, pour identifier aussi les
# anciennes archives sans les renommer ni exposer les clés privées.
SYNCTHING_CERT_LABELS={
    '596a024f389ec867ef98f26a90b011deec2cb4b3d76eeee66250419a15d8565d':'Minisforum',
    'b42a8b0ca84ff36bd29b9f78738264cb46fff56849ce1d32c34e2751cf8f7a1d':'Steamdeck',
}
# Anciens noms sans étiquette acceptés; les nouveaux portent le nom après la date.
SYNCTHING_JSON_PATTERN=re.compile(r'config-\d{8}-\d{6}-\d{6}(?:-(?:Minisforum|Steamdeck|Batocera-[A-Z2-7]{7}))?\.json')

def syncthing_local_label():
    import hashlib
    cert=CONFIG_DIR/'cert.pem'
    if cert.is_file() and not cert.is_symlink():
        digest=hashlib.sha256(cert.read_bytes()).hexdigest()
        known=SYNCTHING_CERT_LABELS.get(digest)
        if known: return known
    # Fournit un identifiant unique lisible après un futur changement d'identité.
    p=subprocess.run(
        ['syncthing','device-id','--home='+str(CONFIG_DIR)],
        capture_output=True,text=True,timeout=10
    )
    device_id=p.stdout.strip()
    if p.returncode or not re.fullmatch(r'[A-Z2-7]{7}(?:-[A-Z2-7]{7}){7}',device_id):
        raise RuntimeError('Identité Syncthing introuvable : sauvegarde non créée.')
    return SYNCTHING_DEVICE_LABELS.get(device_id,'Batocera-'+device_id[:7])

def syncthing_backup_label(kind,path):
    if kind=='JSON':
        return syncthing_json_label(path) or 'Ancienne identité'
    digest=syncthing_archive_identity(path)
    if not digest:
        return 'Archive non identifiée'
    name=SYNCTHING_CERT_LABELS.get(digest)
    if name: return name
    import hashlib
    cert=CONFIG_DIR/'cert.pem'
    if cert.is_file() and not cert.is_symlink():
        if hashlib.sha256(cert.read_bytes()).hexdigest()==digest:
            return syncthing_local_label()
    return 'Ancienne identité'

def syncthing_archive_identity(path):
    import hashlib, tarfile
    try:
        with tarfile.open(path,'r:gz') as tar:
            members=[m for m in tar.getmembers() if m.name=='config/cert.pem']
            if len(members)!=1 or not members[0].isfile() or not (0<members[0].size<100000):
                return None
            stream=tar.extractfile(members[0])
            if stream is None: return None
            with stream:
                return hashlib.sha256(stream.read()).hexdigest()
    except (OSError,tarfile.TarError,EOFError):
        return None

def syncthing_archive_matches_local(path):
    import hashlib, tarfile
    cert=CONFIG_DIR/'cert.pem'
    key=CONFIG_DIR/'key.pem'
    if any(not f.is_file() or f.is_symlink() for f in (cert,key)):
        return False
    try:
        with tarfile.open(path,'r:gz') as tar:
            for filename,active in (('cert.pem',cert),('key.pem',key)):
                m=tar.getmember('config/'+filename)
                if not m.isfile() or m.size>100000: return False
                with tar.extractfile(m) as f:
                    if hashlib.sha256(f.read()).digest()!=hashlib.sha256(active.read_bytes()).digest():
                        return False
        return True
    except (OSError,KeyError,tarfile.TarError,EOFError):
        return False

def syncthing_json_label(path):
    match=re.fullmatch(r'config-\d{8}-\d{6}-\d{6}-(Minisforum|Steamdeck|Batocera-[A-Z2-7]{7})\.json',path.name)
    return match.group(1) if match else None

# Anciennes sauvegardes de l'API Syncthing, creees par Client.backup().
# Elles ne contiennent ni les cles de l'appareil ni son index de synchronisation.
# Restauration distincte des archives .tar.gz et uniquement via l'API locale.
def syncthing_json_restore_menu(selected_file=None):
    if BASE.is_symlink() or not BASE.is_dir():
        print('[SÉCURITÉ] Dossier de sauvegarde absent ou non sûr.')
        return
    names=SYNCTHING_JSON_PATTERN
    if selected_file is None:
        # Compatibilite avec les anciens appels du menu JSON.
        files=sorted((p for p in BASE.iterdir()
                      if names.fullmatch(p.name) and p.is_file() and not p.is_symlink()),
                     reverse=True)
        if not files:
            print('[INFO] Aucune sauvegarde JSON disponible.')
            return
        for i,p in enumerate(files,1):
            print(f'[{i}] JSON - {syncthing_backup_label("JSON",p)}')
            print('    '+p.name)
        selected=ask('Numéro à restaurer (0 = annuler) : ')
        if selected=='0': return
        if not selected.isdigit() or not 1<=int(selected)<=len(files):
            print('[INFO] Choix invalide.')
            return
        p=files[int(selected)-1]
    else:
        p=pathlib.Path(selected_file)
        if p.parent != BASE or not names.fullmatch(p.name):
            print('[SÉCURITÉ] Fichier JSON hors dossier ou nom inattendu.')
            return
    # Une ancienne sauvegarde JSON sans provenance est consultable et supprimable,
    # mais pas restaurable de manière fiable : elle contient tous les appareils.
    archive_label=syncthing_json_label(p)
    if archive_label != syncthing_local_label():
        print('[SÉCURITÉ] Provenance JSON non vérifiée pour cet appareil.')
        print('[INFO] Restauration refusée ; fichier conservé.')
        return
    print('[INFO] Restauration JSON : Syncthing doit être démarré.')
    print('[INFO] Clés privées et index conservés.')
    try:
        if p.is_symlink() or not p.is_file() or p.stat().st_size>10_000_000:
            raise RuntimeError('Fichier non ordinaire ou trop volumineux.')
        with p.open('r',encoding='utf-8') as f:
            saved=json.load(f)
        def check_config(data):
            if not isinstance(data,dict):
                raise RuntimeError('Contenu JSON invalide.')
            if (not isinstance(data.get('folders'),list) or
                not isinstance(data.get('devices'),list) or
                not isinstance(data.get('gui'),dict) or
                not isinstance(data.get('version'),int)):
                raise RuntimeError('Sauvegarde non reconnue comme une configuration Syncthing.')
            if any(not isinstance(d,dict) or not isinstance(d.get('deviceID'),str)
                   for d in data['devices']):
                raise RuntimeError('Liste des appareils invalide.')
            if any(not isinstance(f,dict) or not isinstance(f.get('id'),str)
                   for f in data['folders']):
                raise RuntimeError('Liste des dossiers invalide.')
        check_config(saved)
        if not running():
            raise RuntimeError('Syncthing arrêté : démarrez son service avant de restaurer un JSON.')
        client=Client()
        status=client.get('system/status')
        own_id=status.get('myID') if isinstance(status,dict) else None
        if not isinstance(own_id,str) or len(own_id)<50:
            raise RuntimeError('Identité locale non vérifiable : restauration refusée.')
        current=client.get('config')
        check_config(current)
        for cfg in (saved,current):
            if own_id not in {d['deviceID'] for d in cfg['devices']}:
                raise RuntimeError('Identité différente : sauvegarde non destinée à cet appareil.')
        if saved['version']>current['version']:
            raise RuntimeError('Version de configuration plus récente que le Syncthing actif.')
        if saved==current:
            print('[INFO] Cette configuration est déjà active.')
            return
        print('\nSauvegarde :',p.name)
        print('Dossiers   :',len(current['folders']),'actuel(s) ->',len(saved['folders']),'archivé(s)')
        print('Appareils  :',len(current['devices']),'actuel(s) ->',len(saved['devices']),'archivé(s)')
        print('[ATTENTION] Les dossiers partagés, appareils et paramètres seront remplacés.')
        print('[INFO] Les clés et les données synchronisées ne seront pas effacées.')
        if not confirm('Restaurer cette ancienne configuration JSON ?'):
            print('[INFO] Annulé.'); return
        if ask('Tapez RESTAURER pour confirmer : ')!='RESTAURER':
            print('[INFO] Annulé.'); return
        # Refuser d'ecraser une configuration modifiee pendant les confirmations.
        if client.get('config')!=current:
            raise RuntimeError('Configuration active modifiée entre-temps : opération annulée.')
        # Sauvegarde d'urgence : echec = aucune restauration.
        client.backup()
        client.put('config',saved)
        print('[OK] Configuration JSON transmise à Syncthing.')
        print('[INFO] L’ancienne configuration active a été sauvegardée au préalable.')
        print('[INFO] Vérifiez les dossiers, appareils et l’état du service.')
    except Exception as e:
        print('[ERREUR] Restauration JSON :',e)
        print('[SÉCURITÉ] Sauvegarde sélectionnée conservée.')

def config_archives_menu():
    import tarfile, tempfile, hashlib, stat
    COLOR_CYAN='\033[1;96m'; COLOR_YELLOW='\033[1;33m'
    COLOR_WHITE='\033[0;37m'; COLOR_GREY='\033[0;90m'
    COLOR_RED='\033[1;31m'; COLOR_GREEN='\033[1;32m'; OFF='\033[0m'

    def line(message='', color=COLOR_WHITE):
        _raw_print(color + str(message) + OFF, flush=True)
    def header(label):
        clear_menu()
        line('  +-----------------------------------+',COLOR_CYAN)
        line('  | '+label.center(33)+' |',COLOR_CYAN)
        line('  +-----------------------------------+',COLOR_CYAN)
        line()
    def option(code,label):
        line(f'  {COLOR_YELLOW}{menu_marker(code)}{OFF}  {COLOR_WHITE}{label}{OFF}',color='')
    def footer():
        line()
        option('0','Retour')
        option('Q','Quitter le gestionnaire')
        line()
    def info(message): line('[INFO] '+message,COLOR_GREY)
    def ok(message): line('[OK] '+message,COLOR_GREEN)
    def warn(message): line('[ATTENTION] '+message,COLOR_YELLOW)
    def error(message): line('[ERREUR] '+message,COLOR_RED)

    def files_to_save():
        config=CONFIG_DIR/'config.xml'
        if not config.is_file() or config.is_symlink():
            raise RuntimeError('config.xml introuvable ou non sûr.')
        ET.parse(config)
        names=('config.xml','cert.pem','key.pem','https-cert.pem','https-key.pem')
        files=[(CONFIG_DIR/n,'config/'+n) for n in names
               if (CONFIG_DIR/n).is_file() and not (CONFIG_DIR/n).is_symlink()]
        ign=pathlib.Path('/userdata/saves/.stignore')
        if ign.is_file() and not ign.is_symlink():
            files.append((ign,'saves/.stignore'))
        return files

    def all_backups():
        entries=[]
        if ARCHIVES.is_dir() and not ARCHIVES.is_symlink():
            entries.extend(('TAR.GZ',p) for p in ARCHIVES.iterdir()
                           if (p.name.startswith('syncthing-config-') or
                               p.name.startswith('avant-restauration-'))
                           and p.name.endswith('.tar.gz')
                           and p.is_file() and not p.is_symlink())
        if BASE.is_dir() and not BASE.is_symlink():
            entries.extend(('JSON',p) for p in BASE.iterdir()
                           if SYNCTHING_JSON_PATTERN.fullmatch(p.name)
                           and p.is_file() and not p.is_symlink())
        def date_key(item):
            m=re.search(r'\d{8}-\d{6}(?:-\d{6})?',item[1].name)
            return m.group(0) if m else ''
        return sorted(entries,key=date_key,reverse=True)

    def inspect_backups():
        # Cette verification sert aussi a proteger la derniere sauvegarde
        # reelle de chaque appareil. Les anciennes identites restent visibles.
        result=[]
        for kind,p in all_backups():
            label=(syncthing_backup_label(kind,p) if kind=='TAR.GZ'
                   else syncthing_json_label(p) or 'Ancienne identité')
            valid=False
            index=False
            fp=None
            try:
                if kind=='TAR.GZ':
                    fp=syncthing_archive_identity(p)
                    if fp:
                        index=validate_syncthing_archive(p)
                        valid=True
                else:
                    if p.stat().st_size<=10_000_000:
                        with p.open(encoding='utf-8') as f: obj=json.load(f)
                        valid=(isinstance(obj,dict)
                               and isinstance(obj.get('devices'),list)
                               and isinstance(obj.get('folders'),list)
                               and isinstance(obj.get('gui'),dict)
                               and isinstance(obj.get('version'),int))
            except Exception:
                pass
            result.append({'kind':kind,'path':p,'label':label,
                           'valid':valid,'index':index,'identity':fp,
                           'size':p.stat().st_size})
        # Protéger la dernière sauvegarde valide pour chacune de nos deux
        # machines ; une archive TAR.GZ (avec clés) est prioritaire.
        protected=set()
        for label in ('Minisforum','Steamdeck'):
            candidates=[x for x in result if x['valid'] and x['label']==label]
            if candidates:
                tar_candidates=[x for x in candidates if x['kind']=='TAR.GZ']
                chosen=(tar_candidates or candidates)[0]
                protected.add(chosen['path'])
        for x in result:
            x['protected']=x['path'] in protected
        return result

    def ordered(entries):
        return ([x for label in ('Minisforum','Steamdeck') for x in entries if x['label']==label]
                +[x for x in entries if x['label'] not in ('Minisforum','Steamdeck')])

    def backup_list(entries):
        items=ordered(entries)
        if not items:
            info('Aucune sauvegarde disponible.')
            return items
        for category,label in (('Minisforum','MINISFORUM'),('Steamdeck','STEAMDECK'),('other','ANCIENNES SAUVEGARDES')):
            group=[(i,x) for i,x in enumerate(items,1)
                   if (x['label']==category if category!='other'
                       else x['label'] not in ('Minisforum','Steamdeck'))]
            if not group: continue
            line(label,COLOR_CYAN)
            for index,x in group:
                p=x['path']; display=p.name
                stamp=re.search(r'\d{8}-\d{6}',display)
                date=(stamp.group(0)[6:8]+'/'+stamp.group(0)[4:6]+'/'+stamp.group(0)[:4]
                      if stamp else 'Date inconnue')
                state=('Protégée' if x['protected'] else
                       ('Archive invalide' if not x['valid'] else ''))
                line(f'  {COLOR_YELLOW}{menu_marker(index)}{OFF}  {COLOR_WHITE}{date} — {x["kind"]}{OFF}',color='')
                line('      '+display,COLOR_GREY)
                if category=='other': line('      Appareil : '+x['label'],COLOR_GREY)
                if state: line('      '+state,COLOR_YELLOW if not x['valid'] else COLOR_GREY)
            line()
        return items

    def pick(items):
        if not items: return None
        raw=ask('Numéro (0 = retour, Q = quitter) : ').strip().lower()
        if raw=='q': sys.exit(99)
        if raw=='0': return None
        if not raw.isdigit() or not 1<=int(raw)<=len(items):
            warn('Numéro invalide.')
            return None
        return items[int(raw)-1]

    def details(x):
        p=x['path']
        header('DETAIL DE LA SAUVEGARDE')
        line('Appareil   : '+x['label'])
        line('Nom        : '+p.name)
        line('Format     : '+x['kind'])
        line('Taille     : '+f'{x["size"]/1024**2:.2f} Mio')
        line('Clés       : '+('Présentes' if x['kind']=='TAR.GZ' and x['valid'] else 'Non garanties'))
        line('Index      : '+('Présent' if x['index'] else 'Absent / non vérifié'))
        line('Vérification : '+('Valide' if x['valid'] else 'Non validée'))
        if x['protected']: warn('Dernière sauvegarde de cet appareil : protégée')
        line()

    def delete_selected(x):
        if x['protected']:
            warn('Suppression refusée : dernière archive valide protégée.')
            return
        p=x['path']
        details(x)
        warn('Suppression définitive de cette archive seulement.')
        if not confirm('Supprimer cette sauvegarde ?'):
            info('Annulé.'); return
        if ask('Tapez SUPPRIMER pour confirmer : ')!='SUPPRIMER':
            info('Annulé.'); return
        # Revérifier après les confirmations : aucune suppression hors des
        # deux dossiers gérés, aucun lien symbolique, aucune archive protégée.
        current=inspect_backups()
        matching=[i for i in current if i['path']==p and i['kind']==x['kind']]
        if len(matching)!=1 or matching[0]['protected']:
            error('Archive devenue introuvable ou protégée.'); return
        if not p.parent in (BASE,ARCHIVES) or p.parent.is_symlink():
            error('Chemin non autorisé.'); return
        st=os.lstat(p)
        if not stat.S_ISREG(st.st_mode) or st.st_nlink!=1 or st.st_size!=x['size']:
            error('Archive modifiée, non ordinaire ou liée : suppression refusée.'); return
        p.unlink()
        ok('Sauvegarde supprimée : '+p.name)

    def manage_backups():
        while True:
            header('GESTION DES SAUVEGARDES')
            entries=inspect_backups()
            listed=backup_list(entries)
            footer()
            selected=pick(listed)
            if selected is None:
                return
            while True:
                details(selected)
                option('1','Afficher les informations')
                option('2','Supprimer cette sauvegarde')
                footer()
                ch=menu_key()
                if ch=='q': sys.exit(99)
                if ch=='0': break
                if ch=='1':
                    details(selected)
                    pause()
                elif ch=='2':
                    delete_selected(selected)
                    pause()
                    break
                else: warn('Choix invalide.')

    def restore_menu():
        while True:
            header('RESTAURATION SYNCTHING')
            line('Appareil actuel : '+syncthing_local_label())
            line('Service : '+('ACTIF' if running() else 'ARRÊTÉ'),
                 COLOR_GREEN if running() else COLOR_GREY)
            line()
            entries=inspect_backups()
            listed=backup_list(entries)
            if not listed:
                pause(); return
            warn('Une restauration peut remplacer les partages et paramètres.')
            footer()
            selected=pick(listed)
            if selected is None: return
            p=selected['path']; kind=selected['kind']
            details(selected)
            if not selected['valid']:
                error('Archive invalide : restauration refusée.')
                pause(); continue
            if kind=='JSON':
                if syncthing_json_label(p)!=syncthing_local_label():
                    error('JSON non attribuable à cet appareil : restauration refusée.')
                    pause(); continue
                syncthing_json_restore_menu(p)
                pause(); continue
            # Ne jamais restaurer des clés différentes de celles de l'appareil.
            # L'étiquette du fichier peut être mensongère ; les deux paires
            # de certificats et clés doivent être comparées octet à octet.
            if not syncthing_archive_matches_local(p):
                error('Identité différente : restauration TAR.GZ bloquée.')
                warn('Ne pas restaurer les clés d’un autre appareil.')
                pause(); continue
            header('CONFIRMATION RESTAURATION')
            line('Appareil    : '+syncthing_local_label())
            line('Archive     : '+p.name)
            line('Identité    : Correspondante',COLOR_GREEN)
            line('Index       : '+('Présent' if selected['index'] else 'Absent'))
            warn('Syncthing doit être arrêté pour une restauration TAR.GZ.')
            option('1','Configuration seule')
            if selected['index']:
                option('2','Configuration + index')
                option('3','Index seul')
            footer()
            ch=menu_key()
            if ch=='q': sys.exit(99)
            if ch=='0': continue
            if ch not in (('1','2','3') if selected['index'] else ('1',)):
                warn('Choix indisponible.'); pause(); continue
            if not confirm('Confirmer la restauration ?'):
                info('Annulé.'); continue
            if ask('Tapez RESTAURER pour confirmer : ')!='RESTAURER':
                info('Annulé.'); continue
            if ch in ('2','3') and not confirm('Confirmer aussi la restauration de l’index ?'):
                info('Annulé.'); continue
            try:
                restore_syncthing_archive(p,ch)
                ok('Restauration terminée.')
            except Exception as e:
                error('Restauration : '+str(e))
                warn('Configuration et archives conservées si échec.')
            pause()
            return

    while True:
        header('CONFIGURATION SYNCTHING')
        option('1','Sauvegarder')
        option('2','Restaurer')
        option('3','Gérer les sauvegardes')
        footer()
        ch=menu_key()
        if ch=='q': sys.exit(99)
        if ch=='0': return
        if ch=='2': restore_menu(); continue
        if ch=='3': manage_backups(); continue
        if ch!='1': warn('Choix invalide.'); continue
        if not confirm('Créer une archive locale (clés privées incluses) ?'): continue
        files=files_to_save()
        inclure_index=confirm('Inclure l\'index Syncthing ?')
        index=CONFIG_DIR/'index-v0.14.0.db'
        if inclure_index:
            if running():
                error('Arrêtez Syncthing avant de sauvegarder l’index.')
                pause(); continue
            if not index.is_dir() or index.is_symlink():
                error('Index Syncthing absent ou non sûr.')
                pause(); continue
            fichiers_index=list(index.iterdir())
            if not fichiers_index or any(not f.is_file() or f.is_symlink() for f in fichiers_index):
                error('Structure de l’index inattendue.')
                pause(); continue
        if ARCHIVES.is_symlink():
            error('Dossier des archives non sûr.')
            pause(); continue
        ARCHIVES.mkdir(parents=True,exist_ok=True)
        os.chmod(ARCHIVES,0o700)
        dest=ARCHIVES/('syncthing-config-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')+'-'+syncthing_local_label()+'.tar.gz')
        fd,tmp=tempfile.mkstemp(prefix='.syncthing-',suffix='.tmp',dir=ARCHIVES)
        os.close(fd)
        try:
            with tarfile.open(tmp,'w:gz') as tar:
                for src,arc in files:
                    tar.add(src,arcname=arc,recursive=False)
                if inclure_index:
                    if running(): raise RuntimeError('Syncthing actif : sauvegarde annulée.')
                    for src in fichiers_index:
                        if not src.is_file() or src.is_symlink():
                            raise RuntimeError('Index modifié pendant la sauvegarde.')
                        tar.add(src,arcname='index/index-v0.14.0.db/'+src.name,recursive=False)
                    if running(): raise RuntimeError('Syncthing redémarré : sauvegarde annulée.')
            with tarfile.open(tmp,'r:gz') as verification:
                membres=verification.getmembers()
                if not membres or any(not m.isfile() for m in membres):
                    raise RuntimeError('Archive invalide.')
                if inclure_index:
                    attendus={'index/index-v0.14.0.db/'+f.name for f in fichiers_index}
                    if not attendus.issubset({m.name for m in membres}):
                        raise RuntimeError('Index incomplet dans l’archive.')
            os.chmod(tmp,0o600)
            os.replace(tmp,dest)
            ok('Archive créée : '+dest.name)
            line('Appareil : '+syncthing_local_label())
            warn('Archive confidentielle : contient les clés privées.')
        except Exception as e:
            error('Sauvegarde impossible : '+str(e))
        finally:
            if os.path.exists(tmp): os.unlink(tmp)
        pause()
SERVICE_SCRIPT='/usr/share/batocera/services/syncthing'
def validate_syncthing_archive(selected):
    import tarfile
    import re

    allowed = {
        'config/config.xml',
        'config/cert.pem',
        'config/key.pem',
        'config/https-cert.pem',
        'config/https-key.pem',
        'saves/.stignore'
    }
    prefix = 'index/index-v0.14.0.db/'

    if selected.is_symlink() or not selected.is_file():
        raise RuntimeError('Archive absente ou lien symbolique interdit.')
    with tarfile.open(selected, 'r:gz') as tar:
        members = tar.getmembers()
        names = [m.name for m in members]

        if not members or len(members) > 10000:
            raise RuntimeError('Archive vide ou trop volumineuse.')

        if len(names) != len(set(names)):
            raise RuntimeError('Fichiers dupliqués.')

        total = 0
        index_names = []

        for m in members:
            if not m.isfile():
                raise RuntimeError('Type de fichier interdit.')

            if m.name in allowed:
                limit = 5_000_000
            elif m.name.startswith(prefix):
                name = m.name[len(prefix):]
                if not re.fullmatch(
                    r'[A-Za-z0-9][A-Za-z0-9._-]{0,127}',
                    name
                ) or '..' in name:
                    raise RuntimeError('Nom index invalide.')
                limit = 1_000_000_000
                index_names.append(m.name)
            else:
                raise RuntimeError('Chemin interdit : '+m.name)

            if m.size < 0 or m.size > limit:
                raise RuntimeError('Taille de fichier interdite.')

            total += m.size
            if total > 2_000_000_000:
                raise RuntimeError('Archive trop volumineuse.')

        # Lire intégralement chaque membre pour détecter les archives tronquées.
        for m in members:
            with tar.extractfile(m) as stream:
                remaining=m.size
                while remaining:
                    chunk=stream.read(min(1024*1024,remaining))
                    if not chunk:
                        raise RuntimeError('Archive tronquée : '+m.name)
                    remaining-=len(chunk)

        required = {
            'config/config.xml',
            'config/cert.pem',
            'config/key.pem'
        }
        if not required.issubset(names):
            raise RuntimeError('Configuration incomplète.')

        xml = tar.extractfile('config/config.xml').read()
        ET.fromstring(xml)

        if index_names:
            current_name = prefix+'CURRENT'
            if current_name not in names:
                raise RuntimeError('CURRENT manquant.')

            current = tar.extractfile(current_name).read()
            if len(current) > 256:
                raise RuntimeError('CURRENT invalide.')

            manifest = current.decode('ascii').strip()
            if not re.fullmatch(r'MANIFEST-[0-9]+', manifest):
                raise RuntimeError('Manifeste invalide.')

            if prefix+manifest not in names:
                raise RuntimeError('Manifeste absent.')

    return bool(index_names)

def syncthing_index_identity_matches(tar):
    import hashlib

    for name in ('cert.pem', 'key.pem'):
        active = CONFIG_DIR/name

        if not active.is_file() or active.is_symlink():
            raise RuntimeError(
                'Identité active introuvable : '+name
            )

        member = tar.getmember('config/'+name)
        if not member.isfile() or member.size > 5_000_000:
            raise RuntimeError(
                'Identité archivée invalide : '+name
            )

        with tar.extractfile(member) as stream:
            archived = hashlib.sha256(stream.read()).digest()

        current = hashlib.sha256(active.read_bytes()).digest()

        if archived != current:
            raise RuntimeError(
                'Identité différente : restauration index seul refusée.'
            )

    return True

def restore_syncthing_index(tar):
    import tempfile
    import tarfile

    syncthing_stopped_strict()

    prefix = 'index/index-v0.14.0.db/'
    target = CONFIG_DIR/'index-v0.14.0.db'

    members = [
        m for m in tar.getmembers()
        if m.name.startswith(prefix)
    ]

    if not members:
        raise RuntimeError('Index absent de cette archive.')

    if CONFIG_DIR.is_symlink() or not CONFIG_DIR.is_dir():
        raise RuntimeError('Dossier Syncthing invalide.')

    if target.is_symlink():
        raise RuntimeError('Index actif : lien symbolique interdit.')

    if target.exists() and not target.is_dir():
        raise RuntimeError('Index actif inattendu.')

    stage = pathlib.Path(tempfile.mkdtemp(
        prefix='.syncthing-index-stage-',
        dir=CONFIG_DIR
    ))

    backup = None

    try:
        for m in members:
            name = m.name[len(prefix):]
            dest = stage/name

            if not m.isfile() or '/' in name or not name:
                raise RuntimeError('Fichier index invalide.')

            with tar.extractfile(m) as src:
                with dest.open('xb') as out:
                    shutil.copyfileobj(src, out)

            os.chmod(dest, 0o600)

            if dest.stat().st_size != m.size:
                raise RuntimeError('Taille index incorrecte.')

        current = (stage/'CURRENT').read_text().strip()

        if not current.startswith('MANIFEST-'):
            raise RuntimeError('CURRENT invalide.')

        if not (stage/current).is_file():
            raise RuntimeError('Manifeste absent.')

        syncthing_stopped_strict()

        if target.is_symlink() or (target.exists() and not target.is_dir()):
            raise RuntimeError('Index actif modifié pendant la préparation.')
        if target.exists():
            stamp = datetime.datetime.now().strftime(
                '%Y%m%d-%H%M%S-%f'
            )
            backup = CONFIG_DIR/(
                '.index-v0.14.0.db-secours-'+stamp
            )
            os.replace(target, backup)

        try:
            syncthing_stopped_strict()
            os.replace(stage, target)
        except Exception:
            if backup is not None and not target.exists():
                os.replace(backup, target)
            raise

        print('[OK] Index Syncthing restauré.')

        if backup is not None:
            print('[SÉCURITÉ] Ancien index conservé :')
            print(backup)
        return backup

    finally:
        if stage.exists():
            try:
                shutil.rmtree(stage)
            except Exception as e:
                print(
                    '[ATTENTION] Nettoyage temporaire impossible :',
                    e
                )
                print('[INFO] Dossier à vérifier :', stage)

def restore_syncthing_archive(selected, choice):
    import tarfile, tempfile
    if choice not in ('1','2','3'):
        raise RuntimeError('Choix de restauration invalide.')
    with_index=choice in ('2','3')
    with_config=choice in ('1','2')
    has_index=validate_syncthing_archive(selected)
    if not syncthing_archive_matches_local(selected):
        raise RuntimeError('Identité archivée différente de la paire active : restauration refusée.')
    if with_index and not has_index:
        raise RuntimeError('Index absent de cette archive.')
    syncthing_stopped_strict()
    if CONFIG_DIR.is_symlink() or not CONFIG_DIR.is_dir():
        raise RuntimeError('Dossier de configuration inattendu.')
    if ARCHIVES.is_symlink():
        raise RuntimeError('Dossier des archives inattendu.')
    # Répertoire de travail isolé sur le même volume que /userdata.
    with tempfile.TemporaryDirectory(prefix='.syncthing-restore-',dir=CONFIG_DIR) as work:
        work=pathlib.Path(work)
        staged=work/'staged'
        previous=work/'previous'
        staged.mkdir(mode=0o700)
        previous.mkdir(mode=0o700)
        config_names=('config.xml','cert.pem','key.pem','https-cert.pem','https-key.pem')
        replacements=[]
        original=[]
        with tarfile.open(selected,'r:gz') as tar:
            if choice=='3':
                syncthing_index_identity_matches(tar)
            if with_config:
                for name in config_names:
                    arc='config/'+name
                    try:
                        member=tar.getmember(arc)
                    except KeyError:
                        continue
                    dest=CONFIG_DIR/name
                    replacements.append((member,dest,0o600))
                try:
                    member=tar.getmember('saves/.stignore')
                except KeyError:
                    pass
                else:
                    dest=pathlib.Path('/userdata/saves/.stignore')
                    replacements.append((member,dest,0o644))
                # Stage all new content and save originals before first replacement.
                for i,(member,dest,mode) in enumerate(replacements):
                    if dest.is_symlink() or (dest.exists() and not dest.is_file()):
                        raise RuntimeError('Destination non sûre : '+str(dest))
                    newfile=staged/str(i)
                    with tar.extractfile(member) as src, newfile.open('xb') as out:
                        shutil.copyfileobj(src,out)
                    if newfile.stat().st_size!=member.size:
                        raise RuntimeError('Extraction incomplète : '+member.name)
                    os.chmod(newfile,mode)
                    oldfile=previous/str(i)
                    existed=dest.exists()
                    if existed: shutil.copy2(dest,oldfile)
                    original.append((dest,oldfile,existed))
                ET.parse(staged/'0')  # config.xml est toujours le premier fichier.
                # Emergency archive of current configuration, outside work folder.
                ARCHIVES.mkdir(parents=True,exist_ok=True)
                os.chmod(ARCHIVES,0o700)
                emergency=ARCHIVES/('avant-restauration-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')+'.tar.gz')
                fd,tmp=tempfile.mkstemp(prefix='.avant-restauration-',dir=ARCHIVES)
                os.close(fd)
                try:
                    with tarfile.open(tmp,'w:gz') as out:
                        for dest,oldfile,existed in original:
                            if existed:
                                arc=('saves/.stignore' if dest.name=='.stignore' else 'config/'+dest.name)
                                out.add(oldfile,arcname=arc,recursive=False)
                    os.chmod(tmp,0o600)
                    os.replace(tmp,emergency)
                finally:
                    if os.path.exists(tmp): os.unlink(tmp)
                print('[SÉCURITÉ] Configuration précédente archivée :',emergency)
            # No changes to active files until all staging and validation succeeded.
            applied=[]
            index_installed=False
            index_backup=None
            try:
                for i,(_,dest,_) in enumerate(replacements):
                    syncthing_stopped_strict()
                    if dest.is_symlink() or (dest.exists() and not dest.is_file()):
                        raise RuntimeError('Destination modifiée : '+str(dest))
                    os.replace(staged/str(i),dest)
                    applied.append(i)
                if with_index:
                    syncthing_stopped_strict()
                    index_backup=restore_syncthing_index(tar)
                    index_installed=True
            except Exception:
                if index_installed:
                    # Index replacement succeeded but another operation failed.
                    target=CONFIG_DIR/'index-v0.14.0.db'
                    if target.is_dir() and not target.is_symlink():
                        failed=work/'failed-index'
                        os.replace(target,failed)
                    if index_backup is not None and index_backup.exists():
                        os.replace(index_backup,target)
                failures=[]
                for i in reversed(applied):
                    dest,oldfile,existed=original[i]
                    try:
                        if existed: os.replace(oldfile,dest)
                        elif dest.exists() and dest.is_file() and not dest.is_symlink(): dest.unlink()
                    except Exception as err:
                        failures.append(str(dest)+': '+str(err))
                if failures:
                    raise RuntimeError('Retour arrière incomplet : '+'; '.join(failures))
                raise
        print('[OK] Restauration terminée.')
        print('[CONTENU]',{'1':'configuration','2':'configuration + index','3':'index'}[choice])
        print('[INFO] Syncthing reste ARRÊTÉ. Vérifiez appareils et dossiers avant démarrage.')

def syncthing_stopped_strict():
    try:
        p=subprocess.run(
            ['pidof','syncthing'],
            capture_output=True,
            text=True,
            timeout=4
        )
    except Exception as e:
        raise RuntimeError(
            'Impossible de vérifier Syncthing : '+str(e)
        )
    if p.returncode == 0:
        raise RuntimeError(
            'Syncthing est actif : opération refusée.'
        )
    if p.returncode != 1:
        raise RuntimeError(
            'État de Syncthing incertain : opération refusée.'
        )
    return True

def running():
    try:
        p=subprocess.run(['pidof','syncthing'],capture_output=True,text=True,timeout=4)
        return p.returncode==0 and bool(p.stdout.strip())
    except Exception: return False
def enabled():
    try:
        p=subprocess.run(['batocera-services','list'],capture_output=True,text=True,timeout=8)
        for line in p.stdout.splitlines():
            parts=line.strip().split(';')
            if parts and parts[0].strip().lower()=='syncthing':
                return len(parts)>1 and parts[1].strip() not in ('-','0','off','disabled')
    except Exception: pass
    return None
def service_info():
    # Indicateurs communs aux menus Installation et Logiciels :
    # vert ✓ = confirmé, rouge ✗ = absent/désactivé, orange ◆ = indéterminé.
    active=running(); cfg=locate(); boot=enabled()
    def status_line(label, value, state):
        if state is True: color, glyph = _GREEN, '✓'
        elif state is False: color, glyph = _RED, '✗'
        else: color, glyph = _ORANGE, '◆'
        print(f'  {color}{glyph}  {label} : {value}{_RESET}', flush=True)
    status_line('Service', 'ACTIF' if active else 'ARRÊTÉ', active)
    status_line('Configuration', 'PRÉSENTE' if cfg else 'ABSENTE', bool(cfg))
    status_line('Démarrage auto', 'ACTIVÉ' if boot is True else 'DÉSACTIVÉ' if boot is False else 'INCONNU', boot)
    if not cfg and not active:
        print('Attention : identité non créée.', flush=True)
    return active,cfg,boot
def service_command(action):
    if not pathlib.Path(SERVICE_SCRIPT).is_file():
        print('ERREUR : script de service Batocera introuvable.'); return False
    try:
        p=subprocess.run([SERVICE_SCRIPT,action],capture_output=True,text=True,timeout=25)
        if p.stdout.strip(): print(p.stdout.strip())
        if p.returncode:
            print('ERREUR :',p.stderr.strip() or 'Commande refusée.'); return False
        return True
    except Exception as e:
        print('ERREUR :',e); return False
def service():
    # Menu Service regroupé : marche / arrêt, redémarrage et démarrage auto.
    while True:
        clear_menu()
        print('\n========== SERVICE SYNCTHING ==========')
        active,cfg,boot=service_info()
        print()
        menu_option('1','Arrêter' if active else 'Démarrer')
        menu_option('2','Redémarrer')
        menu_option('3','Démarrage automatique')
        print()
        menu_option('0','Retour')
        menu_option('Q','Quitter le gestionnaire')
        choice=menu_key()
        if choice=='0': return
        if choice=='q': sys.exit(99)
        if choice=='1':
            action='stop' if active else 'start'
            if not active and not cfg:
                print('ATTENTION : premier démarrage, une nouvelle identité Syncthing peut être créée.')
                print('Aucun dossier ni appareil ne sera associé automatiquement.')
            if not confirm(('Arrêter' if active else 'Démarrer')+' Syncthing ?'): continue
            if service_command(action):
                time.sleep(2)
                print('Résultat :','ACTIF' if running() else 'ARRÊTÉ')
                if action=='start' and not running():
                    print('ATTENTION : Syncthing ne semble pas avoir démarré. Consultez /userdata/system/logs/syncthing.log')
            pause()
        elif choice=='2':
            if confirm('Redémarrer le service Syncthing ?'):
                if service_command('restart'):
                    time.sleep(2)
                    print('Résultat :','ACTIF' if running() else 'ARRÊTÉ')
                pause()
        elif choice=='3':
            action='disable' if boot is True else 'enable'
            if not confirm(('Désactiver' if boot is True else 'Activer')+' Syncthing au démarrage ?'): continue
            try:
                p=subprocess.run(['batocera-services',action,'syncthing'],capture_output=True,text=True,timeout=15)
                if p.returncode: print('ERREUR :',p.stderr.strip() or p.stdout.strip() or 'Commande non prise en charge.')
                else: print('Paramètre enregistré.'); service_info()
            except Exception as e: print('ERREUR :',e)
            pause()
        else:
            print('Choix invalide.')
            pause()

def offline_folders():
    """Préparer un dossier local dans config.xml sans API ni démarrage."""
    if running():
        print('Syncthing est actif : utilisez le menu habituel.'); return
    path=locate()
    if not path:
        print('ERREUR : config.xml introuvable. Aucune modification.'); return
    try:
        tree=ET.parse(path); root=tree.getroot()
    except Exception as e:
        print('ERREUR : XML illisible :',e); return
    while True:
        print('\n========== DOSSIERS SYNCTHING (HORS LIGNE) ==========')
        print('Service : ARRÊTÉ — aucune synchronisation lancée')
        for i,f in enumerate(root.findall('folder'),1):
            print(f'[{i}] {f.get("label") or f.get("id")} — {f.get("path")} — {f.get("type","sendreceive")}')
        menu_option('A','Préparer un partage')
        menu_option('V','Vérifier la configuration')
        print()
        menu_option('0','Retour')
        menu_option('Q','Quitter le gestionnaire')
        choice=menu_key(multi=True)
        if choice=='0': return
        if choice=='q': sys.exit(99)
        if choice=='v':
            try:
                ET.parse(path)
                print('Configuration XML valide. Syncthing est toujours arrêté.')
            except Exception as e: print('ERREUR :',e)
            pause(); continue
        if choice!='a': continue
        fid=ask('Identifiant du dossier : ').strip()
        dest=ask('Chemin absolu : ').strip()
        label=ask('Nom affiché : ').strip() or fid
        if not fid or len(fid)>128 or any(c in fid for c in '/\\\r\n') or any(f.get('id')==fid for f in root.findall('folder')):
            print('ERREUR : identifiant invalide ou déjà utilisé.'); pause(); continue
        target=pathlib.Path(dest)
        if dest!='/userdata/saves' and (not dest.startswith('/userdata/') or '..' in target.parts):
            print('ERREUR : chemin hors de /userdata ou invalide.'); pause(); continue
        if not target.is_dir() or target.is_symlink():
            print('ERREUR : le dossier doit exister et ne pas être un lien symbolique.'); pause(); continue
        if fid=='iotzt-hrpt6' and dest!='/userdata/saves':
            print('ERREUR : le partage Saves attendu doit utiliser /userdata/saves.'); pause(); continue
        print('Préparation hors ligne :',label, fid, dest)
        print('Mode : sendonly (envoi uniquement). Aucun appareil distant autorisé.')
        print('Aucune synchronisation ne sera lancée. La configuration sera sauvegardée.')
        if not confirm('Enregistrer ce partage dans config.xml ?'): continue
        import copy
        draft=copy.deepcopy(root)
        folder=ET.SubElement(draft,'folder',{'id':fid,'label':label,'path':dest,'type':'sendonly','rescanIntervalS':'3600','fsWatcherEnabled':'false'})
        # Local device only, never authorize a remote device in offline mode.
        local_id=None
        for d in draft.findall('device'):
            if d.get('name')=='BATOCERA' and d.get('id'): local_id=d.get('id'); break
        # The local identity can be read from the XML root's own device element only
        # when unambiguous; otherwise Syncthing can populate it on startup.
        if local_id: ET.SubElement(folder,'device',{'id':local_id})
        stamp=datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
        BASE.mkdir(parents=True,exist_ok=True)
        backup=BASE/('config-offline-'+stamp+'.xml')
        temp=path.with_name('config.xml.tmp-'+stamp)
        try:
            shutil.copy2(path,backup)
            os.chmod(backup,0o600)
            ET.ElementTree(draft).write(temp,encoding='utf-8',xml_declaration=True)
            ET.parse(temp)
            os.chmod(temp,0o600)
            os.replace(temp,path)
            root=draft
            print('Sauvegarde :',backup)
            print('Partage préparé. Syncthing reste arrêté.')
            print('ATTENTION : ne démarrez pas Syncthing avant vérification des appareils et partages.')
        except Exception as e:
            print('ERREUR : aucune activation :',e)
            try: temp.unlink(missing_ok=True)
            except Exception: pass
        pause()

def folders(c):
    while True:
        cfg=c.get('config'); fs=cfg.get('folders',[])
        print('\nDOSSIERS SYNCTHING')
        for i,f in enumerate(fs,1): print(f'[{i}] {f.get("label") or f.get("id")} — {f.get("path")}')
        menu_option('A','Ajouter'); menu_option('M','Modifier'); menu_option('S','Retirer le partage'); menu_option('0','Retour')
        ch=menu_key('Choix : ')
        if ch=='0': return
        if ch=='a':
            fid=ask('Identifiant unique du dossier : '); path=ask('Chemin absolu existant : '); label=ask('Nom affiché : ') or fid
            if not fid or any(x.get('id')==fid for x in fs) or not path.startswith('/userdata/') or not pathlib.Path(path).is_dir(): print('ID ou chemin invalide.'); pause(); continue
            if not confirm(f'Partager {path} ?'): continue
            cfg['folders'].append({'id':fid,'label':label,'path':path,'type':'sendreceive','devices':[],'rescanIntervalS':3600})
        elif ch in ('m','s'):
            try: idx=int(ask('Numéro du dossier : '))-1; assert 0<=idx<len(fs)
            except Exception: print('Choix invalide.'); continue
            f=fs[idx]
            if ch=='m':
                label=ask('Nouveau nom (vide = conserver) : ')
                if not label: continue
                f['label']=label
            else:
                print('Les fichiers locaux ne seront pas supprimés.')
                if not confirm('Retirer ce dossier de Syncthing ?'): continue
                cfg['folders'].pop(idx)
        else: continue
        try: c.edit(cfg)
        except Exception as e: print('ÉCHEC :',e)
        pause()
def ignores(c):
    fs=c.get('config').get('folders',[])
    for i,f in enumerate(fs,1): print(f'[{i}] {f.get("label") or f.get("id")} — {f.get("path")}')
    try: idx=int(ask('Dossier (0 = retour) : '))-1; assert 0<=idx<len(fs)
    except Exception: return
    f=fs[idx]; fid=urllib.parse.quote(f['id'],safe='')
    while True:
        data=c.get('db/ignores?folder='+fid)
        patterns=data.get('ignore',[])
        print('\nEXCLUSIONS :',f.get('label') or f['id'])
        for i,x in enumerate(patterns,1): print(f'[{i}] {x}')
        menu_option('A','Ajouter'); menu_option('S','Supprimer'); menu_option('0','Retour')
        ch=menu_key('Choix : ')
        if ch=='0': return
        if ch=='a':
            rule=ask('Règle à exclure (ex. flatpak) : ')
            if not rule or '\n' in rule or '\r' in rule or rule.startswith('#') or len(rule)>250: print('Règle invalide.'); continue
            if rule in patterns: print('Règle déjà présente.'); continue
            new=patterns+[rule]
        elif ch=='s':
            try: idx=int(ask('Numéro de la règle : '))-1; assert 0<=idx<len(patterns)
            except Exception: continue
            new=patterns[:idx]+patterns[idx+1:]
        else: continue
        if not confirm('Enregistrer les nouvelles exclusions ?'): continue
        try:
            c.backup()
            c.put('db/ignores?folder='+fid,{'ignore':new})
            print('Exclusions enregistrées.')
        except Exception as e: print('ÉCHEC :',e)
        pause()
def devices(c):
    # Jamais d'action sur l'identité locale Syncthing.
    while True:
        cfg=c.get('config')
        me=c.get('system/status').get('myID')
        if not me:
            print('[ERREUR] Identifiant local non disponible.'); return
        ds=[d for d in cfg.get('devices',[]) if d.get('deviceID')!=me]
        clear_menu()
        print('\n========== APPAREILS ASSOCIÉS ==========')
        print('APPAREIL LOCAL')
        print(syncthing_local_label(),'— CET APPAREIL (',me[:7],')')
        print('APPAREILS DISTANTS :',len(ds))
        print()
        menu_option('1','Afficher les appareils')
        menu_option('2','Ajouter un appareil')
        menu_option('3','Renommer un appareil')
        menu_option('4','Retirer un appareil')
        print()
        menu_option('0','Retour')
        menu_option('Q','Quitter le gestionnaire')
        ch=menu_key()
        if ch=='0': return
        if ch=='q': sys.exit(99)
        if ch=='1':
            print('\nAPPAREILS DISTANTS')
            if not ds: print('Aucun appareil distant associé.')
            for i,d in enumerate(ds,1):
                print(f'[{i}] {d.get("name") or "Sans nom"} — {d.get("deviceID","")}')
            pause(); continue
        if ch=='2':
            did=ask('Identifiant complet Syncthing : ').upper().strip()
            name=ask('Nom de l’appareil : ')
            if did==me or len(did)<50 or any(d.get('deviceID')==did for d in cfg.get('devices',[])):
                print('[ERREUR] Identifiant local, invalide ou déjà présent.'); pause(); continue
            if not confirm('Associer cet appareil ?'): continue
            cfg['devices'].append({'deviceID':did,'name':name,'addresses':['dynamic']})
        elif ch in ('3','4'):
            if not ds:
                print('Aucun appareil distant.'); pause(); continue
            print('\nAPPAREILS DISTANTS')
            for i,d in enumerate(ds,1):
                print(f'[{i}] {d.get("name") or "Sans nom"} — {d.get("deviceID","")}')
            try:
                idx=int(ask('Numéro (0 = retour) : '))-1
                if idx==-1: continue
                assert 0<=idx<len(ds)
            except Exception:
                print('Choix invalide.'); pause(); continue
            remote=ds[idx]
            if ch=='3':
                name=ask('Nouveau nom : ')
                if not name: continue
                remote['name']=name
            else:
                print('Retrait des partages distants uniquement, aucun fichier local supprimé.')
                if not confirm('Retirer cet appareil ?'): continue
                did=remote['deviceID']
                cfg['devices']=[d for d in cfg['devices'] if d.get('deviceID')!=did]
                for f in cfg.get('folders',[]):
                    f['devices']=[x for x in f.get('devices',[]) if x.get('deviceID')!=did]
        else:
            print('Choix invalide.'); pause(); continue
        try: c.edit(cfg)
        except Exception as e: print('[ERREUR] Modification :',e)
        pause()

def status(c):
    try:
        sysinfo=c.get('system/status')
        myid=sysinfo.get('myID')
        if not myid: raise RuntimeError('Identité locale introuvable.')
        cfg=c.get('config')
        con=c.get('system/connections').get('connections',{})
        print('\n=== ÉTAT DE SYNCHRONISATION ===')
        print('APPAREIL LOCAL')
        print(syncthing_local_label(),'—',myid[:7])
        print('\nAPPAREILS DISTANTS')
        remote=[d for d in cfg.get('devices',[]) if d.get('deviceID')!=myid]
        if not remote: print('Aucun appareil distant.')
        for d in remote:
            state='CONNECTÉ' if con.get(d.get('deviceID'),{}).get('connected') else 'HORS LIGNE'
            color=_GREEN if state=='CONNECTÉ' else _RED
            _raw_print(f'  {_WHITE}{d.get("name") or d.get("deviceID")}{_RESET} : {color}{state}{_RESET}')
        print('\nDOSSIERS SYNCHRONISÉS')
        for f in cfg.get('folders',[]):
            try:
                db=c.get('db/status?folder='+urllib.parse.quote(f['id'],safe=''))
                state=db.get('state','inconnu')
                need=db.get('needTotalItems',0)
                color=_GREEN if state=='idle' and need==0 else _GOLD
                _raw_print(f'  {_WHITE}{f.get("label") or f["id"]}{_RESET} : {color}{state}{_RESET} — {need} élément(s) en attente')
            except Exception as e:
                print('[ERREUR]',f.get('id'),':',e)
    except Exception as e:
        print('État indisponible :',e)
def repair(c):
    print('DIAGNOSTIC SYNCTHING')
    try:
        c.get('system/status'); print('✓ API locale accessible')
        cfg=c.get('config'); print('✓ Configuration lisible')
        for f in cfg.get('folders',[]):
            if not pathlib.Path(f.get('path','')).is_dir(): print('! Dossier absent :',f.get('path'))
        print('Réparation automatique limitée : aucune suppression ni recréation forcée.')
    except Exception as e: print('! Problème détecté :',e)
# Nettoyage des conflits Syncthing : aperçu par système, copie de secours
# hors /userdata/saves, double confirmation, aucun autre fichier modifié.
# Les copies *.sync-conflict-* sont des fichiers ordinaires synchronisés :
# leur retrait sera propagé aux autres appareils par Syncthing.
CONFLICT_ROOT=pathlib.Path('/userdata/saves')
CONFLICT_BACKUPS=pathlib.Path('/userdata/system/backup-conflits-syncthing')
CONFLICT_NAME=re.compile(r'\.sync-conflict-\d{8}-\d{6}-[A-Z2-7]{7}(?:\.|$)')
CONFLICT_EXCLUDED_DIRS={('flatpak',),('Installscripts',),('ports','rgsx')}

def conflict_inventory(root=CONFLICT_ROOT):
    import stat
    if not root.is_dir() or root.is_symlink():
        raise RuntimeError('Dossier Saves absent ou non sûr.')
    entries=[]
    root_dev=root.stat().st_dev
    for folder,dirs,files in os.walk(root,topdown=True,followlinks=False):
        parent=pathlib.Path(folder)
        relative=parent.relative_to(root)
        kept=[]
        for dirname in sorted(dirs):
            child=parent/dirname
            parts=relative.parts+(dirname,)
            if dirname in ('.stversions','.stfolder') or parts in CONFLICT_EXCLUDED_DIRS:
                continue
            try:
                st=child.lstat()
                if not stat.S_ISDIR(st.st_mode) or st.st_dev!=root_dev:
                    continue
            except OSError:
                continue
            kept.append(dirname)
        dirs[:]=kept
        for name in sorted(files):
            if not CONFLICT_NAME.search(name):
                continue
            p=parent/name
            try:
                st=p.lstat()
            except OSError:
                continue
            if not stat.S_ISREG(st.st_mode) or st.st_dev!=root_dev:
                continue
            rel=p.relative_to(root)
            entries.append({'path':p,'rel':rel,'size':st.st_size,
                            'ino':st.st_ino,'dev':st.st_dev,'mtime':st.st_mtime_ns})
    return sorted(entries,key=lambda x:x['rel'].as_posix())

def conflict_hash(p):
    import hashlib
    h=hashlib.sha256()
    with p.open('rb') as f:
        for block in iter(lambda:f.read(1024*1024),b''):
            h.update(block)
    return h.hexdigest()

def conflict_archive_and_remove(entries,root=CONFLICT_ROOT,store=CONFLICT_BACKUPS):
    import stat, hashlib
    if not entries:
        raise RuntimeError('Aucun fichier sélectionné.')
    if root.is_symlink() or not root.is_dir():
        raise RuntimeError('Dossier Saves non sûr.')
    if store.is_symlink():
        raise RuntimeError('Dossier de secours symbolique refusé.')
    store.mkdir(mode=0o700,parents=True,exist_ok=True)
    if store.is_symlink():
        raise RuntimeError('Dossier de secours non sûr.')
    # Contrôle des noms et des instantanés AVANT la copie.
    for entry in entries:
        rel=entry['rel']
        if (rel.is_absolute() or '..' in rel.parts or
            not CONFLICT_NAME.search(rel.name) or
            rel.parts[:1] in (('flatpak',),('Installscripts',)) or
            rel.parts[:2]==('ports','rgsx') or '.stversions' in rel.parts):
            raise RuntimeError('Chemin non autorisé : '+str(rel))
        p=root/rel
        if p!=entry['path']:
            raise RuntimeError('Chemin inattendu : '+str(rel))
        # Ne jamais suivre de liens symboliques, même dans les dossiers parents.
        cur=root
        for component in rel.parts[:-1]:
            cur=cur/component
            if cur.is_symlink():
                raise RuntimeError('Dossier symbolique : '+str(cur))
        st=p.lstat()
        if (not stat.S_ISREG(st.st_mode) or st.st_ino!=entry['ino'] or
            st.st_dev!=entry['dev'] or st.st_size!=entry['size'] or
            st.st_mtime_ns!=entry['mtime']):
            raise RuntimeError('Fichier modifié : '+str(rel))
    total=sum(x['size'] for x in entries)
    if shutil.disk_usage(store).free < total+16*1024*1024:
        raise RuntimeError('Espace libre insuffisant pour sauvegarder les conflits.')
    label=syncthing_local_label()
    stamp=datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    target=store/('conflits-'+label+'-'+stamp)
    target.mkdir(mode=0o700)
    manifest=[]
    # Copier la totalité puis vérifier chaque SHA-256 avant la première suppression.
    for entry in entries:
        original=entry['path']; dest=target/'fichiers'/entry['rel']
        dest.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(original,dest,follow_symlinks=False)
        digest=conflict_hash(original)
        if digest!=conflict_hash(dest):
            raise RuntimeError('Vérification SHA-256 échouée : '+str(entry['rel']))
        manifest.append({'fichier':entry['rel'].as_posix(),
                         'sha256':digest,'taille':entry['size']})
    (target/'manifest.json').write_text(
        json.dumps({'appareil':label,'date':stamp,'fichiers':manifest},
                   indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    (target/'LIRE-MOI.txt').write_text(
        'Sauvegarde des copies de conflit Syncthing retirées du partage.\n'
        'Les chemins originaux sont sous /userdata/saves.\n'
        'Les fichiers normaux de sauvegarde de jeux ne sont pas concernés.\n',
        encoding='utf-8')
    # Après archivage intégral, refuser la suppression si un fichier a évolué.
    for entry,item in zip(entries,manifest):
        p=entry['path']; st=p.lstat()
        if (not stat.S_ISREG(st.st_mode) or st.st_ino!=entry['ino'] or
            st.st_dev!=entry['dev'] or st.st_size!=entry['size'] or
            st.st_mtime_ns!=entry['mtime'] or conflict_hash(p)!=item['sha256']):
            raise RuntimeError('Source modifiée ; aucune suppression lancée : '+str(entry['rel']))
    done=0
    for entry,item in zip(entries,manifest):
        p=entry['path']; st=p.lstat()
        if (not stat.S_ISREG(st.st_mode) or st.st_ino!=entry['ino'] or
            st.st_dev!=entry['dev'] or st.st_size!=entry['size'] or
            st.st_mtime_ns!=entry['mtime']):
            raise RuntimeError(f'Arrêt après {done} retrait(s) : source modifiée.')
        p.unlink()
        done+=1
    return target,done

def conflicts_menu():
    from collections import Counter
    def header():
        clear_menu()
        _raw_print(_CYAN+'  --- CONFLITS SYNCTHING ---'+_RESET)
        _raw_print()
    def row_option(num,label):
        menu_option(num,label)
    def footer():
        _raw_print()
        row_option('0','Retour')
        row_option('Q','Quitter le gestionnaire')
    def pretty_size(size):
        if size>=1024*1024: return f'{size/1024/1024:.1f} Mio'
        if size>=1024: return f'{size/1024:.0f} Kio'
        return str(size)+' octets'
    def groups(entries):
        counter=Counter(x['rel'].parts[0] if len(x['rel'].parts)>1 else '(racine)'
                        for x in entries)
        return sorted(counter.items(),key=lambda x:x[0].casefold())
    def view(entries):
        header()
        _raw_print(_CYAN+'  FICHIERS EN CONFLIT'+_RESET)
        _raw_print()
        for i,x in enumerate(entries,1):
            _raw_print(_WHITE+f'  {i}. '+x['rel'].as_posix()+_RESET)
            if i%12==0 and i<len(entries):
                if ask('Entrée = suite, 0 = arrêt : ')=='0': break
        pause()
    def execute(items,description):
        header()
        _raw_print(_WHITE+'  Sélection : '+description+_RESET)
        _raw_print('  Fichiers :',len(items))
        _raw_print('  Taille   :',pretty_size(sum(x['size'] for x in items)))
        _raw_print()
        for x in items[:8]:
            _raw_print(_WHITE+'  '+x['rel'].as_posix()+_RESET)
        if len(items)>8:
            _raw_print(_GOLD+f'  ... et {len(items)-8} autres fichiers.'+_RESET)
        _raw_print()
        _raw_print(_GOLD+'  Attention : certaines copies peuvent contenir une'+_RESET)
        _raw_print(_GOLD+'  ancienne progression de jeu non récupérée.'+_RESET)
        _raw_print(_GOLD+'  Le retrait sera synchronisé avec les autres appareils.'+_RESET)
        _raw_print(_WHITE+'  Une copie sera conservée hors de /userdata/saves.'+_RESET)
        _raw_print()
        if not confirm('Retirer ces copies de conflit du partage ?'):
            _raw_print('  Annulé.'); pause(); return
        if ask('Tapez SUPPRIMER pour confirmer : ')!='SUPPRIMER':
            _raw_print('  Annulé.'); pause(); return
        # Vérifier le groupe et chaque état avant d'agir, même après saisie.
        try:
            where,number=conflict_archive_and_remove(items)
            _raw_print(_GREEN+f'  [OK] {number} conflit(s) retiré(s).'+_RESET)
            _raw_print(_WHITE+'  Copie de sécurité :'+_RESET)
            _raw_print(_WHITE+'  '+str(where)+_RESET)
            _raw_print(_GOLD+'  Vérifiez ensuite la synchronisation sur les 2 appareils.'+_RESET)
        except Exception as e:
            _raw_print(_RED+'  [ERREUR] '+str(e)+_RESET)
            _raw_print(_GOLD+'  Aucun fichier non archivé ne doit être supprimé.'+_RESET)
        pause()
    while True:
        header()
        try:
            entries=conflict_inventory()
        except Exception as e:
            _raw_print(_RED+'  [ERREUR] '+str(e)+_RESET)
            pause(); return
        if not entries:
            _raw_print(_GREEN+'  [OK] Aucun fichier de conflit détecté.'+_RESET)
            _raw_print(_WHITE+'  Fichiers de jeux existants inchangés.'+_RESET)
            footer()
            choice=menu_key()
            if choice=='q': sys.exit(99)
            if choice=='0': return
            continue
        summary=groups(entries)
        _raw_print(_WHITE+f'  {len(entries)} conflit(s) — {pretty_size(sum(x["size"] for x in entries))}'+_RESET)
        _raw_print()
        _raw_print(_CYAN+'  PAR SYSTÈME'+_RESET)
        for name,count in summary:
            _raw_print(_WHITE+f'  {name:<14} : {count}'+_RESET)
        _raw_print()
        row_option('1','Afficher les fichiers')
        row_option('2','Supprimer par système')
        row_option('3','Supprimer tous les conflits')
        footer()
        choice=menu_key()
        if choice=='q': sys.exit(99)
        if choice=='0': return
        if choice=='1': view(entries); continue
        if choice=='3': execute(entries,'Tous les systèmes'); continue
        if choice=='2':
            header()
            for i,(name,count) in enumerate(summary,1):
                _raw_print(_GOLD+'  '+menu_marker(i)+_RESET+_WHITE+f'  {name} : {count} conflit(s)'+_RESET)
            _raw_print()
            selected=ask('Numéro (0 = retour, Q = quitter) : ').strip().lower()
            if selected=='q': sys.exit(99)
            if selected=='0': continue
            if not selected.isdigit() or not 1<=int(selected)<=len(summary):
                _raw_print(_GOLD+'  Choix invalide.'+_RESET); pause(); continue
            system=summary[int(selected)-1][0]
            chosen=[x for x in entries if
                    (x['rel'].parts[0] if len(x['rel'].parts)>1 else '(racine)')==system]
            execute(chosen,system)
        else:
            _raw_print(_GOLD+'  Choix invalide.'+_RESET)

def versioning_menu():

    def ligne(*textes):
        print(*textes, end='\n', flush=True)
    # Supporte la configuration XML à l'arrêt, ou l'API lorsque le service tourne.
    while True:
        active=running()
        if active:
            c=Client(); cfg=c.get('config')
            fs=cfg.get('folders',[])
        else:
            xml=locate()
            if not xml: print('Configuration Syncthing absente.'); return
            tree=ET.parse(xml); root=tree.getroot(); fs=root.findall('folder')
        ligne()
        ligne('\033[1;96m  +----------------------------+\033[0m')
        ligne('\033[1;96m  |         VERSIONNAGE        |\033[0m')
        ligne('\033[1;96m  +----------------------------+\033[0m')
        ligne()
        ligne('Service :', 'ACTIF' if active else 'ARRÊTÉ')
        for i,f in enumerate(fs,1):
            if active:
                v=f.get('versioning') or {}; typ=v.get('type','')
                keep=(v.get('params') or {}).get('keep','5')
                name=f.get('label') or f.get('id'); dest=f.get('path','')
            else:
                v=f.find('versioning'); typ=v.get('type','') if v is not None else ''
                keep=(v.find('param[@key="keep"]').get('val','5') if v is not None and v.find('param[@key="keep"]') is not None else '5')
                name=f.get('label') or f.get('id'); dest=f.get('path','')
            state=('Simple ('+str(keep or '5')+' versions)') if typ=='simple' else ('Désactivé' if not typ else 'Autre mode : '+typ)
            menu_option(str(i),name)
            couleur = (
                '\033[1;32m' if typ == 'simple'
                else '\033[1;31m' if not typ
                else '\033[1;33m'
            )
            ligne(f'       {couleur}{state}\033[0m')
            ligne(f'       {dest[:24]}')
            ligne()
        ligne()
        menu_option('0','Retour')
        menu_option('Q','Quitter le gestionnaire')
        choice=menu_key('Dossier à gérer : ',multi=True)
        if choice=='0': return
        if choice=='q': sys.exit(99)
        try: idx=int(choice)-1; assert 0<=idx<len(fs)
        except Exception: print('Choix invalide.'); continue
        f=fs[idx]
        dest=pathlib.Path(f.get('path','') if active else f.get('path',''))
        # Pas de chemin personnalisé pour les versions : Syncthing utilise .stversions.
        archive=dest/'.stversions'
        ligne()
        ligne('\033[1;96m  --- OPTIONS VERSIONNAGE ---\033[0m')
        ligne()
        menu_option('1','Activer le versionnage')
        menu_option('2','Désactiver le versionnage')
        menu_option('3','Versions')
        menu_option('4','Nettoyer les versions')
        ligne('       \033[1;33mService arrêté uniquement\033[0m')
        ligne()
        menu_option('0','Retour')
        menu_option('Q','Quitter le gestionnaire')
        op=menu_key()
        if op=='0': continue
        if op=='q': sys.exit(99)
        if op in ('1','2'):
            if op=='1':
                raw=ask('Nombre de versions à conserver [5] : ') or '5'
                if not raw.isdigit() or not 1<=int(raw)<=100:
                    print('Nombre invalide (1 à 100).'); pause(); continue
                typ='simple'; keep=str(int(raw))
            else: typ=''; keep=''
            if not confirm('Enregistrer ce changement de versionnage ?'): continue
            if active:
                f['versioning']={'type':typ,'params':{'keep':keep} if typ else {},'cleanupIntervalS':3600,'fsPath':''}
                c.edit(cfg)
            else:
                if running(): print('Service démarré entre-temps : opération annulée.'); pause(); continue
                v=f.find('versioning')
                if v is not None: f.remove(v)
                v=ET.SubElement(f,'versioning')
                v.set('type',typ)
                if typ: ET.SubElement(v,'param',{'key':'keep','val':keep})
                # Les versions Syncthing stockent la valeur dans l'attribut val.
                stamp=datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
                BASE.mkdir(parents=True,exist_ok=True)
                backup=BASE/('config-versioning-'+stamp+'.xml')
                temp=xml.with_name('config.xml.tmp-versioning-'+stamp)
                try:
                    shutil.copy2(xml,backup); os.chmod(backup,0o600)
                    tree.write(temp,encoding='utf-8',xml_declaration=True)
                    ET.parse(temp); os.chmod(temp,0o600)
                    if running(): raise RuntimeError('Syncthing a démarré : annulation.')
                    os.replace(temp,xml)
                    print('Sauvegarde :',backup)
                finally: temp.unlink(missing_ok=True)
            print('Versionnage enregistré.'); pause()
        elif op in ('3','4'):
            if not dest.is_dir() or dest.is_symlink() or not str(dest.resolve()).startswith('/userdata/'):
                print('Chemin de dossier non sûr ou inexistant.'); pause(); continue
            if archive.is_symlink(): print('Archive symbolique : opération refusée.'); pause(); continue
            if not archive.exists(): print('Aucune ancienne version (.stversions absent).'); pause(); continue
            if not archive.is_dir(): print('Archive non répertoire : opération refusée.'); pause(); continue
            size=0; count=0
            for parent, dirs, files in os.walk(archive,followlinks=False):
                dirs[:]=[d for d in dirs if not (pathlib.Path(parent)/d).is_symlink()]
                for name in files:
                    fp=pathlib.Path(parent)/name
                    if not fp.is_symlink():
                        try: size+=fp.stat().st_size; count+=1
                        except OSError: pass
            print(f'Anciennes versions : {count} fichiers, {size/1024**2:.1f} Mio')
            if op=='4':
                if running(): print('Arrêtez Syncthing avant le nettoyage.'); pause(); continue
                print('ATTENTION : suppression définitive des anciennes versions, sans toucher aux sauvegardes actuelles.')
                if ask('Pour confirmer, tapez NETTOYER : ')!='NETTOYER': continue
                if running(): print('Service redémarré : nettoyage annulé.'); pause(); continue
                # Aucun lien symbolique n'est suivi par rmtree.
                shutil.rmtree(archive)
                print('Anciennes versions supprimées. Les fichiers actuels sont conservés.')
            pause()
        else: print('Choix invalide.')

def syncthing_group_menu(title, labels, handler):
    # Un seul niveau de navigation, l'ensemble des fonctions reste disponible.
    while True:
        clear_menu()
        print()
        _raw_print(_CYAN+'  +----------------------------+'+_RESET)
        _raw_print(_CYAN+f'  {title.upper():^30}'+_RESET)
        _raw_print(_CYAN+'  +----------------------------+'+_RESET)
        print()
        for index,label in enumerate(labels,1):
            menu_option(str(index),label)
        print()
        menu_option('0','Retour')
        menu_option('Q','Quitter le gestionnaire')
        ch=menu_key()
        if ch=='0': return
        if ch=='q': sys.exit(99)
        if not ch.isdigit() or not 1<=int(ch)<=len(labels):
            print('Choix invalide.'); pause(); continue
        try:
            handler(ch)
        except Exception as e:
            print('[ERREUR]',e)
            pause()

def syncthing_folder_action(ch):
    if ch=='1':
        if running(): folders(Client())
        else: offline_folders()
    elif ch=='2':
        ignores(Client())  # L'utilisateur choisit toujours le dossier.
    elif ch=='3':
        versioning_menu()

def syncthing_lan_ipv4():
    """IP réseau de Batocera, sans appel à un service Internet.

    Préférer une carte Ethernet/Wi-Fi aux interfaces VPN, Docker ou virtuelles.
    Ne jamais inventer une adresse lorsque la détection échoue.
    """
    def ip_ok(value):
        try:
            a=ipaddress.ip_address(value)
            return (isinstance(a,ipaddress.IPv4Address)
                    and not (a.is_loopback or a.is_link_local or a.is_multicast
                             or a.is_unspecified or a.is_reserved))
        except ValueError:
            return False
    def command(args):
        try:
            p=subprocess.run(args,capture_output=True,text=True,timeout=3)
            return p.stdout if p.returncode==0 else ''
        except (OSError,subprocess.TimeoutExpired):
            return ''

    raw=command(['ip','-o','-4','addr','show','up','scope','global'])
    default=command(['ip','-4','route','show','default'])
    default_names=set(re.findall(r'\bdev\s+([^\s]+)',default))
    candidates=[]
    for line in raw.splitlines():
        fields=line.split()
        if len(fields)<4: continue
        interface=fields[1].split('@',1)[0]
        found=re.search(r'\binet\s+([0-9.]+)/\d+',line)
        if not found or not ip_ok(found.group(1)): continue
        ipv4=found.group(1)
        # L'adresse locale Ethernet/Wi-Fi est plus utile sur un téléphone
        # que celle d'un réseau virtuel ou d'un VPN.
        physical=interface.startswith(('eth','en','wl','wlan'))
        virtual=interface.startswith(('tun','tap','wg','tailscale','docker','br-','virbr','veth','zt'))
        rank=(0 if physical else 2 if virtual else 1,
              0 if ipaddress.ip_address(ipv4).is_private else 1,
              0 if interface in default_names else 1)
        candidates.append((rank,ipv4))
    if candidates:
        return min(candidates,key=lambda x:x[0])[1]
    # Secours pour les versions de Batocera sans commande ip -o.
    for ipv4 in command(['hostname','-I']).split():
        if ip_ok(ipv4): return ipv4
    route=command(['ip','-4','route','get','1.1.1.1'])
    match=re.search(r'\bsrc\s+([0-9.]+)',route)
    if match and ip_ok(match.group(1)): return match.group(1)
    return None

def syncthing_web_address(client):
    """Afficher une URL avec l'IP réseau et signaler une GUI restreinte."""
    tree=ET.parse(client.xml)
    gui=tree.getroot().find('gui')
    if gui is None or gui.get('enabled','true').lower()!='true':
        _raw_print(f'{_ORANGE}  Interface Web Syncthing désactivée.{_RESET}')
        return
    bind=(gui.findtext('address') or '127.0.0.1:8384').strip()
    port='8384'
    if ':' in bind:
        possible=bind.rsplit(':',1)[1]
        if possible.isdigit() and 1<=int(possible)<=65535:
            port=possible
        else:
            _raw_print(f'{_ORANGE}  Port Syncthing non reconnu.{_RESET}')
            return
    tls=gui.get('tls','false').lower() in ('true','1','yes')
    scheme='https' if tls else 'http'
    lan=syncthing_lan_ipv4()
    print()
    _raw_print(f'{_CYAN}  --- INTERFACE WEB SYNCTHING ---{_RESET}')
    print()
    if not lan:
        _raw_print(f'{_ORANGE}  Adresse réseau introuvable.{_RESET}')
        return
    _raw_print(f'{_WHITE}  Adresse sur le réseau :{_RESET}')
    _raw_print(f'  {scheme}://{lan}:{port}')  # URL brute, facilement copiable en SSH
    # Afficher le lien demandé n'ouvre pas le port lui-même.
    host=bind.rsplit(':',1)[0].strip('[]').lower() if ':' in bind else bind.lower()
    if host in ('127.0.0.1','localhost','::1'):
        print()
        _raw_print(f'{_ORANGE}  ◆ Accès distant non activé.{_RESET}')
        _raw_print(f'{_WHITE}  Syncthing écoute sur localhost.{_RESET}')
    elif host not in ('0.0.0.0','::','',lan):
        print()
        _raw_print(f'{_ORANGE}  ◆ Accès via cette IP à vérifier.{_RESET}')
    # Aucun changement de configuration, pare-feu ou authentification.

def syncthing_maintenance_action(ch):
    if ch=='1':
        status(Client()); pause()
    elif ch=='2':
        repair(Client()); pause()
    elif ch=='3':
        conflicts_menu()
    elif ch=='4':
        c=Client()
        syncthing_web_address(c)
        pause()

while True:
    clear_menu()
    print()
    _raw_print(_CYAN+'  +----------------------------+'+_RESET)
    _raw_print(_CYAN+'  |         SYNCTHING          |'+_RESET)
    _raw_print(_CYAN+'  +----------------------------+'+_RESET)
    print()
    for index,label in enumerate((
        'Service Syncthing',
        'Dossiers et exclusions',
        'Appareils associés',
        'État et maintenance',
        'Sauvegardes',
    ),1):
        menu_option(str(index),label)
    print()
    menu_option('0','Retour')
    menu_option('Q','Quitter le gestionnaire')
    print()
    service_info()
    print()
    choice=menu_key()
    if choice=='0': break
    if choice=='q': sys.exit(99)
    try:
        if choice=='1':
            service()
        elif choice=='2':
            syncthing_group_menu('DOSSIERS ET EXCLUSIONS',
                ('Dossiers synchronisés','Exclusions','Versionnage'),
                syncthing_folder_action)
        elif choice=='3':
            devices(Client())
        elif choice=='4':
            syncthing_group_menu('ÉTAT ET MAINTENANCE',
                ('État de synchronisation','Diagnostic / Réparation',
                 'Nettoyer les conflits','Interface Web'),
                syncthing_maintenance_action)
        elif choice=='5':
            config_archives_menu()
        else:
            print('Choix invalide.'); pause()
    except Exception as e:
        print('[ERREUR]',e)
        pause()

PYSYN
  local rc=$?
  if [[ "$rc" == 99 ]]; then exit 0; fi
}

# RAMBO / LINDBERGH - script GitHub verifie ; cache comme secours hors ligne.
# L'ancien dossier Rambo reste intact et n'est utilise que pour migration.
# Le hook game-start ne vide linuxloader qu'au lancement du jeu Rambo.
rambo_script_path='/userdata/system/configs/emulationstation/scripts/game-start/nettoyage-rambo.sh'
RAMBO_REMOTE="https://raw.githubusercontent.com/$REPO/main/Rambo/nettoyage-rambo.sh"
RAMBO_CACHE="$CACHE/Rambo/nettoyage-rambo.sh"
RAMBO_LEGACY="$BASE/Rambo/nettoyage-rambo.sh"
RAMBO_SHA256='1083a888cfbedf1fde5edd49d075ca8cc063c3b573e8c8542713b810c6cb2d6c'
RAMBO_SOURCE=''
rambo_validate(){
  local f="$1" hash
  [[ -f "$f" && ! -L "$f" && -s "$f" ]] || return 1
  hash="$(sha256sum "$f" | cut -d' ' -f1)" || return 1
  [[ "$hash" == "$RAMBO_SHA256" ]] && bash -n "$f"
}
rambo_prepare(){
  local tmp force="${1:-0}"
  RAMBO_SOURCE=''
  [[ ! -L "$CACHE/Rambo" && ! -L "$RAMBO_CACHE" ]] || {
    echo '[SÉCURITÉ] Cache Rambo symbolique refusé.'; return 1;
  }
  mkdir -p -- "$CACHE/Rambo" || return 1
  if [[ "$force" != 1 ]] && rambo_validate "$RAMBO_CACHE"; then
    RAMBO_SOURCE="$RAMBO_CACHE"
    echo '[SOURCE] RAMBO : cache.'
    return 0
  fi
  tmp="$(mktemp "$CACHE/Rambo/.rambo-download.XXXXXX")" || return 1
  if command -v curl >/dev/null 2>&1 &&
     curl -fLsS --connect-timeout 5 --max-time 30 "$RAMBO_REMOTE" -o "$tmp" 2>/dev/null &&
     rambo_validate "$tmp"; then
    if ! mv -f -- "$tmp" "$RAMBO_CACHE"; then
      rm -f -- "$tmp"
      return 1
    fi
    RAMBO_SOURCE="$RAMBO_CACHE"
    echo '[RAMBO] GitHub OK ; cache Rambo prêt.'
    return 0
  fi
  rm -f -- "$tmp"
  echo '[RAMBO] GitHub indisponible ou contenu invalide : utilisation du cache local.'
  if rambo_validate "$RAMBO_CACHE"; then
    RAMBO_SOURCE="$RAMBO_CACHE"
    echo '[RAMBO] Secours local dans cache-gestionnaire fonctionnel.'
    return 0
  fi
  echo '[ERREUR] Rambo : cache et GitHub indisponibles.'
  return 1
}
rambo_check_version(){
  local v
  v="$(detect_batocera_version)" || v=''
  case "$v" in
    44|44.*) return 0 ;;
    *) echo "[SÉCURITÉ] Fonction Rambo réservée à Batocera 44 (détecté : ${v:-inconnu})."; return 1 ;;
  esac
}
rambo_install(){
  local target="$rambo_script_path" dir tmp
  rambo_check_version || return 1
  rambo_prepare || return 1
  dir="$(dirname "$target")"
  if [[ -e "$target" || -L "$target" ]]; then
    if [[ ! -f "$target" || -L "$target" ]]; then
      echo '[SÉCURITÉ] Cible non ordinaire : installation refusée.'
      return 1
    fi
    if cmp -s "$RAMBO_SOURCE" "$target" && [[ -x "$target" ]]; then
      echo '[OK] Rambo : script OK.'
      return 0
    fi
    confirm 'Sauver et remplacer Rambo ?' || { echo '[INFO] Annulé.'; return 0; }
    backup_file "$target" "$SAVES/Rambo" 'nettoyage-rambo.sh' || return 1
  else
    confirm 'Installer nettoyage Rambo ?' || { echo '[INFO] Annulé.'; return 0; }
  fi
  mkdir -p -- "$dir" || return 1
  tmp="$(mktemp "$dir/.rambo-install.XXXXXX")" || return 1
  if ! cp -p -- "$RAMBO_SOURCE" "$tmp" || ! bash -n "$tmp" ||
     ! chmod 755 "$tmp" || ! mv -f -- "$tmp" "$target"; then
    rm -f -- "$tmp"
    echo '[ERREUR] Installation Rambo impossible : cible précédente préservée.'
    return 1
  fi
  echo '[OK] Rambo : nettoyage installé.'
  echo '[INFO] Aucun fichier linuxloader supprimé durant cette installation.'
}
rambo_uninstall(){
  local target="$rambo_script_path"
  if [[ -L "$target" || ( -e "$target" && ! -f "$target" ) ]]; then
    echo '[SÉCURITÉ] Cible non ordinaire : suppression refusée.'
    return 1
  fi
  [[ -f "$target" ]] || { echo '[INFO] Aucun script Rambo installé.'; return 0; }
  confirm 'Supprimer uniquement le hook Rambo (sans toucher à linuxloader) ?' || { echo '[INFO] Annulé.'; return 0; }
  backup_file "$target" "$SAVES/Rambo" 'nettoyage-rambo.sh' || return 1
  rm -f -- "$target" || return 1
  echo '[OK] Script Rambo supprimé.'
  echo '[INFO] linuxloader inchangé.'
}
rambo_menu(){
  local choice
  while :; do
    refresh_screen
    ui_section 'PATCH RAMBO (LINDBERGH)'
    if [[ -f "$rambo_script_path" && ! -L "$rambo_script_path" ]] &&
       rambo_validate "$rambo_script_path" && [[ -x "$rambo_script_path" ]]; then
      ui_print success '  État : Rambo OK'
    elif [[ -f "$rambo_script_path" ]]; then
      ui_print warning '  État : script présent (différent de notre version)'
    else
      ui_print warning '  État : script absent'
    fi
    ui_print info '  Rambo : nettoyage au lancement'
    ui_item '1) Installer / Réinstaller'
    ui_item '2) Désinstaller le script'
    ui_item '3) Dernières opérations'
    ui_item '4) Vérifier GitHub / cache'
    echo
    ui_item '0) Retour'
    ui_item 'Q) Quitter le gestionnaire'
    choice="$(read_key 'Votre choix : ')" || return 0
    case "$choice" in
      1) rambo_install || ui_print warning '[ATTENTION] Installation Rambo non terminée.'; pause ;;
      2) rambo_uninstall || ui_print warning '[ATTENTION] Désinstallation Rambo non terminée.'; pause ;;
      3)
        if [[ -f /userdata/system/logs/nettoyage-rambo.log ]]; then
          tail -n 15 /userdata/system/logs/nettoyage-rambo.log
        else
          echo '[INFO] Aucun journal Rambo.'
        fi
        pause ;;
      4) rambo_prepare 1 || ui_print warning '[ATTENTION] Préparation Rambo incomplète.'; pause ;;
      0) return 0 ;;
      *) ui_print warning 'Choix invalide.'; pause ;;
    esac
  done
}


# STAR WARS BATTLE POD / TEKNOPARROT — Batocera 44.
# Conserve l'emplacement fonctionnel du hook d'evenements Batocera.
BATTLEPOD_SCRIPT='/userdata/system/scripts/battlepod-ecrans.sh'
BATTLEPOD_LOG='/userdata/system/logs/battlepod-ecrans.log'
battlepod_content(){
  cat <<'BATTLEPOD_SCRIPT_CONTENT'
#!/bin/bash
[ "$1" = "gameStart" ] || exit 0
[ "$2" = "teknoparrot" ] || exit 0
ROM="${5,,}"
case "$ROM" in
  *battle*pod*) ;;
  *) exit 0 ;;
esac
LOG="/userdata/system/logs/battlepod-ecrans.log"
mkdir -p /userdata/system/logs
printf '%s - Battle Pod detecte : %s\n' "$(date)" "$5" >> "$LOG"
if ! command -v wlr-randr >/dev/null 2>&1; then
  echo 'ERREUR - wlr-randr indisponible' >> "$LOG"
  exit 1
fi
# Ne pas toucher a l'affichage d'un Steam Deck ou d'un autre materiel.
OUTPUTS="$(wlr-randr 2>> "$LOG")" || exit 1
if ! grep -q '^DP-1 ' <<< "$OUTPUTS" || ! grep -q '^HDMI-A-1 ' <<< "$OUTPUTS"; then
  echo 'INFO - sorties DP-1/HDMI-A-1 absentes : aucune modification' >> "$LOG"
  exit 0
fi
if wlr-randr --output DP-1 --pos 0,0 --output HDMI-A-1 --pos 3440,0 >> "$LOG" 2>&1; then
  echo 'OK - Ecrans repositionnes' >> "$LOG"
else
  echo 'ERREUR - Repositionnement impossible' >> "$LOG"
  exit 1
fi
BATTLEPOD_SCRIPT_CONTENT
}
battlepod_status(){
  local target="$BATTLEPOD_SCRIPT" tmp
  if [[ ! -e "$target" && ! -L "$target" ]]; then echo '?'; return; fi
  [[ -f "$target" && ! -L "$target" ]] || { echo '!'; return; }
  tmp="$(mktemp)" || { echo '!'; return; }
  battlepod_content > "$tmp"
  if cmp -s -- "$target" "$tmp" && [[ -x "$target" ]]; then echo X
  else echo '!'; fi
  rm -f -- "$tmp"
}
battlepod_install(){
  local target="$BATTLEPOD_SCRIPT" dir tmp
  rambo_check_version || return 1
  if [[ -e "$target" || -L "$target" ]]; then
    [[ -f "$target" && ! -L "$target" ]] || { echo '[SÉCURITÉ] Cible Star Wars non ordinaire.'; return 1; }
    if [[ "$(battlepod_status)" == X ]]; then
      echo '[OK] Star Wars : script conforme, conservé.'; return 0
    fi
    confirm 'Sauvegarder et remplacer le script Star Wars existant ?' || { echo '[INFO] Script Star Wars conservé.'; return 0; }
    backup_file "$target" "$SAVES/StarWarsBattlePod" 'battlepod-ecrans.sh' || return 1
  else
    confirm 'Installer le correctif Star Wars Battle Pod ?' || { echo '[INFO] Annulé.'; return 0; }
  fi
  dir="$(dirname "$target")"
  [[ ! -L "$dir" ]] || { echo '[SÉCURITÉ] Dossier des hooks symbolique refusé.'; return 1; }
  mkdir -p -- "$dir" || return 1
  tmp="$(mktemp "$dir/.battlepod-install.XXXXXX")" || return 1
  if ! battlepod_content > "$tmp" || ! bash -n "$tmp" ||
     ! chmod 755 "$tmp" || ! mv -f -- "$tmp" "$target"; then
    rm -f -- "$tmp"
    echo '[ERREUR] Correctif Star Wars non installé.'
    return 1
  fi
  echo '[OK] Star Wars : repositionnement automatique installé.'
}
battlepod_uninstall(){
  local target="$BATTLEPOD_SCRIPT"
  [[ ! -L "$target" && ( ! -e "$target" || -f "$target" ) ]] || { echo '[SÉCURITÉ] Cible non ordinaire.'; return 1; }
  [[ -f "$target" ]] || { echo '[INFO] Correctif Star Wars absent.'; return 0; }
  confirm 'Désinstaller uniquement le correctif Star Wars ?' || { echo '[INFO] Annulé.'; return 0; }
  backup_file "$target" "$SAVES/StarWarsBattlePod" 'battlepod-ecrans.sh' || return 1
  rm -f -- "$target" || return 1
  echo '[OK] Correctif Star Wars désinstallé (Rambo intact).'
}
battlepod_menu(){
  local choice status
  while :; do
    refresh_screen
    ui_section 'PATCH STAR WARS BATTLE POD'
    status="$(battlepod_status)"
    case "$status" in
      X) ui_print success '  État : installé (conforme)' ;;
      '?') ui_print warning '  État : absent' ;;
      *) ui_print warning '  État : script existant différent' ;;
    esac
    ui_print info '  DP-1 : 0,0 / HDMI-A-1 : 3440,0'
    ui_item '1) Installer / Réinstaller'
    ui_item '2) Désinstaller le script'
    ui_item '3) Dernières opérations'
    echo
    ui_item '0) Retour'
    ui_item 'Q) Quitter le gestionnaire'
    choice="$(read_key 'Votre choix : ')" || return 0
    case "$choice" in
      1) battlepod_install || ui_print warning '[ATTENTION] Installation Star Wars incomplète.'; pause ;;
      2) battlepod_uninstall || ui_print warning '[ATTENTION] Désinstallation Star Wars incomplète.'; pause ;;
      3) if [[ -f "$BATTLEPOD_LOG" ]]; then tail -n 15 "$BATTLEPOD_LOG"; else echo '[INFO] Aucun journal Star Wars.'; fi; pause ;;
      0) return 0 ;;
      q|Q) exit 0 ;;
      *) ui_print warning 'Choix invalide.'; pause ;;
    esac
  done
}
patchs_jeux_verify(){
  local r s
  r="$(installation_status rambo)"
  s="$(battlepod_status)"
  ui_section 'ÉTAT DES PATCHS'
  case "$r" in
    X) ui_print success '  ✓ Rambo : installé' ;;
    '?') ui_print warning '  ◆ Rambo : absent' ;;
    *) ui_print warning '  ◆ Rambo : à vérifier' ;;
  esac
  case "$s" in
    X) ui_print success '  ✓ Star Wars : installé' ;;
    '?') ui_print warning '  ◆ Star Wars : absent' ;;
    *) ui_print warning '  ◆ Star Wars : à vérifier' ;;
  esac
}
patchs_jeux_install_all(){
  local status errors=0
  rambo_check_version || return 1
  echo '[INFO] Installation groupée : Rambo + Star Wars.'
  confirm 'Vérifier / installer les deux patchs jeux ?' || { echo '[INFO] Annulé.'; return 0; }
  echo '--- RAMBO ---'
  status="$(installation_status rambo)"
  if [[ "$status" == X ]]; then
    echo '[OK] Rambo : déjà installé, aucune modification.'
  elif [[ "$status" == '!' ]]; then
    echo '[ATTENTION] Rambo : fichier existant différent, conservé. Gestion individuelle disponible.'
  else
    rambo_install || errors=1
  fi
  echo '--- STAR WARS BATTLE POD ---'
  status="$(battlepod_status)"
  if [[ "$status" == X ]]; then
    echo '[OK] Star Wars : déjà installé, aucune modification.'
  elif [[ "$status" == '!' ]]; then
    echo '[ATTENTION] Star Wars : fichier existant différent, conservé. Gestion individuelle disponible.'
  else
    battlepod_install || errors=1
  fi
  echo '--- VÉRIFICATION ---'
  patchs_jeux_verify
  (( errors == 0 )) || return 1
}
patchs_jeux_menu(){
  local choice
  while :; do
    refresh_screen
    ui_section 'INSTALLATION - PATCHS JEUX'
    ui_item '1) Installer les deux patchs'
    ui_installation_item 2 'Rambo (Lindbergh)' "$(installation_status rambo)" 25
    ui_installation_item 3 'Star Wars Battle Pod' "$(battlepod_status)" 25
    ui_item '4) Vérifier les deux patchs'
    echo
    ui_installation_legend
    ui_item '0) Retour'
    ui_item 'Q) Quitter le gestionnaire'
    choice="$(read_key 'Votre choix : ')" || return 0
    case "$choice" in
      1) patchs_jeux_install_all || ui_print warning '[ATTENTION] Installation groupée incomplète.'; pause ;;
      2) rambo_menu ;;
      3) battlepod_menu ;;
      4) patchs_jeux_verify; pause ;;
      0) return 0 ;;
      q|Q) exit 0 ;;
      *) ui_print warning 'Choix invalide.'; pause ;;
    esac
  done
}

# Cache isolé : jamais de suppression des sauvegardes ou des installateurs TEST.
cache_guard(){
  [[ "$CACHE" == '/userdata/saves/Installscripts/cache-gestionnaire' ]] || return 1
  [[ -d "$CACHE" && ! -L "$CACHE" ]] || return 1
  [[ -d "$BASE" && ! -L "$BASE" ]] || return 1
}
cache_inspect(){
  local mode="$1"
  cache_guard || { ui_print warning '[SÉCURITÉ] Cache inaccessible.'; return 1; }
  python3 - "$CACHE" "$mode" <<'PYCACHE'
import os, sys, stat, pathlib, subprocess, zipfile
root = pathlib.Path(sys.argv[1])
mode = sys.argv[2]
files, dirs, bad = [], [], []
total = 0
for base, names, filenames in os.walk(root, topdown=True, followlinks=False):
    for name in list(names):
        p = pathlib.Path(base) / name
        st = p.lstat()
        if not stat.S_ISDIR(st.st_mode):
            bad.append(str(p.relative_to(root)))
            names.remove(name)
        else:
            dirs.append(p)
    for name in filenames:
        p = pathlib.Path(base) / name
        st = p.lstat()
        if not stat.S_ISREG(st.st_mode):
            bad.append(str(p.relative_to(root)))
            continue
        files.append(p)
        total += st.st_size
print(f'[CACHE] {len(files)} fichiers | {total / 1048576:.2f} Mio')
if bad:
    print(f'[SÉCURITÉ] {len(bad)} entrée(s) suspecte(s).')
    for name in bad[:3]:
        print('  -', name[:27])
    sys.exit(1)
if mode == 'summary':
    pass
elif mode == 'info':
    categories = {}
    for p in files:
        rel = p.relative_to(root)
        group = rel.parts[0] if len(rel.parts) > 1 else 'Autres fichiers'
        count, size = categories.get(group, (0, 0))
        categories[group] = (count + 1, size + p.stat().st_size)
    if not files:
        print('[INFO] Cache vide.')
    else:
        print('Répartition :')
        for group, (count, size) in sorted(categories.items(), key=lambda item: (-item[1][1], item[0]))[:8]:
            name = group if len(group) <= 23 else group[:20] + '...'
            print(f'  {name} : {count} | {size / 1048576:.1f} Mio')
        if len(categories) > 8:
            print(f'  + {len(categories) - 8} autre(s) dossier(s)')
elif mode == 'verify':
    checked, ignored, issues = 0, 0, []
    for p in files:
        suffix = p.suffix.lower()
        if suffix not in ('.sh', '.zip', '.json', '.png'):
            ignored += 1
            continue
        try:
            if p.stat().st_size == 0:
                raise ValueError('fichier vide')
            if suffix == '.sh':
                r = subprocess.run(['bash', '-n', str(p)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
                if r.returncode:
                    raise ValueError('syntaxe Bash')
            elif suffix == '.zip':
                with zipfile.ZipFile(p) as z:
                    if z.testzip() is not None:
                        raise ValueError('archive corrompue')
            elif suffix == '.json':
                import json
                json.loads(p.read_text(encoding='utf-8'))
            elif suffix == '.png':
                if p.read_bytes()[:8] != b'\x89PNG\r\n\x1a\n':
                    raise ValueError('format PNG')
            checked += 1
        except (OSError, ValueError, zipfile.BadZipFile, subprocess.TimeoutExpired) as exc:
            issues.append((p.name, str(exc)))
    print(f'[OK] Vérifiés : {checked}' if not issues else f'[ATTENTION] Vérifiés : {checked}')
    print(f'Anomalies : {len(issues)}')
    if ignored:
        print(f'Non contrôlés : {ignored}')
    for name, reason in issues[:5]:
        short = name if len(name) <= 24 else name[:21] + '...'
        print(f'  {short} : {reason}')
    if len(issues) > 5:
        print(f'  + {len(issues)-5} autre(s) anomalie(s)')
    print('[INFO] Format uniquement.')
    if issues:
        sys.exit(1)
elif mode == 'clear':
    for p in files:
        p.unlink()
    for p in sorted(dirs, key=lambda x: len(x.parts), reverse=True):
        p.rmdir()
    print('[OK] Cache vidé.')
else:
    sys.exit(2)
PYCACHE
}
cache_management_menu(){
  local choice
  while :; do
    refresh_screen
    ui_section 'GESTION DU CACHE'
    ui_item '1) Informations'
    ui_item '2) Vider le cache'
    ui_item '3) Vérifier le cache'
    echo
    ui_item '0) Retour'
    ui_item 'Q) Quitter le gestionnaire'
    choice="$(read_key 'Votre choix : ')" || return 0
    case "$choice" in
      1) cache_inspect info; pause ;;
      2) if cache_inspect summary && confirm 'Vider le cache ?'; then cache_inspect clear; else echo '[INFO] Annulé.'; fi; pause ;;
      3) cache_inspect verify; pause ;;
      0) return 0 ;;
      *) ui_print warning 'Choix invalide.'; pause ;;
    esac
  done
}

gestion_installations_menu(){
  local choice
  while :; do
    refresh_screen
    ui_section 'GESTION DES INSTALLATIONS'
    ui_item '1) Comparer GitHub / cache'
    ui_item '2) Télécharger'
    echo
    ui_item '3) Gestion du cache'
    ui_item '0) Retour'
    ui_item 'Q) Quitter le gestionnaire'
    choice="$(read_key 'Votre choix : ')" || return 0
    case "$choice" in
      1) check_local_updates; pause ;;
      2) download_menu ;;
      3) cache_management_menu ;; 
      0) return 0 ;;
      *) ui_print warning 'Choix invalide.'; pause ;;
    esac
  done
}

gestion_diagnostics_menu(){
  local choice
  while :; do
    refresh_screen
    ui_section 'DIAGNOSTICS'
    ui_item '1) Diagnostic du système'
    ui_item '2) Journal'
    echo
    ui_item '0) Retour'
    ui_item 'Q) Quitter le gestionnaire'
    choice="$(read_key 'Votre choix : ')" || return 0
    case "$choice" in
      1) diag_menu ;;
      2)
        if [[ -w /dev/tty ]]; then
          show_safe_journal > /dev/tty 2>&1
        else
          show_safe_journal
        fi
        pause ;;
      0) return 0 ;;
      *) ui_print warning 'Choix invalide.'; pause ;;
    esac
  done
}

# Volume au demarrage (Batocera 44) : service utilisateur autonome.
# Le service Volume Hotkey reste totalement independant.
STARTVOL_SERVICE='/userdata/system/services/volume_demarrage'
startvol_current(){
  local current=''
  if [[ -f "$STARTVOL_SERVICE" && ! -L "$STARTVOL_SERVICE" ]]; then
    current="$(sed -nE 's/^[[:space:]]*batocera-audio[[:space:]]+setSystemVolume[[:space:]]+([0-9]{1,3})[[:space:]]*$/\1/p' "$STARTVOL_SERVICE" | head -n 1)"
  fi
  if [[ "$current" =~ ^[0-9]{1,3}$ ]] && (( 10#$current <= 100 )); then
    printf '%d' "$((10#$current))"
  else
    printf '%s' '--'
  fi
}
startvol_install(){
  local pct="$1" tmp='' backup=''
  [[ "$pct" =~ ^[0-9]+$ ]] && (( pct >= 0 && pct <= 100 )) || {
    echo '[ERREUR] Volume invalide (0-100).'; return 1;
  }
  if [[ -L "$STARTVOL_SERVICE" ]]; then
    echo '[SECURITE] Service symbolique : operation refusee.'; return 1
  fi
  if [[ -e "$STARTVOL_SERVICE" ]]; then
    backup="${STARTVOL_SERVICE}.bak-$(date +%Y%m%d-%H%M%S)"
    if ! cp -p -- "$STARTVOL_SERVICE" "$backup"; then
      echo '[ERREUR] Sauvegarde impossible, aucune modification.'; return 1
    fi
    echo "[OK] Sauvegarde : $backup"
  fi
  if ! mkdir -p /userdata/system/services; then return 1; fi
  tmp="$(mktemp /userdata/system/services/.volume_demarrage.XXXXXX)" || return 1
  cat > "$tmp" <<EOF_STARTVOL
#!/bin/bash
# BLONDIN EDITION : volume general de demarrage (Batocera 44).
[ "\$1" = "start" ] || exit 0
(
    sleep 10
    batocera-audio setSystemVolume $pct
) >/tmp/volume-demarrage.log 2>&1 &
exit 0
EOF_STARTVOL
  if ! bash -n "$tmp" || ! chmod 755 "$tmp" || ! mv -f -- "$tmp" "$STARTVOL_SERVICE"; then
    rm -f -- "$tmp"
    echo '[ERREUR] Installation du service impossible.'; return 1
  fi
  if ! batocera-services enable volume_demarrage; then
    echo '[ATTENTION] Fichier installe, activation auto non confirmee.'; return 1
  fi
  if ! batocera-services stop volume_demarrage >/dev/null 2>&1; then :; fi
  if batocera-services start volume_demarrage; then
    echo "[OK] Volume programme a $pct % (apres 10 s au demarrage)."
  else
    echo '[ATTENTION] Service active mais demarrage immediat non confirme.'
  fi
}
# État du démarrage auto déclaré dans batocera-services (format nom;état).
# N'affiche pas un statut actif supposé quand la liste est inaccessible.
startvol_autostart_status(){
  local listing='' line='' name='' status=''
  command -v batocera-services >/dev/null 2>&1 || { printf 'inconnu'; return; }
  listing="$(batocera-services list 2>/dev/null)" || { printf 'inconnu'; return; }
  while IFS= read -r line; do
    name="${line%%;*}"
    [[ "${name,,}" == volume_demarrage ]] || continue
    if [[ "$line" != *';'* ]]; then printf 'inconnu'; return; fi
    status="${line#*;}"
    status="${status%%;*}"
    case "${status,,}" in
      -|0|off|disabled|false|no) printf 'non';;
      ''|unknown) printf 'inconnu';;
      *) printf 'oui';;
    esac
    return
  done <<< "$listing"
  printf 'non'
}
startvol_uninstall(){
  local status=''
  if [[ -L "$STARTVOL_SERVICE" ]]; then
    ui_print error '  Lien symbolique : suppression refusée.'
    return 1
  fi
  if [[ ! -e "$STARTVOL_SERVICE" ]]; then
    ui_print info '  Service déjà absent.'
    return 0
  fi
  if [[ ! -f "$STARTVOL_SERVICE" ]]; then
    ui_print error '  Type de fichier inattendu.'
    return 1
  fi
  # On désactive avant suppression, et on ne masque pas un échec.
  if ! batocera-services disable volume_demarrage; then
    ui_print error '  Désactivation échouée : fichier conservé.'
    return 1
  fi
  batocera-services stop volume_demarrage >/dev/null 2>&1 || true
  if [[ -L "$STARTVOL_SERVICE" || ! -f "$STARTVOL_SERVICE" ]]; then
    ui_print error '  Fichier modifié : suppression annulée.'
    return 1
  fi
  if rm -- "$STARTVOL_SERVICE"; then
    ui_print success '  ✓ Service désinstallé.'
    ui_print info '  Volume Hotkey conservé.'
  else
    ui_print error '  Suppression impossible.'
    return 1
  fi
}
startvol_menu(){
  local choice pct installed autostart=''
  while :; do
    refresh_screen
    ui_section 'VOLUME AUTO-DÉMARRAGE'
    if [[ -f "$STARTVOL_SERVICE" && ! -L "$STARTVOL_SERVICE" ]]; then
      installed='present'
      ui_print success '  ✓ Service installé'
      autostart="$(startvol_autostart_status)"
      case "$autostart" in
        oui) ui_print success '  ✓ Démarrage auto activé' ;;
        non) ui_print warning '  ✗ Démarrage auto désactivé' ;;
        *) ui_print warning '  ◆ Démarrage auto inconnu' ;;
      esac
      ui_print info "  Volume : $(startvol_current) % | Délai : 10 s"
    else
      installed='absent'
      ui_print warning '  ✗ Service absent'
    fi
    echo
    ui_item '1) Installer / Modifier'
    ui_item '2) Activer'
    ui_item '3) Désactiver'
    ui_item '4) Désinstaller'
    echo
    ui_item '0) Retour'
    ui_item 'Q) Quitter le gestionnaire'
    choice="$(read_key 'Votre choix : ')" || return 0
    [[ "$choice" == __ESC__ ]] && continue
    case "$choice" in
      1)
        echo '  Volume souhaité (0 à 100 %) :'
        ui_prompt 'Pourcentage : '
        IFS= read -r pct || return 0
        if [[ "$pct" =~ ^[0-9]{1,3}$ ]] && (( 10#$pct <= 100 )); then
          pct="$((10#$pct))"
          if confirm "Appliquer $pct % au démarrage ?"; then startvol_install "$pct"; else echo '[INFO] Annulé.'; fi
        else
          echo '[ERREUR] Entrer une valeur de 0 à 100.'
        fi
        pause ;;
      2)
        if [[ "$installed" == absent ]]; then
          echo '[INFO] Installer avec le choix 1.'
        elif confirm 'Activer le volume au démarrage ?'; then
          batocera-services enable volume_demarrage && batocera-services start volume_demarrage
        fi
        pause ;;
      3)
        if [[ "$installed" == absent ]]; then
          ui_print info '  Service absent.'
        elif confirm 'Désactiver le volume au démarrage ?'; then
          if batocera-services disable volume_demarrage; then
            batocera-services stop volume_demarrage >/dev/null 2>&1 || true
            ui_print info '  Désactivé ; fichier conservé.'
          else
            ui_print error '  Désactivation impossible.'
          fi
        fi
        pause ;;
      4)
        if [[ "$installed" == absent ]]; then
          ui_print info '  Service déjà absent.'
        elif confirm 'Désinstaller Volume auto-démarrage ?'; then
          startvol_uninstall
        else
          ui_print info '  Annulé.'
        fi
        pause ;;
      0) return 0 ;;
      Q|q) return 0 ;;
      *) ui_print warning 'Choix invalide.'; pause ;;
    esac
  done
}

# Batocera 44 : suppression sélective des noms de tri numérotés ARRM.
# Ne touche pas aux autres champs XML et crée une sauvegarde par gamelist modifiée.
arrm_sort_scan_apply(){
  local mode="${1:-scan}"
  python3 - "$mode" "$SAVES/ClassementARRM" <<'PYARRMSORT'
import os, re, shutil, sys, tempfile, datetime
from pathlib import Path
from xml.etree import ElementTree as ET

mode, backup_root = sys.argv[1], Path(sys.argv[2])
root = Path('/userdata/roms')
# Ne cibler que les champs sur une ligne au format ARRM valide : 06 =- Nom.
# L'ancrage sur une ligne évite de capturer d'autres balises.
pattern = re.compile(rb'(?m)^[ \t]*<sortname>[ \t]*[0-9]+[ \t]*=-[^\r\n<]*</sortname>[ \t]*(?:\r?\n|$)', re.I)
entries = []
if not root.is_dir():
    print('[ERREUR] Dossier des ROMs absent.'); sys.exit(1)
for path in sorted(root.rglob('gamelist.xml')):
    try:
        if path.is_symlink() or not path.is_file():
            continue
        data = path.read_bytes()
        if b'\0' in data:
            print('[ATTENTION] Fichier non textuel ignoré :',path); continue
        matches = list(pattern.finditer(data))
        if not matches: continue
        # Avant toute opération, il faut un XML original bien formé.
        ET.fromstring(data)
        after, count = pattern.subn(b'',data)
        ET.fromstring(after)
        entries.append((path,data,after,count))
    except (OSError,ET.ParseError) as exc:
        print('[ATTENTION] Gamelist ignorée :',path,'-',exc)
print('  Systèmes concernés :',len(entries))
print('  Noms de tri ARRM :',sum(e[3] for e in entries))
for path, _data, _after, count in entries:
    print('  %-22s %d' % (path.parent.name, count))
if mode=='scan':
    if not entries: print('[OK] Aucun tri ARRM à corriger.')
    sys.exit(0)
if mode!='apply':
    print('[ERREUR] Action inconnue.'); sys.exit(1)
if not entries:
    print('[OK] Aucune correction nécessaire.'); sys.exit(0)
run_dir = backup_root / datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
changed=0
for path, original, after, count in entries:
    tmp=None
    try:
        # Si un programme a modifié la gamelist depuis le diagnostic, ne pas l'écraser.
        if path.read_bytes()!=original:
            print('[ATTENTION] Modifiée pendant l’analyse, ignorée :',path); continue
        relative=path.relative_to(root)
        destination=run_dir/relative
        destination.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(path,destination)
        if destination.read_bytes()!=original:
            raise OSError('Sauvegarde non conforme')
        fd,tmpname=tempfile.mkstemp(prefix='.gamelist-arrm-',suffix='.tmp',dir=str(path.parent))
        tmp=Path(tmpname)
        with os.fdopen(fd,'wb') as f:
            f.write(after)
            f.flush(); os.fsync(f.fileno())
        os.chmod(tmp,path.stat().st_mode & 0o777)
        os.replace(tmp,path)
        tmp=None
        changed+=count
        print('[OK]',path.parent.name,':',count,'tri(s) supprimé(s)')
    except OSError as exc:
        print('[ERREUR]',path,'-',exc)
    finally:
        if tmp is not None:
            try: tmp.unlink(missing_ok=True)
            except OSError: pass
print('[BILAN]',changed,'nom(s) de tri corrigé(s).')
print('[SAUVEGARDES]',run_dir)
print('[INFO] Actualiser les listes de jeux dans EmulationStation.')
PYARRMSORT
}

arrm_sort_menu(){
  refresh_screen
  ui_section 'CLASSEMENT DES JEUX ARRM'
  ui_print info '  Analyse des gamelists (sans modification)...'
  if ! arrm_sort_scan_apply scan; then
    ui_print error '  Diagnostic impossible.'
    pause
    return 1
  fi
  echo
  ui_print warning '  Fermer EmulationStation avant correction pour éviter'
  ui_print warning '  une réécriture des gamelists par le système.'
  echo
  if confirm 'Supprimer les noms de tri numérotés ARRM ?'; then
    arrm_sort_scan_apply apply
  else
    ui_print info '  Correction annulée.'
  fi
  pause
}

# =========== SAUVEGARDE DES PARAMETRES - BATOCERA 44 ===========
# Local : archives non chiffrees ; GitHub : archives chiffrees uniquement.
# Aucune ROM, partie sauvegardee, bouteille Wine, runner ou cle Syncthing.
backup_params_engine(){
  local operation="$1"
  BLONDIN_BACKUP_COLOR="$UI_COLOR" python3 - "$operation" "$SAVES/ParametresBatocera44" <<'PY_BACKUP44'
import base64, datetime, getpass, hashlib, io, json, os, pathlib, re
import shutil, subprocess, sys, tarfile, tempfile, urllib.request, urllib.error

ACTION = sys.argv[1]
ROOT = pathlib.Path(sys.argv[2])
USERDATA = pathlib.Path('/userdata')
REPO = 'blondin-svg/batocera-backups'
API = 'https://api.github.com/repos/' + REPO + '/contents/'
MAX_UPLOAD = 900_000   # Limite volontaire pour l'API GitHub Contents.
MAX_SOURCE = 4_000_000
MANIFEST_NAME = 'manifest.json'
# Systèmes choisis par l'utilisateur : jamais les entrées LinuxLoader par défaut.
CUSTOM_CFG_DIR = USERDATA/'system/configs/emulationstation'
CUSTOM_SELECTION_NAME = 'systemes-personnalises-selection.json'
CUSTOM_PATTERN = re.compile(r'^es_systems_([a-z0-9_-]+)\.cfg$')
CUSTOM_ARCHIVE_PREFIX = 'system/configs/emulationstation/'
CUSTOM_DEFAULTS = {'hacks', 'windowsretro'}

class BackupError(Exception): pass

# Couleurs uniquement pour l'affichage, jamais pour la logique de restauration.
# Python lit ici son code via un heredoc : stdin n'est JAMAIS un terminal.
# Utiliser /dev/tty pour detecter le terminal SSH reel, meme avec tee.
def backup_color_terminal():
    if os.environ.get('BLONDIN_BACKUP_COLOR') != '1' or 'NO_COLOR' in os.environ:
        return False
    try:
        fd=os.open('/dev/tty', os.O_RDONLY | getattr(os, 'O_NOCTTY', 0))
        try:
            return os.isatty(fd)
        finally:
            os.close(fd)
    except OSError:
        return False
COLOR_ENABLED = backup_color_terminal()
COLORS = {'title': '1;96', 'ok': '1;32', 'warning': '1;33',
          'error': '1;31', 'info': '0;36', 'choice': '1;37'}
def paint(value, role):
    value = str(value)
    return ('\033[' + COLORS[role] + 'm' + value + '\033[0m') if COLOR_ENABLED else value

def status_ok(message):
    print(paint('[OK]', 'ok'), message)

def status_warning(message):
    print(paint('[!]', 'warning'), message)


def prompt(msg):
    try:
        with open('/dev/tty', 'r', encoding='utf-8') as inp:
            print(msg, end='', flush=True)
            return inp.readline().strip()
    except OSError:
        return input(msg).strip()

def device_id():
    candidates=[]
    for f in ('/sys/class/dmi/id/product_name','/sys/class/dmi/id/board_name'):
        try: candidates.append(pathlib.Path(f).read_text(errors='ignore').lower())
        except OSError: pass
    return 'SteamDeck' if any('jupiter' in x or 'galileo' in x or 'steam deck' in x for x in candidates) else 'MiniPC'

def device():
    detected=device_id()
    print('[APPAREIL] Détection :',detected)
    print('  1) Mini-PC   2) Steam Deck')
    choice=prompt('  Choix [Entrée = détection] : ')
    if choice not in ('','1','2'): raise BackupError('Choix invalide.')
    return {'1':'MiniPC','2':'SteamDeck'}.get(choice,detected)

def custom_slug(filename):
    match=CUSTOM_PATTERN.fullmatch(filename)
    return match.group(1) if match else None

def selected_path(dev):
    return ROOT/dev/CUSTOM_SELECTION_NAME

def get_selected(dev):
    path=selected_path(dev)
    if not path.exists():
        return set(CUSTOM_DEFAULTS)
    if not path.is_file() or path.is_symlink():
        raise BackupError('Sélection des systèmes invalide.')
    try:
        value=json.loads(path.read_text(encoding='utf-8'))
    except (OSError,ValueError) as exc:
        raise BackupError('Impossible de lire la sélection des systèmes : '+str(exc))
    if not isinstance(value,list) or any(not isinstance(v,str) or not re.fullmatch(r'[a-z0-9_-]+',v) for v in value):
        raise BackupError('Format de sélection des systèmes invalide.')
    return set(value)

def custom_defs():
    if CUSTOM_CFG_DIR.is_symlink() or not CUSTOM_CFG_DIR.is_dir():
        return []
    return sorted((p for p in CUSTOM_CFG_DIR.glob('es_systems_*.cfg')
                   if custom_slug(p.name) and p.is_file() and not p.is_symlink()),
                  key=lambda p:p.name)

def custom_rom_path(data,slug):
    # Autoriser uniquement un dossier simple sous /userdata/roms.
    # Aucune commande dans le XML n'est exécutée.
    import xml.etree.ElementTree as ET
    if len(data)>MAX_SOURCE:
        raise BackupError('Configuration de système trop volumineuse : '+slug)
    try:
        root=ET.fromstring(data)
    except ET.ParseError as exc:
        raise BackupError('XML invalide pour '+slug+' : '+str(exc))
    systems=root.findall('system') if root.tag=='systemList' else ([root] if root.tag=='system' else [])
    if len(systems)!=1:
        raise BackupError('Définition système inattendue : '+slug)
    node=systems[0]
    actual=(node.findtext('path') or '').strip()
    # Ne pas autoriser un chemin externe ni un sous-chemin avec traversal.
    if actual!='/userdata/roms/'+slug:
        raise BackupError('Chemin ROMs non conforme pour '+slug+' : '+actual)
    return USERDATA/'roms'/slug

def custom_archive_items(files):
    result=[]
    for key,content in sorted(files.items()):
        if not key.startswith(CUSTOM_ARCHIVE_PREFIX):
            continue
        basename=key[len(CUSTOM_ARCHIVE_PREFIX):]
        slug=custom_slug(basename)
        if slug is None:
            raise BackupError('Définition système interdite : '+key)
        destination=custom_rom_path(content,slug)
        result.append((slug,destination))
    return result

def latest_local_customs(dev):
    """Read only the newest unencrypted local backup; never assume GitHub content."""
    folder=ROOT/dev
    if not folder.is_dir() or folder.is_symlink():
        return None,None
    candidates=sorted((p for p in folder.glob('Batocera44-'+dev+'-*.tar.gz')
                       if p.is_file() and not p.is_symlink()),
                      key=lambda p:p.name, reverse=True)
    if not candidates:
        return None,None
    archive=candidates[0]
    try:
        if archive.stat().st_size>30_000_000:
            raise ValueError('Archive trop volumineuse pour aperçu')
        with tarfile.open(archive,'r:gz') as tf:
            members=tf.getmembers()
            if len(members)>200 or any(not m.isfile() or m.size>MAX_SOURCE for m in members):
                raise ValueError('Archive non conforme')
            manifest=tf.extractfile(MANIFEST_NAME)
            if manifest is None:raise ValueError('Manifeste absent')
            metadata=json.load(manifest)
            if metadata.get('format')!=1 or metadata.get('device')!=dev or metadata.get('batocera')!='44':
                raise ValueError('Manifeste incompatible')
            hashes=metadata.get('files',{})
            if not isinstance(hashes,dict):raise ValueError('Inventaire invalide')
            names={m.name for m in members if m.name!=MANIFEST_NAME}
            if names!=set(hashes):raise ValueError('Inventaire incomplet')
            present=set()
            for name in names:
                if not name.startswith(CUSTOM_ARCHIVE_PREFIX):continue
                slug=custom_slug(name[len(CUSTOM_ARCHIVE_PREFIX):])
                if not slug:continue
                data=tf.extractfile(name).read()
                if hashlib.sha256(data).hexdigest()!=hashes[name]:
                    raise ValueError('Empreinte incorrecte')
                custom_rom_path(data,slug)
                present.add(slug)
            return present,archive.name
    except (OSError,ValueError,KeyError,tarfile.TarError,json.JSONDecodeError) as exc:
        status_warning('Dernière sauvegarde locale non vérifiable : '+str(exc))
        return None,archive.name

def custom_selection_menu(dev):
    available=custom_defs()
    if not available:
        print('[INFO] Aucun fichier es_systems_*.cfg détecté.')
        return
    # Toujours en tête, les autres systèmes classés alphabétiquement.
    priority={'hacks':0,'windowsretro':1}
    available.sort(key=lambda p:(priority.get(custom_slug(p.name),2),custom_slug(p.name)))
    backed_up,backup_name=latest_local_customs(dev)
    # Un système déjà présent dans la dernière archive locale n'a pas besoin
    # d'être sélectionné une seconde fois. Il reste automatiquement repris
    # dans les sauvegardes suivantes (voir custom_saved_paths).
    already=set(backed_up or ())
    selected=get_selected(dev)-already
    while True:
        show_heading('SYSTÈMES PERSONNALISÉS')
        print('  [x] À ajouter  ',paint('✓','ok'),'Déjà sauvegardé')
        if backup_name is None:
            print('  '+paint('Aucune sauvegarde locale.','warning'))
        elif backed_up is None:
            print('  '+paint('Dernière archive non vérifiable.','warning'))
        print('')
        for n,p in enumerate(available,1):
            slug=custom_slug(p.name)
            is_priority=slug in priority
            name=paint(slug.upper() if is_priority else slug,
                       'title' if is_priority else 'choice')
            mark=paint('[x]','ok') if slug in selected else '[ ]'
            saved=paint('✓','ok') if slug in already else ''
            label=f'  {n:02d}) {mark} {name}'
            # Symbole court : même WINDOWSRETRO tient sur une seule ligne.
            print(label + ('  '+saved if saved else ''))
        print('')
        print('  0) Enregistrer / retour')
        answer=prompt('Numéro à activer/désactiver : ')
        if answer=='0':
            dest=selected_path(dev)
            dest.parent.mkdir(parents=True,exist_ok=True)
            if dest.is_symlink(): raise BackupError('Lien symbolique de sélection refusé.')
            fd,temp=tempfile.mkstemp(prefix='.selection-',dir=dest.parent)
            try:
                with os.fdopen(fd,'w',encoding='utf-8') as f:
                    json.dump(sorted(selected),f,ensure_ascii=False,indent=2)
                    f.write('\n')
                os.chmod(temp,0o600)
                os.replace(temp,dest)
            finally:
                if os.path.exists(temp): os.unlink(temp)
            status_ok('À ajouter : '+str(len(selected))+' système(s).')
            return
        if not answer.isdigit() or not 1<=int(answer)<=len(available):
            status_warning('Choix invalide.'); continue
        slug=custom_slug(available[int(answer)-1].name)
        if slug in already:
            status_ok(slug+' : déjà sauvegardé ; conservé pour les prochaines archives.')
            continue
        if slug in selected:selected.remove(slug)
        else:
            custom_rom_path(available[int(answer)-1].read_bytes(),slug)
            selected.add(slug)
        # La coche "sauvegardé" reflète la dernière archive, et n'évolue pas
        # lors d'un simple changement de sélection.

def custom_saved_paths(dev):
    # Une nouvelle archive doit rester autonome : conserver les systèmes
    # déjà présents dans la dernière sauvegarde, même décochés dans le menu.
    already,_=latest_local_customs(dev)
    selected=get_selected(dev)|set(already or ())
    result=[]
    for p in custom_defs():
        slug=custom_slug(p.name)
        if slug in selected:
            custom_rom_path(p.read_bytes(),slug)
            result.append(p)
    absent=sorted(selected-{custom_slug(p.name) for p in custom_defs()})
    for slug in absent:status_warning('Système sélectionné mais absent : '+slug)
    return result

def safe_sources(dev):
    base=USERDATA/'system'
    paths=[base/'batocera.conf']
    es=base/'configs/emulationstation'
    paths += [es/'es_settings.cfg',es/'es_input.cfg']
    if (es/'collections').is_dir() and not (es/'collections').is_symlink():
        paths += sorted(p for p in (es/'collections').rglob('*') if p.is_file())
    # Emulateurs : seules les configurations utilisateur (pas les donnees de jeux).
    for rel in ('configs/retroarch/retroarchcustom.cfg','configs/retroarch/retroarch-core-options.cfg',
                'configs/retroarch/retroarch-core-options.cfg'):
        paths.append(base/rel)
    paths += custom_saved_paths(dev)
    seen=set()
    for p in paths:
        if p in seen or not p.is_file() or p.is_symlink(): continue
        seen.add(p)
        if not p.resolve().is_relative_to(base.resolve()): continue
        if p.stat().st_size > MAX_SOURCE:
            print('[ATTENTION] Fichier trop volumineux ignoré :',p)
            continue
        yield p

def password(twice=False):
    pw=getpass.getpass('Phrase secrète de chiffrement (non enregistrée) : ')
    if len(pw)<12: raise BackupError('Phrase secrète trop courte (12 caractères minimum).')
    if twice and pw!=getpass.getpass('Confirmer la phrase secrète : '):
        raise BackupError('Confirmation différente.')
    return pw

def openssl(src,dst,pw,decrypt=False):
    if not shutil.which('openssl'): raise BackupError('OpenSSL absent ; sauvegarde chiffrée impossible.')
    read_fd,write_fd=os.pipe()
    try:
        os.write(write_fd,(pw+'\n').encode())
        os.close(write_fd); write_fd=-1
        args=['openssl','enc','-aes-256-cbc','-pbkdf2','-iter','250000','-salt',
              '-pass',f'fd:{read_fd}','-in',str(src),'-out',str(dst)]
        if decrypt: args.insert(2,'-d')
        res=subprocess.run(args,pass_fds=(read_fd,),capture_output=True,text=True)
        if res.returncode: raise BackupError('Déchiffrement ou chiffrement impossible (clé incorrecte ou archive endommagée).')
    finally:
        os.close(read_fd)
        if write_fd!=-1: os.close(write_fd)

def create_archive(target,pw,dev):
    target.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='batocera-backup-') as tmp:
        raw=pathlib.Path(tmp)/'config.tar.gz'
        files=list(safe_sources(dev))
        if not files: raise BackupError('Aucun paramètre Batocera trouvé.')
        meta={'format':1,'batocera':'44','device':dev,
              'created':datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'files':{},'custom_systems':[]}
        with tarfile.open(raw,'w:gz') as tf:
            for p in files:
                rel=p.relative_to(USERDATA).as_posix()
                data=p.read_bytes()
                meta['files'][rel]=hashlib.sha256(data).hexdigest()
                if rel.startswith(CUSTOM_ARCHIVE_PREFIX):
                    meta['custom_systems'].append(custom_slug(p.name))
                t=tarfile.TarInfo(rel);t.size=len(data);t.mode=0o600
                tf.addfile(t,io.BytesIO(data))
            b=json.dumps(meta,ensure_ascii=False,sort_keys=True).encode()
            t=tarfile.TarInfo(MANIFEST_NAME);t.size=len(b);t.mode=0o600
            tf.addfile(t,io.BytesIO(b))
        temp=target.with_name('.'+target.name+'.part')
        try:
            if pw is None:
                # Sauvegarde locale lisible sans phrase secrète.
                shutil.copyfile(raw,temp)
            else:
                # Sauvegarde GitHub chiffrée avant tout transfert.
                openssl(raw,temp,pw)
            os.chmod(temp,0o600)
            temp.replace(target)
        finally: temp.unlink(missing_ok=True)
    print('[OK] Archive créée :',target)
    print('[FICHIERS] Paramètres sauvegardés :',len(files))
    print('[TAILLE] Archive',('locale non chiffrée' if pw is None else 'chiffrée'),':',target.stat().st_size,'octets')

def decode_archive(archive,pw,expected_dev):
    with tempfile.TemporaryDirectory(prefix='batocera-restore-') as tmp:
        raw=pathlib.Path(tmp)/'config.tar.gz'
        if archive.name.endswith('.tar.gz.enc'):
            if pw is None: raise BackupError('Phrase secrète requise pour cette archive.')
            openssl(archive,raw,pw,decrypt=True)
        elif archive.name.endswith('.tar.gz'):
            if pw is not None: raise BackupError('Archive locale : chiffrement inattendu.')
            shutil.copyfile(archive,raw)
        else:
            raise BackupError('Format de sauvegarde non reconnu.')
        result={}
        with tarfile.open(raw,'r:gz') as tf:
            members=tf.getmembers()
            names=[m.name for m in members]
            if len(names)!=len(set(names)): raise BackupError('Archive invalide : doublons.')
            for item in members:
                if not item.isfile() or item.size>MAX_SOURCE or item.name.startswith('/') or '..' in pathlib.PurePosixPath(item.name).parts:
                    raise BackupError('Archive invalide : chemin ou contenu non autorisé.')
                if item.name!=MANIFEST_NAME and not item.name.startswith('system/'):
                    raise BackupError('Archive invalide : chemin non autorisé.')
                result[item.name]=tf.extractfile(item).read()
        if MANIFEST_NAME not in result: raise BackupError('Manifeste absent.')
        meta=json.loads(result.pop(MANIFEST_NAME).decode())
        if meta.get('format')!=1 or meta.get('batocera')!='44' or meta.get('device')!=expected_dev:
            raise BackupError('Version Batocera ou appareil différent : restauration refusée.')
        if set(result)!=set(meta['files']): raise BackupError('Inventaire des fichiers incohérent.')
        for k,b in result.items():
            if hashlib.sha256(b).hexdigest()!=meta['files'][k]:
                raise BackupError('Empreinte invalide : '+k)
        customs=custom_archive_items(result)
        if 'custom_systems' in meta:
            declared=meta['custom_systems']
            if not isinstance(declared,list) or sorted(declared)!=sorted(slug for slug,_ in customs):
                raise BackupError('Inventaire des systèmes personnalisés incohérent.')
        return result

def github_request(method,path,token,data=None):
    req=urllib.request.Request(API+urllib.parse.quote(path,safe='/'),data=data,method=method,
        headers={'Authorization':'Bearer '+token,'Accept':'application/vnd.github+json',
                 'X-GitHub-Api-Version':'2022-11-28','User-Agent':'Blondin-Batocera-Backup',
                 'Content-Type':'application/json'})
    try:
        with urllib.request.urlopen(req,timeout=35) as response: return json.load(response)
    except urllib.error.HTTPError as exc:
        raise BackupError('GitHub : HTTP '+str(exc.code)+' (vérifier les droits Contents du jeton et le dépôt privé).') from None
    except urllib.error.URLError as exc:
        raise BackupError('GitHub indisponible : '+str(exc.reason)) from None

def token():
    value=getpass.getpass('Jeton GitHub (Contents lecture/écriture, jamais sauvegardé) : ')
    if not value: raise BackupError('Jeton manquant.')
    return value

def remote_list(tok,dev):
    try: arr=github_request('GET',dev,tok)
    except BackupError as exc:
        # Dossier absent sur dépôt vierge : 404 sans échec général.
        if 'HTTP 404' in str(exc): return []
        raise
    return sorted((x for x in arr if isinstance(x,dict) and x.get('name','').endswith('.enc')),
                  key=lambda x:x['name'],reverse=True)

def upload(archive,tok,dev):
    if archive.stat().st_size>MAX_UPLOAD:
        raise BackupError('Archive >900 Ko : conservée localement ; envoi GitHub ignoré (limite de sécurité API).')
    rel=dev+'/'+archive.name
    existing=None
    try: existing=github_request('GET',rel,tok).get('sha')
    except BackupError as exc:
        if 'HTTP 404' not in str(exc): raise
    body={'message':'Sauvegarde chiffrée Batocera 44 '+dev,
          'content':base64.b64encode(archive.read_bytes()).decode()}
    if existing: body['sha']=existing
    github_request('PUT',rel,tok,json.dumps(body).encode())
    print('[OK] Sauvegarde envoyée au dépôt privé :',REPO+'/'+rel)

def decode_github_content(payload):
    # GitHub Contents renvoie du Base64 avec retours à la ligne (76 caractères).
    # Ignorer uniquement les séparateurs ASCII ; valider ensuite le Base64 strictement.
    if not isinstance(payload,dict) or payload.get('encoding')!='base64':
        raise BackupError('Réponse GitHub : encodage inattendu.')
    content=payload.get('content')
    if not isinstance(content,str):
        raise BackupError('Réponse GitHub : contenu absent.')
    compact=re.sub(r'[ \t\r\n\f\v]', '', content)
    try:
        result=base64.b64decode(compact,validate=True)
    except (ValueError,base64.binascii.Error):
        raise BackupError('Réponse GitHub : contenu Base64 invalide.') from None
    if not result or len(result)>MAX_UPLOAD:
        raise BackupError('Archive GitHub vide ou supérieure à 900 Ko.')
    # Vérifier aussi le SHA Git blob renvoyé par l’API (avant déchiffrement).
    sha=payload.get('sha')
    if isinstance(sha,str) and re.fullmatch(r'[0-9a-fA-F]{40}',sha):
        expected=hashlib.sha1(b'blob '+str(len(result)).encode()+b'\0'+result).hexdigest()
        if expected.lower()!=sha.lower():
            raise BackupError('Archive GitHub : empreinte Git incorrecte.')
    return result

def pick(files):
    if not files: raise BackupError('Aucune sauvegarde disponible.')
    for i,f in enumerate(files,1):print(f'  {i}) {f.name}')
    n=prompt('Numéro (0 = annuler) : ')
    if not n.isdigit() or int(n)==0 or not 1<=int(n)<=len(files):
        raise BackupError('Sélection annulée.')
    return files[int(n)-1]

def pending_check(line):
    left,value=line.split('=',1)
    if not left.strip().endswith('.wine-runner'): return True
    name=value.strip()
    if name.lower() in ('','auto','default'):
        return True
    folder=USERDATA/'system/wine/custom'
    custom=folder/name
    builtin=pathlib.Path('/usr/wine')/name
    return ((custom.is_dir() and not custom.is_symlink()) or builtin.is_dir())

def allowed_backup_path(k):
    allowed={'system/batocera.conf',
             'system/configs/emulationstation/es_settings.cfg',
             'system/configs/emulationstation/es_input.cfg',
             'system/configs/retroarch/retroarchcustom.cfg',
             'system/configs/retroarch/retroarch-core-options.cfg'}
    if k.startswith(CUSTOM_ARCHIVE_PREFIX):
        return custom_slug(k[len(CUSTOM_ARCHIVE_PREFIX):]) is not None
    return k in allowed or (k.startswith('system/configs/emulationstation/collections/')
                            and pathlib.PurePosixPath(k).suffix in ('.cfg','.xcc'))

def show_heading(title):
    # Format volontairement court pour les terminaux SSH mobiles.
    print('')
    print(paint('--- ' + title + ' ---', 'title'))

def verify_archive(archive,dev):
    # Lecture et controles uniquement ; aucune modification des parametres.
    if not archive.is_file() or archive.is_symlink():
        raise BackupError('Fichier archive introuvable ou lien symbolique.')
    show_heading('SAUVEGARDE')
    # La date/heure suffit pour identifier l'archive a l'ecran.
    stamp=re.search(r'(\d{8})-(\d{6})\.tar\.gz(?:\.enc)?$',archive.name)
    print('Archive :', (stamp.group(1)+' '+stamp.group(2)) if stamp else archive.name)
    print('Taille  :', archive.stat().st_size, 'octets')
    print('Appareil :', dev)
    encrypted=archive.name.endswith('.tar.gz.enc')
    if not encrypted and not archive.name.endswith('.tar.gz'):
        raise BackupError('Format de sauvegarde inconnu.')
    files=decode_archive(archive,password() if encrypted else None,dev)
    unexpected=[k for k in files if not allowed_backup_path(k)]
    if unexpected:
        raise BackupError('Chemin non autorisé : '+', '.join(unexpected[:3]))
    if not files: raise BackupError('Archive vide : aucun paramètre.')
    show_heading('CONTRÔLES')
    status_ok('Lecture / déchiffrement')
    status_ok('Format Batocera 44')
    status_ok('Appareil compatible')
    status_ok('Empreintes SHA-256')
    print(paint('Fichiers :', 'info'),len(files))
    show_heading('APERÇU DES FICHIERS')
    for k in sorted(files):
        current=USERDATA/k
        try:
            same=current.is_file() and not current.is_symlink() and current.read_bytes()==files[k]
        except OSError:
            same=False
        # Afficher seulement le nom du fichier pour eviter les lignes coupees.
        label=pathlib.PurePosixPath(k).name
        print(' ', paint('[=]', 'ok') if same else paint('[!]', 'warning'), label)
    conf=files.get('system/batocera.conf',b'')
    try:
        lines=conf.decode('utf-8').splitlines()
    except UnicodeDecodeError:
        raise BackupError('batocera.conf non lisible en UTF-8.')
    selections=[line for line in lines if re.match(r'^\s*[^#\s][^=]*\.wine-runner\s*=',line)]
    unavailable=[line for line in selections if not pending_check(line)]
    show_heading('RUNNERS WINE')
    print(paint('Choix :', 'info'),len(selections))
    print(paint('Absents :', 'warning' if unavailable else 'ok'),len(unavailable))
    for line in unavailable:
        name=line.split('=',1)[0].strip()
        print('  ',paint('[!]', 'warning'), ' ', name[:32],sep='')
    customs=custom_archive_items(files)
    if customs:
        show_heading('SYSTÈMES PERSONNALISÉS')
        for slug,rompath in customs:
            print(' ',paint('[OK]', 'ok'),slug,'- dossier',
                  ('présent' if rompath.is_dir() and not rompath.is_symlink() else 'à créer'))
    show_heading('BILAN')
    status_ok('Vérification terminée')
    print(paint('[=]', 'ok'), 'Identique ', paint('[!]', 'warning'), 'Différent')
    return files

def select_restore_scope(files):
    # Toujours appelé après decode_archive / verify_archive, avant toute écriture.
    custom_keys=sorted(k for k in files if k.startswith(CUSTOM_ARCHIVE_PREFIX))
    show_heading('TYPE DE RESTAURATION')
    print('  1) Tous les paramètres')
    print('  2) Systèmes personnalisés')
    print('  0) Annuler')
    if not custom_keys:
        status_warning('Aucun système personnalisé dans cette archive.')
    choice=prompt('Choix [0 = annuler] : ')
    if choice=='0' or choice not in ('1','2'):
        status_ok('Annulé : aucun paramètre modifié.')
        return None,None
    if choice=='2':
        if not custom_keys:
            status_warning('Restauration ciblée impossible : aucun système sauvegardé.')
            return None,None
        return {k:files[k] for k in custom_keys},'Systèmes personnalisés'
    return files,'Tous les paramètres'

def restore(files,dev,scope):
    for k in files:
        if not allowed_backup_path(k):
            raise BackupError('Archive avec fichier non autorisé : '+k)
    custom_dirs=custom_archive_items(files)
    dests={k:USERDATA/k for k in files}
    if any(p.is_symlink() or any(x.is_symlink() for x in p.parents if x!=USERDATA.parent)
           for p in dests.values()):
        raise BackupError('Lien symbolique dans les destinations : restauration refusée.')
    show_heading('CONFIRMATION')
    print('Mode :',scope)
    print('Fichiers :',len(files))
    if custom_dirs: print('Systèmes :',', '.join(slug for slug,_ in custom_dirs))
    print(paint('[!]', 'warning'), 'Quitter EmulationStation')
    print('    avant de restaurer.')
    print('')
    print('  ',paint('1)', 'ok'),'Restaurer')
    print('  ',paint('0)', 'warning'),'Annuler')
    print('')
    choice=prompt('Choix [0 = annuler] : ')
    if choice!='1':
        status_ok('Annulé : aucun paramètre modifié.')
        return
    # Sauvegarder avant d'écraser, en conservant la restauration possible même sans ES.
    safety=ROOT/dev/'AvantRestauration'
    safety.mkdir(parents=True,exist_ok=True)
    stamp=datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
    folder=safety/stamp
    folder.mkdir(exist_ok=False)
    try:
        prepared={}
        pending=[]
        for k,b in files.items():
            if k=='system/batocera.conf':
                lines=b.decode('utf-8').splitlines(keepends=True)
                keep=[]
                for line in lines:
                    if re.match(r'^\s*[^#\s][^=]*\.wine-runner\s*=',line) and not pending_check(line):
                        pending.append(line.rstrip('\r\n'))
                    else: keep.append(line)
                b=''.join(keep).encode('utf-8')
            prepared[k]=b
        for k,d in dests.items():
            if d.exists():
                back=folder/k
                back.parent.mkdir(parents=True,exist_ok=True)
                shutil.copy2(d,back)
        # Créer les dossiers uniquement après confirmation et sauvegarde des fichiers.
        # Refuser tout chemin existant qui n'est pas un vrai dossier.
        for slug,rompath in custom_dirs:
            if rompath.is_symlink() or (rompath.exists() and not rompath.is_dir()):
                raise BackupError('Dossier ROMs non sûr : '+str(rompath))
            if rompath.parent.is_symlink():
                raise BackupError('Racine ROMs non sûre.')
        for slug,rompath in custom_dirs:
            if not rompath.exists():
                rompath.parent.mkdir(parents=True,exist_ok=True)
                rompath.mkdir()  # n'écrit jamais de ROM.
                status_ok('Dossier créé : '+str(rompath))
        for k,b in prepared.items():
            p=dests[k]; p.parent.mkdir(parents=True,exist_ok=True)
            fd,tmp=tempfile.mkstemp(prefix='.restore-blondin-',dir=p.parent)
            try:
                with os.fdopen(fd,'wb') as f: f.write(b)
                os.chmod(tmp,0o600)
                os.replace(tmp,p)
            finally:
                if os.path.exists(tmp):os.unlink(tmp)
        if pending:
            pending_path=ROOT/dev/'runners-en-attente.txt'
            pending_path.write_text('\n'.join(pending)+'\n',encoding='utf-8')
            os.chmod(pending_path,0o600)
            print('[ATTENTION]',len(pending),'Runner(s) personnalisés absents : choix mis en attente.')
            print('[FICHIER]',pending_path)
        print('[OK] Restauration terminée :',scope)
        print('[SAUVEGARDE]',folder)
        print('[INFO] Redémarrer EmulationStation pour appliquer les réglages.')
        if pending: print('[INFO] Réinstaller les Runners manquants si nécessaire.')
    except Exception:
        print('[ERREUR] Restauration interrompue. Copies des anciens fichiers :',folder)
        raise

def retry_runners(dev):
    f=ROOT/dev/'runners-en-attente.txt'
    if not f.is_file(): raise BackupError('Aucun Runner en attente.')
    conf=USERDATA/'system/batocera.conf'
    if not conf.is_file(): raise BackupError('batocera.conf absent.')
    pending=f.read_text(encoding='utf-8').splitlines()
    ready=[line for line in pending if pending_check(line)]
    missing=[line for line in pending if not pending_check(line)]
    print('[RUNNERS] Disponibles :',len(ready),' / toujours absents :',len(missing))
    if not ready:return
    if prompt('Appliquer les choix devenus disponibles ? Taper OUI : ')!='OUI':return
    content=conf.read_text(encoding='utf-8')
    for line in ready:
        key=line.split('=',1)[0]
        content='\n'.join(x for x in content.split('\n') if x.split('=',1)[0]!=key)
        content=content.rstrip('\n')+'\n'+line+'\n'
    backup=conf.with_name('batocera.conf.pre-runners-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S'))
    shutil.copy2(conf,backup)
    conf.write_text(content,encoding='utf-8')
    if missing:f.write_text('\n'.join(missing)+'\n',encoding='utf-8')
    else:f.unlink()
    print('[OK] Choix Runners rétablis :',len(ready))

def main():
    dev=device()
    local=ROOT/dev
    local.mkdir(parents=True,exist_ok=True)
    if ACTION in ('save','save_github'):
        # GitHub reste chiffré, local uniquement sans chiffrement.
        if ACTION=='save':
            print('[ATTENTION] Sauvegarde locale NON CHIFFRÉE : elle peut contenir des informations confidentielles.')
            print('[INFO] Conserver cette archive sur un support protégé, hors du disque réinstallé.')
        pw=password(twice=True) if ACTION=='save_github' else None
        extension='.tar.gz.enc' if ACTION=='save_github' else '.tar.gz'
        archive=local/('Batocera44-'+dev+'-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S')+extension)
        create_archive(archive,pw,dev)
        if ACTION=='save_github':upload(archive,token(),dev)
    elif ACTION=='restore_local':
        archive=pick(sorted((p for p in local.iterdir() if p.is_file() and not p.is_symlink() and (p.name.endswith('.tar.gz') or p.name.endswith('.tar.gz.enc'))),reverse=True))
        files=verify_archive(archive,dev)
        chosen,scope=select_restore_scope(files)
        if chosen is not None: restore(chosen,dev,scope)
    elif ACTION=='restore_github':
        tok=token()
        entries=remote_list(tok,dev)
        selected=pick([pathlib.Path(x['name']) for x in entries])
        rel=dev+'/'+selected.name
        payload=github_request('GET',rel,tok)
        data=decode_github_content(payload)
        if len(data)>MAX_UPLOAD:
            raise BackupError('Archive GitHub trop volumineuse : restauration refusée.')
        # Vérifier l'archive distante dans un dossier temporaire, avant toute restauration.
        with tempfile.TemporaryDirectory(prefix='batocera-restore-github-') as tmp:
            archive=pathlib.Path(tmp)/selected.name
            archive.write_bytes(data)
            files=verify_archive(archive,dev)
            chosen,scope=select_restore_scope(files)
            if chosen is not None: restore(chosen,dev,scope)
    elif ACTION=='verify_local':
        archive=pick(sorted((p for p in local.iterdir() if p.is_file() and not p.is_symlink() and (p.name.endswith('.tar.gz') or p.name.endswith('.tar.gz.enc'))),reverse=True))
        verify_archive(archive,dev)
    elif ACTION=='verify_github':
        tok=token()
        entries=remote_list(tok,dev)
        selected=pick([pathlib.Path(x['name']) for x in entries])
        rel=dev+'/'+selected.name
        payload=github_request('GET',rel,tok)
        data=decode_github_content(payload)
        # Temporaire isolé : ne télécharge rien dans les sauvegardes permanentes.
        with tempfile.TemporaryDirectory(prefix='batocera-check-github-') as tmp:
            archive=pathlib.Path(tmp)/selected.name
            archive.write_bytes(data)
            verify_archive(archive,dev)
    elif ACTION=='custom_menu': custom_selection_menu(dev)
    elif ACTION=='list':
        entries=sorted((p for p in local.iterdir() if p.is_file() and not p.is_symlink() and (p.name.endswith('.tar.gz') or p.name.endswith('.tar.gz.enc'))),reverse=True)
        print('[SAUVEGARDES]',len(entries))
        for entry in entries:print(' ',entry.name, '-',entry.stat().st_size,'octets')
    elif ACTION=='retry': retry_runners(dev)
    else:raise BackupError('Action inconnue.')

try: main()
except (BackupError,OSError,ValueError,tarfile.TarError,UnicodeError,KeyError) as exc:
    print(paint('[ERREUR]', 'error'),exc)
    sys.exit(1)
PY_BACKUP44
}

backup_params_menu(){
  local choice
  while :; do
    refresh_screen
    ui_section 'SAUVEGARDES V44'
    ui_print info '  Local : non chiffré'
    ui_print info '  GitHub : chiffré'
    ui_print info '  Contrôle avant restauration'
    echo
    ui_item '1) Sauvegarder en local'
    ui_item '2) Sauvegarder sur GitHub'
    ui_item '3) Restaurer depuis local'
    ui_item '4) Restaurer depuis GitHub'
    ui_item '5) Voir les sauvegardes'
    ui_item '6) Réappliquer les runners'
    ui_item '7) Systèmes personnalisés'
    ui_item '0) Retour'
    choice="$(read_key 'Votre choix : ')" || return 0
    case "$choice" in
      1) backup_params_engine save; pause ;;
      2) backup_params_engine save_github; pause ;;
      3) backup_params_engine restore_local; pause ;;
      4) backup_params_engine restore_github; pause ;;
      5) backup_params_engine list; pause ;;
      6) backup_params_engine retry; pause ;;
      7) backup_params_engine custom_menu; pause ;;
      0) return 0 ;;
      *) ui_print warning 'Choix invalide.'; pause ;;
    esac
  done
}
# =========== FIN SAUVEGARDE PARAMETRES V44 ===========

# Affiche le temps restant dans la ligne 04 du menu Gestion.
# Lecture seule : le minuteur et ntfy ne sont jamais modifies.
ui_gestion_extinction(){
  local workers='' count=0 pid='' token='' path='' wp wt wpath remaining=''
  local message='' role='menu' prefix='04 ▸  Extinction'
  if workers="$(shutdown_workers list 2>/dev/null)"; then
    if [[ -n "$workers" ]]; then
      while IFS=' ' read -r wp wt wpath; do
        [[ -n "$wp" ]] || continue
        ((count+=1))
        pid="$wp"; token="$wt"; path="$wpath"
      done <<< "$workers"
    fi
    if (( count == 1 )); then
      remaining="$(shutdown_remaining "$path" "$token")"
      if [[ "$remaining" =~ ^[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
        message="● $remaining"
        role='success'
        # Seuil avertissement : 5 min ou moins.
        local hh mm ss
        IFS=: read -r hh mm ss <<< "$remaining"
        if (( 10#$hh == 0 && 10#$mm < 5 )); then role='warning'; fi
      else
        message='● Indisponible'
        role='warning'
      fi
    elif (( count > 1 )); then
      message='! Plusieurs minuteurs'
      role='warning'
    else
      message='○ Inactif'
      role='info'
    fi
  else
    message='! Etat inconnu'
    role='warning'
  fi
  # Garde le même habillage que les autres lignes ; colore uniquement l'état.
  if (( UI_COLOR )); then
    local color=$'\033[0;36m'
    case "$role" in
      success) color=$'\033[1;32m' ;;
      warning) color=$'\033[1;33m' ;;
      info) color=$'\033[0;36m' ;;
    esac
    printf '  \033[1;33m04 ▸\033[0m  \033[0;37mExtinction\033[0m  %s%s\033[0m\n' "$color" "$message"
  else
    printf '  %s  %s\n' "$prefix" "$message"
  fi
}

# Installation / reparation du lanceur Ports et de sa fiche EmulationStation.
blondin_ports_action(){
 local mode="$1"
 python3 - "$mode" <<'PYPORTS'
import hashlib, io, json, os, shutil, sys, tempfile, urllib.request, zipfile
import xml.etree.ElementTree as ET
from datetime import datetime
from pathlib import Path

mode = sys.argv[1]
ports = Path('/userdata/roms/ports')
launcher = ports / 'Gestionnaire Batocera.sh'
keys = ports / 'Gestionnaire Batocera.sh.keys'
manager = Path('/userdata/system/gestionnaire-batocera.sh')
gamelist = ports / 'gamelist.xml'
media = ports / 'images/gestionnaire-batocera'
backup = Path('/userdata/system/backup-gestionnaire-ports')
cache = Path('/userdata/system/cache-gestionnaire/visuels_ports_batocera_principaux.zip')
zip_url = 'https://raw.githubusercontent.com/blondin-svg/blondin.rep/main/visuels_ports_batocera_principaux.zip'
zip_prefix = 'visuels_ports_batocera_covers_definitifs/gestionnaire-batocera/'
images = {k: media / (k + '.png') for k in ('cover', 'fanart', 'logo')}


def safe_regular(p):
    return p.is_file() and not p.is_symlink()


def atomic_put(p, data, perms=0o644):
    p.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix='.blondin-', dir=str(p.parent))
    try:
        with os.fdopen(fd, 'wb') as f:
            f.write(data)
            f.flush()
            os.fsync(f.fileno())
        os.chmod(name, perms)
        os.replace(name, p)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def read_tree():
    if gamelist.is_symlink():
        raise ValueError('gamelist.xml est un lien symbolique')
    tree = ET.parse(gamelist) if gamelist.is_file() else ET.ElementTree(ET.Element('gameList'))
    if tree.getroot().tag != 'gameList':
        raise ValueError('Racine XML inattendue')
    return tree


def entries(root):
    return [g for g in root.findall('game') if (g.findtext('path') or '').strip().removeprefix('./') == launcher.name]


def validate_png(data, label):
    if (len(data) < 33 or data[:8] != b'\x89PNG\r\n\x1a\n' or
            data[12:16] != b'IHDR' or int.from_bytes(data[16:20], 'big') <= 0 or
            int.from_bytes(data[20:24], 'big') <= 0):
        raise ValueError('PNG invalide : ' + label)
    if len(data) > 16 * 1024 * 1024:
        raise ValueError('PNG trop volumineux : ' + label)


def extract_three(data):
    result = {}
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        for kind in images:
            path = zip_prefix + kind + '.png'
            matches = [i for i in z.infolist() if i.filename == path and not i.is_dir()]
            if len(matches) != 1:
                raise ValueError('Image manquante ou dupliquée dans ZIP : ' + path)
            info = matches[0]
            if info.file_size > 16 * 1024 * 1024:
                raise ValueError('Image trop volumineuse : ' + kind)
            content = z.read(info)
            validate_png(content, kind)
            result[kind] = content
    return result


if mode == 'state':
    for title, p in [('Gestionnaire', manager), ('Lanceur Ports', launcher),
                     ('Commandes manette', keys), ('Gamelist', gamelist)]:
        print(('[OK] ' if safe_regular(p) else '[ABSENT] ') + title)
    for kind, p in images.items():
        print(('[OK] ' if safe_regular(p) else '[ABSENT] ') + kind)
    try:
        print('[INFO] Entrée Ports :', len(entries(read_tree().getroot())))
    except (OSError, ValueError, ET.ParseError) as exc:
        print('[ATTENTION] Gamelist :', exc)
    sys.exit(0)
if mode != 'install':
    sys.exit(2)
if not safe_regular(manager):
    print('[ERREUR] Gestionnaire actif introuvable')
    sys.exit(1)
for p in (launcher, keys, gamelist, backup, cache, media, *images.values()):
    if p.is_symlink():
        print('[ERREUR] Lien symbolique non autorisé :', p)
        sys.exit(1)

try:
    tree = read_tree()
    print('[INFO] Téléchargement des illustrations GitHub...')
    request = urllib.request.Request(zip_url, headers={'User-Agent': 'Blondin-Batocera-44/3.0.15'})
    try:
        with urllib.request.urlopen(request, timeout=35) as response:
            data = response.read(45 * 1024 * 1024 + 1)
        if len(data) > 45 * 1024 * 1024:
            raise ValueError('Archive trop volumineuse')
        pictures = extract_three(data)
        # Archive complète en cache, après contrôle des trois illustrations.
        atomic_put(cache, data)
        print('[OK] Archive GitHub valide')
    except Exception as e:
        print('[ATTENTION] GitHub inaccessible :', str(e)[:160])
        if not safe_regular(cache):
            raise ValueError('Aucun cache valide disponible ; installation annulée')
        pictures = extract_three(cache.read_bytes())
        print('[OK] Visuels récupérés dans le cache vérifié')

    root = tree.getroot()
    found = entries(root)
    game = found[0] if found else ET.SubElement(root, 'game')
    for other in found[1:]:
        root.remove(other)
    fields = {
        'path': './Gestionnaire Batocera.sh',
        'name': 'Gestionnaire Batocera ★ BLONDIN EDITION ★',
        'desc': 'Gestionnaire pour Batocera 44 : installations, applications, diagnostics, patchs Rambo et Star Wars, sauvegardes, Syncthing et téléchargements 1fichier Premium.',
        'developer': 'Blondin/ChatGPT',
        'publisher': 'ChatGPT',
        'releasedate': '20261108T000000',
        'genre': 'Utilitaire',
        'players': '1',
        'image': './images/gestionnaire-batocera/fanart.png',
        'fanart': './images/gestionnaire-batocera/fanart.png',
        'thumbnail': './images/gestionnaire-batocera/cover.png',
        'marquee': './images/gestionnaire-batocera/logo.png',
    }
    for tag, value in fields.items():
        element = game.find(tag)
        if element is None:
            element = ET.SubElement(game, tag)
        element.text = value
    xml = ET.tostring(root, encoding='utf-8', xml_declaration=True)
    ET.fromstring(xml)

    launcher_text = """#!/bin/bash
export DISPLAY="${DISPLAY:-:0}"
export BLONDIN_PORTS_PAD=1
SCRIPT=/userdata/system/gestionnaire-batocera.sh
if [[ ! -f "$SCRIPT" ]]; then
  echo '[ERREUR] Gestionnaire introuvable.'
  sleep 5
  exit 1
fi
exec xterm -bg black -fg white -fa 'DejaVu Sans Mono' -fs 32 \\
  -geometry '100x29+650+85' -sb -rightbar -sl 5000 \\
  -title 'Gestionnaire Batocera - BLONDIN EDITION' \\
  -e /bin/bash "$SCRIPT"
"""
    # Les fichiers existants ne seront modifiés qu'après validation du ZIP et du XML.
    backup.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    for p in (launcher, keys, gamelist, *images.values()):
        if safe_regular(p):
            target = backup / (p.name + '.' + stamp + '.bak')
            shutil.copy2(p, target)
            if hashlib.sha256(target.read_bytes()).digest() != hashlib.sha256(p.read_bytes()).digest():
                raise ValueError('Sauvegarde non conforme : ' + str(p))
    atomic_put(launcher, launcher_text.encode(), 0o755)
    if not safe_regular(keys):
        actions = [('up','KEY_UP'),('down','KEY_DOWN'),('left','KEY_LEFT'),('right','KEY_RIGHT'),
                   ('joystick1up','KEY_UP'),('joystick1down','KEY_DOWN'),
                   ('joystick1left','KEY_LEFT'),('joystick1right','KEY_RIGHT'),
                   ('b','KEY_ENTER'),('a','KEY_0'),('start','KEY_ENTER'),
                   ('pageup','KEY_PAGEUP'),('pagedown','KEY_PAGEDOWN')]
        content = {'actions_player1': [{'trigger': t, 'type': 'key', 'target': v} for t,v in actions]}
        atomic_put(keys, (json.dumps(content, indent=2) + '\n').encode())
    for kind, content in pictures.items():
        atomic_put(images[kind], content)
    atomic_put(gamelist, xml)
    print('[OK] Lanceur Ports et manette prêts')
    print('[OK] Cover, fanart et logo installés')
    print('[OK] Fiche gamelist mise à jour ; autres jeux conservés')
    print('[INFO] Actualiser les listes de jeux EmulationStation')
except Exception as exc:
    print('[ERREUR] Installation Ports :', exc)
    sys.exit(1)
PYPORTS
}
blondin_ports_menu(){
 local choice
 while :; do
   refresh_screen
   ui_section 'GESTIONNAIRE DANS PORTS'
   ui_item '1) Installer / réparer'
   ui_item '2) Vérifier'
   echo
   ui_item '0) Retour'
   ui_item 'Q) Quitter le gestionnaire'
   choice="$(read_key 'Votre choix : ')" || return 0
   case "$choice" in
     1) if confirm 'Installer dans Ports ?'; then blondin_ports_action install; fi; pause ;;
     2) blondin_ports_action state; pause ;;
     0) return 0 ;;
     *) ui_print warning 'Choix invalide.'; pause ;;
   esac
 done
}


# Correction souris / double ecran - Batocera 44 (Mini-PC).
SOURIS_SERVICE=/userdata/system/services/correction_souris
SOURIS_HOOK=/userdata/system/configs/emulationstation/scripts/game-end/correction-souris.sh
souris_service_content(){
cat <<'SOURIS_SVC'
#!/bin/bash

case "$1" in
    start)
        (
            sleep 5
            wlr-randr --output DP-1 --pos 0,0 \
                      --output HDMI-A-1 --pos 3440,0
        ) >> /userdata/system/log-correction-souris.log 2>&1 &
        ;;
    stop)
        ;;
esac
SOURIS_SVC
}
souris_hook_content(){
cat <<'SOURIS_HOOK'
#!/bin/bash

(
    sleep 3

    wlr-randr \
        --output DP-1 --pos 0,0 \
        --output HDMI-A-1 --pos 3440,0

) >> /userdata/system/log-correction-souris.log 2>&1 &

exit 0
SOURIS_HOOK
}
souris_file_state(){
  local path="$1" producer="$2" tmp
  if [[ ! -e "$path" && ! -L "$path" ]]; then echo absent; return; fi
  if [[ ! -f "$path" || -L "$path" ]]; then echo autre; return; fi
  tmp="$(mktemp)" || { echo autre; return; }
  "$producer" > "$tmp"
  if cmp -s "$tmp" "$path" && [[ -x "$path" ]]; then echo conforme; else echo autre; fi
  rm -f -- "$tmp"
}
souris_install_file(){
  local path="$1" producer="$2" status dir tmp
  status="$(souris_file_state "$path" "$producer")"
  if [[ "$status" == conforme ]]; then echo "[OK] Déjà installé : $path"; return 0; fi
  if [[ "$status" == autre ]]; then
    echo "[SÉCURITÉ] Fichier existant différent : $path"
    echo '[INFO] Conservé sans modification.'
    return 1
  fi
  dir="$(dirname "$path")"
  [[ ! -L "$dir" ]] || { echo '[SÉCURITÉ] Dossier symbolique refusé.'; return 1; }
  mkdir -p -- "$dir" || return 1
  tmp="$(mktemp "$dir/.correction-souris.XXXXXX")" || return 1
  if ! "$producer" > "$tmp" || ! bash -n "$tmp" || ! chmod 755 "$tmp" || ! mv -n -- "$tmp" "$path"; then
    rm -f -- "$tmp"; echo '[ERREUR] Installation impossible.'; return 1
  fi
  rm -f -- "$tmp"
  echo "[OK] Installé : $path"
}
souris_install(){
  if ! command -v wlr-randr >/dev/null 2>&1; then
    echo '[ERREUR] wlr-randr absent.'; return 1
  fi
  if ! wlr-randr 2>/dev/null | grep -qE '(^| )DP-1($| )'; then
    echo '[ATTENTION] Sortie DP-1 non détectée dans cette session.'
    confirm 'Continuer sur cet appareil malgré tout ?' || return 0
  fi
  confirm 'Installer la correction souris / double écran ?' || return 0
  local rc=0
  souris_install_file "$SOURIS_SERVICE" souris_service_content || rc=1
  souris_install_file "$SOURIS_HOOK" souris_hook_content || rc=1
  if [[ "$(souris_file_state "$SOURIS_SERVICE" souris_service_content)" == conforme ]]; then
    if command -v batocera-services >/dev/null 2>&1; then
      batocera-services enable correction_souris || echo '[ATTENTION] Activer correction_souris dans Paramètres système > Services.'
    else
      echo '[INFO] Activer correction_souris dans Paramètres système > Services.'
    fi
  fi
  echo '[INFO] Redémarrer Batocera pour tester la correction au démarrage.'
  return "$rc"
}
souris_uninstall(){
  confirm 'Désinstaller la correction souris et ses deux scripts ?' || return 0
  local path producer state removed=0
  for path in "$SOURIS_SERVICE" "$SOURIS_HOOK"; do
    if [[ "$path" == "$SOURIS_SERVICE" ]]; then producer=souris_service_content; else producer=souris_hook_content; fi
    state="$(souris_file_state "$path" "$producer")"
    if [[ "$state" == conforme ]]; then
      if [[ "$path" == "$SOURIS_SERVICE" ]] && command -v batocera-services >/dev/null 2>&1; then
        batocera-services disable correction_souris || echo '[ATTENTION] Vérifier la désactivation dans Services.'
      fi
      rm -f -- "$path" || return 1
      echo "[OK] Supprimé : $path"
      removed=1
    elif [[ "$state" == autre ]]; then
      echo "[SÉCURITÉ] Script différent conservé : $path"
    fi
  done
  (( removed )) || echo '[INFO] Aucun script conforme à supprimer.'
}
souris_menu(){
  local choice s h
  while :; do
    refresh_screen
    ui_section 'CORRECTION SOURIS / DOUBLE ÉCRAN'
    s="$(souris_file_state "$SOURIS_SERVICE" souris_service_content)"
    h="$(souris_file_state "$SOURIS_HOOK" souris_hook_content)"
    ui_print info "  Démarrage : $s"
    ui_print info "  Après jeu  : $h"
    ui_print info '  DP-1 : 0,0 / HDMI-A-1 : 3440,0'
    ui_item '1) Installer / vérifier'
    ui_item '2) Désinstaller'
    ui_item '3) Journal des corrections'
    echo
    ui_item '0) Retour'
    ui_item 'Q) Quitter le gestionnaire'
    choice="$(read_key 'Votre choix : ')" || return 0
    case "$choice" in
      1) souris_install; pause ;;
      2) souris_uninstall; pause ;;
      3) if [[ -f /userdata/system/log-correction-souris.log ]]; then tail -n 20 /userdata/system/log-correction-souris.log; else echo '[INFO] Journal absent.'; fi; pause ;;
      0) return 0 ;;
      q|Q) exit 0 ;;
      *) ui_print warning 'Choix invalide.'; pause ;;
    esac
  done
}

gestion_menu(){
  local choice
  while :; do
    refresh_screen
    ui_section 'GESTION'
    ui_item '1) Gestion des installations'
    ui_item '2) Diagnostics'
    ui_item '3) Informations système'
    ui_gestion_extinction
    ui_item '5) Tri des jeux (ARRM)'
    ui_item '6) Sauvegarde / restauration'
    ui_item '7) Gestionnaire dans Ports'
    echo
    ui_item '0) Retour'
    ui_item 'Q) Quitter le gestionnaire'
    choice="$(read_key 'Votre choix : ')" || return 0
    case "$choice" in
      1) gestion_installations_menu ;;
      2) gestion_diagnostics_menu ;;
      3) sys_info_menu ;;
      4) extinction_menu ;;
      5) arrm_sort_menu ;;
      6) backup_params_menu ;;
      7) blondin_ports_menu ;;
      0) return 0 ;;
      *) ui_print warning 'Choix invalide.'; pause ;;
    esac
  done
}


# Sortie de veille selon la version :
# Batocera 42 : clic gauche XTEST valide sur mini-PC.
# Batocera 43.1 : touche Espace XTEST (methode validee auparavant sur Steam Deck tactile).
# Appele uniquement apres annulation confirmee du minuteur.
wake_video_screensaver(){
  local version mode
  version="$(detect_batocera_version)" || version=''
  case "$version" in
    42|42.*) mode=click ;;
    43.1|43.1.*) mode=space ;;
    *) echo "[ATTENTION] Version $version : reveil automatique non configure."; return 1 ;;
  esac
  DISPLAY=:0 python3 - "$mode" <<'PYWAKE'
import ctypes, sys, time
mode = sys.argv[1]
try:
    x11 = ctypes.CDLL('libX11.so.6')
    xtst = ctypes.CDLL('libXtst.so.6')
    x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
    x11.XOpenDisplay.restype = ctypes.c_void_p
    x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
    x11.XFlush.argtypes = [ctypes.c_void_p]
    x11.XKeysymToKeycode.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
    x11.XKeysymToKeycode.restype = ctypes.c_uint
    xtst.XTestFakeButtonEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
    xtst.XTestFakeButtonEvent.restype = ctypes.c_int
    xtst.XTestFakeKeyEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
    xtst.XTestFakeKeyEvent.restype = ctypes.c_int
    display = x11.XOpenDisplay(b':0')
    if not display:
        raise RuntimeError('Affichage X11 :0 inaccessible')
    try:
        if mode == 'space':
            keycode = x11.XKeysymToKeycode(display, 0x20)  # XK_space
            if not keycode:
                raise RuntimeError('Touche Espace non disponible dans le clavier X11')
            press = xtst.XTestFakeKeyEvent(display, keycode, 1, 0)
            x11.XFlush(display)
            time.sleep(0.12)
            release = xtst.XTestFakeKeyEvent(display, keycode, 0, 0)
            label = 'Touche Espace'
        else:
            press = xtst.XTestFakeButtonEvent(display, 1, 1, 0)
            x11.XFlush(display)
            time.sleep(0.12)
            release = xtst.XTestFakeButtonEvent(display, 1, 0, 0)
            label = 'Clic gauche'
        x11.XFlush(display)
        if not (press and release):
            raise RuntimeError('Simulation non confirmee par XTEST')
        print('[OK] Réveil envoyé : '+label+'.')
    finally:
        x11.XCloseDisplay(display)
except (OSError, AttributeError, RuntimeError) as exc:
    print('[ATTENTION] Reveil X11 impossible :', exc)
    sys.exit(1)
PYWAKE
}

# Etat du minuteur dans le menu principal : consultation uniquement.
shutdown_main_status(){
  # Lecture independante du fichier d'etat et de /proc : ne modifie rien.
  # Evite de classer un minuteur valide "A verifier" sur la seule base
  # d'une liste de processus incomplete.
  python3 - <<'PYSTATUS'
import os, re, sys, time
from pathlib import Path
trigger = Path('/userdata/system/configs/emulationstation/scripts/screensaver-start/shutdown-trigger.sh')
state = Path('/tmp/shutdown.screensaver')
if not trigger.is_file():
    print('Desactivee')
    sys.exit(0)
if not state.exists():
    print('En attente')
    sys.exit(0)
try:
    parts = state.read_text().split()
    if len(parts) != 2 or not re.fullmatch(r'[0-9]+-[0-9]+-[0-9]+', parts[1]):
        raise ValueError('etat incorrect')
    pid_text, token = parts
    if not pid_text.isdigit():
        raise ValueError('pid incorrect')
    pid = int(pid_text)
    cmd = [v.decode('utf-8') for v in Path(f'/proc/{pid}/cmdline').read_bytes().split(b'\0') if v]
    if len(cmd) != 4 or cmd[0] not in ('/bin/bash','bash') or cmd[1] != str(trigger) or cmd[2:] != ['--worker',token]:
        raise ValueError('worker different')
    # Le script actif fixe une seule constante DELAY simple.
    source = trigger.read_text(encoding='utf-8')
    durations = re.findall(r'^\s*DELAY\s*=\s*["\']?([0-9]+)([smh]?)["\']?\s*(?:#.*)?$', source, re.M)
    if len(durations) != 1:
        raise ValueError('duree ambiguë')
    amount, unit = durations[0]
    seconds = int(amount) * {'':1, 's':1, 'm':60, 'h':3600}[unit]
    if seconds <= 0:
        raise ValueError('duree incorrecte')
    # Jeton genere par date +%s au lancement du worker.
    start = int(token.split('-')[0])
    now = int(time.time())
    if start > now + 10 or now - start > seconds + 120:
        raise ValueError('horodatage incoherent')
    left = max(0, start + seconds - now)
    # Affichage HH:MM sans secondes, arrondi a la minute superieure
    # pour ne pas afficher 00:00 alors qu'il reste quelques secondes.
    total_minutes = (left + 59) // 60
    hh, mm = divmod(total_minutes, 60)
    print(f'{hh:02d}:{mm:02d}')
except (OSError, ValueError, UnicodeError, KeyError, IndexError):
    print('A vérifier')
PYSTATUS
}

# Utilise la procedure officielle du script V1.6.9 : --manual annule
# l'ancien worker avec --timer-only, puis demarre le nouveau. Ne jamais
# appeler directement --worker ou envoyer un signal non verifie.
restart_shutdown_timer(){
  local trigger=/userdata/system/configs/emulationstation/scripts/screensaver-start/shutdown-trigger.sh
  local workers='' pid='' token='' path='' count=0 wp wt wpath updated='' new_pid='' new_token=''
  [[ -s "$trigger" ]] && bash -n "$trigger" || { echo '[ERREUR] Script de déclenchement absent ou invalide.'; pause; return 0; }
  workers="$(shutdown_workers list)" || { echo '[ERREUR] Vérification des minuteurs impossible.'; pause; return 0; }
  if [[ -n "$workers" ]]; then
    while IFS=' ' read -r wp wt wpath; do
      [[ -n "$wp" ]] || continue
      ((count+=1)); pid="$wp"; token="$wt"; path="$wpath"
    done <<< "$workers"
  fi
  if (( count != 1 )) || [[ "$path" != "$trigger" ]]; then
    echo '[SÉCURITÉ] Relance possible uniquement avec un minuteur actif reconnu et unique.'
    pause; return 0
  fi
  if [[ ! -r /tmp/shutdown.screensaver ]] || ! read -r new_pid new_token </tmp/shutdown.screensaver || [[ "$new_pid" != "$pid" || "$new_token" != "$token" ]]; then
    echo '[SÉCURITÉ] Le minuteur enregistre ne correspond pas au processus actif.'
    pause; return 0
  fi
  echo "[MINUTEUR] Temps restant : $(shutdown_remaining "$path" "$token")"
  show_shutdown_delay "$trigger"
  if ! confirm 'Relancer le minuteur depuis zero ?'; then return 0; fi
  if ! screensaver_active; then echo '[SÉCURITÉ] Veille non confirmée : relance refusée.'; pause; return 0; fi
  # Le script annule et attend l'arret de son worker avant d'en creer un autre.
  if ! /bin/bash "$trigger" --manual; then
    echo '[ERREUR] Relance echouee. Vérifier le minuteur avant toute nouvelle action.'
    pause; return 0
  fi
  updated="$(shutdown_workers list)" || updated=''
  new_pid=''; new_token=''
  if [[ -r /tmp/shutdown.screensaver ]]; then read -r new_pid new_token </tmp/shutdown.screensaver || true; fi
  if [[ "$new_pid" =~ ^[0-9]+$ && "$new_token" =~ ^[0-9]+-[0-9]+-[0-9]+$ && "$new_token" != "$token" && "$updated" == "$new_pid $new_token $trigger" ]]; then
    echo "[OK] Minuteur relancé."
    echo "[DÉLAI] $(shutdown_remaining "$trigger" "$new_token")"
  else
    echo '[ATTENTION] Relance demandée mais nouvel etat non confirmé.'
  fi
  pause
}

# Notifications ntfy V7 integrees au gestionnaire (installation locale, sans GitHub).
ntfy_v7_status(){
  local service=/userdata/system/services/notifications_extinction_ntfy
  local config=/userdata/system/notifications-extinction-ntfy/config
  local topic='' device=''
  if [[ -f "$config" ]]; then
    topic="$(sed -n 's/^TOPIC=//p' "$config" | head -n 1)"
    device="$(sed -n 's/^DEVICE=//p' "$config" | head -n 1)"
    if [[ -n "$topic" ]]; then
      printf '[SUJET NTFY] %s\n' "$topic"
    else
      echo '[SUJET NTFY] NON CONFIGURÉ'
    fi
    [[ -n "$device" ]] && printf '[APPAREIL] %s\n' "$device"
  else
    echo '[SUJET NTFY] NON CONFIGURÉ'
  fi
  if [[ -x "$service" ]]; then
    "$service" status || true
  else
    echo '[SERVICE] Absent.'
  fi
}

ntfy_v7_install(){
  local tmp
  tmp="$(mktemp "$CACHE/.ntfy-v7.XXXXXX.sh")" || { echo '[ERREUR] Fichier temporaire impossible.'; return 1; }
  # Installateur V7 embarque : aucune connexion GitHub requise.
  cat > "$tmp" <<'NTFY_V7_EMBEDDED_INSTALLER'
#!/bin/bash
# Notifications ntfy + relance locale - TEST V7
set -u
ROOT=/userdata/system
DIR="$ROOT/notifications-extinction-ntfy"
SERVICE="$ROOT/services/notifications_extinction_ntfy"
CONFIG="$DIR/config"
PY="$DIR/watch.py"
TRIGGER="$ROOT/configs/emulationstation/scripts/screensaver-start/shutdown-trigger.sh"
STATE=/tmp/shutdown.screensaver
MARKER=/tmp/batocera-screensaver-active
printf '\n=== Notifications extinction ntfy - TEST ===\n'
echo 'Aucun script de veille existant ne sera modifie.'
echo 'Bouton Relancer : réseau local.'
echo 'Remise a zero du minuteur.'
read -r -p 'Installer le service de notifications ? [o/N] : ' answer
[[ "$answer" =~ ^[oOyY]$ ]] || { echo '[INFO] Annulé.'; exit 0; }
[[ -r "$TRIGGER" ]] || { echo '[ERREUR] shutdown-trigger.sh absent.'; exit 1; }
command -v python3 >/dev/null || { echo '[ERREUR] Python 3 requis.'; exit 1; }
command -v curl >/dev/null || { echo '[ERREUR] curl requis.'; exit 1; }
# Réutiliser les réglages existants par défaut lors d'une réinstallation.
OLD_TOPIC='' OLD_DEVICE=''
if [[ -f "$CONFIG" ]]; then
  OLD_TOPIC="$(sed -n 's/^TOPIC=//p' "$CONFIG" | head -n 1)"
  OLD_DEVICE="$(sed -n 's/^DEVICE=//p' "$CONFIG" | head -n 1)"
fi
if [[ -n "$OLD_TOPIC" ]]; then
  # Une réinstallation ne doit jamais changer silencieusement le sujet actif.
  printf '[INFO] Sujet actuel : %s\n' "$OLD_TOPIC"
  read -r -p 'Sujet ntfy (Entrée = conserver) : ' TOPIC
  TOPIC="${TOPIC:-$OLD_TOPIC}"
else
  # Pas de sujet partagé/prévisible : 128 bits aléatoires par installation.
  DEFAULT_TOPIC="$(python3 - <<'PYNTFYTOPIC'
import secrets
print('batocera-' + secrets.token_hex(16))
PYNTFYTOPIC
)" || { echo '[ERREUR] Sujet automatique indisponible.'; exit 1; }
  printf '[SUJET PROPOSÉ] %s\n' "$DEFAULT_TOPIC"
  read -r -p 'Sujet ntfy (Entrée = accepter) : ' TOPIC
  TOPIC="${TOPIC:-$DEFAULT_TOPIC}"
fi
[[ "$TOPIC" =~ ^[A-Za-z0-9_-]{12,120}$ ]] || { echo '[ERREUR] Sujet invalide (12 a 120 caractères : lettres, chiffres, - et _).'; exit 1; }
if [[ -n "$OLD_DEVICE" ]]; then
  printf '[INFO] Appareil existant : %s\n' "$OLD_DEVICE"
  read -r -p 'Nom de cet appareil (Entrée = conserver) : ' DEVICE
  DEVICE="${DEVICE:-$OLD_DEVICE}"
else
  read -r -p 'Nom de cet appareil (ex : Steam Deck OLED) : ' DEVICE
fi
[[ -n "$DEVICE" && ${#DEVICE} -le 60 && "$DEVICE" != *$'\n'* && "$DEVICE" != *$'\r'* ]] || { echo '[ERREUR] Nom d appareil requis (max 60 caracteres).'; exit 1; }
mkdir -p "$DIR" "$ROOT/services" || exit 1
if [[ -f "$CONFIG" ]]; then cp -p "$CONFIG" "$CONFIG.bak.$(date +%Y%m%d-%H%M%S)" || exit 1; fi
printf 'TOPIC=%s\nDEVICE=%s\n' "$TOPIC" "$DEVICE" > "$CONFIG" || exit 1
chmod 600 "$CONFIG"
cat > "$PY" <<'PYTHON'
#!/usr/bin/env python3
"""Batocera ntfy: alerts and local authenticated timer restart."""
import http.server, ipaddress, os, re, secrets, socket, subprocess, threading, time
from pathlib import Path
from urllib.parse import urlsplit
ROOT = Path('/userdata/system/notifications-extinction-ntfy')
TRIGGER = '/userdata/system/configs/emulationstation/scripts/screensaver-start/shutdown-trigger.sh'
STATE = Path('/tmp/shutdown.screensaver')
MARKER = Path('/tmp/batocera-screensaver-active')
PATTERN = re.compile(r'^\s*DELAY\s*=\s*["\']?(\d+)([smh]?)["\']?\s*(?:#.*)?$', re.M)
PORT = 18765
lock = threading.Lock()
authorization = {'token': None, 'cycle': None, 'used': False}

def config():
    data = {}
    for line in (ROOT/'config').read_text().splitlines():
        k, sep, v = line.partition('=')
        if sep: data[k] = v
    return data['TOPIC'], data['DEVICE']

def argv(pid):
    return [a.decode('utf-8', 'replace') for a in Path(f'/proc/{pid}/cmdline').read_bytes().split(b'\0') if a]

def current():
    parts = STATE.read_text().split()
    if len(parts) != 2 or not parts[0].isdigit() or not re.fullmatch(r'\d+-\d+-\d+', parts[1]): return None
    pid, token = int(parts[0]), parts[1]
    if argv(pid) not in (['/bin/bash', TRIGGER, '--worker', token], ['bash', TRIGGER, '--worker', token]): return None
    if not MARKER.is_file(): return None
    matches = PATTERN.findall(Path(TRIGGER).read_text())
    if len(matches) != 1: return None
    value, unit = matches[0]
    duration = int(value) * {'':1, 's':1, 'm':60, 'h':3600}[unit]
    return token, int(token.split('-')[0]) + duration - time.time(), duration

def local_ip():
    # Batocera utilise une version de hostname sans option -I.
    # La commande ip est compatible avec Batocera 42 et 43.1.
    try:
        out = subprocess.check_output(['ip', '-4', '-o', 'addr', 'show', 'scope', 'global'],
                                      text=True, stderr=subprocess.DEVNULL, timeout=3)
        for line in out.splitlines():
            match = re.search(r'\binet\s+(\d+\.\d+\.\d+\.\d+)/(\d+)', line)
            if not match: continue
            ip = ipaddress.ip_address(match.group(1))
            if ip.is_private and not ip.is_loopback and not ip.is_link_local:
                return str(ip), int(match.group(2))
    except (OSError, subprocess.SubprocessError, ValueError):
        pass
    return None

def format_duration(seconds):
    seconds = int(seconds)
    hours, remainder = divmod(seconds, 3600)
    minutes, seconds = divmod(remainder, 60)
    if hours:
        return f'{hours} h {minutes:02d}'
    if minutes:
        return f'{minutes} min' if not seconds else f'{minutes} min {seconds:02d} s'
    return f'{seconds} s'

def notify(topic, device, kind, action=None, duration=None):
    title = {'ten':'Batocera - Extinction dans 10 minutes', 'end':'Batocera - Extinction dans 1 minute', 'restart':'Batocera - Minuteur relance'}[kind]
    msg = {'ten':f'{device} : extinction automatique dans moins de 10 minutes.',
           'end':f'{device} : extinction automatique dans moins de 1 minute.',
           'restart':f'{device} : le minuteur est reparti pour sa duree complete.'}[kind]
    if duration is not None and kind in ('ten', 'end'):
        msg += '\nDelai actif : ' + format_duration(duration)
    cmd = ['curl','-fsS','--connect-timeout','3','--max-time','6', '-H','Title: '+title,
           '-H','Priority: high']
    if action:
        cmd += ['-H', 'Actions: http, Relancer le minuteur, '+action+', method=POST, clear=true']
    cmd += ['--data-binary', msg, 'https://ntfy.sh/'+topic]
    try:
        return subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=8).returncode == 0
    except (OSError, subprocess.TimeoutExpired): return False

class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_): pass
    def do_POST(self):
        # Only private LAN clients in the same /24 as this Batocera device.
        address = local_ip()
        try:
            client = ipaddress.ip_address(self.client_address[0])
            network = ipaddress.ip_network(f'{address[0]}/{address[1]}', strict=False)
            allowed = client in network and client.is_private
        except (ValueError, TypeError): allowed = False
        if not allowed:
            self.send_error(403); return
        path = urlsplit(self.path).path
        secret = path.removeprefix('/restart/') if path.startswith('/restart/') else ''
        with lock:
            valid = (len(secret) == 64 and secrets.compare_digest(secret, authorization['token'] or '')
                     and not authorization['used'])
            if valid:
                try: status = current()
                except (OSError, ValueError, KeyError, UnicodeError): status = None
                valid = bool(status and status[0] == authorization['cycle'] and status[1] > 0)
            if valid:
                old_cycle = authorization['cycle']
                authorization['used'] = True
        if not valid:
            self.respond(410, 'Lien expire ou minuteur inactif.'); return
        # Relance officielle : le trigger V1.6.9 annule l'ancien worker,
        # puis cree un nouveau jeton sans sortir de l'economiseur.
        try:
            result = subprocess.run(['/bin/bash', TRIGGER, '--manual'], timeout=12,
                                    capture_output=True)
            if result.returncode != 0:
                self.respond(500, 'Relance non confirmee.'); return
            # Le nouveau worker peut apparaitre avec un leger retard.
            # Comparer au jeton capture AVANT la relance, pas a l'etat
            # partage qui peut deja avoir ete actualise par main().
            after = None
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline:
                try: after = current()
                except (OSError, ValueError, KeyError, UnicodeError): after = None
                if after and after[0] != old_cycle and after[1] > 0:
                    break
                time.sleep(0.2)
            else:
                self.respond(500, 'Nouveau minuteur non confirme.'); return
            topic, device = config()
            notify(topic, device, 'restart')
            self.respond(200, 'Minuteur relance pour sa duree complete.')
        except (OSError, subprocess.TimeoutExpired):
            self.respond(500, 'Relance non confirmee.')
    def respond(self, status, message):
        data = message.encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type','text/plain; charset=utf-8')
        self.send_header('Cache-Control','no-store')
        self.send_header('Content-Length',str(len(data)))
        self.end_headers()
        self.wfile.write(data)

def main():
    topic, device = config()
    server = http.server.ThreadingHTTPServer(('0.0.0.0', PORT), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    seen, last_token = set(), None
    while True:
        try: status = current()
        except (OSError, ValueError, KeyError, UnicodeError): status = None
        if status is None:
            last_token = None
            seen.clear()
            with lock: authorization.update(token=None, cycle=None, used=False)
        else:
            token, remaining, duration = status
            if token != last_token:
                last_token, seen = token, set()
                with lock: authorization.update(token=secrets.token_hex(32), cycle=token, used=False)
            if 8 < remaining <= 600 and 'ten' not in seen:
                address = local_ip()
                with lock: key = authorization['token']
                action = f'http://{address[0]}:{PORT}/restart/{key}' if address and key else None
                if notify(topic, device, 'ten', action, duration): seen.add('ten')
            if 0 < remaining <= 60 and 'end' not in seen:
                address = local_ip()
                with lock: key = authorization['token']
                action = f'http://{address[0]}:{PORT}/restart/{key}' if address and key else None
                if notify(topic, device, 'end', action, duration): seen.add('end')
        time.sleep(2)
if __name__ == '__main__': main()
PYTHON
chmod 700 "$PY"
cat > "$SERVICE" <<'SERVICEFILE'
#!/bin/bash
# Service Batocera : notifications d extinction ntfy
PIDFILE=/var/run/notifications_extinction_ntfy.pid
SCRIPT=/userdata/system/notifications-extinction-ntfy/watch.py
case "${1:-}" in
  start)
    if [[ -s "$PIDFILE" ]]; then
      read -r pid < "$PIDFILE"
      if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then exit 0; fi
    fi
    nohup python3 "$SCRIPT" >/dev/null 2>&1 </dev/null &
    echo "$!" > "$PIDFILE"
    ;;
  stop)
    if [[ -s "$PIDFILE" ]]; then
      read -r pid < "$PIDFILE"
      if [[ "$pid" =~ ^[0-9]+$ ]] && [[ -r "/proc/$pid/cmdline" ]]; then
        cmd="$(tr '\0' ' ' < "/proc/$pid/cmdline")"
        [[ "$cmd" == *"$SCRIPT"* ]] && kill "$pid" 2>/dev/null || true
      fi
    fi
    rm -f "$PIDFILE"
    ;;
  status)
    if [[ -s "$PIDFILE" ]]; then
      read -r pid < "$PIDFILE"
      if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then echo "Actif (PID $pid)"; exit 0; fi
    fi
    echo 'Inactif'; exit 1
    ;;
  *) echo 'Usage: start|stop|status'; exit 2 ;;
esac
SERVICEFILE
chmod 755 "$SERVICE"
python3 -m py_compile "$PY" || { echo '[ERREUR] Syntaxe Python invalide.'; exit 1; }
if command -v batocera-services >/dev/null 2>&1; then
    batocera-services enable notifications_extinction_ntfy || echo '[ATTENTION] Activation au démarrage non confirmée.'
fi
"$SERVICE" stop || true
"$SERVICE" start || { echo '[ERREUR] Demarrage impossible.'; exit 1; }
"$SERVICE" status
printf '\n[OK] Installation locale terminee.\n'
echo 'Scripts d extinction inchanges.'
echo 'Bouton Relancer : sans Chrome.'
echo 'Alertes a 10 min et 1 min.'
echo 'Notification effacee après relance.'
echo 'Téléphone : meme réseau local.'
echo 'Seconde alerte : 1 min avant.'
NTFY_V7_EMBEDDED_INSTALLER
  if ! bash -n "$tmp"; then
    echo '[ERREUR] Installateur integre invalide.'
    rm -f -- "$tmp"
    return 1
  fi
  bash "$tmp"
  local rc=$?
  rm -f -- "$tmp"
  return "$rc"
}

# Modification ciblée du sujet ntfy sans réinstallation et sans toucher au minuteur.
# Le processus V7 lit TOPIC au démarrage : relance uniquement si déjà actif.
ntfy_v7_change_topic(){
  local config='/userdata/system/notifications-extinction-ntfy/config'
  local service='/userdata/system/services/notifications_extinction_ntfy'
  local savedir="$SAVES/NotificationsNtfy"
  local old_topic='' new_topic='' backup='' running=0
  if [[ ! -f "$config" || -L "$config" || ! -x "$service" || -L "$service" ]]; then
    echo '[SÉCURITÉ] Configuration ou service ntfy absent/non ordinaire.'
    echo '[INFO] Utiliser Installer / Réinstaller.'
    return 1
  fi
  if ! grep -Fq 'notifications-extinction-ntfy/watch.py' "$service"; then
    echo '[SÉCURITÉ] Service ntfy non reconnu : aucune modification.'
    return 1
  fi
  # Exiger un seul sujet et un seul appareil ; ne jamais écraser une config inconnue.
  if ! python3 - "$config" <<'PYCHECKTOPIC'
import pathlib, re, sys
try:
    lines = pathlib.Path(sys.argv[1]).read_text(encoding='utf-8').splitlines()
    topics = [line[6:] for line in lines if line.startswith('TOPIC=')]
    devices = [line[7:] for line in lines if line.startswith('DEVICE=')]
    assert len(topics)==len(devices)==1
    assert re.fullmatch(r'[A-Za-z0-9_-]{12,120}', topics[0])
    assert devices[0] and len(devices[0]) <= 60
except (OSError, UnicodeError, ValueError, AssertionError):
    sys.exit(1)
PYCHECKTOPIC
  then
    echo '[SÉCURITÉ] Configuration ntfy inhabituelle : changement refusé.'
    return 1
  fi
  old_topic="$(sed -n 's/^TOPIC=//p' "$config")"
  printf '[SUJET ACTUEL] %s\n' "$old_topic"
  echo '[INFO] Le nouveau sujet devra également être configuré dans l’application ntfy.'
  read -r -p 'Nouveau sujet (Entrée = annuler) : ' new_topic || return 1
  if [[ -z "$new_topic" || "$new_topic" == "$old_topic" ]]; then
    echo '[INFO] Sujet inchangé.'
    return 0
  fi
  if [[ ! "$new_topic" =~ ^[A-Za-z0-9_-]{12,120}$ ]]; then
    echo '[ERREUR] Sujet invalide (12 à 120 caractères : lettres, chiffres, - et _).'
    return 1
  fi
  confirm 'Confirmer le changement de sujet ntfy ?' || { echo '[INFO] Annulé.'; return 0; }
  if [[ -L "$savedir" || ( -e "$savedir" && ! -d "$savedir" ) ]]; then
    echo '[SÉCURITÉ] Dossier des sauvegardes non ordinaire.'
    return 1
  fi
  mkdir -p -- "$savedir" || return 1
  backup="$savedir/config.bak-$(date +%Y%m%d-%H%M%S)-$$"
  cp -p -- "$config" "$backup" || {
    echo '[ERREUR] Impossible de sauvegarder la configuration.'
    return 1
  }
  printf '[SAUVEGARDE] %s\n' "$backup"
  "$service" status >/dev/null 2>&1 && running=1
  # Écriture atomique en conservant les autres paramètres sans exécuter le fichier.
  if ! python3 - "$config" "$new_topic" <<'PYCHANGETOPIC'
import os, pathlib, sys, tempfile
p = pathlib.Path(sys.argv[1])
topic = sys.argv[2]
temp = None
try:
    lines = p.read_text(encoding='utf-8').splitlines(keepends=True)
    changed = [f'TOPIC={topic}\n' if line.startswith('TOPIC=') else line for line in lines]
    with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=p.parent,
                                     prefix='.ntfy-topic-', delete=False) as f:
        temp = f.name
        f.writelines(changed)
        f.flush()
        os.fsync(f.fileno())
    os.chmod(temp, 0o600)
    os.replace(temp, p)
except (OSError, UnicodeError):
    if temp:
        try: os.unlink(temp)
        except OSError: pass
    sys.exit(1)
PYCHANGETOPIC
  then
    echo '[ERREUR] Modification impossible ; sauvegarde conservée.'
    return 1
  fi
  if (( running )); then
    if ! "$service" stop || ! "$service" start || ! "$service" status >/dev/null 2>&1; then
      echo '[ERREUR] Redémarrage du service ntfy impossible. Restauration du sujet précédent.'
      if ! cp -p -- "$backup" "$config"; then
        echo '[ERREUR] Restauration automatique impossible : utiliser la sauvegarde affichée.'
        return 1
      fi
      "$service" stop >/dev/null 2>&1 || true
      "$service" start >/dev/null 2>&1 || true
      echo '[INFO] Sujet précédent restauré.'
      return 1
    fi
    echo '[OK] Sujet modifié ; service relancé.'
  else
    echo '[OK] Sujet modifié ; service toujours arrêté.'
  fi
  printf '[NOUVEAU SUJET] %s\n' "$new_topic"
  echo '[INFO] Abonnez aussi votre téléphone à ce sujet dans ntfy.'
}

ntfy_v7_menu(){
  local choice
  while :; do
    refresh_screen
    ui_section 'NOTIFICATIONS NTFY'
    ntfy_v7_status
    echo
    ui_item '1) Installer / Réinstaller'
    ui_item '2) État du service'
    ui_item '3) Télécharger ntfy'
    if uninstall_present ntfy; then
      ui_item '4) Désinstaller'
      ui_item '5) Modifier le sujet'
    fi
    echo
    echo
    ui_item '0) Retour'
    ui_item 'Q) Quitter le gestionnaire'
    echo
    choice="$(read_key 'Votre choix : ')" || return 0
    case "$choice" in
      1)
        refresh_screen
        ui_section 'INSTALLATION NTFY'
        ntfy_v7_install
        pause
        ;;
      2)
        refresh_screen
        ui_section 'ETAT NTFY'
        ntfy_v7_status
        echo
        pause
        ;;
      3)
        refresh_screen
        ui_section 'TÉLÉCHARGER NTFY'
        # OSC 8 : lien cliquable dans les terminaux compatibles.
        # L'URL en clair reste visible et copiable partout.
        local url label
        for label in 'Google Play Store' 'F-Droid' 'Site officiel'; do
          case "$label" in
            'Google Play Store') url='https://play.google.com/store/apps/details?id=io.heckel.ntfy' ;;
            'F-Droid') url='https://f-droid.org/packages/io.heckel.ntfy/' ;;
            'Site officiel') url='https://ntfy.sh' ;;
          esac
          printf '%s :\n' "$label"
          if [[ -t 1 && "${TERM:-dumb}" != dumb ]]; then
            printf '\033]8;;%s\033\\%s\033]8;;\033\\\n' "$url" "$url"
          else
            printf '%s\n' "$url"
          fi
          echo
        done
        echo
        pause
        ;;
      4)
        if uninstall_present ntfy; then
          refresh_screen
          ui_section 'DÉSINSTALLATION NTFY'
          uninstall_selected ntfy
        else
          echo '[INFO] ntfy déjà absent.'
        fi
        pause ;;
      5)
        if uninstall_present ntfy; then
          refresh_screen
          ui_section 'MODIFIER LE SUJET NTFY'
          ntfy_v7_change_topic
        else
          echo '[INFO] Installer ntfy avant de modifier son sujet.'
        fi
        pause ;;
      0) return 0 ;;
      *) echo '[INFO] Choix invalide.'; sleep 1 ;;
    esac
  done
}

# Interface en direct : la touche est lue sur le terminal sans Enter.
# Ne touche pas au minuteur tant qu'aucune action n'est confirmee.
extinction_menu(){
  local choice workers count pid token path remaining trigger wp wt wpath
  local redraw=1 previous_status="" status_line=""
  trigger=/userdata/system/configs/emulationstation/scripts/screensaver-start/shutdown-trigger.sh
  if [[ ! -t 0 ]]; then
    echo '[ERREUR] Le suivi en direct necessite un terminal SSH interactif.'
    return 1
  fi
  while :; do
    workers="$(shutdown_workers list)" || { echo '[ERREUR] Lecture des minuteurs impossible.'; pause; return 1; }
    count=0; pid=''; token=''; path=''; remaining=''
    if [[ -n "$workers" ]]; then
      while IFS=' ' read -r wp wt wpath; do
        [[ -n "$wp" ]] || continue
        ((count+=1))
        pid="$wp"; token="$wt"; path="$wpath"
      done <<< "$workers"
    fi
    if (( count == 1 )); then
      remaining="$(shutdown_remaining "$path" "$token")"
      status_line="[ACTIF] Temps restant : $remaining"
    elif (( count > 1 )); then
      status_line="[ATTENTION] $count minuteurs detectes."
    else
      status_line='[INACTIF] Aucun minuteur en cours.'
    fi
    if (( redraw )); then
      refresh_screen
      ui_section 'EXTINCTION'
      show_shutdown_delay "$trigger"
      echo "$status_line"
    echo
    ui_item '1) Modifier le délai'
    ui_item '2) Relancer le minuteur'
    ui_item '3) Notifications ntfy V7'
    echo
    ui_item '0) Retour'
    ui_item 'Q) Quitter le gestionnaire'
    echo
    ui_prompt 'Votre choix : '
      previous_status="$status_line"
      redraw=0
    elif [[ "$status_line" != "$previous_status" ]]; then
      # Neuf lignes séparent le début de la ligne d'état et le prompt.
      # Huit lignes visaient la ligne vide suivante et dupliquaient l'état.
      # Le curseur de saisie est sauvegardé puis restauré.
      printf '\0337\033[9A\r\033[2K%s\0338' "$status_line" > /dev/tty
      previous_status="$status_line"
    fi
    choice=''
    IFS= read -r -s -n 1 -t 1 choice || true
    manager_quit_key "$choice" && return 0
    case "$choice" in
      0) printf '\n'; return 0 ;;
      1) printf '\n'; change_shutdown_delay; pause; redraw=1 ;;
      2) printf '\n'; restart_shutdown_timer; redraw=1 ;;
      3) printf '\n'; ntfy_v7_menu; redraw=1 ;;
      '') ;;
      *) printf '\n[INFO] Choix invalide : %s\n' "$choice"; sleep 1; redraw=1 ;;
    esac
  done
}


# Lecture en temps reel des donnees batterie exposees par le noyau Linux.
steamdeck_battery_status(){
  local bat='' d f percent status now full design power remaining mins hours
  for d in /sys/class/power_supply/BAT*; do
    [[ -d "$d" ]] || continue
    [[ -r "$d/type" ]] || continue
    IFS= read -r f < "$d/type" || continue
    [[ "$f" == Battery ]] || continue
    bat="$d"
    break
  done
  if [[ "${1:-}" != embedded ]]; then
    refresh_screen
    ui_section 'ÉTAT DE LA BATTERIE'
  fi
  echo
  if [[ -z "$bat" ]]; then
    echo '[INFO] Aucune batterie détectée sur cet appareil.'
    echo '[INFO] Fonction destinée au Steam Deck.'
    [[ "${1:-}" == embedded ]] || pause
    return 0
  fi
  percent=''
  status='Inconnu'
  if [[ -r "$bat/capacity" ]]; then IFS= read -r percent < "$bat/capacity" || true; fi
  if [[ -r "$bat/status" ]]; then IFS= read -r status < "$bat/status" || true; fi
  case "$status" in
    Charging) status='En charge' ;;
    Discharging) status='En décharge' ;;
    Full) status='Pleine' ;;
    'Not charging') status='Pas en charge' ;;
  esac
  sys_info_row 'Batterie' "${bat##*/}"
  if [[ "$percent" =~ ^[0-9]+$ ]]; then
    if (( percent <= 15 )); then sys_info_row Niveau "$percent %" error
    elif (( percent <= 30 )); then sys_info_row Niveau "$percent %" warning
    else sys_info_row Niveau "$percent %" success; fi
  else
    sys_info_row Niveau 'Non disponible' warning
  fi
  sys_info_row État "$status" info
  local cycle temp_raw ac online val
  if [[ -r "$bat/cycle_count" ]]; then
    IFS= read -r cycle < "$bat/cycle_count" || true
    [[ "$cycle" =~ ^[0-9]+$ ]] && sys_info_row Cycles "$cycle"
  fi
  if [[ -r "$bat/temp" ]]; then
    IFS= read -r temp_raw < "$bat/temp" || true
    if [[ "$temp_raw" =~ ^[0-9]+$ ]]; then
      if (( temp_raw > 1000 )); then sys_info_row "Temp. batterie" "$((temp_raw / 1000)) °C"
      else sys_info_row "Temp. batterie" "$((temp_raw / 10)) °C"; fi
    fi
  fi
  for ac in /sys/class/power_supply/*; do
    [[ -r "$ac/type" && -r "$ac/online" ]] || continue
    IFS= read -r val < "$ac/type" || continue
    case "$val" in Mains|USB|USB_C|USB_PD|USB_DCP) ;; *) continue ;; esac
    IFS= read -r online < "$ac/online" || continue
    if [[ "$online" == 1 ]]; then sys_info_row 'Alimentation' 'Secteur' success; break; fi
  done
  now='' full='' design='' power=''
  for f in energy_now charge_now; do
    if [[ -r "$bat/$f" ]]; then IFS= read -r now < "$bat/$f" || true; break; fi
  done
  for f in energy_full charge_full; do
    if [[ -r "$bat/$f" ]]; then IFS= read -r full < "$bat/$f" || true; break; fi
  done
  for f in energy_full_design charge_full_design; do
    if [[ -r "$bat/$f" ]]; then IFS= read -r design < "$bat/$f" || true; break; fi
  done
  if [[ "$full" =~ ^[0-9]+$ && "$design" =~ ^[0-9]+$ ]] && (( design > 0 )); then
    local health=$((100 * full / design))
    if (( health < 70 )); then sys_info_row Santé "$health %" warning
    else sys_info_row Santé "$health %" success; fi
  fi
  if [[ -r "$bat/energy_full_design" && -r "$bat/energy_full" ]]; then
    local ef ed
    IFS= read -r ef < "$bat/energy_full" || true
    IFS= read -r ed < "$bat/energy_full_design" || true
    if [[ "$ef" =~ ^[0-9]+$ && "$ed" =~ ^[0-9]+$ ]]; then
      sys_info_row 'Cap. actuelle' "$(awk -v n="$ef" 'BEGIN{printf "%.1f Wh", n/1000000}')"
      sys_info_row 'Cap. origine' "$(awk -v n="$ed" 'BEGIN{printf "%.1f Wh", n/1000000}')"
    fi
  fi
  # Steam Deck : estimation en decharge a partir des valeurs uAh, uA et uV.
  # Uniquement si les mesures sont disponibles et coherentes.
  if [[ "$status" == 'En décharge' && -r "$bat/charge_now" && -r "$bat/current_now" && -r "$bat/voltage_now" ]]; then
    local charge_remaining discharge_current battery_voltage autonomy_minutes watts
    IFS= read -r charge_remaining < "$bat/charge_now" || true
    IFS= read -r discharge_current < "$bat/current_now" || true
    IFS= read -r battery_voltage < "$bat/voltage_now" || true
    if [[ "$charge_remaining" =~ ^[0-9]+$ && "$discharge_current" =~ ^[0-9]+$ && "$battery_voltage" =~ ^[0-9]+$ ]] && (( charge_remaining > 0 && discharge_current > 0 && battery_voltage > 0 )); then
      watts="$(awk -v i="$discharge_current" -v v="$battery_voltage" 'BEGIN{printf "%.2f", i*v/1000000000000}')"
      autonomy_minutes="$(awk -v q="$charge_remaining" -v i="$discharge_current" 'BEGIN{printf "%.0f", 60*q/i}')"
      if [[ "$autonomy_minutes" =~ ^[0-9]+$ ]] && (( autonomy_minutes > 0 && autonomy_minutes <= 10080 )); then
        sys_info_row 'Consommation' "${watts} W"
        sys_info_row 'Autonomie est.' "$(printf '%s h %02d min' "$((autonomy_minutes / 60))" "$((autonomy_minutes % 60))")"
      fi
    fi
  fi
  # Estimation uniquement lorsque le noyau expose energie et puissance
  # dans des unites compatibles. Ne pas confondre charge (uAh) et energie (uWh).
  if [[ ! ( -r "$bat/charge_now" && -r "$bat/current_now" && -r "$bat/voltage_now" && "$status" == 'En décharge' ) && -r "$bat/energy_now" && -r "$bat/power_now" ]]; then
    IFS= read -r now < "$bat/energy_now" || true
    IFS= read -r power < "$bat/power_now" || true
    if [[ "$now" =~ ^[0-9]+$ && "$power" =~ ^[0-9]+$ ]] && (( power > 0 )); then
      remaining="$now"
      if [[ "$status" == 'En charge' && -r "$bat/energy_full" ]]; then
        IFS= read -r full < "$bat/energy_full" || true
        if [[ "$full" =~ ^[0-9]+$ ]] && (( full >= now )); then remaining=$((full-now)); fi
      fi
      mins=$((60 * remaining / power))
      hours=$((mins / 60))
      if [[ "$status" == 'En décharge' ]]; then
        sys_info_row 'Autonomie est.' "$(printf '%s h %02d min' "$hours" "$((mins % 60))")"
      elif [[ "$status" == 'En charge' ]]; then
        sys_info_row 'Charge estimée' "$(printf '%s h %02d min' "$hours" "$((mins % 60))")"
      fi
    fi
  fi
  echo
  ui_print info '  Estimations selon le système.'
  [[ "${1:-}" == embedded ]] || pause
}

# Informations système : lecture locale, actualisation uniquement sur demande.
# Aucune commande de configuration ou modification des services.
# En mode aperçu, largeur réelle du terminal et libellés courts.
# Les autres écrans (mise à jour, disques) gardent leur affichage historique.
sys_info_row(){
  local label="$1" value="$2" role="${3:-success}" color='' reset=''
  local cols=${SYS_INFO_TERMINAL_COLS:-80} available='' chunk='' rest=''
  if (( UI_COLOR )); then
    case "$role" in
      error) color=$'\033[1;31m' ;;
      warning) color=$'\033[1;33m' ;;
      info) color=$'\033[1;36m' ;;
      *) color=$'\033[1;32m' ;;
    esac
    reset=$'\033[0m'
  fi

  if [[ "${SYS_INFO_COMPACT:-0}" == 1 ]]; then
    [[ "$cols" =~ ^[0-9]+$ ]] || cols=40
    (( cols >= 20 )) || cols=20
    # 2 espaces + 12 colonnes de libellé + ' : ' = 17 colonnes.
    # La valeur est affichée sur la même ligne si elle tient entièrement.
    if (( 17 + ${#value} <= cols )); then
      if (( UI_COLOR )); then
        printf '  \033[0;37m%-12s : %s%s\033[0m\n' "$label" "$color" "$value"
      else
        printf '  %-12s : %s\n' "$label" "$value"
      fi
    else
      if (( UI_COLOR )); then
        printf '  \033[0;37m%-12s :\033[0m\n' "$label"
      else
        printf '  %-12s :\n' "$label"
      fi
      # Si l'écran est étroit, afficher la valeur entière sur des lignes
      # indentées, avec coupure aux espaces lorsque c'est possible.
      available=$(( cols - 4 ))
      rest="$value"
      while [[ -n "$rest" ]]; do
        if (( ${#rest} <= available )); then
          chunk="$rest"; rest=''
        else
          chunk="${rest:0:available}"
          if [[ "$chunk" == *' '* ]]; then
            chunk="${chunk% *}"
            rest="${rest:${#chunk}}"
            rest="${rest# }"
          else
            rest="${rest:available}"
          fi
          [[ -n "$chunk" ]] || { chunk="${rest:0:available}"; rest="${rest:available}"; }
        fi
        if (( UI_COLOR )); then printf '    %s%s\033[0m\n' "$color" "$chunk"
        else printf '    %s\n' "$chunk"; fi
      done
    fi
    return 0
  fi

  # Présentation originelle, préservée hors de l'aperçu système.
  if (( UI_COLOR )); then
    case "$role" in
      error) color=$'\033[1;31m' ;;
      warning) color=$'\033[1;33m' ;;
      *) color=$'\033[1;32m' ;;
    esac
    printf '  \033[0;37m%s : %s%s\033[0m\n' "$label" "$color" "$value"
  else
    printf '  %s : %s\n' "$label" "$value"
  fi
}
sys_info_temperature(){
  local wanted="$1" hw name file raw candidate=''
  for hw in /sys/class/hwmon/hwmon*; do
    [[ -r "$hw/name" ]] || continue
    IFS= read -r name < "$hw/name" || continue
    if [[ "$wanted" == cpu ]]; then
      case "$name" in k10temp|coretemp|zenpower) ;; *) continue ;; esac
    else
      case "$name" in amdgpu) ;; *) continue ;; esac
    fi
    for file in "$hw"/temp*_input; do
      [[ -r "$file" ]] || continue
      IFS= read -r raw < "$file" || continue
      [[ "$raw" =~ ^[0-9]+$ ]] || continue
      candidate=$((raw / 1000))
      break
    done
    [[ -n "$candidate" ]] && break
  done
  if [[ -z "$candidate" && "$wanted" == cpu ]]; then
    for file in /sys/class/thermal/thermal_zone*/temp; do
      [[ -r "$file" ]] || continue
      IFS= read -r raw < "$file" || continue
      [[ "$raw" =~ ^[0-9]+$ ]] || continue
      candidate=$((raw / 1000))
      break
    done
  fi
  if [[ -z "$candidate" ]]; then sys_info_row "${wanted^^}" 'Non disponible' warning
  elif (( candidate >= 90 )); then sys_info_row "${wanted^^}" "$candidate °C" error
  elif (( candidate >= 80 )); then sys_info_row "${wanted^^}" "$candidate °C" warning
  else sys_info_row "${wanted^^}" "$candidate °C" info; fi
}
sys_info_cpu_load(){
  local tag user nice system idle iowait irq softirq steal guest guestnice
  local idle1 total1 idle2 total2 busy delta
  read -r tag user nice system idle iowait irq softirq steal guest guestnice < /proc/stat || return 0
  idle1=$((idle + ${iowait:-0}))
  total1=$((user + nice + system + idle + ${iowait:-0} + ${irq:-0} + ${softirq:-0} + ${steal:-0}))
  sleep 0.25
  read -r tag user nice system idle iowait irq softirq steal guest guestnice < /proc/stat || return 0
  idle2=$((idle + ${iowait:-0}))
  total2=$((user + nice + system + idle + ${iowait:-0} + ${irq:-0} + ${softirq:-0} + ${steal:-0}))
  delta=$((total2-total1))
  if (( delta > 0 )); then
    busy=$((100 * (delta - (idle2-idle1)) / delta))
    sys_info_row 'Charge CPU' "$busy %" info
  else sys_info_row 'Charge CPU' 'Non disponible' warning; fi
}
sys_info_battery_present(){
  local d f
  for d in /sys/class/power_supply/BAT*; do
    [[ -r "$d/type" ]] || continue
    IFS= read -r f < "$d/type" || continue
    [[ "$f" == Battery ]] && return 0
  done
  return 1
}
sys_info_active_theme(){
  local theme=''
  theme="$(python3 - <<'PY'
import re
from pathlib import Path
import xml.etree.ElementTree as ET
paths = [
    Path('/userdata/system/configs/emulationstation/es_settings.cfg'),
    Path('/userdata/system/configs/emulationstation/es_settings.xml'),
    Path('/userdata/system/.emulationstation/es_settings.cfg'),
]
for path in paths:
    if not path.is_file():
        continue
    try:
        root = ET.parse(path).getroot()
        for element in root.iter():
            if element.get('name', '').lower() in ('themeset', 'theme'):
                value = (element.get('value') or element.text or '').strip()
                if value:
                    print(value)
                    raise SystemExit(0)
    except (ET.ParseError, OSError):
        try:
            content = path.read_text(errors='replace')
            match = re.search(r'ThemeSet.{0,120}?value="([^"]+)"', content, re.I)
            if match:
                print(match.group(1))
                raise SystemExit(0)
        except OSError:
            pass
PY
)"
  [[ -n "$theme" ]] || theme='Non disponible'
  theme="${theme#es-theme-}"
  sys_info_row 'Thème' "$theme" info
}
sys_info_batocera_version(){
  local v=''
  v="$(detect_batocera_version)" || true
  if [[ "$v" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    printf 'v%s' "$v"
  else
    printf 'Non disponible'
  fi
}
# Metadonnees locales de la version installee (ne lance aucune mise a jour).
# /usr/share/batocera/batocera.version est cree lors de la compilation de l'image.
# La date indique la compilation, et NON la publication officielle.
sys_info_release_details(){
  local raw='' build='' build_date='Non disponible' build_type='Non déterminé' channel=''
  if [[ -r /usr/share/batocera/batocera.version ]]; then
    IFS= read -r raw < /usr/share/batocera/batocera.version || true
  fi
  if [[ -n "$raw" ]]; then
    build="${raw%% *}"
    if [[ "$raw" =~ ([0-9]{4})/([0-9]{2})/([0-9]{2})[[:space:]]+([0-9]{2}:[0-9]{2}) ]]; then
      build_date="${BASH_REMATCH[3]}/${BASH_REMATCH[2]}/${BASH_REMATCH[1]} ${BASH_REMATCH[4]}"
    elif [[ "$raw" =~ ([0-9]{4})/([0-9]{2})/([0-9]{2}) ]]; then
      build_date="${BASH_REMATCH[3]}/${BASH_REMATCH[2]}/${BASH_REMATCH[1]}"
    fi
    if [[ "$build" == *-dev* || "$build" == *-beta* || "$build" == *-alpha* ]]; then
      build_type='Développement'
    elif [[ "$build" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
      build_type='Stable'
    fi
  else
    build='Non disponible'
  fi
  channel="$(sys_info_update_channel)"
  sys_info_row 'Build' "$build" info
  sys_info_row 'Compilation' "$build_date" info
  case "$build_type" in
    Stable) sys_info_row 'Type' "$build_type" info ;;
    Développement) sys_info_row 'Type' "$build_type" warning ;;
    *) sys_info_row 'Type' "$build_type" warning ;;
  esac
  case "$channel" in
    stable) sys_info_row 'Canal MAJ' 'Stable' info ;;
    butterfly|beta) sys_info_row 'Canal MAJ' 'Butterfly' warning ;;
    *) sys_info_row 'Canal MAJ' 'Indéterminé' warning ;;
  esac
  if [[ "${SYS_UPDATES_ALL_CHECKED:-0}" == 1 ]]; then
    sys_info_row 'État MAJ' '2 canaux contrôlés' info
    sys_info_overview_update_status 'Stable' "${SYS_STABLE_STATUS:-}" "${SYS_STABLE_ROLE:-warning}" "${SYS_STABLE_WEBVERSION:-}"
    sys_info_overview_update_status 'Butterfly' "${SYS_BUTTERFLY_STATUS:-}" "${SYS_BUTTERFLY_ROLE:-warning}" "${SYS_BUTTERFLY_WEBVERSION:-}"
  else
    sys_info_row 'État MAJ' 'Non vérifiée' warning
  fi
  if [[ -n "${SYS_UPDATE_CHECKED_AT:-}" ]]; then
    sys_info_row 'Contrôle MAJ' "$SYS_UPDATE_CHECKED_AT" info
  fi
}
# L'etat indique la position de la version en ligne PAR RAPPORT a la version
# installee, et non pas simplement le resultat officiel "No Update found!".
# Important : uniquement l'affichage. Les controles de securite et les actions
# d'installation/retour arriere conservent les etats officiels non modifies.
sys_info_update_display_status(){
  local status="$1" webversion="$2" installed='' relation='unknown'
  if [[ "$status" == 'Aucune mise à jour disponible' || "$status" == 'MISE À JOUR DISPONIBLE' ]]; then
    if [[ -n "$webversion" && "$webversion" != '--' && -r /usr/share/batocera/batocera.version ]]; then
      IFS= read -r installed < /usr/share/batocera/batocera.version || true
      relation="$(sys_info_version_relation "$installed" "$webversion")" || relation=unknown
    fi
    if [[ "$relation" == older ]]; then
      printf '%s\n' 'Version antérieure disponible'
    elif [[ "$status" == 'MISE À JOUR DISPONIBLE' ]]; then
      printf '%s\n' 'MAJ disponible'
    elif [[ "$relation" == same ]]; then
      printf '%s\n' 'À jour'
    else
      # Si la relation est inconnue, ne pas affirmer que l'on est à jour.
      printf '%s\n' 'Aucune MAJ détectée'
    fi
  elif [[ "$status" == Vérification\ impossible* ]]; then
    printf '%s\n' 'Vérification impossible'
  else
    printf '%s\n' "${status:-Vérification impossible}"
  fi
}
# Résumé compact des deux canaux dans l'aperçu système.
sys_info_overview_update_status(){
  local label="$1" status="$2" role="$3" webversion="${4:-}" short=''
  short="$(sys_info_update_display_status "$status" "$webversion")"
  case "$short" in
    'Version antérieure disponible') short='Version antérieure'; role=warning ;;
    'À jour') role=success ;;
    'MAJ disponible') role=warning ;;
    *) role=warning ;;
  esac
  sys_info_row "$label" "$short" "$role"
}
# Canal configure pour les mises a jour, different du type de build installe.
sys_info_update_channel(){
  local channel='' config=/userdata/system/batocera.conf
  if [[ -r "$config" ]]; then
    channel="$(sed -nE 's/^[[:space:]]*updates[.]type[[:space:]]*=[[:space:]]*([^[:space:]#]+).*/\1/p' "$config" | tail -n 1)"
  fi
  # Valeur par defaut du canal Batocera si aucune surcharge utilisateur.
  [[ -n "$channel" ]] || channel=stable
  case "$channel" in stable|butterfly|beta) printf '%s\n' "$channel" ;; *) echo unknown ;; esac
}
# Controle manuel en lecture seule : aucune mise a jour ou configuration n'est modifiee.
# Le resultat est affiche dans un ecran dedie, jamais efface avant une pause.
SYS_UPDATE_STATUS='Non vérifiée (option 3)'
SYS_UPDATE_ROLE=warning
SYS_UPDATE_WEBVERSION=''
SYS_UPDATE_CHECKED_AT=''
SYS_UPDATE_OFFICIAL_STATUS=''
SYS_UPDATE_DIAGNOSTIC=''
SYS_UPDATE_EXITCODE=''
SYS_UPDATES_ALL_CHECKED=0
sys_info_check_updates(){
  local channel='' answer='' state='' online='' detail='' rc='' diagnostic=''
  # Un argument explicite choisit le canal du controle, sans changer batocera.conf.
  channel="${1:-}"
  [[ -n "$channel" ]] || channel="$(sys_info_update_channel)"
  SYS_UPDATE_WEBVERSION=''
  SYS_UPDATE_OFFICIAL_STATUS=''
  SYS_UPDATE_DIAGNOSTIC=''
  SYS_UPDATE_EXITCODE=''
  SYS_UPDATE_CHECKED_AT="$(date '+%d/%m/%Y %H:%M' 2>/dev/null || true)"
  SYS_UPDATE_STATUS='Vérification impossible'
  SYS_UPDATE_ROLE=warning
  if [[ "$channel" == unknown ]]; then
    SYS_UPDATE_STATUS='Canal de mise à jour inconnu'
    SYS_UPDATE_DIAGNOSTIC='Vérifier updates.type dans batocera.conf.'
    return 0
  fi
  # Stable se controle sans argument (syntaxe officielle), Butterfly avec argument.
  # Une limite de 20 secondes evite un blocage reseau du menu.
  answer="$(python3 - "$channel" <<'PY_CHECK_UPDATES'
import errno, os, pty, re, select, subprocess, sys, time
branch=sys.argv[1]
branch='butterfly' if branch=='beta' else branch
# Depuis Batocera 44, batocera-check-updates est un alias de cette commande.
# --check-upgrade : controle uniquement, aucune mise a jour installee.
cmd=['/usr/bin/batocera-upgrade','--check-upgrade',branch]
def clean(s,limit=180):
    return re.sub(r'[\x00-\x1f\x7f|]+',' ',str(s)).strip()[:limit]
def emit(state='',online='',status='',rc='',note=''):
    print('|'.join((clean(state),clean(online),clean(status),clean(rc),clean(note,300))))

# Le programme officiel choisit son affichage via `test -t 1`.
# Un pseudo-terminal garantit le diagnostic detaille meme si le gestionnaire journalise stdout.
master=slave=None
try:
    master,slave=pty.openpty()
    p=subprocess.Popen(cmd,stdin=subprocess.DEVNULL,stdout=slave,stderr=slave,
                       start_new_session=True,close_fds=True)
    os.close(slave);slave=None
    output=bytearray()
    deadline=time.monotonic()+25
    expired=False
    while True:
        remaining=deadline-time.monotonic()
        if remaining<=0:
            expired=True
            p.kill()
            break
        readable,_,_=select.select([master],[],[],min(remaining,0.5))
        if readable:
            try:
                chunk=os.read(master,4096)
            except OSError as exc:
                if exc.errno==errno.EIO: break
                raise
            if not chunk: break
            if len(output)<32768:
                output.extend(chunk[:32768-len(output)])
        elif p.poll() is not None:
            break
    rc=p.wait(timeout=3)
    if expired:
        emit('ERREUR',rc=str(rc),note='Delai de 25 secondes depasse (reseau ou serveur)')
    else:
        lines=output.decode('utf-8','replace').splitlines()
        def field(label):
            for line in lines:
                m=re.match(r'\s*'+re.escape(label)+r'\s*:\s*(.*?)\s*$',line,re.I)
                if m:return clean(m.group(1))
            return ''
        status=field('Status')
        online=field('Webversion')
        low=status.lower()
        if not online or online=='--':
            state='ERREUR'
            note='Version distante inaccessible ou absente. '
        elif re.search(r'no\s+update|already\s+up.to.date',low):
            state='OK';note=''
        elif re.search(r'possible\s+update|update\s+(?:found|available)',low):
            state='MAJ';note=''
        else:
            state='INCONNU';note='Statut officiel non reconnu. '
        if state in ('ERREUR','INCONNU'):
            useful=[clean(line,120) for line in lines if line.strip()]
            note += ' '.join(useful[-2:])[:220] if useful else 'Aucune reponse exploitable.'
        # Le code 1 signifie aussi "aucune mise a jour" dans certaines versions.
        emit(state,online,status,str(rc),note)
except FileNotFoundError:
    emit('ERREUR',note='Programme /usr/bin/batocera-upgrade absent')
except OSError as exc:
    emit('ERREUR',note='Erreur locale : '+str(exc))
except subprocess.TimeoutExpired:
    emit('ERREUR',note='Arret du controle depasse')
finally:
    for fd in (master,slave):
        if fd is not None:
            try: os.close(fd)
            except OSError: pass
PY_CHECK_UPDATES
)" || {
    SYS_UPDATE_STATUS='Vérification impossible (erreur locale)'
    SYS_UPDATE_DIAGNOSTIC="Échec du contrôle Python."
    return 0
  }
  IFS='|' read -r state online detail rc diagnostic <<< "$answer"
  SYS_UPDATE_WEBVERSION="$online"
  SYS_UPDATE_OFFICIAL_STATUS="$detail"
  SYS_UPDATE_EXITCODE="$rc"
  SYS_UPDATE_DIAGNOSTIC="$diagnostic"
  case "$state" in
    OK) SYS_UPDATE_STATUS='Aucune mise à jour disponible'; SYS_UPDATE_ROLE=success ;;
    MAJ) SYS_UPDATE_STATUS='MISE À JOUR DISPONIBLE'; SYS_UPDATE_ROLE=warning ;;
    ERREUR) SYS_UPDATE_STATUS='Vérification impossible (diagnostic disponible)'; SYS_UPDATE_ROLE=warning ;;
    *) SYS_UPDATE_STATUS='Résultat indéterminé'; SYS_UPDATE_ROLE=warning ;;
  esac
  return 0
}
# Controle les deux branches officielles, sans tenir compte du canal configure.
# Cette fonction ne modifie pas updates.type et n'installe rien.
sys_info_check_all_updates(){
  local branch
  SYS_UPDATES_ALL_CHECKED=1
  for branch in stable butterfly; do
    sys_info_check_updates "$branch"
    if [[ "$branch" == stable ]]; then
      SYS_STABLE_STATUS="$SYS_UPDATE_STATUS"
      SYS_STABLE_ROLE="$SYS_UPDATE_ROLE"
      SYS_STABLE_WEBVERSION="$SYS_UPDATE_WEBVERSION"
      SYS_STABLE_OFFICIAL_STATUS="$SYS_UPDATE_OFFICIAL_STATUS"
      SYS_STABLE_DIAGNOSTIC="$SYS_UPDATE_DIAGNOSTIC"
      SYS_STABLE_EXITCODE="$SYS_UPDATE_EXITCODE"
    else
      SYS_BUTTERFLY_STATUS="$SYS_UPDATE_STATUS"
      SYS_BUTTERFLY_ROLE="$SYS_UPDATE_ROLE"
      SYS_BUTTERFLY_WEBVERSION="$SYS_UPDATE_WEBVERSION"
      SYS_BUTTERFLY_OFFICIAL_STATUS="$SYS_UPDATE_OFFICIAL_STATUS"
      SYS_BUTTERFLY_DIAGNOSTIC="$SYS_UPDATE_DIAGNOSTIC"
      SYS_BUTTERFLY_EXITCODE="$SYS_UPDATE_EXITCODE"
    fi
  done
  SYS_UPDATE_WEBVERSION=''
  SYS_UPDATE_STATUS='2 canaux contrôlés'
  SYS_UPDATE_ROLE=info
}

# Coupe les messages longs pour les ecrans SSH sur telephone.
sys_info_mobile_text(){
  local value="$1" role="${2:-info}" line='' word
  local -a words=()
  read -r -a words <<< "$value"
  for word in "${words[@]}"; do
    while (( ${#word} > 25 )); do
      [[ -z "$line" ]] || { ui_print "$role" "  $line"; line=''; }
      ui_print "$role" "  ${word:0:25}"
      word="${word:25}"
    done
    if [[ -n "$line" ]] && (( ${#line} + 1 + ${#word} > 25 )); then
      ui_print "$role" "  $line"
      line=''
    fi
    if [[ -z "$line" ]]; then line="$word"; else line+=" $word"; fi
  done
  [[ -z "$line" ]] || ui_print "$role" "  $line"
}

# Effacement fiabilise : les commandes ANSI et le contenu passent tous deux
# par stdout/tee, dans le meme ordre (pas d'echo de l'ancien ecran).
sys_info_update_clear_screen(){
  if [[ -t 0 && -w /dev/tty ]]; then
    printf '\033[3J\033[H\033[2J'
  fi
}

# Un bloc par canal, avec un etat propre a chacun.
sys_info_check_channel_screen(){
  local label="$1" status="$2" role="$3" webversion="$4" diagnostic="$7"
  local version='' yyyy='' mm='' dd='' hhmm='' shown=''
  shown="$(sys_info_update_display_status "$status" "$webversion")"
  echo
  ui_print section "  === $label ==="
  case "$shown" in
    'À jour') sys_info_row 'État' "$shown" success ;;
    'MAJ disponible') sys_info_row 'État' "$shown" warning ;;
    'Version antérieure disponible')
      ui_print info '  État :'
      sys_info_mobile_text "$shown" warning ;;
    *)
      ui_print info '  État :'
      sys_info_mobile_text "$shown" "$role" ;;
  esac
  if [[ -n "$webversion" ]]; then
    if [[ "$webversion" =~ ^([^[:space:]]+)[[:space:]]+([0-9]{4})/([0-9]{2})/([0-9]{2})[[:space:]]+([0-9]{2}:[0-9]{2})$ ]]; then
      version="${BASH_REMATCH[1]}"
      yyyy="${BASH_REMATCH[2]}"; mm="${BASH_REMATCH[3]}"
      dd="${BASH_REMATCH[4]}"; hhmm="${BASH_REMATCH[5]}"
      sys_info_row 'Version' "$version" info
      sys_info_row 'Date' "$dd/$mm/$yyyy" info
      sys_info_row 'Heure' "$hhmm" info
    else
      ui_print info '  Version en ligne :'
      sys_info_mobile_text "$webversion" info
    fi
  fi
  # Le retour officiel et son code sont conserves en interne pour la fiabilite
  # du controle mais ne polluent plus l'affichage du gestionnaire.
  if [[ -n "$diagnostic" ]]; then
    ui_print warning '  Diagnostic :'
    sys_info_mobile_text "$diagnostic" warning
  fi
}
# Affichage independant du canal choisi dans la configuration Batocera.
sys_info_check_screen(){
  local _key='' configured=''
  # Même flux que les lignes journalisées par tee : ordre d'effacement fiable.
  sys_info_update_clear_screen
  ui_section 'MAJ BATOCERA'
  configured="$(sys_info_update_channel)"
  case "$configured" in
    stable) configured='Stable' ;;
    butterfly|beta) configured='Butterfly' ;;
    *) configured='Inconnu' ;;
  esac
  sys_info_row 'Canal choisi' "$configured" info
  ui_print info '  Contrôle des deux canaux.'
  sys_info_check_channel_screen 'STABLE' \
    "${SYS_STABLE_STATUS:-Non verifiee}" "${SYS_STABLE_ROLE:-warning}" \
    "${SYS_STABLE_WEBVERSION:-}" "${SYS_STABLE_OFFICIAL_STATUS:-}" \
    "${SYS_STABLE_EXITCODE:-}" "${SYS_STABLE_DIAGNOSTIC:-}"
  sys_info_check_channel_screen 'BUTTERFLY' \
    "${SYS_BUTTERFLY_STATUS:-Non verifiee}" "${SYS_BUTTERFLY_ROLE:-warning}" \
    "${SYS_BUTTERFLY_WEBVERSION:-}" "${SYS_BUTTERFLY_OFFICIAL_STATUS:-}" \
    "${SYS_BUTTERFLY_EXITCODE:-}" "${SYS_BUTTERFLY_DIAGNOSTIC:-}"
  echo
  ui_print info '  Contrôle uniquement :'
  ui_print info '  Rien n’est installé.'
}

# Résumé de batterie : affiché seulement si le noyau expose une batterie.
# Aucune estimation inventée ni jauge graphique sensible aux largeurs SSH.
sys_info_battery_overview(){
  local bat='' d kind='' percent='' state='' translated=''
  for d in /sys/class/power_supply/BAT*; do
    [[ -r "$d/type" ]] || continue
    IFS= read -r kind < "$d/type" || continue
    [[ "$kind" == Battery ]] || continue
    bat="$d"; break
  done
  [[ -n "$bat" ]] || return 0
  echo
  ui_print section '  BATTERIE'
  if [[ -r "$bat/capacity" ]]; then
    IFS= read -r percent < "$bat/capacity" || true
  fi
  if [[ "$percent" =~ ^[0-9]+$ ]] && (( 10#$percent <= 100 )); then
    if (( 10#$percent <= 15 )); then sys_info_row Niveau "$percent %" error
    elif (( 10#$percent <= 30 )); then sys_info_row Niveau "$percent %" warning
    else sys_info_row Niveau "$percent %" success; fi
  else
    sys_info_row Niveau 'Non disponible' warning
  fi
  if [[ -r "$bat/status" ]]; then
    IFS= read -r state < "$bat/status" || true
  fi
  case "$state" in
    Charging) translated='En charge' ;;
    Discharging) translated='Sur batterie' ;;
    Full) translated='Chargée' ;;
    'Not charging') translated='Pas en charge' ;;
    *) translated='Indéterminée' ;;
  esac
  if [[ "$translated" == Indéterminée ]]; then
    sys_info_row Alimentation "$translated" warning
  else
    sys_info_row Alimentation "$translated" info
  fi
}

# Fiche système compacte, mêmes informations sur Mini-PC et Steam Deck.
sys_info_overview(){
  local model='' model_file mem_total=0 mem_available=0 ram_used disk_line uptime_sec h m
  local cols='' tty_cols='' SYS_INFO_COMPACT=1 SYS_INFO_TERMINAL_COLS=40
  # La taille communiquée par le terminal SSH prévaut sur un COLUMNS obsolète.
  if [[ -t 0 ]]; then
    tty_cols="$(stty size 2>/dev/null)" || tty_cols=''
    cols="${tty_cols##* }"
  fi
  if [[ ! "$cols" =~ ^[0-9]+$ ]] || (( cols < 20 )); then
    cols="${COLUMNS:-40}"
  fi
  [[ "$cols" =~ ^[0-9]+$ ]] || cols=40
  (( cols >= 20 )) || cols=20
  SYS_INFO_TERMINAL_COLS="$cols"

  refresh_screen
  ui_section 'INFORMATIONS SYSTÈME'
  echo
  ui_print section '  MACHINE'
  model_file=/sys/devices/virtual/dmi/id/product_name
  if [[ -r "$model_file" ]]; then IFS= read -r model < "$model_file" || true; fi
  if [[ -z "$model" || "$model" == 'Default string' ]]; then
    model="$(uname -m)"
  fi
  # Le même écran identifie l'appareil automatiquement, sans valeur fictive.
  sys_info_row 'Appareil' "$model" info
  sys_info_row 'Batocera' "$(sys_info_batocera_version)" info
  sys_info_release_details
  sys_info_active_theme
  echo
  ui_print section '  RÉSEAU'
  local network_ip=''
  network_ip="$(onef_local_ip)" || network_ip=''
  if [[ -n "$network_ip" ]]; then
    sys_info_row 'IP locale' "$network_ip" success
  else
    sys_info_row 'IP locale' 'Non disponible' warning
  fi
  echo
  ui_print section '  PERFORMANCES'
  sys_info_temperature cpu
  sys_info_temperature gpu
  [[ -r /proc/stat ]] && sys_info_cpu_load
  echo
  ui_print section '  MÉMOIRE / STOCKAGE'
  if [[ -r /proc/meminfo ]]; then
    while read -r key value unit; do
      case "$key" in MemTotal:) mem_total="$value" ;; MemAvailable:) mem_available="$value" ;; esac
    done < /proc/meminfo
  fi
  if (( mem_total > 0 )); then
    ram_used=$((mem_total-mem_available))
    sys_info_row 'RAM utilisée' "$(awk -v u="$ram_used" -v t="$mem_total" 'BEGIN{printf "%.1f / %.1f Go",u/1048576,t/1048576}')" info
  else sys_info_row 'RAM utilisée' 'Non disponible' warning; fi
  disk_line="$(df -hP /userdata 2>/dev/null | awk 'NR==2 {print $4 " / " $2}')"
  sys_info_row 'Disque' "${disk_line:-Non disponible}" info
  # Batterie uniquement sur les machines qui en exposent une (Steam Deck).
  if sys_info_battery_present; then
    sys_info_battery_overview
  fi
  echo
  ui_print section '  SYSTÈME'
  if [[ -r /proc/uptime ]]; then
    read -r uptime_sec _ < /proc/uptime || uptime_sec=0
    uptime_sec="${uptime_sec%%.*}"
    if [[ "$uptime_sec" =~ ^[0-9]+$ ]]; then
      h=$((uptime_sec / 3600)); m=$(((uptime_sec % 3600) / 60))
      sys_info_row 'Temps allumé' "${h} h $(printf '%02d' "$m") min" info
    fi
  fi
}

# Lecture seule : inventaire des disques et partitions, y compris USB.
sys_info_disks(){
  refresh_screen
  ui_section 'DISQUES ET PARTITIONS'
  echo
  python3 - "$UI_COLOR" <<'PY'
import json, os, re, shutil, subprocess, sys
color = sys.argv[1] == '1'
CYAN, YELLOW, GREEN, RED, DIM, RESET = ('\033[1;36m','\033[1;33m','\033[1;32m','\033[1;31m','\033[0;37m','\033[0m') if color else ('',)*6
def out(text, tone=''):
    print((tone or '') + text + RESET if color else text)
def run(*args):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=8).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ''
def pairs(line):
    return dict(re.findall(r'(\w+)="((?:\\.|[^"\\])*)"', line))
def readable(n):
    n = float(n)
    for unit in ('o', 'Ko', 'Mo', 'Go', 'To', 'Po'):
        if n < 1024 or unit == 'Po':
            return (f'{n:.1f}' if n < 10 and unit != 'o' else f'{n:.0f}').replace('.', ',') + ' ' + unit
        n /= 1024
    return '?'
def mountpoints(raw):
    # lsblk -P escapes embedded newlines as literal \x0a.
    return [p for p in raw.replace(r'\x0a', '\n').splitlines() if p.startswith('/')]
raw = run('lsblk', '-P', '-b', '-o', 'NAME,PKNAME,TYPE,TRAN,SIZE,FSTYPE,LABEL,MOUNTPOINTS')
if not raw:
    out('  lsblk indisponible.', YELLOW)
    raise SystemExit
entries = [pairs(line) for line in raw.splitlines()]
disks = [e for e in entries if e.get('TYPE') == 'disk']
if not disks:
    out('  Aucun disque détecté.', YELLOW)
for index, disk in enumerate(disks, 1):
    name = disk.get('NAME', '?')
    transport = disk.get('TRAN', '').upper() or 'DISQUE'
    size = readable(disk.get('SIZE') or '0')
    out(f'  {transport} {index} — {size}', CYAN)
    out(f'  {name}', DIM)
    parts = [e for e in entries if e.get('TYPE') == 'part' and
             (e.get('PKNAME') == name or (not e.get('PKNAME') and e.get('NAME','').startswith(name)))]
    visible = []
    for part in parts:
        pname = part.get('NAME', '')
        label = part.get('LABEL', '').strip()
        if label.lower() == 'recovery':
            continue
        if pname == 'nvme0n1p3' and not label:
            label = 'Windows'
        if not label and '/userdata' in mountpoints(part.get('MOUNTPOINTS', '')):
            label = 'Interne'
        if not label:
            continue
        visible.append((part, label))
    if not visible:
        out('    Aucune partition nommée à afficher.', DIM)
    for part, label in visible:
        fs = part.get('FSTYPE') or 'Inconnu'
        fs = {'vfat': 'FAT32', 'ntfs': 'NTFS', 'exfat': 'exFAT'}.get(fs.lower(), fs)
        # Libellés blancs, valeurs vertes ; seule l'occupation change de couleur.
        print(f'    {label} : ' + GREEN + fs + RESET)
        mounts = mountpoints(part.get('MOUNTPOINTS', ''))
        info = None
        for mount in mounts:
            try:
                st = os.statvfs(mount)
                total = st.f_blocks * st.f_frsize
                free = st.f_bavail * st.f_frsize
                if total:
                    used_percent = round(100 * (total - st.f_bfree * st.f_frsize) / total)
                    info = (total, free, used_percent)
                    break
            except OSError:
                continue
        capacity = readable(info[0]) if info else readable(part.get('SIZE') or '0')
        print('    Capacité : ' + GREEN + capacity + RESET)
        if info is None:
            state = 'Non monté' if not mounts else 'Indisponible'
            print('    Libre : ' + DIM + state + RESET)
        else:
            total, free, pct = info
            tone = RED if pct >= 85 else YELLOW if pct >= 75 else GREEN
            print('    Libre : ' + tone + f'{readable(free)} ({pct} % utilisé)' + RESET)
        print()
    out('  SANTÉ DU DISQUE', CYAN)
    if not shutil.which('smartctl'):
        out('    SMART : outil indisponible', DIM)
    else:
        try:
            proc = subprocess.run(['smartctl', '-j', '-a', '/dev/' + name], capture_output=True, text=True, timeout=12)
            data = json.loads(proc.stdout)
        except (OSError, ValueError, subprocess.TimeoutExpired):
            data = {}
        nvme = data.get('nvme_smart_health_information_log') or {}
        smart = data.get('smart_status') or {}
        model = data.get('model_name') or data.get('model_number')
        if model:
            print('    Modèle : ' + GREEN + str(model) + RESET)
        if not nvme and not smart:
            out('    SMART : non disponible', DIM)
        else:
            passed = smart.get('passed')
            warning = nvme.get('critical_warning', 0)
            state = 'Alerte' if passed is False or (isinstance(warning, int) and warning != 0) else 'Bon' if passed is True else 'Indisponible'
            print('    État SMART : ' + (RED if state == 'Alerte' else GREEN if state == 'Bon' else DIM) + state + RESET)
            used = nvme.get('percentage_used')
            if isinstance(used, (int, float)):
                health = max(0, 100-used)
                print('    Santé estimée : ' + (RED if health < 50 else YELLOW if health < 80 else GREEN) + f'{health:g} %' + RESET)
            temp = (data.get('temperature') or {}).get('current')
            if temp is None and isinstance(nvme.get('temperature'), (int,float)):
                temp = round(nvme['temperature'] - 273.15)
            if isinstance(temp, (int,float)):
                print('    Température : ' + (RED if temp >= 75 else YELLOW if temp >= 60 else GREEN) + f'{temp:g} °C' + RESET)
            for key, label, suffix in [('power_on_hours','Fonctionnement',' h'),('power_cycles','Allumages',''),('media_errors',"Erreurs d'intégrité",'')]:
                val = nvme.get(key)
                if isinstance(val, (int,float)):
                    print('    ' + label + ' : ' + GREEN + f'{val:,.0f}'.replace(',', ' ') + suffix + RESET)
            written = nvme.get('data_units_written')
            if isinstance(written, (int,float)):
                print('    Données écrites : ' + GREEN + f'{written * 512000 / 1e12:.2f}'.replace('.', ',') + ' To' + RESET)
            unsafe = nvme.get('unsafe_shutdowns')
            if isinstance(unsafe, (int,float)):
                print('    Arrêts non sécurisés : ' + YELLOW + f'{unsafe:,.0f}'.replace(',', ' ') + RESET)
    print()
PY
  echo
  ui_item '1) Actualiser'
  ui_item '0) Retour'
    ui_item 'Q) Quitter le gestionnaire'
}
sys_info_disks_menu(){
  local choice
  while :; do
    sys_info_disks
    choice="$(read_key 'Votre choix : ')" || return 0
    case "$choice" in
      1) continue ;;
      0) return 0 ;;
      *) ui_print warning 'Choix invalide.'; sleep 1 ;;
    esac
  done
}
# Barriere batterie pour une mise a jour systeme.
# Secteur (Charging/Full) : autorise, meme si le niveau est faible.
# Batterie (Discharging/Not charging) : autorisee seulement si > 30 %.
# Etat inconnu : refuse par securite.
sys_info_upgrade_battery_guard(){
  local device='' battery_type='' status='' percent='' found=0
  if ! sys_info_battery_present; then
    return 0
  fi
  for device in /sys/class/power_supply/BAT*; do
    [[ -r "$device/type" ]] || continue
    IFS= read -r battery_type < "$device/type" || continue
    [[ "$battery_type" == Battery ]] || continue
    found=1
    if [[ ! -r "$device/status" ]]; then
      ui_print error '  État batterie inaccessible.'
      return 1
    fi
    IFS= read -r status < "$device/status" || true
    case "$status" in
      Charging|Full)
        ui_print success '  Alimentation secteur détectée.'
        ;;
      Discharging|'Not charging')
        if [[ ! -r "$device/capacity" ]]; then
          ui_print error '  Niveau batterie inaccessible.'
          return 1
        fi
        IFS= read -r percent < "$device/capacity" || true
        if [[ ! "$percent" =~ ^[0-9]+$ ]] || (( 10#$percent > 100 )); then
          ui_print error '  Niveau batterie invalide.'
          return 1
        fi
        if (( 10#$percent <= 30 )); then
          ui_print error "  Batterie : $percent % (minimum 31 %)."
          ui_print warning '  Branchez le chargeur ou rechargez.'
          return 1
        fi
        ui_print warning "  Batterie : $percent % (sans charge)."
        ui_print warning '  Risque de coupure pendant MAJ.'
        ui_print warning '  Chargeur fortement recommandé.'
        ;;
      *)
        ui_print error '  Alimentation indéterminée.'
        ui_print warning '  Mise à jour refusée par sécurité.'
        return 1
        ;;
    esac
  done
  if (( ! found )); then
    ui_print error '  Batterie détectée mais introuvable.'
    return 1
  fi
  return 0
}

# Comparaison du numero MAJEUR.MINEUR, volontairement conservatrice.
# Le format de build Batocera peut contenir hash/date ; ceux-ci ne suffisent pas
# a garantir qu'une image de retour arriere existe encore sur le serveur.
# Reponse : older, same, newer, unknown (cible par rapport a l'installee).
sys_info_version_relation(){
  local installed="$1" target="$2" imaj='' imin=0 tmaj='' tmin=0
  if [[ "$installed" =~ ^([0-9]+)([.]([0-9]+))?($|[^0-9.]) ]]; then
    imaj="${BASH_REMATCH[1]}"; imin="${BASH_REMATCH[3]:-0}"
  else
    printf '%s\n' unknown; return 1
  fi
  if [[ "$target" =~ ^([0-9]+)([.]([0-9]+))?($|[^0-9.]) ]]; then
    tmaj="${BASH_REMATCH[1]}"; tmin="${BASH_REMATCH[3]:-0}"
  else
    printf '%s\n' unknown; return 1
  fi
  if (( 10#$tmaj < 10#$imaj || (10#$tmaj == 10#$imaj && 10#$tmin < 10#$imin) )); then
    printf '%s\n' older
  elif (( 10#$tmaj == 10#$imaj && 10#$tmin == 10#$imin )); then
    printf '%s\n' same
  else
    printf '%s\n' newer
  fi
}

# Un retour n'est propose que vers la derniere Stable officiellement
# verifiee, lorsqu'elle est numeriquement plus ancienne que l'installation.
# Cela n'autorise PAS une URL arbitraire ni un ancien build Butterfly.
sys_info_previous_stable_available(){
  local installed='' rel=''
  [[ "${SYS_STABLE_STATUS:-}" == 'Aucune mise à jour disponible' ]] || return 1
  [[ -n "${SYS_STABLE_WEBVERSION:-}" && "${SYS_STABLE_WEBVERSION}" != '--' ]] || return 1
  [[ -r /usr/share/batocera/batocera.version ]] || return 1
  IFS= read -r installed < /usr/share/batocera/batocera.version || true
  rel="$(sys_info_version_relation "$installed" "$SYS_STABLE_WEBVERSION")" || return 1
  [[ "$rel" == older ]]
}

# Retour arriere explicite vers le canal Stable uniquement, avec controles
# repetes avant l'ecriture. Ne modifie pas updates.type et ne redemarre pas.
sys_info_downgrade_stable(){
  local current='' target='' target_version='' relation='' current_after='' rc=0
  sys_info_update_clear_screen
  ui_section 'RETOUR VERSION STABLE'
  ui_print warning '  Opération à risque.'
  echo
  if [[ $EUID -ne 0 || ! -x /usr/bin/batocera-upgrade ]]; then
    ui_print error '  Accès système impossible.'
    return 1
  fi
  [[ -r /usr/share/batocera/batocera.version ]] || {
    ui_print error '  Version installée inconnue.'; return 1;
  }
  IFS= read -r current < /usr/share/batocera/batocera.version || true
  # Une recherche de MAJ 'normale' retourne parfois 'No Update found!'
  # pour une version stable plus ancienne : c'est un resultat valable ici.
  sys_info_check_updates stable
  target="$SYS_UPDATE_WEBVERSION"
  if [[ "$SYS_UPDATE_STATUS" != 'Aucune mise à jour disponible' || -z "$target" ]]; then
    ui_print error '  Stable non vérifiée.'
    ui_print warning '  Retour arrière refusé.'
    return 1
  fi
  relation="$(sys_info_version_relation "$current" "$target")" || relation=unknown
  if [[ "$relation" != older ]]; then
    ui_print warning '  Pas de Stable antérieure'
    ui_print warning '  identifiée avec certitude.'
    return 1
  fi
  target_version="${target%% *}"
  ui_print info '  Version actuelle :'
  sys_info_mobile_text "$current" info
  ui_print warning '  Retour vers Stable :'
  sys_info_mobile_text "$target" warning
  echo
  ui_print warning '  RISQUE : anciens émulateurs'
  ui_print warning '  et réglages incompatibles.'
  ui_print warning '  Sauvegarde externe requise'
  ui_print warning '  (configurations et saves).'
  ui_print info '  ROMs et userdata normalement'
  ui_print info '  conservés par Batocera.'
  ui_print info '  Aucun redémarrage auto.'
  echo
  sys_info_upgrade_battery_guard || return 1
  confirm 'Sauvegarde EXTERNE vérifiée ?' || { ui_print info '  Annulé.'; return 0; }
  confirm "REVENIR à Stable $target_version ?" || { ui_print info '  Annulé.'; return 0; }
  # Contrôle de la batterie ET de la version juste avant la commande système.
  sys_info_upgrade_battery_guard || return 1
  IFS= read -r current_after < /usr/share/batocera/batocera.version || true
  [[ "$current_after" == "$current" ]] || {
    ui_print error '  Build installé a changé.'; return 1;
  }
  ui_print info '  Dernière vérification Stable...'
  sys_info_check_updates stable
  if [[ "$SYS_UPDATE_STATUS" != 'Aucune mise à jour disponible' || "$SYS_UPDATE_WEBVERSION" != "$target" ]]; then
    ui_print error '  Version en ligne changée.'
    ui_print warning '  Opération annulée.'
    return 1
  fi
  relation="$(sys_info_version_relation "$current_after" "$SYS_UPDATE_WEBVERSION")" || relation=unknown
  [[ "$relation" == older ]] || {
    ui_print error '  Cible non antérieure.'; return 1;
  }
  echo
  ui_print warning '  Retour arrière en cours...'
  ui_print warning '  NE PAS interrompre Batocera.'
  # La commande officielle telecharge la derniere Stable pour l'architecture.
  # Aucun changement du canal permanent ni formatage de userdata.
  if [[ -t 0 && -w /dev/tty ]]; then
    /usr/bin/batocera-upgrade --upgrade --type stable </dev/tty >/dev/tty 2>&1 || rc=$?
  else
    /usr/bin/batocera-upgrade --upgrade --type stable || rc=$?
  fi
  echo
  if (( rc == 0 )); then
    ui_print success '  [OK] Retour préparé.'
    ui_print info '  Redémarrer après vérif.'
    SYS_UPDATES_ALL_CHECKED=0
    SYS_UPDATE_CHECKED_AT=''
  else
    ui_print error "  [ERREUR] Code $rc"
    ui_print warning '  Vérifier le système avant'
    ui_print warning '  tout redémarrage.'
  fi
  return 0
}

# Mise a jour Batocera : opt-in explicite, sans modifier updates.type.
# Le canal est passe a --upgrade --type et n'est jamais enregistre dans batocera.conf.
# Une nouvelle verification officielle est obligatoire juste avant l'installation.
sys_info_upgrade_action(){
  local branch="${1:-}" label='' current='' online='' current_major='' online_major=''
  local rc=0
  case "$branch" in
    stable) label=Stable ;;
    butterfly) label=Butterfly ;;
    *) ui_print error '  Canal inconnu.'; return 1 ;;
  esac
  sys_info_update_clear_screen
  ui_section 'INSTALLER MAJ BATOCERA'
  ui_print warning "  Canal : $label"
  ui_print info '  Contrôle officiel en cours...'
  echo
  if [[ $EUID -ne 0 ]]; then
    ui_print error '  Lancer le gestionnaire en root.'
    return 1
  fi
  if [[ ! -x /usr/bin/batocera-upgrade ]]; then
    ui_print error '  batocera-upgrade absent.'
    return 1
  fi
  # Ne jamais autoriser une installation a partir d'un ancien resultat affiche.
  sys_info_check_updates "$branch"
  if [[ "$SYS_UPDATE_STATUS" != 'MISE À JOUR DISPONIBLE' ]]; then
    ui_print warning '  Aucune MAJ confirmée.'
    ui_print info '  Aucun fichier installé.'
    if [[ -n "$SYS_UPDATE_DIAGNOSTIC" ]]; then
      sys_info_mobile_text "$SYS_UPDATE_DIAGNOSTIC" warning
    fi
    return 0
  fi
  online="$SYS_UPDATE_WEBVERSION"
  if [[ -r /usr/share/batocera/batocera.version ]]; then
    IFS= read -r current < /usr/share/batocera/batocera.version || true
  fi
  ui_print info '  Version installée :'
  sys_info_mobile_text "$current" info
  ui_print info '  Version proposée :'
  sys_info_mobile_text "$online" success
  # Interdire une regression de version majeure (par exemple 44 -> stable 43.1).
  # La detection officielle doit de toute facon annoncer MAJ disponible.
  if [[ "$current" =~ ^([0-9]+)([.][0-9]+)? ]] && [[ "$online" =~ ^([0-9]+)([.][0-9]+)? ]]; then
    current_major="${current%%[!0-9]*}"
    online_major="${online%%[!0-9]*}"
    if (( 10#$online_major < 10#$current_major )); then
      ui_print error '  Mise à niveau refusée :'
      ui_print warning '  Version majeure antérieure.'
      return 1
    fi
  fi
  echo
  ui_print warning '  ATTENTION : vraie mise à jour.'
  if sys_info_battery_present; then
    ui_print warning '  Chargeur recommandé.'
  fi
  ui_print warning '  Sauvegarder vos données.'
  ui_print warning '  Garder la session SSH ouverte.'
  ui_print info '  Aucun redémarrage automatique.'
  echo
  # Verifier le seuil avant toute confirmation. Pas de modification systeme ici.
  sys_info_upgrade_battery_guard || return 1
  confirm 'Sauvegardes faites et risques compris ?' || { ui_print info '  Annulé.'; return 0; }
  confirm "INSTALLER la mise a jour $label maintenant ?" || { ui_print info '  Annulé.'; return 0; }
  # Recontroler juste avant l'installation si le niveau a chute pendant la confirmation.
  sys_info_upgrade_battery_guard || return 1
  echo
  ui_print warning '  Installation en cours...'
  ui_print warning '  NE PAS interrompre Batocera.'
  echo
  # Direct au terminal pour l'affichage officiel en temps reel.
  # Le gestionnaire reste ouvert tant que la commande fonctionne.
  if [[ -t 0 && -w /dev/tty ]]; then
    /usr/bin/batocera-upgrade --upgrade --type "$branch" </dev/tty >/dev/tty 2>&1 || rc=$?
  else
    /usr/bin/batocera-upgrade --upgrade --type "$branch" || rc=$?
  fi
  echo
  if (( rc == 0 )); then
    ui_print success '  [OK] Mise à jour préparée.'
    ui_print info '  Redémarrer Batocera après.'
    SYS_UPDATES_ALL_CHECKED=0
    SYS_UPDATE_CHECKED_AT=''
  else
    ui_print error "  [ERREUR] Echec, code $rc"
    ui_print warning '  Ne pas redémarrer avant'
    ui_print warning '  de vérifier le système.'
  fi
  return 0
}

# Un seul ecran pour consulter Stable/Butterfly et, si une MAJ est detectee,
# lancer volontairement son installation. Aucune action sans choix explicite.
sys_info_updates_menu(){
  local choice=''
  sys_info_check_all_updates
  while :; do
    sys_info_check_screen
    echo
    if [[ "${SYS_STABLE_STATUS:-}" == 'MISE À JOUR DISPONIBLE' ]]; then
      ui_item '1) Installer Stable'
    elif sys_info_previous_stable_available; then
      ui_item "1) Retour Stable (${SYS_STABLE_WEBVERSION%% *})"
    else
      ui_item '1) Stable : MAJ indisponible'
    fi
    if [[ "${SYS_BUTTERFLY_STATUS:-}" == 'MISE À JOUR DISPONIBLE' ]]; then
      ui_item '2) Installer Butterfly'
    else
      ui_item '2) Butterfly : MAJ indisponible'
    fi
    ui_item '3) Revérifier les 2 canaux'
    echo
    ui_item '0) Retour'
    ui_item 'Q) Quitter le gestionnaire'
    echo
    choice="$(read_key 'Votre choix : ')" || return 0
    case "$choice" in
      1)
        if [[ "${SYS_STABLE_STATUS:-}" == 'MISE À JOUR DISPONIBLE' ]]; then
          sys_info_upgrade_action stable
          pause
          return 0
        elif sys_info_previous_stable_available; then
          sys_info_downgrade_stable
          pause
          return 0
        else
          ui_print warning '  Aucune version Stable'
          ui_print warning '  antérieure confirmée.'
          pause
        fi ;;
      2)
        if [[ "${SYS_BUTTERFLY_STATUS:-}" != 'MISE À JOUR DISPONIBLE' ]]; then
          ui_print warning '  Aucune MAJ Butterfly confirmée.'
          pause
        else
          sys_info_upgrade_action butterfly
          pause
          return 0
        fi ;;
      3) sys_info_check_all_updates ;;
      0) return 0 ;;
      *) ui_print warning 'Choix invalide.'; sleep 1 ;;
    esac
  done
}

sys_info_menu(){
  local choice
  while :; do
    sys_info_overview
    echo
    ui_item '1) Actualiser'
    ui_item '2) Détails des disques'
    ui_item '3) Vérifier / MAJ Batocera'
    echo
    ui_item '0) Retour'
    ui_item 'Q) Quitter le gestionnaire'
    echo
    choice="$(read_key 'Votre choix : ')" || return 0
    case "$choice" in
      1) continue ;;
      2) sys_info_disks_menu ;;
      3) sys_info_updates_menu ;;
      0) return 0 ;;
      *) ui_print warning 'Choix invalide.'; sleep 1 ;;
    esac
  done
}

# Commandes systeme avec confirmation explicite.
# Les actions destructives sont lancees uniquement apres accord.
batocera_command_menu(){
  local choice
  while :; do
    refresh_screen
    ui_section 'BATOCERA COMMANDE'
    echo
    ui_item '1) Redémarrer Batocera'
    ui_item '2) Eteindre Batocera'
    ui_item '3) Restart EmulationStation'
    ui_item '4) Sauvegarde modifications'
    ui_item '5) Actualiser jeux'
    echo
    echo
    ui_item '0) Retour'
    ui_item 'Q) Quitter le gestionnaire'
    echo
    choice="$(read_key 'Votre choix : ')" || return 0
    case "$choice" in
      0) return 0 ;;
      1)
        if confirm 'Confirmer le redemarrage de Batocera ?'; then
          echo '[ACTION] Redémarrage de Batocera...'
          batocera-es-swissknife --reboot
          echo '[ATTENTION] La commande de redemarrage est revenue au gestionnaire.'
          pause
        fi ;;
      2)
        if confirm 'Confirmer l extinction de Batocera ?'; then
          echo '[ACTION] Extinction de Batocera...'
          batocera-es-swissknife --shutdown
          echo '[ATTENTION] La commande d extinction est revenue au gestionnaire.'
          pause
        fi ;;
      3)
        if confirm 'Confirmer le restart d EmulationStation ?'; then
          echo '[ACTION] Redemarrage d EmulationStation...'
          if batocera-es-swissknife --restart; then
            echo '[OK] Commande de redemarrage envoyee.'
          else
            echo '[ERREUR] Echec du redemarrage d EmulationStation.'
          fi
          pause
        fi ;;
      4)
        if confirm 'Confirmer la sauvegarde des modifications système ?'; then
          if command -v batocera-save-overlay >/dev/null 2>&1; then
            if batocera-save-overlay; then
              echo '[OK] Modifications sauvegardées.'
            else
              echo '[ERREUR] La sauvegarde overlay a échoué.'
            fi
          else
            echo '[ERREUR] Commande batocera-save-overlay introuvable.'
          fi
          pause
        fi ;;
      5)
        # Actualisation de la liste des jeux via l'API locale d'EmulationStation.
        # Même endpoint que : curl -s http://localhost:1234/reloadgames
        if ! command -v curl >/dev/null 2>&1; then
          ui_print error '  [ERREUR] curl est introuvable.'
        elif curl -fsS --connect-timeout 2 --max-time 15 \
          -o /dev/null 'http://localhost:1234/reloadgames'; then
          ui_print success '  [OK] Actualisation des jeux demandée.'
        else
          ui_print error '  [ERREUR] Actualisation impossible : vérifier EmulationStation.'
        fi
        pause ;;
      *) echo '[INFO] Choix invalide.'; sleep 1 ;;
    esac
  done
}


# ============= MODULE 1FICHIER PREMIUM / BATOCERA 44 – DOSSIERS WEB =============
# Intégré au gestionnaire. Web facultatif, jamais lancé automatiquement.
ONEF_DIR='/userdata/system/blondin-1fichier'
ONEF_BIN="$ONEF_DIR/onefichier.py"
ONEF_CFG='/userdata/system/configs/blondin-1fichier'
ONEF_WEB_DIR="$ONEF_CFG/web"
ONEF_DEFAULT='/userdata/roms/flatpak/Telechargements'
onef_installer(){
  local update=0 previous_hash='' was_running=0
  if [[ -f "$ONEF_BIN" && ! -L "$ONEF_BIN" ]]; then
    previous_hash="$(sha256sum "$ONEF_BIN" 2>/dev/null | awk '{print $1}')"
    if [[ "$previous_hash" == '87689ad7c451621f88e935f95f5776dcc9594030f5638f86a7cafd0f758e90a9' && -f "$ONEF_DIR/blondin_firefox_history.py" ]] && grep -q 'firefox_annotation_sources_v101' "$ONEF_DIR/blondin_firefox_history.py" 2>/dev/null; then return 0; fi
    if [[ "$previous_hash" != '87689ad7c451621f88e935f95f5776dcc9594030f5638f86a7cafd0f758e90a9' && "$previous_hash" != '04a97fb61cee040f4107403f102e367491a1397c251846ddff69e46cc07f7d0b' && "$previous_hash" != '66fb083007e1c4c9a74647c63c407f27484531a9e0332f287f7fe236818673b9' && "$previous_hash" != '19faad752f10b8b783c043243c81d60ebc58d72c992fac6b8fb49475e6d93246' && "$previous_hash" != '0efa28b34149d6590ac89e799989f253dc04cba082d9e0d0e9efb8b57327dd0d' && "$previous_hash" != 'c50dfb23db3f55540dc721e40a02cb174eaacbd1e4c3b2349fa25356313645bc' && "$previous_hash" != 'c50dfb23db3f55540dc721e40a02cb174eaacbd1e4c3b2349fa25356313645bc' && "$previous_hash" != '0bf806233d74be06c0a69b0417f865d2b0087372cd5735f5de9dec1450fa7c96' && "$previous_hash" != 'ddeb7b8a5b4023e58d2883f97d2dc53807cd1566fab23a99cbe8c5f6dbaf0b1f' && "$previous_hash" != 'd6fffcf9807f77884b49df653bf91c0e2f269ec10586afdfe81d3c6a5bbe11ce' && "$previous_hash" != '04a71b115fa5b0cdd4a3632e04859caff6b9cb868561a5e8342f89079da08863' && "$previous_hash" != '362baf36ee130a31c1ada992c03d138151a81f0a6341c461b04c41b7e294a7b7' ]]; then
      echo '[ATTENTION] Moteur 1fichier personnalisé ou inconnu : conservé.'
      echo '[INFO] Mise à jour de la connexion Web non appliquée.'
      return 0
    fi
    update=1
    if onef_web_running; then was_running=1; fi
    if ! cp -p "$ONEF_BIN" "$ONEF_BIN.avant-v2.0.102-TEST"; then
      echo '[ERREUR] Sauvegarde du moteur impossible.'; return 1
    fi
  else
    if ! confirm 'Installer le moteur de téléchargement 1fichier sur cet appareil ?'; then return 1; fi
  fi
  mkdir -p "$ONEF_DIR" "$ONEF_DEFAULT" || return 1
  if ! python3 - "$ONEF_BIN" <<'PYONEF_INSTALL'
import base64,gzip,pathlib,sys,os
payload='''H4sIAAAAAAAC/819227kSJbYe30FSz1TJLtSVEqqS3emqHJd1NM1rS4VJPX0jiVtDjPJlFhikjkkUypNloDxgxcwYGBhj4H1Agt4n2yX/WrAD37b+pP+An+CzyUiGCQjU1m9bcM9g1KSEXHixIkT5xYngl/c35gV+cYwTjei9Mqa3pQXWbp9b21t7UWSpWGcWpvjeHQRR7n1No8m8WxirVtFGaRhAOWR9SIos1GUB9ajR9bx3tGxNcnCWRJ5AOBePJlmeWkF+fk0yIuoY4VBGZXxBH6dR+U0KIqOdVGWU6+I8qso71jviiztWBm8ngblRRIPO1YOlYtolEclvC0uZmWcwN/4PA3wb4H/zIbTHHBAaMUN/MM9zPIEAHhRnme5ehJ4iKc8+uMsKkp4nsWhxHbIwx6M4zwaZ+8HF3FRZvmNFRRW49W9e4cHB8eWL5H13sJfxwZ6RjmMNNgAbMposjHK0nF8XmwIyOuSoLZ777cHL44AAMHZsOx32bCw732393vtXTCNvcvoxr73496Lesl1NPTK7DJK7Xuv9r55/sP+8eAVzsBihPJsUmyMkwBof7lxHCXR6AImJ5pEaVkANvvPjxQI2UkSFOV6CFSK06CMs9TDObLvvTg8+PFob4C1cADOsh5tt9PEaBKFcWC77r3nb19Dcxu5oOhtbOBgJXm8UTbZuNrcsO/tv37zHdTKI3w1jZPIye2/lk2cZ73r6+tTz30mG55Sy9Nnzkmw/qfn6/+yu/712UMX6j04+evT4uxL99mvYLD3wmhsxWlcOm7vngX/ZYU3mwTFpdPNuk+fuvQO58ebXIZxDiPMkUz+cT4DDoreAw8Mskt65LpIC290AfwPEJ52u/w2Hlswax7VL6ArepK1nmi1eHq1iuJFrS4hfZ3HZTTAeSCyw4IZvhNjAHabivn3ruPyYpAGk4hqefjLemjZXhpdr9vwC5new38eOa53Eb13FQSPeyij96WD3XjhbDItHOgGBp4WszwaBMUojv1vggSXU5yGQBp/y9VAtIYI5M2jaRKMIgcrMEuIESVZEBKWMGxY6bM8JVHg4fuC0c+jIGSMXNHoKkjicJDE6aUD61kQYAKjR3bxxrMkmQTl6AILvaLM46njKmKnWWlNoK8gLiLrd0Eyi/ZQTjj2fhxpEu/b4+O3RzA86iqyublAUPFsjV+fIWUn3nmezabOpsAUuNqJ0nCaxWlJwkcgKxDBWY4LEDjA2K4JqZfJp48WrpQ0Sy2WJrP808cKoT/CqOsyzTvkvw40e1j1jWvS16Z0bkMzuwf/dKwvv4THIk7Pk8jubd4idrKh79thdp3idGyA5B6Q1PFG57FtRcAB1vzWvXW9KB1lIQyhY00i0CKhb789ODq2QcbD3EV54c8JXfzPfj6DGnn8J5Ipds9+EcHyyi37IRJDm2s5cx3LfpmlJbDZ+vHNFBAEuThN4hG13yCZBFWej0bRtDQV3jKpcE00KQWP2TRKHXhm3ZHNSn+766LEz3sKZSQdkFnxpZMrbsIiD+ji2KAYyxkIPJpX0J3OG9CRgNjBd7ZbgWrPMPyJZjnNcQ+IAIN2KqATUG3BeWR3bJz/Kcz8KC5o+t0aR2ILZrgiGEfET7T88R/ROwkB30L49DMDktuuWpj26Sn0sgFvCqAfdA0/T9Y3z8Qs2JZn15aQhEF/cbi2B+09qIVvg/TGyfLQGbk721vWGN6MsJKGjpkYb7KJFUaWXIRy+eEwMxgnrAWQxUir+oJEuDx8TV05eXAtOgubihGLQN5OwZZBfeUgHYosuQIW1gdJk4GMGORlgQyk6zcYKTQH2PcXal1RZREoUoUby9njVTUgK5iB7UHzb83SGFgYtTfMfVpYqksrm1lSx+pDCVHOoDIzipn9yAqzokCaA7U1IsLrGBp/+vju0z+y5iPjRQMMwj0YoQnmhGi/eT8ODr4z9qGPBLmZW8XDJAJhYwFng+YB/VKf2ZCnlcQC2iMDfYKl5stvdApe+7RGlUXjqjKcJb/BISc2vrXPqlqiZ5ww1lP4MnqP4sVyDo722KqsRtaxUCyJn99FN+IXSYvfHh28eRWhbKS3+kxXvegWnFAbwzy7LiKcr2iE9qbGy19YxxeRBQagqARLK0itLE1ugIyzCdjjZQQGyfeWbBxHBXHhJJuBFAWGzeOrqPAEsNcltseJrFpLPUNEIssa1HaHRBSYo/AiuAI4YJij7o/BELCicuTpTBGDMkFPAQQLYN7BYZJcSCJelrtb3UdfkfiAyvCivi7uWBGCUVN9RQiuoRlur3S5uFGWjUrNcMuzDOy6k2m1/ElYTVFY1excGNdUraAzfago6qhbH4HhmOgvACDjRdiOBFYWUK/L5WBwFZ/zUkniSVzikg9m73FekdgwtwVqMGBLWI9pVNSXJHW8bLm/hDm+AI8OFuJPf/57WBDQpACZIoWAAAftgTg8WsQfLMOJGhg85NyBGkdtIQp8sA3iUtxMyF5z5azLAoEk8Bwsy1lUaw/LPvGp4sIZ1LqSs0GtWrOBb5fNhhkDJIEHJgWYQw4hQipMVWmJhbdRPomBhlkqFnwdLIErwNd0YCH5MBhvFBTgWCah5F/Ez9c4p81qVMPAbPh+6QBFU7RLdBE7ZwnYUwKvY3NN+Qp/u7QC6CfbfWTd1Ehl4+DsHv570tvqds/A+CnzWQq2WBTaPVz6WIZrv9toiU5HMETjs9Im5N9IfdKoTyOyeyeEn7Zk6f3ZLctQ8KjZsH4Xh3WrG7zJykewwVUco5843966BUuSahvWzGsSduM4SMsFbgF59BsW9vfQZmdZiPPZFMMfWIC29jiOklCu/6lfw/OetDdZiU3dPpuYAoJo2q85gh2sIb3aYgAkT8GUd+Sgp3Hoh2xOws+GpIhD5XaRR6cUKqryyzhJHPABHKjmdrrQraiKy09Xi4L9G6DYY83ySzCwqjl4xyOrjZpx0qiExnTk21OwTgNWQ3YHxwFIYfgoDsEtoPCOb4sB1WRPnI4zH10vG7vYwEdyWTrvTsjr0bS9NJX9uuFMTYhm8pXtVo2UXq5ZEwAcH+vQU5BFqvqGBKaZJHmplTuyAjAQFq3bD4EcJ72vNJgwdQRWixcYDTppRFNlYbtJS056GlSmDayI/xT5OOPV+PEVG/VdbVx5BBSjkJwHuuhyMEM3xVEDcT2soYnJGMl07uOYUNezezdA2EKwlGo4LF+6+nipHtowCNXasSbBe6fbwbfrErSRCnvFFHwboS2BK4rZeBwXsILtaiga1ylekD+oCx//6UgnOAp91WWl+NApZoZb4CwbOI+J5XMdIjVWqM0zGe5UDemvBzLRdaUfguZATtToETojHJ6wpaJ1lre7yIpSdwhB0wk7rBaO020ys83yw+G+QDYS0RO00Mbot8UR+W1a9FOC+cJ6lbEkQi8UzUvEA6NEWR7kN3L0CBudEWA1LAdRH1gi8gsKdjJB3gDzIvIUYBV4sH8AG3n9+TkpNPtFIxC7joHrja63ad/qhJdT3JNwTuzDIAVH/My3hzdlVPi8fhQrPLTXbc22/6O/ICbD46niIuJvRZC7whQySvFERCmiYtqyuSRWtGSwhsfBCWSOre6Ten3zZIL8oMj8DHgIJg+smoiNRHLGQS6nYQ5GZGSBaZqA76aCyXbdLJuA6+PbwdCu4UUr3L4e2g1rbxSBa1ItsL6FLp/frdVqa4myFs1uIED0JOqhkOkgPkQ4oGGbDtcXsPBJu7XL8L9hko0ufaIoeqTOZnfr0Zf4j2usLlYwteqBuxYFl8Z6gAvHXR2qSnqWSfHQR7OJ3y7qAjnCm2TQU5bGI8ddR6LtbppH0KCgJtVkl26fiN6EahTHsg0yFr40yeDjAKwIZJpP/2WGong8/vQRzUgMM8D8WiWXB2UJPDWLtOnTwsY0d6ys7i1jBDC+08g2DYvMBzJaAUxcXECR3JLy1I80uwbFFBcZWJRgHTr4sphGI98uwIkHwSiNAGH37NEfCs2AL9ZbglpEUT67woKtF5Ih7klvG8xlGTEOQ4eCsmhLSLuV9ir6KBf8Ruy7T/UIkG6LUGPGFbDwmwF/johWNmTNGuvMbbATe4h9FSNm06aH/3Yqm6hn2x22EHrdjl2RHR8r/qPYKFaO0gHNc4kRTTRGe0QLm4jBwEawSshf+FmzI2K9FE2o7GltoCoq1FF+Dw7ptmbIQ0MRTFVwRBxxoe0aN01v00poiEppjAUj8Csquzw8EfQ68yuW/hx43EbFRKpNUu8tCcKT4qYAaysazcjp6qhQlwqaDGh4g4EWFsUw/ICNeTBm4vCsY5YvRQnq1df6fLX3uzc/7O/DQghRb5lLgAHMJUD/QRpdD4qInGrh+NPkjDC8lPy82dHsjwOMnBUge8TWMhhz1tvXrzh2UbcuYHAgq6xYeIJRYZUXcYGOpl0IR6cyQHCloyUN04mcrhl+rTDJaBL6zW1UJIXtbtDUwDg2bKiEOFDIPggHZIU4Vfx+aJ927Q7oWagQUsTRoVUFloqoYrcCJnJCLfIy0KqCTirPb4rii2jiHb3+zfHe4feLAx9veeb2s+xyNpWhD9zmX+DZAWUQvcl0VslEMa8Y1VQbs8AxWgCKnHwMn0ShQ/uz50k2dOwvhbPdyaMrMKYi5pIlcal30rtuUuSdWnu8p9EwLTo1j7QK7mvM9c5tK94Kam3g/XeCNWj0/ZpL/66OGloIIgr1bvEkVMJBJ74QagDintwjSSLoCTfU8UfoxGGB2RaT7Io94IJ3d8VI1tbWXlELWCUJWvehpZqC9gaLHHRsloccZc5IHwYJLKryIopzQBLkG7nZBWWGVPpsQcAYsUnAAFSRwu4OGkHw2t3xt7rdZXHTIxCJgCJqZLV35IC3GE9mEzB9u24lZsubaeTog3YBCbbXsiwxydvvYVG1Qz/FLClrUVKxlMJ4VIIXnE3ApykI+yUMSQHkdiBI40wZ023FUWWB2ENewbb/BlwfMLiGBVlh2aweSW/KCblW1FZIw7rVZu5dBwdNmL1jjxbjTfd9pEj1jpcCvFbKjVy65UtoBe2Ho5CqD0elq1UNZ33K2/0IfYD7J5joE5xLQxcaobIUuycd8IpA1FhBPoxLclSbqT+eYQjXviAB2VJtg968eYJ7J3ftpzW4shbB/pz9kBq+Ym9kaXpPZSB0zHk+VYWzRePFsHbYjmiHK+2dLGeSo9kUJDaZDhZJ3hBkrHUBapG3UjYW7aTo/xnCg+8Wxwb1wQUckGnV7t299Q2OKpgYyohr8OjgzcE3B/v7Bz/yFnScD8YhBkRKDJYE5wEykAWiYpgl8Qhtl8sC7ZoMRHIuZHEL7DgJzguMsB4MDl8dvNn//QfAGsz13MmKjl11aXe6bqvozYv9g5ffYVEbboh7PAiYrE/eJZZ9WB+sOqhXrw/3Xh4fHP4eYbVKdRzaPbXEaoWC6p7CejTUDpPNZ/zM7vVCiDTDnDWI8mxxHYxEQ99jCnqOQ3dhzej9lJQrGY3vlsReF6wi7MA7Grw+Otz7DYdvi3JA4Y7eAh0gN1FBd4MciXOT9NB38gTMFNnpvr+5DCx4IdNkVsTg8xbAflFaWD1wRKrFmEfjmUHZtAJZTJMdv8thP8YAyXLfl4VLgg56tOGz+x/Nctovg9mjySPOqfFMZ5wlSXYtdbI0m5aNSADFUcRpdt+XQ4IHHKFWHEZXVTE8LObDxVpeFyQWWo+4eZUE1hUQBV6OhB27EDLmRdJ0GwZvbkUxmoS3j0ZJVkRGnjfVasMky0b07zYihWR1SZNYi1dkl3YP1dntKlZyp0rckHkbFBuEFr3P6I9TIWUQg8PCI/ekt/mke1YPLAg4wn8VWRbKapNRHs559kWetCf+armAKkkRTFvQXsDGLu7oqIy5WgoTAaPg/mlqk/+kvcm1NwvTD6/QigaDqmFkYLqeli3KQB5iL27fmOk6zVG0McwozaNzMPIxl9FKslGQsBHnTNUGemFhS0/uocoMbDYKBuA4KS8R3IpD4eSg8TYJcD+cHVLQ7NkYPRH4A1SLwb9Hk+kqsr5heBbZWknCGc7SQRkG4EXekdstEFqfZH8CYSPTrcbZLA11dwCQBfNQZE20HHxTGoWYOWpI+QZg3oNLH0+CBKq10hRaOgoNTYdaL4wacI4fxQyMRj2A0LJzTrpnPWN2BNjeYCEGMuBgz8rx+lfgJauIA1EgILsNIALw4KwVhFgfcXYnEYS2dgAqsec6z/WLWZyEr1+pMjMu0ftIjRp+2+7KOSNQGx2oPEqIMwZl5uD8k97FMjLjZFanLabd7shf68MYWN6M1BeKzYgp9aAbAryIEuD3ile9JnpoGr9XNEFivmcs1tF99XH/NS5vABd+Pp/O1gUwMEnNKBGDqpQWWJAVn7krCc1WikutG5nXxkGaAqwY6tBtrGJ0qEBy8L6UU2UqFL5xnTdyFoqeyl0RTqOSwuj1wRzKUHQhCm5FuttLkCtRfkUT3SMKW7TRjr5/GJVkUEjnjp1JTIiTk8hYJzc8T9yV3zga4slnLnbceq6NwpcOExjQxeiDw6+Fs6jKXFektpDOHNRpmdw4KkPwJQi0KGRpyL79BYYsKROH9U4O7pmFOdqe3IAF8WYdvf7Nd6/390UqH5u35QVKDkC5yqL+Bmz0bw7+avByH9hjgIZ/JYB4Rv0F83zPYLTOihNFlbNqYqUm77SmWCZF92w5L5jBJoLfY5i0Tx+9+nau7KZFbeivbTjRZifoZWUkgnJtbnMqloBukWuwS1eP/S5j5BYzG4w3ho7mubEHioZyoIlA3Gt6LasEcbWF3o7f9lQAkaIIwAOoSFr7gg+f3KvvnjYr7MimPZPsXaLV9f/E2mqtNYwTygfHEML4OcwkOMj6lsBimjXASWaY3i56QnbGZDWJhQxrwbsOaZnb+nQgRYokiqaOt/W4lWg8143IhnhoYwdKjYJ2IKBKz3o+G83SiFBmlgW+GAHHIv/fay9TfzDgVT0YOGtqYa+53n42QhubM7aioYPqpmaV1tIQodAbQf/SRKAXl9GNOdU0L9nVwLzVEdp+nBySDRNMcc1gXIU1zWaYHCxOEFo/RkOZ1kWZNeI8lOFwiOH4FGcXiIODfEpuMMsTDOA421u1kSw6eKWZtdReWLXGc1nkKiawVqxvgzRMotzRzjV6L8CQwPGK/A9RReNwPgN1PhAzDRozGXe+DPQAvqyGm1RcLgSafvxLS1EY+o2TW+2DW9WJnVpjBO5hNwPMcUBV6XBPbr8q4pQVp34op9M6d9O3UFqCAeCzVbioJwUuGF1E6wg0zxI68LKOqwsMOUPff7Wu975+QJsOBbUqUnD67+5NNN+P0vPywsYgqyNSLYauK7qsGgBz8KtrDJ5VyRpDtzZDqGhphlyjsJM8idsnIO/A4z3HnCACLPphWVI/ItWx8RhldU6KWNIgJNUonUfdzc5c7ao/F+pfOvyYnzSDdWrfuv1W7mdDOKlMTznEMBv8Zu94wSAJA06GtzdsgxgvJ4lv79wPsxHaq/S8e5ru4F8rCdJzf22cr+3uIDF2d0CkBYqJ1oiL1sRbCsmuXcXRNUqzNUu4EP7adRzSGY+reBSt00MHBRj4fesFOpn+5hp2WMZlEu0uOua8s8HlULEob+jHl/MhWPpF/CdMChtmOczVOry5HWbhzXwMvYO3P30vjkqsz+JOEaTFOgiBeNyfBO8Zld7Tre70PTzn53Haw9+07dKfBiHK4d7mIygdBqNLPEOYhr0vNh9tDre2+qMsAX38xXgb/3d7ml5szeWrx6Mnj8M+Sqp18M3P094Ig115H1Fap5Scrc3p+9skGEbJPIzB7wtuepRPJNEgvLvWY6h1CqpnOis7w1kJypuHFacXMIiywnGrGsFjbNnnoW12u7/uC8LkoFZmRe9pBXKuj2rr0fbmdiRGBUZDGYmGvU0kYZaAXfPF40dPHj993AcDXNCuC7AEYjowQQFBj83H+D8JrstkuI7i84uyB9K6P5rlBZo2GW0GKIgeJ5AE+U0d0Sfb0eNtRf7x2ITn9pOvnn6tIPWAxujfhfNsGozAN+t5jx7fegHtSRZqBs7zOOzjP+uY6gh+ZwRecDKbpEVvc4yJknn/PJj2viYKfoHnA0A2zJGRLngwW0+RkzJQMeMku+4RG7WRe/QIyPioMS1fQUM5m09rHViCvho7JdG4rLHk1tb29qOKJo/wf5IftokfFKd0Gbg4pqTGnuJm9yJCNnBFGCbWWy8zRR0RM51LYqxf50A68JyvgXMlm33xdRhuj8cS068Q09tpHs2J/9YpT7gHz9S4vwBUbWmGW0+3N2uDbdMZ0Csm4IvJ5Rp8DSC+vv0C9//m1RLFdQ88AmKate1cx7LGw0+7Xa6YXUqYjx+HT58G/HYYhEoyjJ88fgKcBxItmgw18o+T6H2fJncdD7QUUmIIfqtTSDW3eBnzUiRuE/UEPjDH9R4QHHGALJbMhaW9TZy4d9lwHwyvuTalTAkoGAV5ODfQe0Uer/PNo2pYWIDjgi5Qh8wbxF0w81QfFU9j0iRzDcejKBzqvPlUjENMaKNZs1dDwxBWSXOK4TXp9GqOn8J/9J4927pauPWmeXaOOx5zITU2N01cWuPrbRS8jyvJchGHYZTqGPKsStDDIFfQSQVosBhvoSCgrMxBKcYoCXv0zvK2ilvw4a6iC5DHOpG2K9rWF642fyA4y5v5sjX5yDhaOWdPR8MwBD70wK1qjoJR3n5cH4/QNUEaT8iQ6kFLTCawNr0nhRWBqb8ONMpmGCnELNMyuv0X4BaNc+A0jN5R5Xn313MiBGYx9ugXyv+/ctY3N7u/dm+xf3OF7S6W3+5ssFGys8FmEpogZERt7f70H/+19WL/4M2r12+sn/78l/b9LVABmm1hdTIJ0F/018igXNv9bVRiuOHUDkajT/+1QC9sZ4Oq7e7Q8rfiUFam9Bl/DX2Ua6DwGhkyMi3IX8vG4zVO6b8g1eKvGYCvVWiQA+WvSWmzJjvkXsAxGF2CtbVGCFSVrO8/fZxg1gpucwVoBKbgykE34O5YI3A3wScBmzlO5DCgvzC+IigolY5oca7J3isBbAlhumaBLwII8Nu13Z/+4e/w4JsKqOG+2s4GgETILN8kMGVRMNLg4gFfvCgV5bj22u4Rnckh1Ecghnc2uKAxQ+C/ru3WLqgwzAxWqhPdfE+F53livoJpXIIq+JOYsUanqKXWdl8Zz4UbuqfqeDXHDMCtdvGMGQ2rmEZJQpMO/gB6Jmty5uRMsTkFbLKU6Gx5INF3//d/+su/sl5eZHER59pBV0Xu5YDA8QlmCU2fogceaIGZg4KygrIaLwSFABXh0ZhcHb2ncH6BLFUxQSHT2dR48jV2TPIsPd81DUkU7UypkTCPgFYb059HRrELgxj/9Df/ztIIAK9XpODoIsvEVPz0D3+xfqCR4tn1qD0VkoifjynyGvWByT0rYkZ5SjwdIhVowzp6ZcYG6wtbeU2U7JCBt3vXgW383Uw18qy3GPaakTzJqxsYVCoenrSn2S0Qezqw7cH0UoeA0YbgDY3hEEFKmuYBgXgMcgwaNMPXK9Imj8ag4y8I2PNROQto0nT2lFRBJf4tKHElTKVWb4rQo1l8FeNNJv+t9AQFwezmmSjOm7WBZ3PQdLIXYTGC2MjjYB27AO4EM7CM1qqJ0leMiBfvQ00QK6g2YTHrfohm12xpJjzZOS0bUxgWXArOiL4QZXz2pz//hxa1C7zgYgRzXajFCQ2nTQwb6khRcPcQZGaUY9JmiDnnLeii75/+/J+1Nd4ATnTTiERMtA+kwqhxEWHUFYELRVGIXTG6WySB94I3C1KyM2DdfSMmGMO7+vQR4WBmg7ydRAul//Q3/17i61kiTafMMHZuBbhDf4Erp4jV/koSiCOEJaYgQEFSnUybzoaY3iY3tLTTROGMso5g/mb5KFq0aAycckj7VXfyyuZXvxSvYOQq//Q/AOdP/4gSgvI+F7IJo4eMEhn4RMIVuwOCGTTRIKC8TIQsNiz7unVCe2G5nIyaXiKC/pBGkvws/HAnLgWewGg2NPIsw25aiVlIyAtLuRmFXlltfgmWy/COqhKP76GNMpklAe0f4D6ZllJSWNMIaADtQczkdH4xBKZdgQ3Els5zoW8kH/xiYkJbCcbR6zO/TP8hrsCTY4Z3s9JktsOcDSWgscjnwG1yR1tl1mC+DdIoMa6wtd06t4sGC+UiMviCTnRx18JHIxwjA/1KRV6dIEjRIquuWUp06SjzzCue+tnWFTR+KY9TGPyDY3QnCx2pVS2uJAryo0i0M0AG62AB3JWsWD5FciSOhJg8G0y3jFF8gFyuejJZDwzrVRyAm2SWvYb4sSGE+NgQQvxajwRttyKINWNaKBLGuMoW1RflKv4q9pytiU0KHhueHVHOkRAyaxb5OFG4qyvIiuU0r/WX6HWYlRdrta4eagxdCSJgC63nqTZBPwY5bk6rGVJhqOH2cBv8U32FFDz7KIvxADno4RzlOR4hZ5mMd9nNpp8+5ryKfubqYcRe0lFAAw8+B2MlMSwZrSnPuaGt4ob2wtDESl2TjPJ4WsKvUxvTaTjx7NTun6aANGhGcdOXf7rixaxa0yjxAendMBvNsAj3Cfc4Z/LFzWs8wuWqqkfHB4fPf7M3+G7v99CTuHrWQ6EnogDX0ZBvnbjapB7Gs5Q1IF3sdYxFjjsv85u52AWkBM0jPg+DPb8uo4mjdeN++HBqn9q3I7pRZ+DKdvTyVusAdDY013uogeazOS3oFdwaMMSWQRGHG+AVbVQ7XFdufJaYK9xEm2IOta5ktChyskt3HiXOqV0FkE5t18MtE7Gn7GeXz05t9HKfa2GiU7uHL9vxI5gBAzzi9je4lLlExKVO7YcOgec9AAIqYlXQCjAOipt0ZCm8r3AD8kbS+zS1LGYRkWJMHRMrYJ9EGQ94duIgM+GOrnOfa7rzigJEHbdfm8p+jXLYFuciuA7i0hK3WEBP6MyNI3ALwDyEDvsVTJwG7pN6JbykmCNysKB054SSmneBnCuTJ05tmPnRJZ7aIj7A62ljTGSgWwZ76Du8ozhkSk5EQOJoIoKInz56TENKi8IckvoQuUDjG3wheCfK8ztJVCH5UgUqezij0NgThS1Cwv9BSvE9GEJ6dMTFf5hHLN+ptf/2YH9/8P0RnpPs9rktOMjJMephH2Rh0rHi4pDderyQZ8zX+GJjTE0F02qPTw13FchJFGD6CAkkP42ure+DKZEDgcsjocqEoRpHUalqCLvseyOUDnqnMLajUZD6XXx6C9gqxHTZhFeORLmwNZ9zbiVdfIVszZiWKDgFVzdcX2Q3LpYnpl9exEmYy5llACox0H+e58GNFxf0ly9kVYXus/pz7+QMQTS7PaWEfFCUnrBkfNXCSyjt5BlJ5xEvYzRzSBoLXNLs2n8FzMTXHnTQFkHhopMXGdTh2piWgpnuFZLaase75o5gXafndL+UF4cfPtAPSvrtqHtXvscDF3y30psZLj2uXl3rAHK+ywtBoOPhbRUAnl9yb7h15ys9xfc5CFWFYi4vYzBNcT6wYk3QiX0/poIkAxYthAYaGCFRknwDEr4DSFSkS2c1cNRZxwvSOqEhYcdp0sQqfJeuhhmfZL8LNarVxE1Ic7VvJ0bMdVvI4vykJeqUv/tba09EkixnmkNzkGsuq5a/+7cWrQqMPVa3RWMqY2QaDfWlD4evNbprOFSrORzcGa1NGgV0fJ2H6I3buQRmTnlUuNE34GffR3H64AE3gFX3DW2eOdzowQP6u9uVP9SdLtQjY6QT7dQ+xMtmWLjyXSFH0Jmjbrh56FC/QFFro1GHuwR6Wv/0PxvhqTil2FfFujo5CQudnEATkLh3kZNq1cgp91Vr9JxGObIAKAifMeeVGqfOZrfboQfyjdQQNwjnL6HUdXso9gkY9wZG0fMSpAEYtREtSAylorl/anckXY5p/xFTPGU0hohZ4fEQKPRrYrxW1Q5Z+6KepBoOVuO14G7SQB2NMBIxbduZeue9W0EsMA6onjvHxix7OSGshjjg3TeSAmPPQIRGL25/Md3IZIIuoZUQsFVP7p0NYQKpu+4KnYBYprowpdJK4RY1LgxyA29SPZ38ILyv4qzK0td1MyUgkkQn9T6NQC90JXVlwwcPJKPtylcerYAHD4AY1TvMfGZFJHrmg+2lrxh1vd7eRZbtbjgAZb0Ohc0vxkeV0ONu91n9xZfeo4eioy+9Jz3xkwAQ3UyjLnjUnTmh0VO3RmHfPcCmQ5BvGysc3LtilTWO9ZYITVlDF2JyaKf270AUFmCN4ubrhE8j1GUWVXWBsTcK9A9oCUhZKQfyjCXaYUS00EG8Evc8Oyz71pWU3GC4PXTi8F+JRw93M8Q1TrgrnGK4OeFNgjQFBAuTvhFjZAIKS0wvxwZUeFuza+hCwLFxyuheDddFj0BaIxdBQbzrmuqzv6+sFWzXNMjcuZxassYXT+2UJ5ZqNSeW8lJIxHBxXTVRxv7i4yRi20VGvRdvwEAHBipKN+LWYI+andWWTdp8gZJeBA6cwpVXMwJYfFKI4gPwV0G7e2UG0ovR3rI4YINMATzEu39ysHRDBzYLxN4i7yEsaN4nb6jh4IodyrpbQCIH5rdyJz58UFPJCU0fPtxf7Py67ISxha08ErRR8BXHRdrOSMvblecDpY3n0rRoDuPdHoNyC1abzCaBG+5v3dekhcYHsedNx4s9T3bg8LAZFAiY0mOsbUg1nbalk8RNqkkyAPr502XCSp+4SnzTJcsL56yQ9CV5pVOfYRucO/QJxfGdBY6dAQ7FC1prEkE1z6o9a3srrRXY004C6XPvESL17UFcd1XtaSY+xRBMc0zP0jf1PAP2cgsRUZcpz/79+0bMP3yosxBJeRVzW4W2kog1ll3IgMy8i7DN0lESjy594lHH9XcFH9Zx1HgKFYUgB0Cs74hSppn6Dtqz2hYlxj6WbVHmlA6Ce5w//fnva/uU1gIlkUb8OQ6uLHMKMGqlodtYrsT8d86ceYmA7rkGJ2bhIqFjqGCVzvmjP8BieKIUXmBKYg+/fUHHtNLzeHzjzAUNexRydYUpJYNi3JUUTeiav4rw3j2yMCo2VQc+06vsBs+5yRUqcdQFzbfyXKDGcCR3q0jcNy3IrYicznMmUdg3dS1lHLKiiIOpO9Neh0UrSCZ2hI6DIfA6RuqBiIrB6XI1/+RMvpF7bjUoMgxENWhXsxYH07c7gWYd7EOr1dwRZbIKmKDhkmSxLcSbI9iCa3q0jVK9l691M0nt4lTFdT3W3vbU9kKIi6NlPmQNJ6prwooLluAlWtYwa26b1vHim/JWRIwrmzATJUtQk20b2t+45dogHR+xu9tx0erW9yN4a06QSNYQNwrwbHYk8ZCNdKbUqsmWHTUaV4/31pj9BdEGzP15NfRK7TTWBYWWPpdGloMekQEQ2L8uaR7Bp1J/kOpYtCLra9ebBFPnvb/73sMbSfs141EJKZQTiuWWdeLRzr6zDE7D/uLkS1mjDIZke2kyB16hjFRCoaF+odj3lWBaYNzUZtncfiyDqwtAgKZtVXXvkuxS1dezYXRNj0Ssk0AOBdsbpOQK7Sv8Fu5RKCSXblBo+Sp37VFUXjF9iKdyiwWb6SH/XzYILxPwF0OkRASCJ6pKqSafMSYgi/TIHO1fZnqp2Ovzm2yPzj1/NCgUYRjZAibqAm/n5+WCtlwDltuEhdsWChbv9TVqiGiBqmQWR7d60BvPjC6mEKeQ0BxjxZpUUl8WQsNHXNxVmwAMFq0SaAruDM3jRbzcH/56hgILd5kcEaxXJe4GRuLAL8n26XYmEd4Evs3XvznkiFAVvgpqw2EofKpebIUfi4QpDhnLWzodvoQU0zU5ORokLQay0DfBUBbBoW9w0N4lukAckq9i8T0tEKaqu+5Dh4anQOETR7KYFlV4SjFLh+alg6Nx+3dFqNApaAj5egiJokB3BJCozqLwEReagkcXVQZPZQ8rx2JBZIjACWPWxMkrRFdqAq3uKfDFZos9BaFryKqom7X1jVaG44kLhd1n9Wex0Wot0ronnuc1ys7gRVIiY4f+bmPCimwSObm/m8MCB6WDurnt7tdyEJuOukCPrv4AXqsld1LkCjfqehy/47MeWoaUTFEFNwda5J7IEPmLnqElA2OUJoKomTVM08FZeQA1nFeNGrEtJIwrozsttBR6LYYp6ePiiasVo/muLOzwmyHXgEV2jccMgXGd09pNrpWvtmn5Orkwj91yxKkct2Nt1YurfDfeShHSANChLlnI1D1/LLiPBglUfvBAPW1BU5GpoaV1XGTxe5p5DdeUlhFJK+msij2wDLSf6JcAyliDGLkMOWC9Z7rZisOjOw2uDImpmmuCMYYI2QsFK96ugsyIl31hiN56Ruz2vSrUimowiHWt5Kc//70mdkBe480VWAODGwhMD0GgbFhNLrCWXTmEgFeD1+5vRuLIWIKQu5y+ogQHX9wohADY4PfBXLisknEW1qNqWghcUAejbCq1EZ881FPcaZXVYX36N6hVCrV6sFQ5AfTseu+yOAVa9C2pTFn6LLL2f2aEw7xu2jEOtGQ0S5Zv7Oc1XjlfJFdaib/1GGArI4jdscVNV3fPzKCVg8ZpdPV06qYdP1+csKQHaNy+0ty4Pm4Y5SwHBxD68IQ6WyfTAbsAI2QvQOL7u5EyYNvoogkbcewaJttI41vpkrTyt+8eiuKVXwB5kcK2HEfjfNZw5BRC07RJeaEB4gRwU/hXeIuNjlXab7PblWAqv1OHqLKBF4aKG8qtNbizvqbFzBMh/aWTVq72WU/QX+1xqERMo8I0KQylU1A4kq+9XHfAwopNu32kPVBr6AYnq4298Ri807zdVOmQts5o6AhlQN5lQjJ11tXq/PnKokEYFYO2VlEdYCfez0l1cJPlCoSsyn++Avk5+oMvglogGD5nYdQUzm+zYSFyYO/WMyvoF2CLqdi0cSirV2Wp3hdm2JxwPubP3VXFbr+ez1rPCAei4QVyFWROq9P6kqumscGoc2bVQRGVEgFa/vWu+zptKIP5tiPyb4U7pee966kW4ntVjB4u4Wbmm6zw4YP4tdN1VU79yyAZgZ0r938MmXeUETaK4kQB6lgX/HacZCCAqNrGNl5g17EmrZJfY8nGEywEAD6/e9IVHgihcfHsD7+aX9xaF9av5iI2MHG9aRAe0TeztkRa060Fnv4fehOsPaGHqj6ANrYo/tCD2lCKPxuE5L1FoDh+5kkl7J+cap8WI9te/619s0c8f/pYe1H/yg+/auy90UvoQ1D8zItBN8zCqHDEYAAduiY+4qMQHDi5jvKXQYFfz7qtcb9cNuLcAq3KSXHetIYwhJaNxfkdFFws3UCm06umxKOXHUry3nJNzjzLVP6wMt+Y589v9agh37Zo2GnXOAxaQjPQfAJER9xc15uf1u+tI00hLq07FbfWdU5r1wby+YXGxYF4ZKRfCy3QTYRCM4wjFD5yDCKfCLfQcOu5j0qltrHPben7UI52joRvJOIrKk/tQ+AHrIZ+jTxbLC87l8l2sEoVNHHHre8/6m7elfYvG99XrUEt6N3TljmJ9A8fAJc9+lAg3ZGJVGv0KUS8YHsasilug9vub0E6FUICVg6ZOeuhcS6DThsQXvjrwwd5yEBoD4pUM1/4WOGWI2oGpfAWVhp/gAEgm9VCC3c+3MDfG5qbDAXzEPDT4s/o6kHshC63/OHwNWpA0GYpc71SkNoBChomFvLoxG0ZxowMqiWPh2AMT96LUXeARF0sW1hbN1a1+g8eiNFr71wdiLpGw9Cl/Ii6Xl9cVnFqu+YtBb5J2KlS7ekMAZ1uwE+1C7qrtF1yAFbZ3BTX6jV3NuXrmsdHV7PApGH3fdmhqKnTqU4aTHkWn77bOD3d+NVGh8QuZkEKWK4C1iRFLWWWOpJ1b9URJOpGfb5eRnXTbNnmLp0EpvMIWWvb8TldbkAnk/h+EDzvv9XtqsQ+leRlxhNBVoeTkNh8GcwSb0k7cdQ81Sx77VjTWVxY//TfTTeyWP/0v1R+hdno0249WbC4NVQNrC+mtC1XPLrEpPgRv0PdPCwJlT58uLMJXesCrOA+a1ftGUBWfqC86qflyxrEX00yLpkRkb4kOxE3AK3SA1b9XPDiGpwF1F4yeHkXzuKWVENrURNId42lErufOyJ5p81ir/wuFReEq3uOszzpUbfwQ2HfwbH02qPS3EjSm+0a2jpsnTdKgnTEBw9N/tZizSrMhEWeVsPxoN0xTrDXrL1UntDRDq+YnJEU1luqOyCtTTjZNN2hj2GLiim6vVnNPZkBwMIHc/27jCzq7/nPb/jPMfw5o3MHV37aif31TWoaZvOrDR8h9+OHD2/pmnnnapfePHgQ7xBQ4Tuvb9YspKuF+5edufgs5Dc557O8is8BTG/rljYggawE9iQ+M7tyaO/ht/SUC4cP2rHn5par2mjFejqKitpvgje0aYknMNDJBK/hGUKiLyEvGQcWH+HyAa4uwPxGXwWPLTTe3TZ9Ut5KIkZT5ygNeQrizqW7khNESzzcZjo8ie/FuUn8KXfykHD4/P9u87SVVLnq1mlfPwerAip60Fi9XBx/MYZT24enqwOGMxocOFziW5na7jlOs/hZfxvQpQfw7rX61qx8S1Vrr6vv0TZL+JPlPSlr8I3wf/GdCj506t5zry3ksE7jlbmW7pj32HvQ/HTNjW8XCn+fMauc/yoq0CjRPcz6SVuSP0F681x83UWktFvmBE5iXhH0e+fvvuMYADnrYsZw33Djr0+C9XF3/euz+fbW7a82gDML/MgfHsTlyB1F9wgApYhR2GrhToU57qzvdNfYkhJnaHPbzH61g2GYj9HMUNWdBBgw+gi0nmtu2S+VcURCoYU/hldwDA2PZDRcJSVpaEpGGtZwaGyKYDHbLNwxVV+6rSMQVD7HaLggzUm+52toDvHOWSj9aiqQWnY6s2nHj6rPhZZq+ddQaGdGqXG47XFgVpQch/iIRrOKSIuStRZuDwkMmqfARsOGp1WdXl/poLesuOCwt/BoZSVd/iPGskDLssIoaj0e2D66JpvVdwt4oZuif40jr1bjcgHjQXsEYDpnr3rDJChzM9pMazXA+6PR0FJSqCN/I5No8Utx6LwWraxBEp+5qkde+5WEVL8+fOA6tdba0WVEdLe78OxyNfwNrCkOLzs4kGfwm44xt6dgdnces9gUocoLTuLjHgx1RC9Dcj56lSiPhAbkYgrWUehSO8Df6KaWDicgY27PIrB4M4w4x/+3uKHz0NG0/4lhjs4+fOAj/A+1I8e+ypMjWCL3rXVqW1HRdCnArKgT+Rc4yP4LHbauxOBb0QTN2HBmtYP12l0y1ejVztL/p+e5f/7p+AYR+83j79ooUFDUzsB/1vlxJV0ivGjz7qUn6i3JSrUkrPqSQQnwTHNeNdn40HBtA8nAnrk+rBDNZ2M9kMbFRQTGFz4x6qFbJYuuVF3LJjWsJDGoOtW0e1hYgTJEXS0hyMoKq1+vQuzM8qZpB6kT/RPjUX5ZuTrSLxs84yPzwBWqUu2cf0XHncZJff1qAHVj0oK2K98SoA1JXRVQgfnMywL4o0jmGwOc1pUBj6s7Ax4/dmu3Bmj2ilW7Dql5bUCFqvnigJpU/YUuD2CcVrlA4I57A0g9VyNY5cYAbLKuLbVFVwYA2+G58YK+XsfQRsZNbONaql0dADNBnDZZcrSfmbitZx88wOXG6RNzlfNx5xxgfM1Af6syBaiKTnxtlYtsjSKJRxEYbptfdQ0iFqN7gsOWZZ6L+yuatyNMDNcizLV7EaQTRVcjLCLcrRaTUibdsqxwihyhV4OnhEciYUyGw/RLxmr5SvrlY/LU6YpbfGiuNY1qYZw2Y1lanfa1ZmoLRV5a3tztY6CwAJ7X7iWQY8VsJuMdBZzCvSDOxJcd9Bp3HegwgxxvRedTrRUb31ck1q65w4icnh1eHYTVlUQrHUZ4da18GH13ZwHlHj5chXL63XbBTFwH0TiJbhrahw+tDnf9bW3A9ZloX5unRQ4acHa2HzxYcnfA6jSSh4Db9+fxVpcSI6C09zCznyYJ/HTo+you4iF9q5n9cTD91M6FIRmp3bvUrktGMm+lI/XNt2P0F5xVxsWuNnaqq//Ney6m7DBTirLqdNkx6eWFiBje5InBSRixoxJLm2Sbf954a9ladcIaplBNXEUDXGmEeO2aTVfQRkvC6P+i1LrVZ6m6I3NlnBffrmkYDWnbeT2lpepffdamnZxcY2Fj7Lx+PaaBs33aSFmErjx+30y/WW1rsf859070P+OmlkpmvVLf9fn0EUQW3zxa3TZqRZhFi3f8RBjJS3kvHQwVuoZUndhWpr1+OW9fM7RF/liDdLJ0MflI+9bm2sNbaZ3sktkEb7rVebjOvZ+51NC82NkQ9yPvbNA3q3Y26PuftvwWrW36UOyCz9JudbsrfJMWVRN10voYbf+f+QHaRd+Pxc5W/X4s1RWbP+bPxUID+qSs2zPXqn1vFc0jW34/vfoWLFCqM7dFISwKmA13KZzGmb0FIJd/iXu1HthMWbED+RwIVlutC45o3dFF4yP1yyFruXILqS2SSDDWlzsiR2Twau/o2O1Q7gc2DMIB/hxoH9VaOjUiv+Ua81tEuptt+Agwfvu99RL/oxMI/iwHkTzE1LIi4n8Hfyyc2lv8VvYUTBVHde3y8QXXCNdIAha/A8CSDjzcOASAP26MEO3OiW2fuSfdM7cNVXyS3jk4IguuU31OvPMWI9gU96Nn1wrwc0qj3mqYPaLJEZ9FxqmBpu5JD1yys9sFH4yGNo+0Tym/RuEwu8I0O/vWbX4YGXNKln7+eaX1XPsS9EEen8epDQNNwwqIqHIii89qzCG/+kYHphrwvs2A+/CD0gbWMdBrWxs794VpH2CHhSDA7AbRjKzHG/t+nJq+c92UonbXNvCDIF93h2HtPOp+/cT0qXn8xjo4UJHK3TWokmz4jr+OTjdTMUq5uGU3CB2RhmDEoSYFwNhauPpjKMLAHfR1gilE9lkHfvKIcbWztqiJBbe58k19jui4k93jvwwe+jpTCQRNRLJLu3dMty3dCRsgoKgnNvplITfP7ywkmzhCY/e4xUC1cBT14rDAu4vko366x+7wh+1XIWT99OndCDVVkUBQarv/W+jR9Vq2WbZBG9WPOPgFQiIuaKXgzPTa6+Ol/qEm7SNN9mcIdsJpUFecSUvh/wwRqgn+PfpDIQSQ7r1l8hukN2AlpTfl7uc+yj+Pf3vHF7iuwQnBhPojeuc4QX5eeMM4DTv0Cz8h73a+BQmbRDlDGpXv/aJIvKOjfZJR70F6wePbw4Pjg5cH+4Pj/aPB0d7h7/YO3T7UJWkyGEV5OQA7M065B3zmHjC+pmHoFRlY4KWPLfE7wwN+dmqlHX4aFCDIfJxRhjDNUZTaNBxwKhB3uxpGx+4LP6Nnd37ce4EfvLCdBM9o0wcRyAPr0BdZgLZ41yi4Krlr17HDPwPwziKklnvvHqq3CQ5LKA2yE3IfemWL4Xl+Tn74W3rvgIwjOx9m0Ldf8OdH2p+iPQa5J/udDX2GiU7sAB75qUBQpS8unLI7GAuEoYQaOaAuteEGYi3gp+fAarcCv1mMYhuca3oXCKwdktHttyyqU6Stbz+zO8Ko89vC24gJGsRifO9beLSEott/3+geTyvandFFFsM69R2ZoQJKEo8v4mG/ZgsUPxLfh6JrmEXO64cpQIlUEgShSTr24DrLL6McDMkGhpTv0IIvgF63xnMdDWEI140G6+u4BJrzZqgG62OFWrhiq2mwN7eeel3436axZ14YlPcDC0a1+urpk8c8CKKT4Do2hPGNw4U1UwZkLS0wZkOQ0BWT9dRPpxJlUdJqQeaCWLqtHOBR/ukjRghgHYPVQA2BI3lRIxO6S0G39eu9uhSnY7UtnUpA8Igs/eCjsYKzau2Rgei6qTgVsMQ4HPvk4Lszy0byYIUTNArOOFBpn+wdHu79cAjF7kMuRHPipPfV2UPHNjexbFGT5ftZ2w1D1RYkiaM1bWMHnHxT4N1DpbO5lG60Pht2egqt2sN/R9DJdRZjf1eNpwO/aafJpp9yLxdww5bS/kOZAQ/VVhmM76GNFjoX4EYavOoIjc4kIDN92RBqRpuYUNw+JjY7jKb4ZWzwTfAezU8fdTVvgNUwLpvQntPehAK2HJaUKj3+q4Ata4MSpAf/UGWuaTYHBELMYLhoog4S3cdpL8oQ9zD6OgtAT4MBTslggKgNUJENBnaPFdq9/wPk4Xk8BcMAAA=='''
out=pathlib.Path(sys.argv[1]);tmp=out.with_suffix('.new')
try:
    code=gzip.decompress(base64.b64decode(payload))
    compile(code,str(out),'exec')
    tmp.write_bytes(code);tmp.chmod(0o700);os.replace(tmp,out)
except Exception as e:
    print('[ERREUR] Installation du moteur :',e);sys.exit(1)
PYONEF_INSTALL
  then return 1; fi
  # Module Firefox partagé entre le menu local et l'interface Web.
  if ! cat > "$ONEF_DIR/blondin_firefox_history.py" <<'PY_BLONDIN_FFOX'
#!/usr/bin/env python3
"""Historique Firefox partagé CLI/Web, lecture seule du profil Mozilla."""
import argparse, datetime, fcntl, hashlib, ipaddress, json, os, pathlib, re, socket, sqlite3, stat, sys, tempfile, time, urllib.parse, urllib.request, urllib.error

ROOT = pathlib.Path('/userdata/system/configs/blondin-1fichier')
PROFILES = pathlib.Path('/userdata/system/.config/mozilla/firefox')
CACHE = ROOT/'firefox-history.json'
HIDDEN = ROOT/'firefox-hidden.json'
LOCK = ROOT/'firefox-history.lock'
ALLOWED = (pathlib.Path('/userdata/roms'), pathlib.Path('/media'))

def json_read(path, default):
    try:
        if path.is_symlink() or not path.is_file():return default
        return json.loads(path.read_text(encoding='utf-8'))
    except (OSError, ValueError, TypeError):return default

def atomic_json(path,data):
    ROOT.mkdir(mode=0o700,parents=True,exist_ok=True)
    if path.is_symlink():raise ValueError('Fichier de suivi non autorisé')
    fd,name=tempfile.mkstemp(prefix='.firefox-',dir=ROOT)
    try:
        with os.fdopen(fd,'w',encoding='utf-8') as f:json.dump(data,f,ensure_ascii=False)
        os.chmod(name,0o600);os.replace(name,path)
    finally:
        if os.path.exists(name):os.unlink(name)

def scan_profile(db):
    query='''SELECT n.place_id,a.name,n.content,n.dateAdded FROM moz_annos n
        JOIN moz_anno_attributes a ON a.id=n.anno_attribute_id
        WHERE a.name IN ('downloads/destinationFileURI','downloads/metaData')
        ORDER BY n.dateAdded DESC LIMIT 3000'''
    uri='file:'+urllib.parse.quote(str(db),safe='/')
    old=False
    try:
        con=sqlite3.connect(uri+'?mode=ro',uri=True,timeout=1.2)
        try: rows=con.execute(query).fetchall()
        finally:con.close()
    except sqlite3.Error:
        # Snapshot checkpointé : les ajouts encore dans le WAL peuvent manquer.
        old=True
        con=sqlite3.connect(uri+'?mode=ro&immutable=1',uri=True,timeout=.3)
        try:rows=con.execute(query).fetchall()
        finally:con.close()
    combined={}
    for place_id,attr,val,added in rows:
        item=combined.setdefault(place_id,{'uri':'','meta':{},'date':0})
        item['date']=max(item['date'],int(added or 0))
        if attr=='downloads/destinationFileURI':item['uri']=str(val)
        elif attr=='downloads/metaData':
            try:item['meta']=json.loads(val)
            except (TypeError,ValueError):pass
    result=[]
    for place_id,obj in combined.items():
        if obj['meta'].get('state') not in (1,'1'):continue
        target=urllib.parse.urlparse(obj['uri'])
        if target.scheme!='file' or target.netloc not in ('','localhost'):continue
        raw=urllib.parse.unquote(target.path)
        path=pathlib.Path(raw)
        if not path.is_absolute() or not path.name or path.name in ('.','..'):continue
        ident=hashlib.sha256((str(db.parent)+'\0'+str(place_id)+'\0'+raw).encode()).hexdigest()
        size=None
        try:
            if path.is_file() and not path.is_symlink():size=path.stat().st_size
        except OSError:pass
        result.append({'id':ident,'name':path.name,'path':raw,'date':obj['date'],
                       'size':size,'exists':size is not None})
    return result,old

def _list_locked():
    cached=json_read(CACHE,{'records':[],'stale':True})
    old=False
    rows=[];failures=0;found=0
    try:profiles=list(PROFILES.iterdir())[:24]
    except OSError:profiles=[]
    for profile in profiles:
        if profile.is_symlink() or not profile.is_dir():continue
        db=profile/'places.sqlite'
        if db.is_symlink() or not db.is_file():continue
        found+=1
        try:
            records,stale=scan_profile(db)
            rows.extend(records)
            old=old or stale
        except (sqlite3.Error,OSError,ValueError):failures+=1
    if not failures and found and not old:
        atomic_json(CACHE,{'records':rows,'stale':False,'saved_at':int(time.time())})
        records=rows;stale=False
    elif not failures and found and rows:
        records=rows;stale=True
    else:
        records=cached.get('records',[]);stale=True
    hidden=set(json_read(HIDDEN,{'ids':[]}).get('ids',[]))
    records=[r for r in records if r.get('id') not in hidden]
    # Deduplicate ids and stable chronological sort.
    records=list({r['id']:r for r in records if isinstance(r,dict) and 'id' in r}.values())
    records.sort(key=lambda x:int(x.get('date') or 0),reverse=True)
    return {'records':records,'stale':stale,'available':bool(found or cached.get('records')),
            'updated':cached.get('saved_at')}

def list_history():
    ROOT.mkdir(parents=True,exist_ok=True)
    with LOCK.open('a+') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        return _list_locked()

# En cours : simple observation des fichiers temporaires Firefox.
# Aucun fichier .part n'est modifié ni supprimé.
def firefox_sizes():
    """Read Firefox download annotations, without any writes to its SQLite files.

    Active Firefox transfers may not have an annotation until completion.
    """
    output={}
    try: profiles=list(PROFILES.iterdir())[:24]
    except OSError:return output
    query="""SELECT a.name,n.content,n.place_id FROM moz_annos n
             JOIN moz_anno_attributes a ON a.id=n.anno_attribute_id
             WHERE a.name IN ('downloads/destinationFileURI','downloads/metaData')
             ORDER BY n.dateAdded DESC LIMIT 1200"""
    for profile in profiles:
        if profile.is_symlink() or not profile.is_dir():continue
        db=profile/'places.sqlite'
        if db.is_symlink() or not db.is_file():continue
        uri='file:'+urllib.parse.quote(str(db),safe='/')
        for options in ('?mode=ro','?mode=ro&immutable=1'):
            try:
                con=sqlite3.connect(uri+options,uri=True,timeout=.15)
                try: rows=con.execute(query).fetchall()
                finally:con.close()
                break
            except sqlite3.Error:rows=[]
        combined={}
        for attr,value,place_id in rows:
            entry=combined.setdefault(place_id,{})
            if attr=='downloads/destinationFileURI':entry['uri']=value
            else:
                try:entry['meta']=json.loads(value)
                except (TypeError,ValueError):pass
        for entry in combined.values():
            uri=entry.get('uri','')
            if not isinstance(uri,str):continue
            parsed=urllib.parse.urlparse(uri)
            if parsed.scheme!='file' or parsed.netloc not in ('','localhost'):continue
            meta=entry.get('meta') or {}
            # Mozilla versions differ; use size only when explicitly reported.
            # A completed entry can describe an older file with the same name.
            if meta.get('state') in (1,'1'):continue
            total=meta.get('fileSize',meta.get('totalBytes'))
            if type(total) not in (float,int) or not (0<total<2**63):continue
            output[urllib.parse.unquote(parsed.path)]=int(total)
    return output

# Best-effort fallback: recent direct download links from Firefox browsing history.
# Explicitly do NOT inspect cookies, authenticate, download content or follow redirects.
# Restrict lookups to a unique filename-matching public HTTP(S) URL.
SIZE_CACHE = ROOT/'firefox-live-sizes.json'

def _public_http_url(url):
    try:
        parsed=urllib.parse.urlsplit(url)
        if parsed.scheme not in ('http','https') or not parsed.hostname or parsed.username or parsed.password:
            return False
        if parsed.port not in (None,80,443):return False
        host=parsed.hostname.rstrip('.').lower()
        if host in ('localhost',) or host.endswith(('.local','.internal','.localhost')):return False
        infos=socket.getaddrinfo(host,parsed.port or (443 if parsed.scheme=='https' else 80),type=socket.SOCK_STREAM)
        return bool(infos) and all(ipaddress.ip_address(i[4][0]).is_global for i in infos)
    except (ValueError,OSError,OverflowError):return False

class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,req,fp,code,msg,headers,newurl):return None

_HEAD=urllib.request.build_opener(urllib.request.ProxyHandler({}),_NoRedirect)

def _head_size(url,filename,minimum):
    if not _public_http_url(url):return None
    try:
        req=urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0 (Blondin read-only size check)','Accept-Encoding':'identity'},method='HEAD')
        with _HEAD.open(req,timeout=2.0) as response:
            if response.status!=200:return None
            content_type=response.headers.get('Content-Type','').lower()
            if 'text/html' in content_type or 'application/json' in content_type:return None
            encoding=response.headers.get('Content-Encoding','identity').lower()
            if encoding not in ('','identity'):return None
            disp=response.headers.get('Content-Disposition','')
            if disp:
                match=re.search(r'filename\*?\s*=\s*(?:UTF-8\'\')?[\"\']?([^;\"\']+)',disp,re.I)
                if match:
                    header_name=urllib.parse.unquote(match.group(1)).strip()
                    if pathlib.PurePosixPath(header_name).name!=filename:return None
            length=response.headers.get('Content-Length','').strip()
            if not length.isdigit():return None
            total=int(length)
            return total if minimum<=total<2**63 else None
    except (urllib.error.URLError,TimeoutError,ValueError,OSError):return None

def _recent_source_urls():
    result=[]
    cutoff=int((time.time()-3600)*1_000_000)
    try: profiles=list(PROFILES.iterdir())[:24]
    except OSError:return result
    for profile in profiles:
        if profile.is_symlink() or not profile.is_dir():continue
        db=profile/'places.sqlite'
        if db.is_symlink() or not db.is_file():continue
        uri='file:'+urllib.parse.quote(str(db),safe='/')
        query='''SELECT DISTINCT p.url FROM moz_places p JOIN moz_historyvisits v
                  ON v.place_id=p.id WHERE v.visit_date>=?
                  ORDER BY v.visit_date DESC LIMIT 150'''
        for options in ('?mode=ro','?mode=ro&immutable=1'):
            try:
                con=sqlite3.connect(uri+options,uri=True,timeout=.12)
                try:rows=con.execute(query,(cutoff,)).fetchall()
                finally:con.close()
                result.extend(x[0] for x in rows if x and isinstance(x[0],str))
                break
            except sqlite3.Error:continue
    return list(dict.fromkeys(result))

def _firefox_sqlite_rows(db,query):
    """Read Firefox's latest WAL if possible, with a consistent temporary snapshot
    fallback when the active database is locked. Never modify the live profile.
    """
    uri='file:'+urllib.parse.quote(str(db),safe='/')
    # Normal read-only SQLite includes committed WAL transactions.
    try:
        con=sqlite3.connect(uri+'?mode=ro',uri=True,timeout=.5)
        try:return con.execute(query).fetchall()
        finally:con.close()
    except (sqlite3.Error,OSError):pass
    # Files are copied together into a private directory. SQLite opens the
    # snapshot in read-only mode and recovers any committed WAL entries.
    # Retrying handles a checkpoint racing with our copy; bad snapshots are
    # discarded. No SQLite file in the Firefox profile is ever opened writable.
    for attempt in range(2):
        try:
            with tempfile.TemporaryDirectory(prefix='blondin-ff-snapshot-') as folder:
                dest=pathlib.Path(folder)/'places.sqlite'
                for suffix in ('','-wal','-shm'):
                    original=pathlib.Path(str(db)+suffix)
                    if original.exists() and not original.is_symlink():
                        limit=750_000_000 if not suffix else 128_000_000
                        if original.stat().st_size>limit:raise OSError('Base Firefox trop volumineuse')
                        with original.open('rb') as inp, pathlib.Path(str(dest)+suffix).open('wb') as out:
                            while True:
                                block=inp.read(1024*1024)
                                if not block:break
                                out.write(block)
                snap='file:'+urllib.parse.quote(str(dest),safe='/')+'?mode=ro'
                con=sqlite3.connect(snap,uri=True,timeout=.3)
                try:return con.execute(query).fetchall()
                finally:con.close()
        except (sqlite3.Error,OSError,ValueError):continue
    # Last resort: checkpointed main database (may be stale). This is never
    # mistaken for proof that Firefox has no active download metadata.
    try:
        con=sqlite3.connect(uri+'?mode=ro&immutable=1',uri=True,timeout=.3)
        try:return con.execute(query).fetchall()
        finally:con.close()
    except (sqlite3.Error,OSError):return []

def _firefox_annotation_sources_v101(pending):
    """Resolve active temporary .part files to Firefox destinations and URLs.

    The random 8-character token appears just before the extension on Firefox
    downloads. Only exact path matches are accepted; never infer a URL from an
    unrelated basename or an older completed file.
    """
    wanted={}
    for target,received in pending:
        path=pathlib.Path(target)
        choices=[target]
        match=re.search(r'\.([A-Za-z0-9]{8})(?=\.)',path.name)
        if match:
            choices.append(str(path.with_name(path.name[:match.start()]+path.name[match.end():])))
        for candidate in choices:
            wanted.setdefault(candidate,[]).append(target)
    matches={}
    query="""SELECT p.url,a.content,a.dateAdded FROM moz_annos a
             JOIN moz_anno_attributes n ON n.id=a.anno_attribute_id
             JOIN moz_places p ON p.id=a.place_id
             WHERE n.name='downloads/destinationFileURI'
             ORDER BY a.dateAdded DESC LIMIT 5000"""
    try:profiles=list(PROFILES.iterdir())[:24]
    except OSError:return {}
    cutoff=(time.time()-7*86400)*1_000_000
    for profile in profiles:
        if profile.is_symlink() or not profile.is_dir():continue
        db=profile/'places.sqlite'
        if db.is_symlink() or not db.is_file():continue
        for url,raw,added in _firefox_sqlite_rows(db,query):
            if not isinstance(url,str) or not isinstance(raw,str):continue
            if not isinstance(added,int) or added<cutoff:continue
            try:parsed=urllib.parse.urlsplit(raw)
            except ValueError:continue
            if parsed.scheme!='file' or parsed.netloc not in ('','localhost'):continue
            destination=urllib.parse.unquote(parsed.path)
            for target in wanted.get(destination,[]):
                matches.setdefault(target,set()).add((url,destination))
    return {target:next(iter(items)) for target,items in matches.items() if len(items)==1}

def firefox_remote_sizes(pending):
    if not pending:return {}
    cache=json_read(SIZE_CACHE,{'entries':{}})
    entries=cache.get('entries',{}) if isinstance(cache,dict) else {}
    if not isinstance(entries,dict):entries={}
    now=time.time()
    # First use the destination explicitly recorded in Firefox, then the
    # older filename-in-URL heuristic only when there is no association.
    linked=_firefox_annotation_sources_v101(pending[:12])
    sources=None
    output={}
    attempts=0
    for target,received in pending[:12]:
        filename=pathlib.Path(target).name
        association=linked.get(target)
        source_url,verified_target=association if association else (None,target)
        identity=hashlib.sha256(source_url.encode()).hexdigest() if source_url else ''
        previous=entries.get(target,{})
        if source_url and isinstance(previous,dict) and now-float(previous.get('checked',0))<90 and previous.get('source','')==identity and type(previous.get('total')) is int:
            total=previous.get('total')
            if type(total) is int and total>=received:
                output[target]=(total,verified_target)
            continue
        if not source_url:
            if sources is None:sources=_recent_source_urls()
            candidates=[]
            for url in sources:
                try:
                    parsed=urllib.parse.urlsplit(url)
                    urlname=pathlib.PurePosixPath(urllib.parse.unquote(parsed.path)).name
                    if urlname==filename and parsed.scheme in ('http','https'):
                        candidates.append(url)
                except ValueError:continue
            if len(candidates)==1:source_url=candidates[0]
        total=None
        if source_url and attempts<4:
            attempts+=1
            total=_head_size(source_url,pathlib.Path(verified_target).name,received)
        entries[target]={'checked':now,'total':total,'source':identity}
        if total is not None:output[target]=(total,verified_target)
    entries={k:v for k,v in entries.items() if isinstance(v,dict) and now-float(v.get('checked',0))<3600}
    try:atomic_json(SIZE_CACHE,{'entries':entries})
    except (OSError,ValueError):pass
    return output

def firefox_active():
    directories={pathlib.Path('/userdata/downloads'),
                 pathlib.Path('/userdata/roms/flatpak/Telechargements'),
                 pathlib.Path('/userdata/system/Downloads')}
    try:
        dirs=list(PROFILES.iterdir())[:24]
    except OSError:
        dirs=[]
    for profile in dirs:
        if profile.is_symlink() or not profile.is_dir():continue
        prefs=profile/'prefs.js'
        try:
            if prefs.is_symlink() or prefs.stat().st_size>4_000_000:continue
            with prefs.open('r',encoding='utf-8',errors='replace') as f:
                for line in f:
                    if not any(key in line for key in ('browser.download.dir','browser.download.lastDir')):continue
                    match=re.search(r'^user_pref\("browser\.download\.(?:dir|lastDir)",\s*("(?:\\.|[^"\\])*")\);',line)
                    if match:
                        try:
                            raw=json.loads(match.group(1))
                            if isinstance(raw,str) and raw.startswith('/'):
                                directories.add(pathlib.Path(raw))
                        except (ValueError,TypeError):pass
        except (OSError,ValueError):pass
    # Download destinations from already recorded history; avoid hitting
    # Firefox SQLite on every 2 s polling request.
    history=json_read(CACHE,{'records':[]})
    for record in history.get('records',[])[:250]:
        try:
            raw=record.get('path','')
            if isinstance(raw,str) and raw.startswith('/'):
                directories.add(pathlib.Path(raw).parent)
        except (ValueError,TypeError):pass
    result=[]
    known=firefox_sizes()
    now=time.time()
    for folder in sorted(directories,key=str)[:80]:
        try:
            if folder.is_symlink() or not folder.is_dir():continue
            # Directory listing is shallow and bounded: never traverse the ROM tree.
            count=0
            for part in folder.iterdir():
                count+=1
                if count>3000:break
                if not part.name.endswith('.part') or part.is_symlink():continue
                info=part.stat(follow_symlinks=False)
                if not stat.S_ISREG(info.st_mode):continue
                age=max(0,now-info.st_mtime)
                # Ignore abandoned partial files older than 30 minutes.
                if age>1800:continue
                realname=part.name[:-5] or part.name
                target=str(part.with_name(realname))
                total=known.get(target)
                if total is not None and total<info.st_size:total=None
                result.append({'id':hashlib.sha256(str(part).encode()).hexdigest(),
                               'path':target,'name':realname,'downloaded':info.st_size,
                               'modified':info.st_mtime,'recent':age<=90,
                               'total':total,'size_known':total is not None})
                if len(result)>=40:break
        except (OSError,PermissionError):continue
        if len(result)>=40:break
    # Firefox's in-memory download panel is not exposed through places.sqlite.
    # Public HEAD checks are only attempted for unambiguous recent direct links.
    missing=[(x['path'],x['downloaded']) for x in result if not x['size_known']]
    extra=firefox_remote_sizes(missing)
    for x in result:
        value=extra.get(x['path'])
        if value is not None:
            x['total']=value[0];x['size_known']=True;x['size_source']='HTTP HEAD'
            # Show the final Firefox filename only when confirmed by the annotation.
            x['name']=pathlib.Path(value[1]).name
        x.pop('path',None)  # Never expose local filesystem paths to the Web client.
    result.sort(key=lambda x:x['modified'],reverse=True)
    return {'downloads':result,'detection':'indicative','total_known':any(x['size_known'] for x in result)}

def secure_unlink(record):
    path=pathlib.Path(record['path'])
    if not path.is_absolute():raise ValueError('Chemin invalide')
    if path.with_name(path.name+'.part').exists():raise ValueError('Téléchargement potentiellement actif')
    parent=path.parent.resolve(strict=True)
    allowed=[r.resolve(strict=True) for r in ALLOWED if r.exists()]
    if not any(parent==r or r in parent.parents for r in allowed):
        raise ValueError('Suppression limitée aux ROMs et aux supports externes')
    flags=os.O_RDONLY|getattr(os,'O_DIRECTORY',0)|getattr(os,'O_NOFOLLOW',0)
    fd_dir=os.open(parent,flags)
    try:
        fd=os.open(path.name,os.O_RDONLY|getattr(os,'O_NOFOLLOW',0)|getattr(os,'O_NONBLOCK',0),dir_fd=fd_dir)
        try:
            st=os.fstat(fd)
            if not stat.S_ISREG(st.st_mode) or st.st_nlink!=1:raise ValueError('Fichier non ordinaire ou lié')
            if record.get('size') is None or st.st_size!=int(record['size']):
                raise ValueError('Taille modifiée : suppression refusée')
            now=os.stat(path.name,dir_fd=fd_dir,follow_symlinks=False)
            if (st.st_dev,st.st_ino)!=(now.st_dev,now.st_ino):raise ValueError('Fichier modifié')
            os.unlink(path.name,dir_fd=fd_dir)
        finally:os.close(fd)
    finally:os.close(fd_dir)

def delete_history(ids,remove_files=False):
    if not isinstance(ids,list) or not 0<len(ids)<=200 or not all(isinstance(x,str) and len(x)==64 for x in ids):
        raise ValueError('Sélection invalide (maximum 200)')
    if type(remove_files) is not bool:raise ValueError('Mode invalide')
    ROOT.mkdir(parents=True,exist_ok=True)
    with LOCK.open('a+') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        # At this point no profile files are modified, and no SQLite write occurs.
        data=_list_locked();by_id={x['id']:x for x in data['records']}
        hidden=set(json_read(HIDDEN,{'ids':[]}).get('ids',[]))
        results=[]
        for ident in dict.fromkeys(ids):
            item=by_id.get(ident)
            if item is None:
                results.append({'id':ident,'ok':False,'error':'Entrée introuvable'});continue
            try:
                if remove_files:secure_unlink(item)
                hidden.add(ident)
                atomic_json(HIDDEN,{'ids':sorted(hidden)})
                results.append({'id':ident,'ok':True})
            except (OSError,ValueError,TypeError) as exc:
                results.append({'id':ident,'ok':False,'error':str(exc)[:160]})
        return results

def main():
    parser=argparse.ArgumentParser()
    sub=parser.add_subparsers(dest='action',required=True)
    sub.add_parser('list')
    p=sub.add_parser('delete');p.add_argument('mode',choices=('history','both'));p.add_argument('ids',nargs='+')
    args=parser.parse_args()
    if args.action=='list':print(json.dumps(list_history(),ensure_ascii=False))
    else:print(json.dumps({'results':delete_history(args.ids,args.mode=='both')},ensure_ascii=False))
if __name__=='__main__':main()
PY_BLONDIN_FFOX
  then echo '[ERREUR] Installation du module Firefox impossible.'; return 1; fi
  chmod 600 "$ONEF_DIR/blondin_firefox_history.py" || return 1

  if (( update )); then
    echo '[OK] Moteur 1fichier mis à jour (masquage suivi Firefox et fermeture distante sécurisée).'
    if (( was_running )); then
      echo '[INFO] Redémarrage du serveur Web existant...'
      onef_web_stop
      # Laisser au serveur précédent le temps de libérer le port HTTPS.
      sleep 1
      python3 "$ONEF_BIN" web --bind 0.0.0.0 --port 8765 \
        --cert "$ONEF_WEB_DIR/cert.pem" --key "$ONEF_WEB_DIR/key.pem" \
        >"$ONEF_WEB_DIR/web.log" 2>&1 </dev/null &
      local pid=$!; echo "$pid" > "$ONEF_WEB_DIR/web.pid"
      sleep 1
      if onef_web_responding; then
        echo '[OK] Interface Web HTTPS relancée.'
      else
        echo '[ATTENTION] Service Web non confirmé : redémarrer dans Gestion > Interface Web.'
      fi
    fi
  else
    echo '[OK] Moteur 1fichier installé. Interface Web non installée.'
  fi
}
# Espacement identique dans tous les sous-menus 1fichier.
onef_navigation(){
  echo
  ui_print info '  --------------------------------'
  ui_item '0) Retour'
  ui_item 'Q) Quitter le gestionnaire'
  echo
}
# Affichage compact et lisible depuis un terminal mobile.
# Lecture seule : aucun changement de l'état des téléchargements.
# Actualisation en direct toutes les 2 secondes pendant l'affichage.
# Une touche 0 retourne au menu, Q quitte, sans modifier les tâches.
onef_progress(){
  if [[ ! -d "$ONEF_CFG/jobs" ]]; then
    ui_print info '  Aucun téléchargement enregistré.'
    pause
    return 0
  fi
  local key='' extra=''
  while :; do
    refresh_screen
    ui_section '1FICHIER - PROGRESSION'
    python3 - "$ONEF_CFG/jobs" <<'PYONEF_PROGRESS'
import json, pathlib, sys
folder=pathlib.Path(sys.argv[1])
items=[]
for p in folder.glob('*.json'):
    try:
        d=json.loads(p.read_text(encoding='utf-8'))
        if not isinstance(d,dict): continue
        name=' '.join(str(d.get('filename') or 'Fichier sans nom').split())
        state=str(d.get('state') or 'inconnu')
        current=max(0,int(d.get('downloaded') or 0))
        size=max(0,int(d.get('size') or 0))
        date=str(d.get('created') or '')
        items.append((date,name,state,current,size))
    except (OSError,ValueError,TypeError,UnicodeError): pass
def human(n):
    unit='o'
    value=float(n)
    for unit in ('o','Ko','Mo','Go','To'):
        if value<1024 or unit=='To': break
        value/=1024
    return f'{value:.1f} {unit}'
if not items:
    print('  Aucun téléchargement enregistré.')
else:
    print(f'  Téléchargements : {len(items)}')
    print()
    for n,(_,name,state,current,size) in enumerate(sorted(items,reverse=True)[:20],1):
        short=name[:28] + ('…' if len(name)>28 else '')
        print(f'  {n:02d}  {short}')
        stat={'termine':'Terminé','telechargement':'En cours','en_attente':'En attente','preparation':'Préparation','interrompu':'Interrompu','erreur':'Erreur'}.get(state,state[:20])
        if size:
            ratio=max(0,min(100,int(current*100/size)))
            filled=min(20,ratio*20//100)
            print(f'      {stat} · {ratio}%')
            print(f'      [{"#"*filled}{"-"*(20-filled)}]')
            print(f'      {human(current)} / {human(size)}')
        else:
            print(f'      {stat} · {human(current)}')
        print()
    if len(items)>20:
        print(f'  {len(items)-20} autres fichiers non affichés.')
PYONEF_PROGRESS
    echo
    firefox_downloads_view active
    echo
    ui_print info '  Actualisation automatique : 2 s'
    ui_print gold '  [0] Retour   [Q] Quitter'
    # Non interactif : ne pas boucler indéfiniment sous SSH redirigé.
    [[ -t 0 ]] || return 0
    key=''
    if IFS= read -r -s -n 1 -t 2 key; then
      case "$key" in
        0) return 0 ;;
        q|Q) manager_quit_key "$key"; return 0 ;;
        $'\033')
          # Absorber les éventuelles séquences de touches directionnelles.
          while IFS= read -r -s -n 1 -t 0.05 extra; do :; done
          ;;
      esac
    fi
  done
}


# Firefox Mozilla : observation facultative, lecture seule.
# Les versions modernes ne fournissent pas toujours la taille totale ou un
# historique exploitable dans places.sqlite : ne jamais inventer un pourcentage.
firefox_downloads_view(){
  local mode="${1:-active}"
  python3 - "$mode" <<'PY_FIREFOX_DOWNLOADS'
import sys, pathlib, sqlite3, json, urllib.parse, os, time, tempfile
mode=sys.argv[1]
root=pathlib.Path('/userdata/system/.config/mozilla/firefox')
cache=pathlib.Path('/userdata/system/cache/blondin-firefox-history.json')

def clean(value, n=38):
    value=' '.join(str(value or '').split())
    return value[:n]+'…' if len(value)>n else value

def human(size):
    value=float(max(0,size))
    for unit in ('o','Ko','Mo','Go','To'):
        if value<1024 or unit=='To': return f'{value:.1f} {unit}'
        value/=1024

def read_profile(db):
    # First use normal read-only SQLite so the current WAL is visible.
    # If Firefox holds an exclusive lock, immutable=1 may recover the last
    # checkpointed snapshot; that snapshot can be older than the live history.
    query="""SELECT n.place_id,a.name,n.content,n.dateAdded
             FROM moz_annos n
             JOIN moz_anno_attributes a ON a.id=n.anno_attribute_id
             JOIN moz_places p ON p.id=n.place_id
             WHERE a.name IN ('downloads/destinationFileURI','downloads/metaData')
             ORDER BY n.dateAdded DESC LIMIT 1000"""
    def read_with_uri(uri):
        with sqlite3.connect(uri,uri=True,timeout=1.2) as con:
            tables={row[0] for row in con.execute(
                "SELECT name FROM sqlite_master WHERE type='table'")}
            if not {'moz_annos','moz_anno_attributes','moz_places'}.issubset(tables):
                raise RuntimeError('Tables de téléchargements absentes')
            joined={}
            for place_id,key,val,date_added in con.execute(query):
                if val is None: continue
                obj=joined.setdefault(place_id,{'uri':'','meta':{},'date':0})
                obj['date']=max(obj['date'],int(date_added or 0))
                if key=='downloads/destinationFileURI':obj['uri']=str(val)
                elif key=='downloads/metaData':
                    try:
                        parsed=json.loads(val)
                        if isinstance(parsed,dict):obj['meta']={
                            'state':parsed.get('state')}
                    except (ValueError,TypeError):pass
            return list(joined.values())
    base='file:'+urllib.parse.quote(str(db),safe='/')
    for attempt in range(3):
        try:
            return read_with_uri(base+'?mode=ro'),False
        except (sqlite3.Error,OSError,RuntimeError):
            if attempt!=2:time.sleep(0.3)
    # Fallback: immutable bypasses active locks but deliberately ignores WAL.
    # Read-only and best-effort; never present this as fresh/live history.
    return read_with_uri(base+'?mode=ro&immutable=1'),True

def read_cache():
    try:
        if cache.is_symlink() or not cache.is_file():return None
        data=json.loads(cache.read_text(encoding='utf-8'))
        if data.get('version')!=1 or not isinstance(data.get('records'),list):return None
        return data['records']
    except (OSError,ValueError,TypeError):return None

def save_cache(records):
    # Persist just the file URI, completion state and timestamp (no browser URLs).
    try:
        cache.parent.mkdir(parents=True,exist_ok=True)
        if cache.is_symlink():return
        fd,tmp=tempfile.mkstemp(prefix='.blondin-firefox-',dir=cache.parent)
        try:
            with os.fdopen(fd,'w',encoding='utf-8') as f:
                json.dump({'version':1,'records':records},f,ensure_ascii=False)
            os.chmod(tmp,0o600)
            os.replace(tmp,cache)
        finally:
            if os.path.exists(tmp):os.unlink(tmp)
    except OSError:pass

found=[]
failures=0
profiles=0
old_snapshot=False
if root.is_dir() and not root.is_symlink():
    for profile in list(root.iterdir())[:24]:
        if not profile.is_dir() or profile.is_symlink():continue
        db=profile/'places.sqlite'
        if not db.is_file() or db.is_symlink():continue
        profiles+=1
        try:
            records,was_old=read_profile(db)
            found.extend(records)
            old_snapshot=old_snapshot or was_old
        except (sqlite3.Error,OSError,RuntimeError):failures+=1

# A failed read must never be presented as an empty Firefox history.
stale=old_snapshot
if failures:
    cached=read_cache()
    if cached is not None:
        found=cached
        stale=True
    elif not found:
        print('  Historique momentanément indisponible :')
        print('  base Firefox verrouillée ou inaccessible.')
        if mode=='history':
            print('  Réessayer après la fin du téléchargement.')
        # Do not claim an empty history. Active .part monitoring remains possible.
        if mode=='history':sys.exit(0)
else:
    if profiles and not old_snapshot:save_cache(found)

found=sorted(found,key=lambda x:int(x.get('date') or 0),reverse=True)
files=[]
folders={pathlib.Path('/userdata/downloads'),
         pathlib.Path('/userdata/roms/flatpak/Telechargements'),
         pathlib.Path('/userdata/system/Downloads')}
for record in found:
    try:
        parsed=urllib.parse.urlparse(record.get('uri',''))
        if parsed.scheme!='file' or parsed.netloc not in ('','localhost'):continue
        path=pathlib.Path(urllib.parse.unquote(parsed.path))
        if not path.is_absolute():continue
        folders.add(path.parent)
        files.append((path,record.get('meta') or {}))
    except (ValueError,OSError,TypeError):continue
if mode=='history':
    print('  FIREFOX - HISTORIQUE')
    if stale:print('  [INFO] Historique de secours : peut être ancien.')
    shown=0
    for path,meta in files:
        state=meta.get('state')
        if state not in (1,'1',None) or (state is None and not path.is_file()):continue
        print('  '+clean(path.name))
        if path.is_file():
            try:print('    Terminé · '+human(path.stat().st_size))
            except OSError:print('    Terminé')
        else:print('    Terminé (fichier déplacé ou absent)')
        shown+=1
        if shown>=40:break
    if not shown:
        print('  Aucun historique Firefox exploitable.' if not failures else
              '  Aucune entrée dans le cache disponible.')
    print('  Source : métadonnées Firefox (lecture seule).')
else:
    print('  FIREFOX')
    active=[]
    for folder in sorted(folders,key=str)[:50]:
        if not folder.is_dir() or folder.is_symlink():continue
        try:
            for part in folder.iterdir():
                if not part.is_file() or part.is_symlink() or not part.name.endswith('.part'):continue
                active.append(part)
                if len(active)>=20:break
        except (OSError,PermissionError):continue
        if len(active)>=20:break
    if not active:
        print('  Aucun fichier .part détecté dans les')
        print('  dossiers connus.')
    else:
        for part in active:
            try:received=human(part.stat().st_size)
            except OSError:received='Taille inconnue'
            print('  '+clean(part.name[:-5] or part.name))
            print('    En cours (probable) · '+received)
            print('    % indisponible (total non fourni)')
    if failures:print('  [INFO] Historique Firefox occupé ; suivi indicatif.')
    print('  Surveillance indicative, sans contrôle de Firefox.')
PY_FIREFOX_DOWNLOADS
}
firefox_history_menu(){
  refresh_screen
  ui_section 'HISTORIQUE FIREFOX'
  firefox_downloads_view history
  echo
  ui_print info '  Historique séparé de 1fichier.'
  ui_print info '  Aucune suppression Firefox.'
  pause
}

onef_web_running(){
  [[ -r "$ONEF_WEB_DIR/web.pid" ]] || return 1
  local pid cmd
  pid="$(cat "$ONEF_WEB_DIR/web.pid" 2>/dev/null)"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  [[ -r "/proc/$pid/cmdline" ]] || return 1
  cmd="$(tr '\0' ' ' < "/proc/$pid/cmdline")"
  [[ "$cmd" == *"$ONEF_BIN web "* ]] || return 1
  kill -0 "$pid" 2>/dev/null
}
onef_web_stop(){
  if onef_web_running; then
    local pid; pid="$(cat "$ONEF_WEB_DIR/web.pid")"
    kill "$pid" && echo '[OK] Interface Web arrêtée.'
  else
    echo '[INFO] Interface Web déjà arrêtée.'
  fi
  rm -f "$ONEF_WEB_DIR/web.pid"
}
# IP LAN de l'appareil, sans interrogation de service Internet.
# Préférence pour l'interface utilisée par la route IPv4 principale.
# Évite de sélectionner par erreur 127.0.0.1 ou une adresse IPv6.
onef_local_ip(){
  # Batocera 44 : hostname -I n'est pas disponible.
  # D'abord l'adresse IPv4 de la route principale, puis une adresse globale.
  local address=''
  if command -v ip >/dev/null 2>&1; then
    address="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") {print $(i+1);exit}}')"
    if [[ ! "$address" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ || "$address" == 127.* || "$address" == 169.254.* ]]; then
      address="$(ip -4 -o addr show scope global 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="inet") {split($(i+1),parts,"/"); if(parts[1] !~ /^127\./ && parts[1] !~ /^169\.254\./) {print parts[1];exit}}}')"
    fi
  fi
  [[ "$address" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ && "$address" != 127.* && "$address" != 169.254.* ]] || return 1
  printf '%s\n' "$address"
}
# Un processus actif ne suffit pas : verifier une reponse du serveur HTTPS.
# Test local uniquement, sans transmettre la cle API ni le jeton Web.
onef_web_responding(){
  onef_web_running || return 1
  command -v curl >/dev/null 2>&1 || return 1
  local code
  code="$(curl --silent --show-error --insecure --noproxy '*' \
    --connect-timeout 2 --max-time 4 -o /dev/null -w '%{http_code}' \
    https://127.0.0.1:8765/ 2>/dev/null)" || return 1
  [[ "$code" == 200 ]]
}
# Statuts Web : mêmes symboles et couleurs que la clé API Premium.
# 1 = condition remplie (✓ vert), 0 = condition non remplie (✗ rouge).
onef_web_status_item(){
  local number="$1" label="$2" valid="$3" glyph color
  if [[ "$valid" == 1 ]]; then
    glyph='✓'; color=$'\033[1;32m'
  else
    glyph='✗'; color=$'\033[1;31m'
  fi
  if (( UI_COLOR )); then
    printf '  \033[1;33m%02d ▸\033[0m  %s%s\033[0m \033[0;37m%s\033[0m\n' \
      "$number" "$color" "$glyph" "$label"
  else
    printf '  %02d ▸  %s %s\n' "$number" "$glyph" "$label"
  fi
}
onef_web_menu(){
  local opt pid ip web_ok web_installed web_running
  while :; do
    refresh_screen
    ui_section '1FICHIER - INTERFACE WEB'
    if [[ -f "$ONEF_WEB_DIR/installed" ]]; then ui_print success '  ● Module Web installé'; else ui_print warning '  ○ Module Web non installé'; fi
    web_ok=0
    if onef_web_responding; then
      web_ok=1
      ui_print success '  ● Service HTTPS accessible localement'
    elif onef_web_running; then
      ui_print warning '  ● Service actif, HTTPS non vérifié'
    else
      ui_print info '  ○ Service Web arrêté'
    fi
    ui_print info '  Module facultatif | Démarrage manuel'
    ip="$(onef_local_ip)" || ip=''
    if [[ -n "$ip" ]]; then
      ui_print info "  IP locale : $ip"
      # Lien en texte brut pour l'auto-detection du terminal Android.
      # Prefixe court afin que l'URL et le port restent sur une seule ligne.
      printf 'Lien: https://%s:8765\n' "$ip"
      if (( ! web_ok )); then
        ui_print warning '  Accès non confirmé : vérifier le Web.'
      fi
    else
      ui_print warning '  IP locale indisponible.'
    fi
    web_installed=0
    web_running=0
    [[ -f "$ONEF_WEB_DIR/installed" ]] && web_installed=1
    if onef_web_running; then web_running=1; fi
    onef_web_status_item 1 'Installer le Web' "$web_installed"
    onef_web_status_item 2 'Démarrer le Web' "$web_running"
    # Inversion volontaire : ✓ quand le service est arrêté.
    onef_web_status_item 3 'Arrêter le Web' "$((1 - web_running))"
    ui_item '4) Jeton de connexion'
    ui_item '5) Désinstaller le Web'
    onef_navigation
    opt="$(read_key 'Votre choix : ')" || return 0
    case "$opt" in
      1)
        if [[ -f "$ONEF_WEB_DIR/installed" ]]; then echo '[INFO] Déjà installé.'
        elif confirm 'Installer le Web HTTPS local (certificat auto-signé) ?'; then
          if ! command -v openssl >/dev/null 2>&1; then
            echo '[ERREUR] openssl indisponible.'
          else
            mkdir -p "$ONEF_WEB_DIR" "$ONEF_CFG"
            chmod 700 "$ONEF_WEB_DIR" "$ONEF_CFG"
            if openssl req -x509 -newkey rsa:2048 -nodes -days 365 -subj '/CN=batocera-local' \
               -keyout "$ONEF_WEB_DIR/key.pem" -out "$ONEF_WEB_DIR/cert.pem" >/dev/null 2>&1; then
              chmod 600 "$ONEF_WEB_DIR/key.pem" "$ONEF_WEB_DIR/cert.pem"
              python3 - "$ONEF_CFG/web.token" <<'PYONEFTOKEN'
from pathlib import Path
import secrets,sys
p=Path(sys.argv[1]);p.parent.mkdir(parents=True,exist_ok=True)
if not p.exists(): p.write_text(secrets.token_urlsafe(32)+'\n')
p.chmod(0o600)
PYONEFTOKEN
              touch "$ONEF_WEB_DIR/installed"
              echo '[OK] Web installé. Démarrage manuel uniquement.'
              echo '[NOTE] Certificat auto-signé : avertissement navigateur attendu.'
            else echo '[ERREUR] Création du certificat impossible.'; fi
          fi
        fi
        pause ;;
      2)
        if [[ ! -f "$ONEF_WEB_DIR/installed" ]]; then echo '[ATTENTION] Installer le module Web avant.'
        elif onef_web_running; then echo '[INFO] Web déjà actif.'
        elif confirm 'Activer le service HTTPS sur le réseau local ?'; then
          python3 "$ONEF_BIN" web --bind 0.0.0.0 --port 8765 \
              --cert "$ONEF_WEB_DIR/cert.pem" --key "$ONEF_WEB_DIR/key.pem" \
              >"$ONEF_WEB_DIR/web.log" 2>&1 </dev/null &
          pid=$!; echo "$pid" > "$ONEF_WEB_DIR/web.pid"
          sleep 1
          if onef_web_responding; then
            ip="$(onef_local_ip)" || ip=''
            if [[ -n "$ip" ]]; then
              echo "[OK] HTTPS local vérifié."
              echo "https://$ip:8765"
            else
              echo '[OK] HTTPS local vérifié. IP locale indisponible.'
            fi
          else
            echo '[ATTENTION] Réponse HTTPS non confirmée.'
            tail -8 "$ONEF_WEB_DIR/web.log"
          fi
        fi
        pause ;;
      3) onef_web_stop; pause ;;
      4)
        if [[ -f "$ONEF_CFG/web.token" ]]; then
          if confirm 'Afficher le jeton secret sur cet écran ?'; then cat "$ONEF_CFG/web.token"; fi
        else echo '[ATTENTION] Installer le Web au préalable.'; fi
        pause ;;
      5)
        if [[ -f "$ONEF_WEB_DIR/installed" ]] && confirm 'Désinstaller seulement le Web (sans effacer téléchargements ou compte) ?'; then
          onef_web_stop
          rm -f "$ONEF_WEB_DIR/installed" "$ONEF_WEB_DIR/key.pem" "$ONEF_WEB_DIR/cert.pem" "$ONEF_WEB_DIR/web.pid"
          echo '[OK] Module Web désinstallé. Données Premium conservées.'
        fi
        pause ;;
      0) return 0 ;;
      *) echo 'Choix invalide.'; sleep 1 ;;
    esac
  done
}
# Choix numerique des telechargements, sans recopier les 32 caracteres.
# Lecture seule des metadonnees; les commandes retry/cancel restent celles du moteur.
onef_choose_job(){
  local action="$1" choice='' start=0 total i row id state name
  local -a items=()
  [[ -d "$ONEF_CFG/jobs" ]] || { echo '[INFO] Aucun téléchargement enregistré.'; return 1; }
  mapfile -t items < <(python3 - "$ONEF_CFG/jobs" "$action" <<'PYONEF_JOBS'
import json,pathlib,sys
folder=pathlib.Path(sys.argv[1]); action=sys.argv[2]
for path in sorted(folder.glob('*.json'),reverse=True):
    try:
        j=json.loads(path.read_text(encoding='utf-8'))
        jid=j.get('id',''); state=j.get('state','')
        if path.name != jid+'.json' or len(jid)!=32 or any(c not in '0123456789abcdef' for c in jid): continue
        if action=='retry' and state not in ('erreur','interrompu'): continue
        if action=='cancel' and state not in ('en_attente','preparation','telechargement'): continue
        name=str(j.get('filename') or j.get('url') or '(sans nom)')
        name=' '.join(name.split())[:55]
        print(jid+'\t'+state+'\t'+name)
    except (OSError,ValueError,TypeError,UnicodeError): pass
PYONEF_JOBS
)
  total=${#items[@]}
  if (( total == 0 )); then
    if [[ "$action" == retry ]]; then echo '[INFO] Rien à reprendre.'
    else echo '[INFO] Rien à interrompre.'; fi
    return 1
  fi
  while :; do
    refresh_screen
    if [[ "$action" == retry ]]; then ui_section 'REPRENDRE UN TELECHARGEMENT'
    else ui_section 'INTERROMPRE UN TELECHARGEMENT'; fi
    ui_print info "  Téléchargements : $total  |  Page $((start / 9 + 1)) / $(((total + 8) / 9))"
    for (( i=start; i<total && i<start+9; i++ )); do
      row="${items[$i]}"
      IFS=$'\t' read -r id state name <<< "$row"
      ui_item "$((i-start+1))) [$state] $name"
    done
    (( start+9 < total )) && ui_print info '  [N] Page suivante'
    (( start > 0 )) && ui_print info '  [P] Page précédente'
    onef_navigation
    choice="$(read_key 'Votre choix : ')" || return 1
    case "$choice" in
      [1-9])
        i=$((start+choice-1))
        ((i<total)) || { echo '[INFO] Choix invalide.'; sleep 1; continue; }
        row="${items[$i]}"
        IFS=$'\t' read -r id state name <<< "$row"
        echo "  Fichier : $name"
        if [[ "$action" == retry ]]; then
          if confirm 'Reprendre ce téléchargement ?'; then python3 "$ONEF_BIN" retry "$id"; fi
        else
          if confirm 'Interrompre ce téléchargement ?'; then python3 "$ONEF_BIN" cancel "$id"; fi
        fi
        return 0 ;;
      n|N) if ((start+9<total)); then start=$((start+9)); fi ;;
      p|P) if ((start>0)); then start=$((start-9)); fi ;;
      0) return 1 ;;
      *) echo '[INFO] Choix invalide.'; sleep 1 ;;
    esac
  done
}

# Historique local : affiche seulement les téléchargements terminés.
# Les métadonnées existantes sont conservées par le moteur dans jobs/*.json.
onef_history(){
  local -a entries=() ids=() chosen=()
  local start=0 total i choice item numbers mode id count
  while :; do
    mapfile -t entries < <(python3 - "$ONEF_CFG/jobs" <<'PYONEF_HISTORY'
import datetime,json,pathlib,re,sys
folder=pathlib.Path(sys.argv[1]); items=[]
if folder.is_dir() and not folder.is_symlink():
 for p in folder.glob('*.json'):
    if p.is_symlink() or not re.fullmatch(r'[a-f0-9]{32}\.json',p.name):continue
    try:
        j=json.loads(p.read_text(encoding='utf-8'))
        if j.get('id')!=p.stem or j.get('state')!='termine':continue
        name=' '.join(str(j.get('filename') or '(nom inconnu)').split())
        date=str(j.get('finished') or j.get('created') or '')
        size=int(j.get('size') or j.get('downloaded') or 0)
        scale='Go' if size>=1024**3 else ('Mo' if size>=1024**2 else 'Ko')
        factor=1024**3 if scale=='Go' else (1024**2 if scale=='Mo' else 1024)
        short=name[:27]+('…' if len(name)>27 else '')
        items.append((date,p.stem,short,f'{size/factor:.1f} {scale}'))
    except (OSError,ValueError,TypeError,UnicodeError): pass
for date,jid,name,size in sorted(items,reverse=True):
 print('\t'.join((jid,name,size,date[:16])))
PYONEF_HISTORY
)
    total=${#entries[@]}
    refresh_screen
    ui_section 'HISTORIQUE 1FICHIER'
    ui_print info "  Fichiers terminés : $total"
    for ((i=start; i<total && i<start+8; i++)); do
      IFS=$'\t' read -r id name size date <<< "${entries[$i]}"
      ui_print menu "  $((i+1))) $name"
      ui_print info "      $size  |  ${date//T/ }"
    done
    echo
    ((start+8<total)) && ui_print info '  [N] Page suivante'
    ((start>0)) && ui_print info '  [P] Page précédente'
    ui_item '1) Supprimer une sélection'
    onef_navigation
    choice="$(read_key 'Votre choix : ')" || return 0
    case "$choice" in
      1)
        if (( total==0 )); then ui_print info '  Historique vide.'; pause; continue; fi
        printf 'Numéros à supprimer (ex. 1,3 ou tout) : '
        IFS= read -r numbers || continue
        ids=()
        if [[ "$numbers" == tout ]]; then
          for item in "${entries[@]}"; do ids+=("${item%%$'\t'*}"); done
        elif [[ "$numbers" =~ ^[0-9]+(,[0-9]+)*$ ]]; then
          local -a parts=()
          IFS=',' read -r -a parts <<< "$numbers"
          for i in "${parts[@]}"; do
            if (( 10#$i>=1 && 10#$i<=total )); then
              item="${entries[10#$i-1]}";ids+=("${item%%$'\t'*}")
            fi
          done
        fi
        if (( ${#ids[@]}==0 )); then ui_print warning '  Sélection invalide.'; pause;continue;fi
        ui_print info "  ${#ids[@]} élément(s) sélectionné(s)."
        ui_item '1) Historique uniquement'
        ui_item '2) Historique + fichiers'
        mode="$(read_key 'Mode : ')" || continue
        case "$mode" in 1) mode=history ;; 2) mode=both ;; *) continue ;; esac
        if [[ "$mode" == both ]]; then
          ui_print warning '  ATTENTION : les fichiers seront supprimés définitivement.'
        else
          ui_print info '  Les fichiers téléchargés seront conservés.'
        fi
        if confirm 'Confirmer la suppression ?'; then
          python3 "$ONEF_BIN" delete-completed "$mode" "${ids[@]}"
        else ui_print info '  Annulé.'; fi
        pause
        start=0
        ;;
      n|N) ((start+8<total)) && start=$((start+8)) ;;
      p|P) ((start>0)) && start=$((start-8)) ;;
      0) return 0 ;;
      *) echo '[INFO] Choix invalide.'; sleep 1 ;;
    esac
  done
}

# Efface uniquement les fiches JSON des téléchargements terminés.
# Les fichiers téléchargés, les fiches actives et la clé API restent intacts.


firefox_history_manage(){
  local data item ans numbers mode i jid
  local -a lines=() chosen=() parts=()
  while :; do
    data="$(python3 "$ONEF_DIR/blondin_firefox_history.py" list)" || { ui_print error '  Historique Firefox inaccessible.'; pause;return; }
    mapfile -t lines < <(python3 - "$data" <<'PY_FFOX_MENU'
import json,sys
try:
 d=json.loads(sys.argv[1]);print('STATUT\t'+('Secours (lecture ancienne)' if d.get('stale') else 'Actualisé'))
 for r in d['records'][:200]:
  name=' '.join(r['name'].split());name=name[:27]+('…' if len(name)>27 else '')
  print('\t'.join((r['id'],name,str(r.get('size') or '?'))))
except (ValueError,KeyError,TypeError):print('STATUT\tIndisponible')
PY_FFOX_MENU
)
    refresh_screen
    ui_section 'HISTORIQUE FIREFOX'
    ui_print info "  ${lines[0]#*$'\t'}"
    ui_print info "  ${#lines[@]} ligne(s) (statut compris)."
    for ((i=1;i<${#lines[@]}&&i<=15;i++)); do
      IFS=$'\t' read -r jid name _ <<< "${lines[i]}"
      ui_print menu "  $i) $name"
    done
    echo
    ui_item '1) Supprimer une sélection'
    onef_navigation
    ans="$(read_key 'Votre choix : ')" || return
    case "$ans" in
      1)
        printf 'Numéros (ex. 1,3 ou tout) : ';IFS= read -r numbers || continue
        chosen=()
        if [[ "$numbers" == tout ]];then
          for item in "${lines[@]:1}"; do chosen+=("${item%%$'\t'*}");done
        elif [[ "$numbers" =~ ^[0-9]+(,[0-9]+)*$ ]];then
          IFS=',' read -r -a parts <<< "$numbers"
          for i in "${parts[@]}";do
            if ((10#$i>=1 && 10#$i<${#lines[@]}));then
              item="${lines[10#$i]}";chosen+=("${item%%$'\t'*}")
            fi
          done
        fi
        if (( ${#chosen[@]}==0 ));then ui_print warning '  Sélection vide.';pause;continue;fi
        ui_item '1) Historique uniquement'
        ui_item '2) Historique + fichiers'
        mode="$(read_key 'Mode : ')" || continue
        [[ "$mode" == 1 || "$mode" == 2 ]] || continue
        if [[ "$mode" == 2 ]];then
          ui_print warning '  ATTENTION : suppression définitive de fichiers.'
        fi
        if confirm 'Confirmer la suppression ?';then
          python3 "$ONEF_DIR/blondin_firefox_history.py" delete "$([[ "$mode" == 1 ]] && echo history || echo both)" "${chosen[@]}"
        fi
        pause;;
      0) return;;
      *) ui_print warning '  Choix invalide.';sleep 1;;
    esac
  done
}
onef_history_menu(){
  local choice
  while :;do
    refresh_screen
    ui_section 'HISTORIQUE'
    ui_item '1) 1fichier Premium'
    ui_item '2) Firefox'
    onef_navigation
    choice="$(read_key 'Votre choix : ')" || return
    case "$choice" in
      1) onef_history;;
      2) firefox_history_manage;;
      0) return;;
      *) sleep 1;;
    esac
  done
}

onef_downloads_menu(){
  local opt url dest
  while :; do
    refresh_screen
    ui_section '1FICHIER - TELECHARGEMENTS'
    ui_print info "  Destination : ${ONEF_DEFAULT##*/}"
    ui_print info '  /userdata/roms/flatpak/'
    echo
    ui_item '1) Nouveau téléchargement'
    ui_item '2) Progression'
    ui_item '3) Reprendre'
    ui_item '4) Interrompre'
    ui_item '5) Historique'
    onef_navigation
    opt="$(read_key 'Votre choix : ')" || return 0
    case "$opt" in
      1)
        printf 'Lien 1fichier HTTPS : '; IFS= read -r url
        printf 'Destination (Entrée = défaut) : '; IFS= read -r dest
        python3 "$ONEF_BIN" add "$url" "${dest:-$ONEF_DEFAULT}"
        pause ;;
      2) onef_progress ;;
      3) onef_choose_job retry; pause ;;
      4) onef_choose_job cancel; pause ;;
      5) onef_history_menu ;;
      0) return 0 ;;
      *) echo '[INFO] Choix invalide.'; sleep 1 ;;
    esac
  done
}

# Statut local de la clé API : on ne lit jamais la clé à l'écran.
# ✓ vert si un fichier régulier et non vide contient une valeur ; ✗ rouge sinon.
onef_api_key_status(){
  local keyfile="$ONEF_CFG/api.key" glyph color
  if [[ -f "$keyfile" && ! -L "$keyfile" && -s "$keyfile" ]] &&
     LC_ALL=C grep -q '[^[:space:]]' "$keyfile" 2>/dev/null; then
    glyph='✓'; color=$'\033[1;32m'
  else
    glyph='✗'; color=$'\033[1;31m'
  fi
  if (( UI_COLOR )); then
    printf '  \033[1;33m01 ▸\033[0m  %s%s\033[0m \033[0;37mClé API Premium\033[0m\n' "$color" "$glyph"
  else
    printf '  01 ▸  %s Clé API Premium\n' "$glyph"
  fi
}
onef_management_menu(){
  local opt
  while :; do
    refresh_screen
    ui_section '1FICHIER - GESTION'
    onef_api_key_status
    ui_item '2) Interface Web'
    onef_navigation
    opt="$(read_key 'Votre choix : ')" || return 0
    case "$opt" in
      1) python3 "$ONEF_BIN" configure; pause ;;
      2) onef_web_menu ;;
      0) return 0 ;;
      *) echo '[INFO] Choix invalide.'; sleep 1 ;;
    esac
  done
}

onef_menu(){
  local opt
  onef_installer || { pause; return 0; }
  while :; do
    refresh_screen
    ui_section '1FICHIER PREMIUM'
    ui_item '1) Gestion'
    ui_item '2) Téléchargements'
    onef_navigation
    opt="$(read_key 'Votre choix : ')" || return 0
    case "$opt" in
      1) onef_management_menu ;;
      2) onef_downloads_menu ;;
      0) return 0 ;;
      *) echo '[INFO] Choix invalide.'; sleep 1 ;;
    esac
  done
}
# Raccourci sans numéro : clic souris en xterm local, lien standard en SSH.
# En SSH, le clic est traité par le terminal du téléphone (pas par Bash).
ONEF_HOME_WEB_ROW=0
ONEF_HOME_MOUSE_ENABLED=0
onef_home_web_item(){
  ONEF_HOME_WEB_ROW=0
  [[ -f "$ONEF_WEB_DIR/installed" ]] || return 0
  local ip='' url='' response='' part=''
  ip="$(onef_local_ip)" || ip=''
  if [[ -n "$ip" ]]; then url="https://${ip}:8765/"; fi
  if [[ -n "${SSH_CONNECTION:-}${SSH_TTY:-}" ]]; then
    ui_print success '      ↳ Interface Web'
    # URL complète sans couleur ni séquence OSC 8 pour détecteurs Android.
    [[ -n "$url" ]] && printf '%s\n' "$url"
    return 0
  fi
  ui_print success '      ↳ Interface Web'
  # Demander au terminal la position du curseur juste après cette ligne.
  # La réponse CSI row;col R est récupérée avant toute saisie du menu.
  if [[ -t 0 && -w /dev/tty ]]; then
    printf '\033[6n' > /dev/tty
    while IFS= read -r -s -n 1 -t 0.18 part; do
      response+="$part"
      [[ "$part" == R || ${#response} -ge 24 ]] && break
    done
    if [[ "$response" =~ ^$'\033'\[([0-9]+)\;([0-9]+)R$ ]]; then
      ONEF_HOME_WEB_ROW=$((BASH_REMATCH[1] - 1))
    fi
  fi
}

onef_home_web_open(){
  local ip='' url='' pid=''
  if [[ ! -f "$ONEF_WEB_DIR/installed" ]]; then
    ui_print warning '  Module Web non installé : Gestion > Interface Web.'
    pause
    return 0
  fi
  if ! onef_web_responding; then
    if onef_web_running; then
      ui_print warning '  Service actif mais HTTPS indisponible.'
      pause
      return 0
    fi
    if ! confirm 'Serveur Web arrêté. Le démarrer ?'; then return 0; fi
    if [[ ! -f "$ONEF_WEB_DIR/cert.pem" || ! -f "$ONEF_WEB_DIR/key.pem" || ! -f "$ONEF_BIN" ]]; then
      ui_print error '  Certificat ou moteur absent : vérifier le module Web.'
      pause
      return 0
    fi
    python3 "$ONEF_BIN" web --bind 0.0.0.0 --port 8765 \
      --cert "$ONEF_WEB_DIR/cert.pem" --key "$ONEF_WEB_DIR/key.pem" \
      >"$ONEF_WEB_DIR/web.log" 2>&1 </dev/null &
    pid=$!
    echo "$pid" > "$ONEF_WEB_DIR/web.pid"
    sleep 1
    if ! onef_web_responding; then
      ui_print error '  HTTPS non confirmé : consulter Gestion > Interface Web.'
      pause
      return 0
    fi
  fi
  ip="$(onef_local_ip)" || ip=''
  if [[ -z "$ip" ]]; then
    ui_print warning '  Adresse IP locale indisponible.'
    pause
    return 0
  fi
  url="https://${ip}:8765/"
  # Pas de dépendance supplémentaire, navigateur Firefox officiel si installé.
  # L'URL reste affichée pour un accès depuis un téléphone ou un terminal SSH.
  if [[ -x /userdata/system/firefox-mozilla/firefox ]]; then
    (
      cd /userdata/system/firefox-mozilla || exit 1
      export HOME=/userdata/system MOZ_DISABLE_AUTO_SAFE_MODE=1
      nohup ./firefox --no-remote --new-window "$url" \
        >/tmp/blondin-1fichier-browser.log 2>&1 </dev/null &
    )
    ui_print success '  Ouverture demandée dans Firefox.'
  elif command -v xdg-open >/dev/null 2>&1; then
    nohup xdg-open "$url" >/tmp/blondin-1fichier-browser.log 2>&1 </dev/null &
    ui_print info '  Ouverture demandée dans le navigateur.'
  else
    ui_print warning '  Navigateur non disponible sur Batocera.'
  fi
  printf 'Lien: %s\n' "$url"
  pause
}

# ============= FIN MODULE 1FICHIER =============

# Ecran d'accueil : le bandeau reste seul a l'ecran jusqu'a une touche.
# La pause est reservee au lancement ; le fonctionnement des menus reste identique.
refresh_screen
ui_banner
ui_print gold '  ★ Appuyer sur une touche  ★  '
ui_print gold '     pour acceder au menu'
if [[ -t 0 ]]; then
  IFS= read -r -s -n 1 _startup_key || true
else
  IFS= read -r _startup_key || true
fi

while :; do
  refresh_screen
  ui_banner
  ui_section 'MENU PRINCIPAL'
  UI_MAIN_MENU=1
  ui_item '1) Installation'
  ui_item '2) Gestion'
  ui_item '3) Logiciels'
  ui_item '4) Syncthing'
  ui_item '5) Batocera commande'
  ui_item '6) 1fichier Premium'
  onef_home_web_item
  echo
  ui_item '0) Quitter'
  UI_MAIN_MENU=0
  ui_print info '  ────────────────────────────────────────'
  ui_print success '  ● PRÊT'
  echo
  # Activer la détection du clic uniquement sur le menu d'accueil local.
  ONEF_HOME_MOUSE_ENABLED=0
  if [[ -z "${SSH_CONNECTION:-}${SSH_TTY:-}" && "${ONEF_HOME_WEB_ROW:-0}" -gt 0 && -t 0 && -w /dev/tty ]]; then
    printf '\033[?1000h\033[?1006h' > /dev/tty
    ONEF_HOME_MOUSE_ENABLED=1
  fi
  choice="$(read_key 'Votre choix : ')" || { [[ "$ONEF_HOME_MOUSE_ENABLED" == 1 ]] && printf '\033[?1000l\033[?1006l' > /dev/tty; break; }
  if [[ "$ONEF_HOME_MOUSE_ENABLED" == 1 ]]; then
    printf '\033[?1000l\033[?1006l' > /dev/tty
    ONEF_HOME_MOUSE_ENABLED=0
  fi
  case "$choice" in
    1) installation_menu ;;
    2) gestion_menu ;;
    3) logiciels_menu ;;
    4) syncthing_menu ;;
    5) batocera_command_menu ;;
    6) onef_menu ;;
    __WEB_CLICK__|w|W) onef_home_web_open ;;
    0|q|Q) break ;;
    *) echo 'Choix invalide.' ;;
  esac
done

: # Le message de fermeture est affiche par le trap EXIT.
