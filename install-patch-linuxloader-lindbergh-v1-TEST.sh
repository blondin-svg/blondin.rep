#!/bin/bash
# Gestionnaire Batocera ★ BLONDIN EDITION ★
# Installer / vérifier / désinstaller le patch LinuxLoader - Lindbergh, Batocera 44.
set -euo pipefail

MODE="${1:-install}"
TARGET='/userdata/system/scripts/blondin-linuxloader-lindbergh.sh'
STATE_DIR='/userdata/system/blondin-linuxloader-patch'
LEGACY_DIR="$STATE_DIR/anciens-scripts-rambo"
MANIFEST="$STATE_DIR/anciens-scripts-rambo.txt"
LOG='/userdata/system/logs/correctif-linuxloader-lindbergh.log'
SOURCE_URL='https://raw.githubusercontent.com/blondin-svg/blondin.rep/main/CorrectifsLinuxLoader/patch-linuxloader-lindbergh-v1-TEST.sh'
EXPECTED_SHA256='b3246b1543d86ec210ece41301364a263c5e7b8df1a49043713d6cbcc54ef7f4'

say(){ printf '%s\n' "$*"; }
valid_patch(){
  [[ -f "$TARGET" && ! -L "$TARGET" && -x "$TARGET" ]] || return 1
  printf '%s  %s\n' "$EXPECTED_SHA256" "$TARGET" | sha256sum -c - >/dev/null 2>&1
}
status(){
  if valid_patch; then
    say '[OK] Correctif LinuxLoader/Lindbergh actif et intègre.'
  elif [[ -e "$TARGET" || -L "$TARGET" ]]; then
    say '[ATTENTION] Hook present mais non conforme.'
  else
    say '[INFO] Correctif non installe.'
  fi
  [[ -f "$MANIFEST" ]] && say '[INFO] Ancien hook RAMBO conserve en sauvegarde.'
  [[ -f "$LOG" ]] && { say '[INFO] Dernieres operations :'; tail -n 8 "$LOG"; }
}
case "$MODE" in
  status|verify|verifier) status; exit 0 ;;
  logs|journal) if [[ -f "$LOG" ]]; then tail -n 25 "$LOG"; else say '[INFO] Aucun journal.'; fi; exit 0 ;;
  install|uninstall) ;;
  *) say 'Usage : bash install-patch-linuxloader-lindbergh-v1-TEST.sh [install|status|logs|uninstall]' >&2; exit 2 ;;
esac

[[ "$(id -u)" -eq 0 ]] || { say '[ERREUR] Executer en root.' >&2; exit 1; }
for path in "$STATE_DIR" "$LEGACY_DIR" '/userdata/system/scripts' '/userdata/system/configs/emulationstation/scripts'; do
  [[ ! -L "$path" ]] || { say "[SECURITE] Lien symbolique interdit : $path" >&2; exit 1; }
done
[[ ! -L "$TARGET" && ! -L "$MANIFEST" ]] || { say '[SECURITE] Cible ou manifeste symbolique.' >&2; exit 1; }
mkdir -p -- "$STATE_DIR" "$LEGACY_DIR" '/userdata/system/scripts'

