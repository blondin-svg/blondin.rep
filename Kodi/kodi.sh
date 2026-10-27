#!/bin/bash
# Lanceur Kodi autonome pour Batocera (Ports).
# Phase 1 : libere le lanceur Ports en demarrant une copie detachee de ce fichier.
if [[ "${1:-}" != '--kodi-detached' ]]; then
    python3 - "$0" <<'PY'
import os
import subprocess
import sys

launcher = os.path.realpath(sys.argv[1])
with open('/tmp/kodi-detache-v5.log', 'ab', buffering=0) as log:
    subprocess.Popen(
        ['/bin/bash', launcher, '--kodi-detached'],
        stdin=subprocess.DEVNULL,
        stdout=log,
        stderr=subprocess.STDOUT,
        start_new_session=True,
        close_fds=True,
    )
PY
    exit $?
fi

# Phase 2 : dans le processus detache, attendre la fin du lanceur Ports.
LOG='/tmp/kodi-detache-test.log'
echo "$(date) - Demande de lancement Kodi" >> "$LOG"
for i in $(seq 1 30); do
    if ! pgrep -f '^/usr/bin/python /usr/bin/batocera-launch .* -system ports ' >/dev/null; then
        break
    fi
    sleep 1
done
if pgrep -f '^/usr/bin/python /usr/bin/batocera-launch .* -system ports ' >/dev/null; then
    echo "$(date) - ERREUR : Ports toujours actif" >> "$LOG"
    exit 1
fi

echo "$(date) - Lancement natif de Kodi" >> "$LOG"
/usr/bin/batocera-es-swissknife --kodi >> "$LOG" 2>&1
echo "$(date) - Fin de Kodi" >> "$LOG"
