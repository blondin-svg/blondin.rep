#!/bin/sh
# Batocera 44 : correctif Sinden Lightgun basé sur codes observes par evdev.
# Bouton avant droit: event clavier EV_KEY code 3 (KEY_2)
# Gachette: event souris EV_KEY code 272 (BTN_LEFT)
# Preserve hotkeygen, service, volume, mappings et duree de 2 secondes.
set -eu

BASE=/userdata/system
APP="$BASE/sinden-exit-combo.py"
SERVICE="$BASE/services/sinden_exit_combo"
NAME=sinden_exit_combo
BACKUP="$BASE/sinden-exit-combo.py.bak-avant-boutons-reels"
NEW="$APP.physical-new"

restore() {
    if [ ! -f "$BACKUP" ]; then
        echo "Sauvegarde absente : $BACKUP" >&2
        exit 1
    fi
    batocera-services stop "$NAME" || true
    cp -p "$BACKUP" "$APP"
    chmod 755 "$APP"
    batocera-services start "$NAME"
    echo "Version precedente restauree ; service relance."
}

if [ "${1:-}" = '--restore' ]; then
    restore
    exit 0
fi

if [ ! -f "$APP" ] || [ ! -f "$SERVICE" ]; then
    echo 'Service Sinden absent : aucune modification.' >&2
    exit 1
fi

python3 - "$APP" "$BACKUP" "$NEW" <<'PY'
import ast
import pathlib
import re
import shutil
import sys

app, backup, new_file = (pathlib.Path(s) for s in sys.argv[1:4])
source = app.read_text(encoding='utf-8')
marker = '# SINDEN_PHYSICAL_PAIR_REAL_CODES_V1'
if marker in source:
    print('Ce correctif est deja installe : aucune modification.')
    sys.exit(0)

# N'effectuer l'installation que sur le service deja adapte a hotkeygen.
if "['hotkeygen', '--send', 'exit']" not in source:
    sys.exit('Le script actuel ne contient pas hotkeygen --send exit : arret sans modification.')

# Ne pas faire de substitution sur une version differente du script.
pattern = re.compile(r'(?m)^KEY_1\s*=\s*2\s*#.*$')
if len(pattern.findall(source)) != 1:
    sys.exit('Code du bouton non reconnu dans ce script : aucune modification.')
source = pattern.sub('KEY_1 = 3                 # Bouton avant droit reel : KEY_2, mesure sur event15', source)

start = source.find('\ndef find_devices():')
end = source.find('\ndef emulator_running():', start + 1)
if start == -1 or end == -1:
    sys.exit('Fonction de detection inconnue : aucune modification.')

replacement = '''
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

'''
source = source[:start + 1] + replacement.lstrip('\n') + source[end + 1:]

ast.parse(source, filename=str(app))
if not backup.exists():
    shutil.copy2(app, backup)
    print('Sauvegarde :', backup)
else:
    print('Sauvegarde existante conservee :', backup)
new_file.write_text(source, encoding='utf-8')
new_file.chmod(0o755)
print('Nouveau script verifie :', new_file)
PY

if [ -e "$NEW" ]; then
    batocera-services stop "$NAME" || true
    mv -f "$NEW" "$APP"
    chmod 755 "$APP"
    if ! batocera-services start "$NAME"; then
        echo 'Echec du demarrage : restauration automatique.' >&2
        restore
        exit 1
    fi
fi

echo 'Peripheriques Sinden surveilles :'
python3 "$APP" --devices || true
echo 'Dernieres lignes du journal :'
tail -n 5 "$BASE/logs/sinden-exit-combo.log" || true
echo "Retour arriere : sh $0 --restore"
