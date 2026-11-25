#!/usr/bin/env python3
# Gestionnaire Batocera ★ Blondin Edition ★ v4.0 TEST
# Batocera 44 / EmulationStation : bloc arcade ancre sur FinalBurn Neo.
# Aucun fichier système /usr/share, ROM ou es_systems_*.cfg n'est modifié.
import argparse
import hashlib
import json
import os
import re
import shutil
import sys
import tempfile
import unicodedata
import xml.etree.ElementTree as ET
from collections import Counter, OrderedDict
from copy import deepcopy
from datetime import datetime
from pathlib import Path

WANTED = ('fbneo', 'neogeo', 'naomi', 'lindbergh', 'teknoparrot')
LABELS = ('FinalBurn Neo', 'Neo Geo', 'Naomi', 'Lindbergh', 'TeknoParrot')
ALIASES = ('Nintendo','Sega','Sony','Microsoft','Atari','NEC','SNK','Bandai',
           'Namco','Capcom','Konami','Taito','Commodore','Amstrad','Panasonic',
           'Sammy','Hudson','Philips','Magnavox','Apple','Sharp','Nokia',
           'Samsung','Sinclair')

parser = argparse.ArgumentParser(description='Tri des systèmes Batocera 44 avec bloc arcade fixe')
parser.add_argument('--preview', action='store_true', help='ne rien modifier (défaut)')
parser.add_argument('--apply', action='store_true', help='sauvegarder puis appliquer')
parser.add_argument('--restore', action='store_true', help='restaurer seulement si le fichier est inchangé depuis application')
parser.add_argument('--current', action='store_true', help='afficher l’ordre actuel')
parser.add_argument('--mode', choices=('arcade','others','both'), default='both')
a = parser.parse_args()
if sum([a.apply, a.restore, a.current]) > 1:
    parser.error('Choisir un seul mode opérationnel.')
ES = Path(os.environ.get('BATO_ES_DIR', '/userdata/system/configs/emulationstation'))
BASE = Path(os.environ.get('BATO_BASE_CFG','/usr/share/emulationstation/es_systems.cfg'))
USER = ES/'es_systems.cfg'
SETTINGS = ES/'es_settings.cfg'
BACKUPS = ES/'.blondin-v4-ordre-backups'


def parse(path):
    tree = ET.parse(path, parser=ET.XMLParser(target=ET.TreeBuilder(insert_comments=True)))
    if tree.getroot().tag != 'systemList':
        raise ValueError('Fichier non conforme (systemList) : ' + str(path))
    return tree


def sid(node):
    return (node.findtext('name') or '').strip() if node.tag == 'system' else ''


def hash_of(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def slug(text):
    text = unicodedata.normalize('NFKD', text).casefold().strip()
    return ''.join(c for c in text if not unicodedata.combining(c))


def maker(raw, sysid):
    if not raw.strip():
        return ('absent:' + sysid, 'Constructeur non renseigné (' + sysid + ')')
    simple = slug(raw)
    for title in ALIASES:
        stem = slug(title)
        if simple == stem or simple.startswith(stem + ' ') or simple.startswith(stem + '-') or simple.startswith(stem + ','):
            return (stem, title)
    return (simple, raw.strip())


def year(value):
    m = re.match(r'^\s*((?:18|19|20)\d\d)(?:[-/.]\d\d(?:[-/.]\d\d)?)?\s*$',value or '')
    return int(m.group(1)) if m else None


def auto_sort():
    if not SETTINGS.is_file():
        return ''
    root = ET.parse(SETTINGS).getroot()
    for child in root:
        if child.get('name') == 'SortSystems':
            return (child.get('value') or '').strip()
    return ''


def atomic_write(tree):
    ES.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix='.blondin-v4-ordre-', dir=ES)
    try:
        with os.fdopen(fd, 'wb') as out:
            tree.write(out, encoding='utf-8', xml_declaration=True)
            out.flush(); os.fsync(out.fileno())
        parse(Path(tmp))
        os.replace(tmp, USER)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def backups():
    if BACKUPS.is_symlink():
        raise ValueError('Sauvegardes sous lien symbolique : refus')
    return sorted(p for p in BACKUPS.iterdir() if p.is_dir() and (p/'info.json').is_file()) if BACKUPS.is_dir() else []


