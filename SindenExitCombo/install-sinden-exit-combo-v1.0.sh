#!/bin/sh
# BLONDIN SINDEN EXIT COMBO V1.0 - BATOCERA 44
# Autonome : bouton avant droit (code 3) + gachette (code 272), maintien 2s.
# Compatible avec hotkeygen, Windows Arcade Loader et LinuxLoader.
# Ne modifie pas Volume Hotkey ni les configurations manettes.
set -eu
BASE=/userdata/system
NAME=sinden_exit_combo
APP="$BASE/sinden-exit-combo.py"
SERVICE="$BASE/services/$NAME"
LOG="$BASE/logs/sinden-exit-combo.log"
PIDFILE=/var/run/sinden_exit_combo.pid
BACKUP="$BASE/sinden-exit-combo-backups"
fail(){ echo "[ERREUR] $*" >&2; exit 1; }
known_install(){
  [ -s "$APP" ] && [ -f "$SERVICE" ] && [ ! -L "$APP" ] && [ ! -L "$SERVICE" ] &&
  { grep -Fq SINDEN_PHYSICAL_PAIR_REAL_CODES_V1 "$APP" || grep -Fq BLONDIN_SINDEN_EXIT_COMBO_V1_0 "$APP"; } &&
  grep -Fq sinden-exit-combo.py "$SERVICE"
}
if [ "${1:-}" = '--restore' ]; then
  [ -f "$BACKUP/last.py" ] && [ -f "$BACKUP/last.service" ] || fail 'Aucune sauvegarde a restaurer.'
  batocera-services stop "$NAME" || true
  cp -p "$BACKUP/last.py" "$APP" || fail 'Restauration du programme impossible.'
  cp -p "$BACKUP/last.service" "$SERVICE" || fail 'Restauration du service impossible.'
  batocera-services enable "$NAME" || fail 'Activation impossible.'
  batocera-services start "$NAME" || fail 'Demarrage impossible.'
  echo '[OK] Version precedente restauree.'
  exit 0
fi
if [ "${1:-}" = '--uninstall' ]; then
  known_install || fail 'Service absent ou inconnu : rien a supprimer.'
  mkdir -p "$BACKUP"
  cp -p "$APP" "$BACKUP/uninstall.py" || fail 'Sauvegarde Python impossible.'
  cp -p "$SERVICE" "$BACKUP/uninstall.service" || fail 'Sauvegarde service impossible.'
  batocera-services disable "$NAME" || fail 'Desactivation impossible.'
  batocera-services stop "$NAME" || fail 'Arret impossible.'
  rm -f "$APP" "$SERVICE" "$PIDFILE"
  echo '[OK] Sinden Exit Combo desinstalle. Sauvegardes et journal conserves.'
  exit 0
fi
[ "${1:-}" = '' ] || [ "${1:-}" = 'install' ] || fail 'Usage : install | --restore | --uninstall'
[ "$(id -u)" -eq 0 ] || fail 'Root requis.'
[ -r /etc/os-release ] && grep -qi batocera /etc/os-release || fail 'Batocera requis.'
grep -Eq '(^|[^0-9])44([^0-9]|$)' /etc/os-release || fail 'Batocera 44 requis.'
for cmd in python3 batocera-services hotkeygen batocera-es-swissknife; do
  command -v "$cmd" >/dev/null 2>&1 || fail "Commande manquante : $cmd"
done
for item in "$APP" "$SERVICE"; do
  [ ! -L "$item" ] || fail "Lien symbolique interdit : $item"
  [ ! -e "$item" ] || [ -f "$item" ] || fail "Fichier special interdit : $item"
done
if [ -e "$APP" ] || [ -e "$SERVICE" ]; then
  known_install || fail 'Installation inconnue ou incomplete. Aucune modification.'
fi
mkdir -p "$BASE/services" "$BASE/logs" "$BACKUP"
newpy="$(mktemp "$BASE/.sinden-exit.XXXXXX")" || fail 'Temporaire indisponible.'
newservice="$(mktemp "$BASE/services/.sinden-exit.XXXXXX")" || fail 'Temporaire indisponible.'
trap 'rm -f "$newpy" "$newservice"' EXIT HUP INT TERM
cat > "$newpy" <<'SINDEN_PY'
#!/usr/bin/env python3
"""Batocera 44 — Sinden avant droit + gâchette pendant 2 s = quitter le jeu.

BLONDIN_SINDEN_EXIT_COMBO_V1_0
Lecture PASSIVE des evenements evdev : aucun grab et aucun remapping.
Surveille le clavier physique Sinden (code 3) et sa souris physique (272).
"""
import glob
import os
import re
import select
import signal
import struct
import subprocess
import sys
import time
from datetime import datetime

