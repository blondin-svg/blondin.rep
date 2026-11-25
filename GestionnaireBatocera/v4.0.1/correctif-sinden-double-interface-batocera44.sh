#!/bin/sh
# Batocera 44 - Sinden Lightgun : corrige le suivi simultane clavier + souris.
# Raccourci inchange : bouton avant droit + gachette (2 s).
# N'affecte ni les mappages, ni les autres services.
set -eu

BASE=/userdata/system
APP="$BASE/sinden-exit-combo.py"
BACKUP="$BASE/sinden-exit-combo.py.bak-avant-double-interface"
NAME=sinden_exit_combo

restore() {
  if [ ! -f "$BACKUP" ]; then
    echo "Sauvegarde introuvable : $BACKUP" >&2
    exit 1
  fi
  batocera-services stop "$NAME" || true
  cp -p "$BACKUP" "$APP"
  chmod 755 "$APP"
  batocera-services start "$NAME"
  echo "Version precedente restauree ; service Sinden relance."
}

if [ "${1:-}" = "--restore" ]; then
  restore
  exit 0
fi

if [ ! -f "$APP" ] || [ ! -f "$BASE/services/$NAME" ]; then
  echo "Installation sinden_exit_combo introuvable : aucune modification." >&2
  exit 1
fi

python3 - "$APP" "$BACKUP" <<'PY'
import ast
import os
from pathlib import Path
import shutil
import sys

app = Path(sys.argv[1])
backup = Path(sys.argv[2])
source = app.read_text(encoding='utf-8')
marker = '# SINDEN_DUAL_INPUT_FIX_V1'
if marker in source:
    print('Correctif double-interface deja applique.')
    sys.exit(0)

old = '''    if any(d[3] for d in found):
        found = [d for d in found if d[3]]  # Évite des doubles appuis brut+virtuel.
    return found
'''
new = '''    # SINDEN_DUAL_INPUT_FIX_V1
    # Le Sinden apparait sous deux interfaces :
    # - clavier USB physique (KEY_1 : bouton avant droit)
    # - pointeur virtuel (BTN_LEFT : gachette)
    # Si un seul Sinden virtuel est present, les lire ensemble est indispensable.
    virtuals = [d for d in found if d[3]]
    keyboards = [d for d in found if 'keyboard' in d[1].casefold() and not d[3]]
    if len(virtuals) == 1 and keyboards:
        # Un seul pistolet virtuel : regrouper les evenements de ses deux interfaces.
        # On limite le clavier a un seul groupe USB pour eviter de croiser deux guns.
        keyboard_groups = {d[2] for d in keyboards}
        if len(keyboard_groups) == 1:
            group = 'sinden-combined:' + virtuals[0][0]
            paired = [(d[0], d[1], group, d[3]) for d in virtuals + keyboards]
            return paired
    if virtuals:
        # Plusieurs pistolets : garder le comportement precedent, sans les melanger.
        return virtuals
    return found
'''
if old not in source:
    sys.exit('Structure de script non reconnue : aucune modification. Transmettre le fichier Python pour analyse.')
updated = source.replace(old, new, 1)
ast.parse(updated, filename=str(app))
if not backup.exists():
    shutil.copy2(app, backup)
    print('Sauvegarde :', backup)
tmp = app.with_name(app.name + '.dualinput-new')
tmp.write_text(updated, encoding='utf-8')
os.chmod(tmp, 0o755)
print('Correction prete :', tmp)
PY

if [ -f "$APP.dualinput-new" ]; then
  batocera-services stop "$NAME" || true
  mv -f "$APP.dualinput-new" "$APP"
  chmod 755 "$APP"
  if ! batocera-services start "$NAME"; then
    echo "Erreur demarrage : restauration de la sauvegarde." >&2
    restore
    exit 1
  fi
fi

echo "Etat du service :"
batocera-services status "$NAME" || true
echo "Peripheriques Sinden surveilles :"
python3 "$APP" --devices || true
echo "Dernieres lignes du journal :"
tail -n 5 "$BASE/logs/sinden-exit-combo.log" || true
echo "Pour annuler : sh $0 --restore"
