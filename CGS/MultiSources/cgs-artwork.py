#!/usr/bin/env python3
"""Manage only CGS Ports artwork; preserve previous values and files."""
import sys, os, json, shutil, tempfile, datetime, xml.etree.ElementTree as ET
from pathlib import Path
PORTS=Path('/userdata/roms/ports')
MEDIA=PORTS/'images'/'gestionnaire-ports'
GAMELIST=PORTS/'gamelist.xml'
BACKUPS=Path('/userdata/saves/Installscripts/saves/CGS/Visuels')
FILES={'image':'CGS-fanart.png','thumbnail':'CGS-cover.png','marquee':'CGS-logo.png','fanart':'CGS-fanart.png'}
SOURCES={'CGS-cover.png':'CGS-thumb.png','CGS-logo.png':'CGS-logo.png','CGS-fanart.png':'CGS-fanart.png'}

def entry_and_tree():
    if not GAMELIST.is_file(): raise RuntimeError('gamelist.xml Ports absent')
    tree=ET.parse(GAMELIST)
    if tree.getroot().tag!='gameList': raise RuntimeError('Racine XML inattendue')
    entries=[e for e in tree.getroot().findall('game') if (e.findtext('path') or '').removeprefix('./')=='CGS.sh']
    if len(entries)!=1: raise RuntimeError(f'Entrée CGS.sh ambiguë ou absente ({len(entries)})')
    if not (PORTS/'CGS.sh').is_file(): raise RuntimeError('Lanceur CGS.sh absent')
    return tree,entries[0]

def write_xml(tree):
    fd,temp=tempfile.mkstemp(prefix='.gamelist-cgs-',suffix='.xml',dir=PORTS)
    try:
        with os.fdopen(fd,'wb') as f: tree.write(f,encoding='utf-8',xml_declaration=True)
        ET.parse(temp)
        os.replace(temp,GAMELIST)
    finally:
        if os.path.exists(temp): os.unlink(temp)

def install(source):
    tree,e=entry_and_tree()
    for dst,src in SOURCES.items():
        path=source/src
        if not path.is_file() or path.read_bytes()[:8]!=b'\x89PNG\r\n\x1a\n': raise RuntimeError('Image manquante ou invalide : '+str(path))
    backup=BACKUPS/(datetime.datetime.now().strftime('%Y%m%d-%H%M%S')+'-'+str(os.getpid()))
    backup.mkdir(parents=True,exist_ok=False)
    shutil.copy2(GAMELIST,backup/'gamelist.xml')
    data={'fields':{},'existing':[]}
    for tag in FILES:
        node=e.find(tag)
        data['fields'][tag]={'present':node is not None,'text':node.text if node is not None else None}
    for name in SOURCES:
        p=MEDIA/name
        if p.exists():
            if not p.is_file(): raise RuntimeError('Destination non standard : '+str(p))
            shutil.copy2(p,backup/name)
            data['existing'].append(name)
    (backup/'manifest.json').write_text(json.dumps(data,ensure_ascii=False,indent=2))
    MEDIA.mkdir(parents=True,exist_ok=True)
    for name,src in SOURCES.items():
        fd,temp=tempfile.mkstemp(prefix='.cgs-art-',dir=MEDIA)
        try:
            with os.fdopen(fd,'wb') as f, (source/src).open('rb') as inp: shutil.copyfileobj(inp,f)
            os.replace(temp,MEDIA/name)
        finally:
            if os.path.exists(temp): os.unlink(temp)
    for tag,name in FILES.items():
        node=e.find(tag)
        if node is None: node=ET.SubElement(e,tag)
        node.text='./images/gestionnaire-ports/'+name
    write_xml(tree)
    print('[OK] Illustrations CGS installées. Sauvegarde :',backup)

def restore():
    candidates=sorted(BACKUPS.glob('*/manifest.json'),reverse=True)
    if not candidates: raise RuntimeError('Aucune sauvegarde des illustrations CGS')
    backup=candidates[0].parent
    data=json.loads((backup/'manifest.json').read_text())
    tree,e=entry_and_tree()
    # Only restore if the CGS entry still points to the images we manage.
    for tag,name in FILES.items():
        if (e.findtext(tag) or '') not in ({'./images/gestionnaire-ports/'+name, './images/gestionnaire-ports/CGS-cover.png'} if tag=='image' else {'./images/gestionnaire-ports/'+name}):
            raise RuntimeError('Fiche CGS modifiée depuis installation : restauration refusée')
    for name in SOURCES:
        p=MEDIA/name
        if name in data['existing'] and not (backup/name).is_file(): raise RuntimeError('Sauvegarde incomplète : '+name)
    for tag,previous in data['fields'].items():
        node=e.find(tag)
        if previous['present']:
            if node is None: node=ET.SubElement(e,tag)
            node.text=previous['text']
        elif node is not None: e.remove(node)
    for name in SOURCES:
        dest=MEDIA/name
        if name in data['existing']: shutil.copy2(backup/name,dest)
        elif dest.exists(): dest.unlink()
    write_xml(tree)
    # Avoid restoring the same snapshot twice.
    (backup/'manifest.json').rename(backup/'manifest.restored.json')
    print('[OK] Illustrations CGS précédentes restaurées depuis',backup)

if __name__=='__main__':
    try:
        if len(sys.argv)<2: raise RuntimeError('Action requise')
        if sys.argv[1]=='install': install(Path(sys.argv[2]))
        elif sys.argv[1]=='restore': restore()
        else: raise RuntimeError('Action inconnue')
    except Exception as exc:
        print('[ERREUR]',exc); sys.exit(1)
