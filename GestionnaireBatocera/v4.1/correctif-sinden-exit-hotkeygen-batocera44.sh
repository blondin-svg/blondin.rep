#!/bin/sh
# Correctif Batocera 44 : Sinden bouton avant droit + gachette 2 s.
# Conserve la detection des boutons, le service existant et le volume.
# Corrige la sortie pour les contextes hotkeygen (Windows Arcade Loader, etc.).
# Sauvegarde et restauration incluses.
set -eu
BASE=/userdata/system
APP="$BASE/sinden-exit-combo.py"
BACKUP="$BASE/sinden-exit-combo.py.bak-avant-hotkeygen"
NAME=sinden_exit_combo
SERVICE="$BASE/services/$NAME"

if [ "${1:-}" = "--restore" ]; then
    if [ ! -f "$BACKUP" ]; then
        echo "Aucune sauvegarde a restaurer : $BACKUP" >&2
        exit 1
    fi
    batocera-services stop "$NAME" || true
    cp -p "$BACKUP" "$APP"
    chmod 755 "$APP"
    batocera-services start "$NAME"
    echo "Version precedente restauree. Service relance."
    exit 0
fi

if [ ! -f "$APP" ] || [ ! -f "$SERVICE" ]; then
    echo "Service Sinden introuvable : installe d'abord la version actuelle." >&2
    exit 1
fi
if ! command -v hotkeygen >/dev/null 2>&1; then
    echo "Commande hotkeygen introuvable." >&2
    exit 1
fi

# Prepare, controle et sauvegarde le script avant tout arret du service.
python3 - "$APP" "$BACKUP" <<'PY'
import ast
import os
import pathlib
import shutil
import sys

app = pathlib.Path(sys.argv[1])
backup = pathlib.Path(sys.argv[2])
source = app.read_text(encoding='utf-8')
marker = '# SINDEN_HOTKEYGEN_CORRECTIF_V2'
if marker in source:
    print('Correctif deja installe.')
    sys.exit(0)
try:
    start = source.index('\ndef exit_game():') + 1
    end = source.index('\ndef monitor(', start) + 1
except ValueError:
    sys.exit('Version du script Sinden non reconnue. Aucune modification.')

replacement = '''# SINDEN_HOTKEYGEN_CORRECTIF_V2

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


'''
updated = source[:start] + replacement + source[end:]
ast.parse(updated, filename=str(app))
if not backup.exists():
    shutil.copy2(app, backup)
    print('Sauvegarde creee :', backup)
path = app.with_name(app.name + '.hotkeygen-new')
path.write_text(updated, encoding='utf-8')
os.chmod(path, 0o755)
print('Script corrige et valide :', path)
PY

if [ -f "$APP.hotkeygen-new" ]; then
    batocera-services stop "$NAME" || true
    mv -f "$APP.hotkeygen-new" "$APP"
    chmod 755 "$APP"
    if ! batocera-services start "$NAME"; then
        echo "Echec de redemarrage. Restauration automatique." >&2
        cp -p "$BACKUP" "$APP"
        batocera-services start "$NAME" || true
        exit 1
    fi
fi

echo "Correctif applique. Combinaison inchangee : avant droit + gachette, 2 secondes."
echo "Pour lire le journal : tail -n 25 /userdata/system/logs/sinden-exit-combo.log"
echo "Pour revenir en arriere : sh $0 --restore"
