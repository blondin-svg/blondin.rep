#!/bin/bash
# Gestionnaire Batocera ★ Blondin Edition ★ v4.1.2 TEST / Batocera 44
# Installateur identique pour kit local hors ligne et publication GitHub.
set -euo pipefail
umask 022
REPO_URL='https://raw.githubusercontent.com/blondin-svg/blondin.rep/main/GestionnaireBatocera/v4.1.2'
SRC_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
TEMP=''
if [[ "${1:-}" == '--online' ]]; then
  command -v curl >/dev/null 2>&1 || { echo '[ERREUR] curl absent.' >&2; exit 1; }
  TEMP="$(mktemp -d /tmp/blondin-v412-online.XXXXXX)"
  trap 'rm -rf -- "$TEMP"' EXIT
  SRC_DIR="$TEMP"
  echo '[INFO] Telechargement de la version complete v4.1.2 depuis GitHub...'
  for file in gestionnaire-batocera-v4.1.2-TEST.sh ordre-systemes-v4.py installer-sinden-avant-droit-gachette-2s-batocera44.sh correctif-sinden-exit-hotkeygen-batocera44.sh correctif-sinden-double-interface-batocera44.sh correctif-sinden-boutons-reels-batocera44.sh; do
    curl --fail --location --silent --show-error --connect-timeout 10 --max-time 90 --output "$SRC_DIR/$file" "$REPO_URL/$file" || exit 1
  done