def restore():
    all_baks = backups()
    if not all_baks:
        raise ValueError('Aucune sauvegarde v4 de classement disponible.')
    latest = all_baks[-1]
    info = json.loads((latest/'info.json').read_text(encoding='utf-8'))
    if not USER.is_file() or USER.is_symlink() or hash_of(USER) != info.get('applied_hash'):
        raise ValueError('Restauration refusée : configuration modifiée depuis le classement.')
    if info.get('user_existed'):
        old = latest/'es_systems.cfg'
        parse(old)
        shutil.copy2(old, USER)
    else:
        USER.unlink()
    print('Configuration précédente restaurée à partir de', latest)
    print('Redémarrer EmulationStation pour afficher les changements.')


def main():
    if a.restore:
        restore(); return 0
    if USER.is_symlink() or BASE.is_symlink():
        raise ValueError('Configuration via lien symbolique non prise en charge.')
    source = USER if USER.is_file() else BASE
    if not source.is_file():
        raise ValueError('es_systems.cfg introuvable, aucune modification.')
    tree = parse(source)
    root = tree.getroot()
    systems = [s for s in root if s.tag == 'system']
    present = OrderedDict()
    for s in systems:
        code = sid(s)
        if not code or code in present:
            raise ValueError('Système sans identifiant ou dupliqué : '+code)
        present[code] = s
    fallback = {}
    if BASE.is_file():
        for s in parse(BASE).getroot():
            code = sid(s)
            if code:
                fallback[code] = {'manufacturer':(s.findtext('manufacturer') or '').strip(),
                                  'release':(s.findtext('release') or '').strip()}
    overrides = {}
    for folder in dict.fromkeys((BASE.parent, ES)):
        if not folder.is_dir():
            continue
        for path in sorted(folder.glob('es_systems_*.cfg')):
            for s in parse(path).getroot():
                code = sid(s)
                if not code:
                    continue
                d = overrides.setdefault(code,{})
                for k in ('manufacturer','release'):
                    if s.find(k) is not None:
                        d[k] = (s.findtext(k) or '').strip()
                if code not in present:
                    if not all((s.findtext(k) or '').strip() for k in ('path','extension','command')):
                        raise ValueError('Système additionnel incomplet : '+code+' dans '+str(path))
                    clone = deepcopy(s)
                    systems.append(clone)
                    present[code] = clone
    ids = [sid(s) for s in systems]
    if a.current:
        print('Ordre actuel ('+str(len(ids))+' systèmes) ; source : '+str(source))
        for i,s in enumerate(systems,1):
            print(f'{i:3d}. {(s.findtext("fullname") or sid(s)).strip()} ({sid(s)})')
        print('Tri automatique SortSystems :',repr(auto_sort()))
        return 0
    missing = [code for code in WANTED if code not in present]
    if missing:
        raise ValueError('Bloc arcade incomplet : '+', '.join(missing)+' ; aucune modification.')
    anchor = ids.index('fbneo')
    if len(systems)-len(WANTED) < anchor:
        raise ValueError('FinalBurn Neo est trop proche de la fin pour conserver sa position.')
    others = [s for s in systems if sid(s) not in WANTED]
    block = [present[k] for k in WANTED]
    if a.mode == 'arcade':
        result = others[:anchor] + block + others[anchor:]
    else:
        if a.mode == 'others' and tuple(ids[anchor:anchor+5]) != WANTED:
            raise ValueError('Regrouper d’abord le bloc arcade (option 2), ou appliquer les deux tris (option 4).')
        groups = OrderedDict()
        names = {}
        positions = {code:i for i,code in enumerate(ids)}
        def meta(node, field):
            code = sid(node)
            return (overrides.get(code,{}).get(field) or (node.findtext(field) or '').strip() or
                    fallback.get(code,{}).get(field,'')).strip()
        for node in others:
            mk, label = maker(meta(node,'manufacturer'),sid(node))
            groups.setdefault(mk,[]).append(node)
            names[mk] = label
        for mk in groups:
            groups[mk].sort(key=lambda s:(year(meta(s,'release')) is None,
                                          year(meta(s,'release')) or 9999,positions[sid(s)]))
        # Ne jamais couper un constructeur ni changer l'index original de FBNeo.
        # Chercher le meilleur sous-ensemble de constructeurs qui occupe exactement
        # les emplacements avant le bloc arcade.
        dp = {0:(0,())}
        items = list(groups.items())
        for mk, group in items:
            size = len(group)
            left = sum(positions[sid(s)] < anchor for s in group)
            right = size - left
            new = {}
            for count,(cost,which) in dp.items():
                candidate=(cost+left,which+(False,))
                if count not in new or candidate[0] < new[count][0]: new[count]=candidate
                if count+size <= anchor:
                    candidate=(cost+right,which+(True,))
                    if count+size not in new or candidate[0] < new[count+size][0]: new[count+size]=candidate
            dp=new
        if anchor not in dp:
            closest=min(dp,key=lambda x:abs(x-anchor)) if dp else 0
            raise ValueError('Tri par constructeur impossible avec FinalBurn Neo IMMOBILE et '
                             'constructeurs intacts. Décalage minimal : '+str(abs(closest-anchor))+'. Aucune modification.')
        choices = dp[anchor][1]
        before=[x for chosen,(_, group) in zip(choices,items) if chosen for x in group]
        after=[x for chosen,(_, group) in zip(choices,items) if not chosen for x in group]
        result=before+block+after
    codes=[sid(s) for s in result]
    if Counter(codes) != Counter(ids) or codes[anchor:anchor+5] != list(WANTED) or codes.index('fbneo') != anchor:
        raise ValueError('Erreur de contrôle : FBNeo ou systèmes modifiés, application interdite.')
    print('=== BLONDIN EDITION — APERÇU v4.0 ===')
    print('Source :',source,'| Systèmes :',len(ids))
    print('Mode :',{'arcade':'Bloc arcade uniquement','others':'Constructeur puis date','both':'Bloc arcade + constructeur puis date'}[a.mode])
    print('FinalBurn Neo : position',anchor+1,'(inchangée)')
    print('Arcade :',' > '.join(LABELS))
    previous = None
    for i,s in enumerate(result,1):
        code=sid(s)
        if code in WANTED: group='ARCADE'
        else:
            effective=overrides.get(code,{}).get('manufacturer') or (s.findtext('manufacturer') or '').strip() or fallback.get(code,{}).get('manufacturer','')
            group=maker(effective,code)[1]
        if group!=previous: print('  -- '+group+' --')
        value=overrides.get(code,{}).get('release') or s.findtext('release') or fallback.get(code,{}).get('release','')
        print(f'  {i:3d}. {(s.findtext("fullname") or code).strip()} ({code})'+(f' — {year(value)}' if year(value) else ''))
        previous=group
    sort=auto_sort()
    print('Tri automatique EmulationStation :',repr(sort))
    if sort.casefold() not in ('','none','0'):
        print('ATTENTION : régler le tri des systèmes sur AUCUN dans EmulationStation.')
        if a.apply: raise ValueError('Tri automatique actif : application refusée.')
    if not a.apply:
        print('APERÇU SEULEMENT — aucun fichier modifié.')
        return 0
    if codes==ids and source==USER and len([n for n in root if n.tag=='system'])==len(result):
        print('Ordre déjà conforme : aucun changement.')
        return 0
    if not ES.is_dir() or ES.is_symlink():
        raise ValueError('Répertoire EmulationStation absent ou sous lien symbolique.')
    if BACKUPS.is_symlink():
        raise ValueError('Dossier de sauvegarde sous lien symbolique.')
    batch=BACKUPS/datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    batch.mkdir(parents=True,exist_ok=False)
    old_user=USER.is_file()
    if old_user: shutil.copy2(USER,batch/'es_systems.cfg')
    else: shutil.copy2(BASE,batch/'es_systems_base_original.cfg')
    children=list(root); iterator=iter(result)
    root[:]=[next(iterator) if ch.tag=='system' else ch for ch in children]
    root.extend(iterator)
    ET.indent(tree,space='  ')
    atomic_write(tree)
    (batch/'info.json').write_text(json.dumps({'user_existed':old_user,'applied_hash':hash_of(USER),
       'mode':a.mode,'timestamp':datetime.now().isoformat()},indent=2),encoding='utf-8')
    print('CLASSEMENT APPLIQUÉ — sauvegarde :',batch)
    print('Aucun ROM ni fichier es_systems_*.cfg n’a été modifié.')
    print('Redémarrer EmulationStation pour prendre en compte l’ordre.')
    return 0


if __name__ == '__main__':
    try: sys.exit(main())
    except (OSError, ET.ParseError, ValueError, KeyError, IndexError) as exc:
        print('[SÉCURITÉ] '+str(exc),file=sys.stderr)
        sys.exit(2)