EV_KEY = 1
KEY_1 = 3                 # Bouton avant droit reel KEY_2 : code 3
BTN_1 = 257               # Même bouton, interface virtuelle Batocera
BTN_LEFT = 272            # Gâchette (clic gauche)
HOLD_SECONDS = 2.0
RESCAN_SECONDS = 2.0
EVENT = struct.Struct('@llHHi')  # struct input_event Linux, architecture native


def log(message):
    print(datetime.now().strftime('%Y-%m-%d %H:%M:%S') + ' | ' + message, flush=True)


def usb_group(path):
    """Rattache clavier et souris physiques d'un même pistolet USB."""
    real = os.path.realpath('/sys/class/input/' + os.path.basename(path) + '/device')
    usb_segments = [s for s in real.split('/') if re.fullmatch(r'\d+-\d+(?:\.\d+)*', s)]
    return ('usb:' + usb_segments[-1]) if usb_segments else ('path:' + path)



def find_devices():
    # SINDEN_PHYSICAL_PAIR_REAL_CODES_V1
    # Clavier Sinden (code 3) + souris Sinden (code 272) du meme USB.
    # L'interface virtuelle event17 n'envoie pas les 2 boutons observes.
    found = []
    for path in sorted(glob.glob('/dev/input/event*')):
        try:
            with open('/sys/class/input/' + os.path.basename(path) + '/device/name',
                      encoding='utf-8', errors='replace') as f:
                name = f.read().strip()
        except OSError:
            continue
        if 'sinden' not in name.casefold():
            continue
        is_virtual = name.casefold().startswith('sinden lightgun')
        group = ('virtual:' + path) if is_virtual else usb_group(path)
        found.append((path, name, group, is_virtual))

    physical = [d for d in found if not d[3]]
    grouped = {}
    for d in physical:
        grouped.setdefault(d[2], []).append(d)
    complete_groups = set()
    for group, entries in grouped.items():
        names = [d[1].casefold() for d in entries]
        if any('keyboard' in name for name in names) and any('mouse' in name for name in names):
            complete_groups.add(group)

    if complete_groups:
        # Un groupe = un pistolet ; jamais de combinaison entre 2 Sinden.
        return [d for d in physical if d[2] in complete_groups]

    # Secours pour un seul pistolet dont les interfaces ont des chemins USB
    # atypiques ; pas de fusion si plusieurs claviers ou souris sont detectes.
    keyboards = [d for d in physical if 'keyboard' in d[1].casefold()]
    mice = [d for d in physical if 'mouse' in d[1].casefold()]
    if len(keyboards) == 1 and len(mice) == 1:
        return [(d[0], d[1], 'sinden-physique-unique', d[3])
                for d in (keyboards[0], mice[0])]

    # Sans paire physique identifiable, ne pas lancer de fausse combinaison.
    return []


def emulator_running():
    """Commande officielle Batocera ; n'agit pas depuis EmulationStation seul."""
    try:
        done = subprocess.run(['batocera-es-swissknife', '--emupid'],
                              text=True, stdout=subprocess.PIPE,
                              stderr=subprocess.DEVNULL, timeout=4, check=False)
        output = done.stdout.split()
        return done.returncode == 0 and bool(output) and output[0].isdigit() and int(output[0]) > 0
    except (OSError, subprocess.TimeoutExpired):
        return False


# SINDEN_HOTKEYGEN_CORRECTIF_V2

def hotkey_exit_context():
    """Retourne le contexte hotkeygen seulement s'il dispose d'une action exit."""
    try:
        info = subprocess.run(['hotkeygen', '--list'], stdout=subprocess.PIPE,
                              stderr=subprocess.DEVNULL, text=True, timeout=5,
                              check=False)
        if info.returncode != 0:
            return None
        match = re.search(r'(?m)^Context\\s+\\[([^\\]]+)\\]:', info.stdout)
        if not match:
            return None
        context = match.group(1).strip().lower()
        if context in ('emulationstation', 'default', 'none'):
            return None
        if re.search(r'(?m)^\\s*exit-+>', info.stdout) is None:
            return None
        return context
    except (OSError, subprocess.TimeoutExpired):
        return None