if [[ "$MODE" == uninstall ]]; then
  if [[ -e "$TARGET" ]]; then
    valid_patch || { say '[ATTENTION] Hook modifie : desinstallation refusee pour eviter de supprimer un fichier inconnu.'; exit 1; }
    rm -f -- "$TARGET"
    say '[OK] Hook LinuxLoader/Lindbergh desinstalle.'
  else
    say '[INFO] Hook deja absent.'
  fi
  # Restaurer les anciens scripts RAMBO deplaces lors de l'installation.
  if [[ -f "$MANIFEST" ]]; then
    while IFS='|' read -r old saved; do
      [[ -n "$old" && -n "$saved" ]] || continue
      case "$old" in
        /userdata/system/configs/emulationstation/scripts/gameStart/nettoyage-rambo.sh|/userdata/system/configs/emulationstation/scripts/game-start/nettoyage-rambo.sh) ;;
        *) say "[ATTENTION] Chemin de restauration inattendu : $old"; continue ;;
      esac
      case "$saved" in "$LEGACY_DIR"/*) ;; *) continue ;; esac
      if [[ -f "$saved" && ! -L "$saved" && ! -e "$old" && ! -L "$old" ]]; then
        mkdir -p -- "$(dirname "$old")"
        mv -- "$saved" "$old"
        say "[OK] Ancien hook RAMBO restaure : $old"
      else
        say "[ATTENTION] Restauration manuelle necessaire : $old"
      fi
    done < "$MANIFEST"
    rm -f -- "$MANIFEST"
  fi
  say '[INFO] Journaux et sauvegardes des fichiers INI conserves.'
  exit 0
fi

if [[ ! -r /etc/os-release ]] || ! grep -qi 'batocera' /etc/os-release || ! grep -Eq '(^|[^0-9])44([^0-9]|$)' /etc/os-release; then
  say '[ERREUR] Ce correctif est reserve a Batocera 44.' >&2
  exit 1
fi
command -v curl >/dev/null || { say '[ERREUR] curl absent.' >&2; exit 1; }
command -v sha256sum >/dev/null || { say '[ERREUR] sha256sum absent.' >&2; exit 1; }
if valid_patch; then
  say '[OK] Correctif deja installe, verification des anciens hooks RAMBO.'
else
  [[ ! -e "$TARGET" || -f "$TARGET" ]] || { say '[SECURITE] Cible inattendue.' >&2; exit 1; }
  tmp="$(mktemp '/userdata/system/scripts/.blondin-linuxloader.XXXXXX')"
  trap 'rm -f -- "${tmp:-}"' EXIT
  curl --fail --location --silent --show-error --retry 2 --connect-timeout 10 --max-time 60 "$SOURCE_URL" -o "$tmp"
  printf '%s  %s\n' "$EXPECTED_SHA256" "$tmp" | sha256sum -c - >/dev/null || { say '[ERREUR] Empreinte GitHub invalide.' >&2; exit 1; }
  bash -n "$tmp"
  if [[ -e "$TARGET" ]]; then
    previous="$STATE_DIR/hook-precedent-$(date '+%Y%m%d-%H%M%S')-$$.sh"
    cp -p -- "$TARGET" "$previous"
    cmp -s -- "$TARGET" "$previous" || { say '[ERREUR] Sauvegarde du hook impossible.' >&2; exit 1; }
    say "[INFO] Ancien hook sauvegarde : $previous"
  fi
  chmod 755 "$tmp"
  mv -f -- "$tmp" "$TARGET"
  trap - EXIT
  say "[OK] Hook installe : $TARGET"
fi

# L'ancien script RAMBO effaçait tout le dossier LinuxLoader, dont controls.ini.
# Ne neutraliser que le script reconnu, et toujours le sauvegarder.
for old in \
 '/userdata/system/configs/emulationstation/scripts/gameStart/nettoyage-rambo.sh' \
 '/userdata/system/configs/emulationstation/scripts/game-start/nettoyage-rambo.sh'; do
  [[ -e "$old" || -L "$old" ]] || continue
  if [[ -L "$old" || ! -f "$old" ]]; then
    say "[ATTENTION] Ancien hook inhabituel, non modifie : $old"; continue
  fi
  if ! grep -Fq "DOSSIER='/userdata/system/configs/linuxloader'" "$old" || ! grep -Fq 'nettoyage-rambo.log' "$old"; then
    say "[ATTENTION] Script RAMBO different, non modifie : $old"; continue
  fi
  saved="$LEGACY_DIR/$(basename "$(dirname "$old")")-nettoyage-rambo-$(date '+%Y%m%d-%H%M%S')-$$.sh"
  cp -p -- "$old" "$saved"
  cmp -s -- "$old" "$saved" || { say '[ERREUR] Sauvegarde RAMBO echouee.' >&2; exit 1; }
  rm -f -- "$old"
  printf '%s|%s\n' "$old" "$saved" >> "$MANIFEST"
  say '[OK] Ancien hook RAMBO neutralise et sauvegarde.'
done

status
say '[INFO] Le correctif agira au prochain lancement Lindbergh, pas pendant cette installation.'
