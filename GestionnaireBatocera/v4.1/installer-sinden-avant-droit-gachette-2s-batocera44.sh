#!/bin/sh
# Batocera 44 — Sinden Lightgun : bouton avant droit + gachette (2 s) = sortir du jeu.
# Ne change pas les mappings Batocera, EmulationStation, ni les autres services.
set -eu
BASE=/userdata/system
NAME=sinden_exit_combo
APP="$BASE/sinden-exit-combo.py"
SERVICE="$BASE/services/$NAME"
LOG="$BASE/logs/sinden-exit-combo.log"
PIDFILE=/var/run/sinden_exit_combo.pid

if [ "${1:-}" = '--uninstall' ]; then
  if command -v batocera-services >/dev/null 2>&1; then
    batocera-services stop "$NAME" 2>/dev/null || true
    batocera-services disable "$NAME" 2>/dev/null || true
  elif [ -x "$SERVICE" ]; then
    "$SERVICE" stop || true
  fi
  rm -f "$SERVICE" "$APP" "$PIDFILE"
  echo 'Service sinden_exit_combo desinstalle. Aucun autre service modifie.'
  echo "Journal conserve : $LOG"
  exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo 'ERREUR : Python 3 est introuvable.' >&2
  exit 1
fi
if ! command -v batocera-services >/dev/null 2>&1; then
  echo 'ERREUR : batocera-services est introuvable.' >&2
  exit 1
fi
if ! command -v batocera-es-swissknife >/dev/null 2>&1; then
  echo 'ERREUR : batocera-es-swissknife est introuvable.' >&2
  exit 1
fi
mkdir -p "$BASE/services" "$BASE/logs"

cat > "$APP.tmp" <<'PY'
#!/usr/bin/env python3
"""Batocera 44 — Sinden avant droit + gâchette pendant 2 s = quitter le jeu.

Lecture PASSIVE des evenements evdev : aucun grab et aucun remapping des boutons.
Gestion des boutons physiques (KEY_1 / BTN_LEFT) ou virtuels Batocera
(BTN_1 / BTN_LEFT). Prefere les peripheriques virtuels Sinden lorsqu'ils existent.
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
KEY_1 = 2                 # Bouton avant droit sur l'interface clavier Sinden
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
    found = []
    for path in sorted(glob.glob('/dev/input/event*')):
        try:
            with open('/sys/class/input/' + os.path.basename(path) + '/device/name',
                      encoding='utf-8', errors='replace') as f:
                name = f.read().strip()
        except OSError:
            continue
        if 'sinden' in name.casefold():
            # evsieve crée habituellement un périphérique virtuel « Sinden lightgun ».
            is_virtual = name.casefold().startswith('sinden lightgun')
            group = ('virtual:' + path) if is_virtual else usb_group(path)
            found.append((path, name, group, is_virtual))
    if any(d[3] for d in found):
        found = [d for d in found if d[3]]  # Évite des doubles appuis brut+virtuel.
    return found


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


def exit_game():
    if not emulator_running():
        log('Combinaison détectée, aucun émulateur en cours : aucune action.')
        return
    log('2 secondes détectées : demande de fermeture de l’émulateur.')
    try:
        subprocess.Popen(['batocera-es-swissknife', '--emukill'],
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True)
    except OSError as exc:
        log('Erreur lors de la fermeture : %s' % exc)


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
PY

# Vérifier le nouveau code AVANT d'arrêter le service en place.
python3 -m py_compile "$APP.tmp"

if [ -e "$SERVICE" ]; then
  batocera-services stop "$NAME" 2>/dev/null || "$SERVICE" stop 2>/dev/null || true
fi
mv -f "$APP.tmp" "$APP"
chmod 755 "$APP"
cat > "$SERVICE" <<'SVC'
#!/bin/sh
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
SVC
chmod 755 "$SERVICE"
batocera-services enable "$NAME"
batocera-services start "$NAME"

printf '\nINSTALLATION TERMINEE — Batocera 44\n'
printf 'Quitter un jeu : bouton AVANT DROIT + GACHETTE maintenus 2 secondes.\n'
printf 'Sinden detecte(s) :\n'
python3 "$APP" --devices || true
printf '\nCommandes utiles :\n'
printf '  batocera-services status %s\n' "$NAME"
printf '  tail -n 40 %s\n' "$LOG"
printf '  batocera-services stop %s\n' "$NAME"
printf '  python3 %s --test\n' "$APP"
printf '  batocera-services start %s\n' "$NAME"
printf '\nDesinstallation : sh %s --uninstall\n' "$0"