def exit_game():
    """Respecte d'abord l'action de sortie du jeu defini par hotkeygen."""
    context = hotkey_exit_context()
    if context:
        log('2 secondes detectees : sortie hotkeygen (contexte ' + context + ').')
        try:
            subprocess.Popen(['hotkeygen', '--send', 'exit'],
                             stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL, start_new_session=True)
        except OSError as exc:
            log('Erreur hotkeygen : %s' % exc)
        return

    if emulator_running():
        log('2 secondes detectees : sortie avec batocera-es-swissknife.')
        try:
            subprocess.Popen(['batocera-es-swissknife', '--emukill'],
                             stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL, start_new_session=True)
        except OSError as exc:
            log('Erreur de fermeture : %s' % exc)
        return

    log('2 secondes detectees, mais aucun contexte de jeu pris en charge : aucune fermeture.')


def monitor(test_mode=False):
    opened = {}  # fd: (path, name, group)
    partial = {}  # fd: octets incomplets (au besoin)
    pressed = set()  # (group, path, code), pas de prise de controle exclusive
    started = {}  # group: moment où les 2 boutons sont appuyés
    triggered = set()
    next_scan = 0.0
    log('Démarrage Sinden avant droit + gâchette, maintien 2.0 s' +
        (' [TEST — aucune fermeture]' if test_mode else ''))
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    try:
        while True:
            now = time.monotonic()
            if now >= next_scan:
                wanted = find_devices()
                current = [(p, n, g) for p, n, g in opened.values()]
                if sorted(current) != sorted([(p, n, g) for p, n, g, _ in wanted]):
                    for fd in opened:
                        try:
                            os.close(fd)
                        except OSError:
                            pass
                    opened.clear()
                    partial.clear()
                    pressed.clear()
                    started.clear()
                    triggered.clear()
                    for path, name, group, _ in wanted:
                        try:
                            fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
                            opened[fd] = (path, name, group)
                            partial[fd] = b''
                        except OSError as exc:
                            log('Impossible de lire %s : %s' % (path, exc))
                    label = ', '.join('%s (%s)' % (p, n) for p, n, _, _ in wanted)
                    log('Périphériques : ' + (label if label else 'aucun Sinden trouvé'))
                next_scan = now + RESCAN_SECONDS
            if not opened:
                time.sleep(0.2)
                continue
            try:
                readable, _, _ = select.select(list(opened), [], [], 0.05)
            except (OSError, ValueError):
                next_scan = 0.0
                for fd in opened:
                    try:
                        os.close(fd)
                    except OSError:
                        pass
                opened.clear()
                continue
            failed = False
            for fd in readable:
                try:
                    buffer = partial[fd] + os.read(fd, EVENT.size * 64)
                    if not buffer:
                        failed = True
                        continue
                    count = len(buffer) // EVENT.size
                    partial[fd] = buffer[count * EVENT.size:]
                    path, name, group = opened[fd]
                    for i in range(count):
                        _, _, kind, code, value = EVENT.unpack_from(buffer, i * EVENT.size)
                        if kind != EV_KEY or value not in (0, 1):
                            continue
                        if test_mode and code in (KEY_1, BTN_1, BTN_LEFT):
                            log('%s %s code=%s %s' %
                                (name, path, code, 'appuyé' if value else 'relâché'))
                        if code not in (KEY_1, BTN_1, BTN_LEFT):
                            continue
                        token = (group, path, code)
                        if value == 1:
                            pressed.add(token)
                        else:
                            pressed.discard(token)
                except OSError:
                    failed = True
            if failed:
                for fd in opened:
                    try:
                        os.close(fd)
                    except OSError:
                        pass
                opened.clear()
                next_scan = 0.0
                pressed.clear()
                started.clear()
                triggered.clear()
                continue
            groups = {item[2] for item in opened.values()}
            now = time.monotonic()
            for group in groups:
                front = any(g == group and c in (KEY_1, BTN_1) for g, _, c in pressed)
                trigger = any(g == group and c == BTN_LEFT for g, _, c in pressed)
                if not (front and trigger):
                    started.pop(group, None)
                    triggered.discard(group)
                    continue
                if group not in started:
                    started[group] = now
                if group not in triggered and now - started[group] >= HOLD_SECONDS:
                    triggered.add(group)
                    if test_mode:
                        log('OK — avant droit + gâchette maintenus 2 secondes')
                    else:
                        exit_game()
    except KeyboardInterrupt:
        return 0
    finally:
        for fd in opened:
            try:
                os.close(fd)
            except OSError:
                pass