elif [[ $# -gt 0 ]]; then
  echo 'Usage : bash install-v4.1.2.sh [--online]' >&2
  exit 2
fi
cleanup(){ [[ -z "$TEMP" ]] || rm -rf -- "$TEMP"; }
trap cleanup EXIT
if [[ "$(id -u)" -ne 0 ]]; then
  echo '[ERREUR] Se connecter en root sur Batocera 44.' >&2; exit 1
fi
if [[ ! -r /etc/os-release ]] || ! grep -qi 'batocera' /etc/os-release || \
   ! grep -Eq '(^|[^0-9])44([^0-9]|$)' /etc/os-release; then
  echo '[ERREUR] Installeur exclusivement prevu pour Batocera 44.' >&2; exit 1
fi
for x in bash python3 sha256sum install mktemp cp; do
  command -v "$x" >/dev/null 2>&1 || { echo "[ERREUR] Commande absente : $x" >&2; exit 1; }
done
# Le manifeste est fixe dans cet installateur : aucun binaire distant non verifie.
cat > "$SRC_DIR/.blondin-v4-expected" <<'SHA256BLONDINV4'
ab900d5827005f368d9d6fda99d87c80d15958be232f40f2f58697f097cdcd53  gestionnaire-batocera-v4.1.2-TEST.sh
be52239e1468fcebd298126d1aecd72a6bb52838e2557bcd374fda4fd9a35295  ordre-systemes-v4.py
24bb2487080dfff08ff9b15617c61675780083b2432bf4266a55519f6cd57fa6  installer-sinden-avant-droit-gachette-2s-batocera44.sh
450de876c472ca01500726f9a301e0bf0739d5e3e7a9ecc6a31e14601cb9ebf7  correctif-sinden-exit-hotkeygen-batocera44.sh
d89147dd1b2afd631f4f9d4e543bbb962d19eb1fd823de4892a3c57a27e8b09d  correctif-sinden-double-interface-batocera44.sh
4d92cff4d1b45b16d14446fb6f3fbf9c60963a89d3735890106fd391c2cada59  correctif-sinden-boutons-reels-batocera44.sh
SHA256BLONDINV4
(cd "$SRC_DIR" && sha256sum -c .blondin-v4-expected) || {
  echo '[SECURITE] Integrite des fichiers v4.1.2 incorrecte, installation annulee.' >&2
  exit 1
}
rm -f -- "$SRC_DIR/.blondin-v4-expected"
bash -n "$SRC_DIR/gestionnaire-batocera-v4.1.2-TEST.sh" || exit 1
for f in "$SRC_DIR"/installer-sinden*.sh "$SRC_DIR"/correctif-sinden*.sh; do
  sh -n "$f" || { echo "[ERREUR] Shell invalide : $f" >&2; exit 1; }
done
python3 - "$SRC_DIR/ordre-systemes-v4.py" <<'PYCOMPILEV4'
import ast,sys
with open(sys.argv[1],encoding='utf-8') as f:
    ast.parse(f.read(),filename=sys.argv[1])
PYCOMPILEV4
# Toutes les validations se font avant toute modification des chemins persistants.
BASE='/userdata/system'
MANAGER="$BASE/gestionnaire-batocera.sh"
H_DIR="$BASE/blondin-v4/helpers"
PORTS='/userdata/roms/ports'
LAUNCHER="$PORTS/Gestionnaire Batocera.sh"
BACKUP="$BASE/backup-gestionnaire-ports"
STAMP="$(date +%Y%m%d-%H%M%S)-$$"
for p in "$BASE" "$MANAGER" "$H_DIR" "$LAUNCHER" "$BACKUP" "$PORTS"; do
  if [[ -L "$p" ]]; then echo "[SECURITE] Lien symbolique interdit : $p" >&2; exit 1; fi
done
mkdir -p -- "$H_DIR" "$PORTS" "$BACKUP"
BATCH="$BACKUP/v4.1.2-$STAMP"
mkdir -m 700 -- "$BATCH"
if [[ -f "$MANAGER" ]]; then cp -p -- "$MANAGER" "$BATCH/gestionnaire-batocera.sh"; fi
if [[ -f "$LAUNCHER" ]]; then cp -p -- "$LAUNCHER" "$BATCH/Gestionnaire Batocera.sh"; fi
if [[ -f "$PORTS/gamelist.xml" ]]; then cp -p -- "$PORTS/gamelist.xml" "$BATCH/gamelist.xml"; fi
for file in ordre-systemes-v4.py installer-sinden-avant-droit-gachette-2s-batocera44.sh correctif-sinden-exit-hotkeygen-batocera44.sh correctif-sinden-double-interface-batocera44.sh correctif-sinden-boutons-reels-batocera44.sh; do
  if [[ -L "$H_DIR/$file" ]]; then echo "[SECURITE] Module sous lien symbolique : $file" >&2; exit 1; fi
  if [[ -f "$H_DIR/$file" ]]; then cp -p -- "$H_DIR/$file" "$BATCH/$file"; fi
done
# Migration du moteur de telechargement connu, sans toucher au service de sauvegarde.
python3 - "$BASE/blondin-1fichier/onefichier.py" "$BATCH" <<'PYMIGRATE401'
import hashlib, os, pathlib, shutil, sys, tempfile
p=pathlib.Path(sys.argv[1]); backup=pathlib.Path(sys.argv[2])
if p.is_symlink() or (p.exists() and not p.is_file()):
    print('[ATTENTION] Moteur 1fichier non regulier : conserve.')
elif p.is_file():
    data=p.read_bytes(); sha=hashlib.sha256(data).hexdigest()
    if sha=='87689ad7c451621f88e935f95f5776dcc9594030f5638f86a7cafd0f758e90a9':
        old=b"--port',type=int,default=8765"; new=b"--port',type=int,default=8766"
        if data.count(old)!=1: raise RuntimeError('Port moteur inattendu')
        data=data.replace(old,new); compile(data,str(p),'exec')
        if hashlib.sha256(data).hexdigest()!='3517d544733b03668da2dc049075aeccbf109a5f737404d26ec79cb00d068e33': raise RuntimeError('Empreinte moteur incorrecte')
        shutil.copy2(p,backup/'onefichier.py')
        fd,tmp=tempfile.mkstemp(prefix='.blondin-v401-',dir=p.parent)
        try:
            with os.fdopen(fd,'wb') as f: f.write(data); f.flush(); os.fsync(f.fileno())
            shutil.copystat(p,tmp); os.replace(tmp,p)
        finally:
            if os.path.exists(tmp): os.unlink(tmp)
        print('[OK] Moteur 1fichier migre vers 8766.')
    elif sha=='3517d544733b03668da2dc049075aeccbf109a5f737404d26ec79cb00d068e33':
        print('[OK] Moteur 1fichier deja sur 8766.')
    else:
        print('[ATTENTION] Moteur personnalise ou autre version : conserve. Le gestionnaire impose 8766.')
PYMIGRATE401
# Mettre a jour uniquement le gestionnaire et ses nouvelles dependances v4.
install -m 755 -- "$SRC_DIR/gestionnaire-batocera-v4.1.2-TEST.sh" "$MANAGER"
for file in ordre-systemes-v4.py installer-sinden-avant-droit-gachette-2s-batocera44.sh correctif-sinden-exit-hotkeygen-batocera44.sh correctif-sinden-double-interface-batocera44.sh correctif-sinden-boutons-reels-batocera44.sh; do
  install -m 755 -- "$SRC_DIR/$file" "$H_DIR/$file"
done
if [[ ! -f "$LAUNCHER" ]]; then
  cat > "$LAUNCHER" <<'LAUNCHERV4'
#!/bin/bash
export DISPLAY="${DISPLAY:-:0}"
export BLONDIN_PORTS_PAD=1
SCRIPT=/userdata/system/gestionnaire-batocera.sh
exec xterm -bg black -fg white -fa 'DejaVu Sans Mono' -fs 32 \
  -geometry '100x29+650+85' -sb -rightbar -sl 5000 \
  -title 'Gestionnaire Batocera - BLONDIN EDITION' -e /bin/bash "$SCRIPT"
LAUNCHERV4
  chmod 755 "$LAUNCHER"
  echo '[OK] Lanceur Ports cree.'
else
  echo '[OK] Lanceur Ports existant conserve.'
fi
# Ne reecrit pas les fichiers .keys ni les visuels : ils restent en place.
# Si gamelist est absent, ajoute seulement une entree; sinon met a jour l'entree du Gestionnaire.
python3 - "$PORTS" <<'PYGAMELISTV4'
import os,sys,json,tempfile,xml.etree.ElementTree as ET
from pathlib import Path
ports=Path(sys.argv[1]); path=ports/'gamelist.xml'
# Préserver les réglages manette existants. Sur une installation vierge,
# reprendre les contrôles Ports du kit hors ligne v3.0.17.
keys=ports/'Gestionnaire Batocera.sh.keys'
if not keys.exists() and not keys.is_symlink():
    actions=[('up','KEY_UP'),('down','KEY_DOWN'),('left','KEY_LEFT'),('right','KEY_RIGHT'),
             ('joystick1up','KEY_UP'),('joystick1down','KEY_DOWN'),
             ('joystick1left','KEY_LEFT'),('joystick1right','KEY_RIGHT'),
             ('b','KEY_ENTER'),('a','KEY_0'),('start','KEY_ENTER'),
             ('pageup','KEY_PAGEUP'),('pagedown','KEY_PAGEDOWN')]
    cfg={'actions_player1':[{'trigger':t,'type':'key','target':v} for t,v in actions]}
    fd,tmp=tempfile.mkstemp(prefix='.blondin-v4-pad-',dir=ports)
    try:
        with os.fdopen(fd,'w',encoding='utf-8') as out:
            json.dump(cfg,out,ensure_ascii=False,indent=2)
            out.write('\n');out.flush();os.fsync(out.fileno())
        os.replace(tmp,keys)
    finally:
        if os.path.exists(tmp):os.unlink(tmp)
    print('[OK] Contrôles manette Ports installés.')
elif keys.is_file() and not keys.is_symlink():
    print('[OK] Contrôles manette Ports existants conservés.')
else:
    print('[ATTENTION] Fichier manette .keys non régulier : aucune modification.',file=sys.stderr)
try:
    tree=ET.parse(path) if path.is_file() else ET.ElementTree(ET.Element('gameList'))
    root=tree.getroot()
    if root.tag!='gameList': raise ValueError('structure XML inattendue')
    games=[g for g in root.findall('game') if (g.findtext('path') or '').strip().removeprefix('./') == 'Gestionnaire Batocera.sh']
    if games:
        game=games[0]
    else:
        game=ET.SubElement(root,'game')
        ET.SubElement(game,'path').text='./Gestionnaire Batocera.sh'
    for extra in games[1:]:root.remove(extra)
    fields={'name':'Gestionnaire Batocera ★ BLONDIN EDITION ★',
            'desc':('Gestionnaire pour Batocera 44 — v4.1.2 TEST : installations, applications, '
                    'diagnostics, extinction, sauvegardes, Sinden Lightgun (sortie de jeu), '
                    'ordre des systèmes arcade et classement par constructeur/date, Syncthing et 1fichier.'),
            'genre':'Utilitaire'}
    for key,value in fields.items():
        node=game.find(key)
        if node is None: node=ET.SubElement(game,key)
        node.text=value
    data=ET.tostring(root,encoding='utf-8',xml_declaration=True)
    ET.fromstring(data)
    fd,tmp=tempfile.mkstemp(prefix='.blondin-v4-gamelist-',dir=ports)
    try:
        with os.fdopen(fd,'wb') as out:
            out.write(data);out.flush();os.fsync(out.fileno())
        os.replace(tmp,path)
    finally:
        if os.path.exists(tmp):os.unlink(tmp)
    print('[OK] Fiche Ports du Gestionnaire mise a jour, autres jeux conserves.')
except (ET.ParseError,OSError,ValueError) as exc:
    print('[ATTENTION] Gamelist conserve ou non actualise :',exc,file=sys.stderr)
PYGAMELISTV4
[[ "$(sha256sum "$MANAGER" | awk '{print $1}')" == 'ab900d5827005f368d9d6fda99d87c80d15958be232f40f2f58697f097cdcd53' ]] || {
  echo '[ERREUR] Fichier gestionnaire installe avec empreinte invalide.' >&2; exit 1; }
echo
printf '[OK] GESTIONNAIRE BATOCERA BLONDIN EDITION v4.1.2 TEST installe.\n'
echo "[INFO] Sauvegarde des fichiers anterieurs : $BATCH"
echo '[INFO] Aucune configuration de ROM ou de systeme ES modifiee pendant l installation.'
echo '[INFO] Lancer depuis Ports -> Gestionnaire Batocera (actualiser la liste des jeux).'
echo '[INFO] Sinden et tri arcade ne sont appliques que depuis leurs menus respectifs.'
echo '[INFO] Telechargement 1fichier HTTPS 8766 ; sauvegarde 8765 et ntfy 18765 inchanges.'
echo '[INFO] Si le Web de telechargement tourne encore sur 8765, le redemarrer depuis son menu.'