if __name__ == '__main__':
    if '--devices' in sys.argv:
        entries = find_devices()
        for path, name, group, is_virtual in entries:
            print('%s | %s | %s' % (path, name, group))
        if not entries:
            print('Aucun Sinden détecté dans /dev/input/event*')
        sys.exit(0 if entries else 1)
    sys.exit(monitor('--test' in sys.argv))
SINDEN_PY
python3 -m py_compile "$newpy" || fail 'Code Python invalide.'
cat > "$newservice" <<'SINDEN_SERVICE'
#!/bin/sh
# BLONDIN_SINDEN_EXIT_COMBO_SERVICE_V1_0
PY=/userdata/system/sinden-exit-combo.py
LOG=/userdata/system/logs/sinden-exit-combo.log
PIDFILE=/var/run/sinden_exit_combo.pid
case "${1:-}" in
  start)
    if [ -f "$PIDFILE" ]; then
      PID=$(cat "$PIDFILE" 2>/dev/null || true)
      if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null && \
         tr '\0' ' ' < "/proc/$PID/cmdline" 2>/dev/null | grep -q 'sinden-exit-combo.py'; then
        exit 0
      fi
      rm -f "$PIDFILE"
    fi
    nohup python3 -u "$PY" >> "$LOG" 2>&1 </dev/null &
    echo "$!" > "$PIDFILE"
    ;;
  stop)
    if [ -f "$PIDFILE" ]; then
      PID=$(cat "$PIDFILE" 2>/dev/null || true)
      if [ -n "$PID" ] && [ -e "/proc/$PID/cmdline" ] && \
         tr '\0' ' ' < "/proc/$PID/cmdline" | grep -q 'sinden-exit-combo.py'; then
        kill "$PID" 2>/dev/null || true
      fi
      rm -f "$PIDFILE"
    fi
    ;;
  status)
    if [ -f "$PIDFILE" ]; then
      PID=$(cat "$PIDFILE" 2>/dev/null || true)
      if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
        echo 'Sinden Exit Combo : actif (avant droit + gachette, 2s)'
        exit 0
      fi
    fi
    echo 'Sinden Exit Combo : arrete'
    exit 1
    ;;
  *) echo 'Usage : start | stop | status' >&2; exit 2 ;;
esac
SINDEN_SERVICE
sh -n "$newservice" || fail 'Code service invalide.'
chmod 755 "$newpy" "$newservice"
if [ -f "$APP" ] && [ -f "$SERVICE" ]; then
  cp -p "$APP" "$BACKUP/last.py" || fail 'Sauvegarde Python impossible.'
  cp -p "$SERVICE" "$BACKUP/last.service" || fail 'Sauvegarde service impossible.'
  batocera-services stop "$NAME" || fail 'Arret du service precedent impossible.'
fi
mv -f "$newpy" "$APP" || fail 'Installation programme impossible.'
mv -f "$newservice" "$SERVICE" || {
  [ ! -f "$BACKUP/last.service" ] || cp -p "$BACKUP/last.service" "$SERVICE"
  [ ! -f "$BACKUP/last.py" ] || cp -p "$BACKUP/last.py" "$APP"
  fail 'Installation service impossible.'
}
if ! batocera-services enable "$NAME" || ! batocera-services start "$NAME"; then
  [ ! -f "$BACKUP/last.service" ] || cp -p "$BACKUP/last.service" "$SERVICE"
  [ ! -f "$BACKUP/last.py" ] || cp -p "$BACKUP/last.py" "$APP"
  [ ! -f "$BACKUP/last.py" ] || batocera-services start "$NAME" || true
  fail 'Demarrage impossible. Ancienne version restauree si disponible.'
fi
echo '[OK] Sinden Exit Combo v1.0 installe : bouton avant droit + gachette (2 secondes).'
python3 "$APP" --devices || true
batocera-services status "$NAME" || true
