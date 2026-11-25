#!/usr/bin/env python3
"""Module Quiver et mise à niveau v4.1.4 -> v4.1.5 TEST, Batocera 44."""
import sys, os, re, shutil, tempfile, hashlib, configparser, subprocess, time
from pathlib import Path
from copy import deepcopy
import xml.etree.ElementTree as ET

BASE=Path('/userdata/system'); ROMS=Path('/userdata/roms'); Q=ROMS/'quiver'
CFG=BASE/'configs/emulationstation/es_systems.cfg'; MAN=BASE/'gestionnaire-batocera.sh'
HELP=BASE/'blondin-v4/helpers/quiver-v415.py'; WRAP=BASE/'quiver-xbox360-launch.py'
APP=BASE/'Quiver/emulator/QuiverLauncher-linux-x64.AppImage'; PROCESS=BASE/'Quiver/configgen/quiver_process.py'; RUN=BASE/'Quiver/configgen/run.py'
PORT=ROMS/'ports/Quiver.sh'; BK=BASE/'backup-gestionnaire-ports'; PENDING=BASE/'blondin-v4/quiver-pending'
PREFIX='python3 '+str(WRAP)+' '
MEDIA={'image','thumbnail','marquee','fanart','video','wheel','boxart','boxback','cartridge','manual','titleshot','mix','bezel','map'}
PORT_CODE='''#!/bin/bash
export HOME="/userdata/system/configs/Quiver/wine/Quiver_Launcher"
export XDG_CONFIG_HOME="/userdata/system/configs/Quiver/config"
export XDG_DATA_HOME="/userdata/system/configs/Quiver/data"
cd /userdata || exit 1
exec /usr/bin/python /userdata/system/Quiver/configgen/quiver_process.py -- /userdata/system/Quiver/emulator/QuiverLauncher-linux-x64.AppImage
'''
WRAP_CODE='''import os,sys
from pathlib import Path
args=sys.argv[1:]
rom=Path(args[args.index('-rom')+1])
def setarg(k,v):
    if k in args: args[args.index(k)+1]=v
    else: args.extend([k,v])
if rom.suffix.lower()=='.quiver':
    setarg('-rom',str(rom.resolve(strict=True)))
    setarg('-system','quiver'); setarg('-systemname',FULLNAME)
    setarg('-emulator','quiver'); setarg('-core','quiver')
    os.execvp('python',['python','/userdata/system/Quiver/configgen/run.py']+args)
os.execvp('batocera-launch',['batocera-launch']+args)
'''

def require(ok,msg):
    if not ok: raise RuntimeError(msg)
def regular(p):
    require(not p.is_symlink() and (not p.exists() or p.is_file()),'Fichier non régulier : '+str(p))
def backup(p):
    if p.is_file():
        BK.mkdir(parents=True,exist_ok=True)
        dest=Path(tempfile.mkdtemp(prefix='quiver-v415-',dir=BK))/p.name
        shutil.copy2(p,dest); print('[SAUVEGARDE]',dest)
def write(p,data,mode=0o644,save=True):
    regular(p); p.parent.mkdir(parents=True,exist_ok=True)
    if p.exists():
        mode=p.stat().st_mode & 0o777
        if save: backup(p)
    fd,tmp=tempfile.mkstemp(prefix='.quiver-',dir=p.parent)
    try:
        with os.fdopen(fd,'wb') as f: f.write(data); f.flush(); os.fsync(f.fileno())
        os.chmod(tmp,mode); os.replace(tmp,p)
    finally:
        if os.path.exists(tmp): os.unlink(tmp)
def xml(p):
    root=ET.parse(p).getroot(); require(root.tag=='gameList','Gamelist invalide : '+str(p)); return root
def systems():
    require(CFG.is_file(),'Configuration ES personnalisée absente.')
    data=CFG.read_text(); ET.fromstring(data)
    result={}
    for m in re.finditer(r'<system>.*?</system>',data,re.S):
        node=ET.fromstring(m.group()); name=node.findtext('name',''); cmd=node.findtext('command','').strip()
        if re.fullmatch(r'[A-Za-z0-9_-]+',name) and name not in ('quiver','ports') and node.findtext('path')==str(ROMS/name) and (cmd.startswith('batocera-launch ') or cmd.startswith(PREFIX)):
            require(name not in result,'Système en double : '+name); result[name]=(m.group(),node)
    return data,result
def hint(p):
    c=configparser.ConfigParser(interpolation=None,strict=False)
    try:
        c.read(p,encoding='utf-8-sig'); d=Path(c.get('Roms','game_directory',fallback='')).name; n=c.get('Game','name',fallback=p.stem)
        if re.match(r'^CUSA\d{5}\b|^PS4\s*[-:]',d,re.I) or re.search(r'\(PS4\)|\[PS4\]',n,re.I): return 'ps4'
        if re.match(r'^XBOX360\s*[-:]',d,re.I) or re.search(r'\((?:X360|XBOX360)\)|\[X360\]',n,re.I): return 'xbox360'
    except (OSError,ValueError,configparser.Error): pass
    return '?'
def candidates():
    return [p for p in sorted(Q.glob('*.quiver')) if p.is_file() and not p.is_symlink() and not is_app(p)]
def is_app(p):
    try: return bool(re.search(r'(?im)^\s*executable\s*=.*QuiverLauncher.*AppImage',p.read_text(errors='replace'))) or re.sub(r'[^a-z0-9]','',p.stem.lower()) in ('quiver','quiverlauncher')
    except OSError: return False
def owned(p):
    return p.is_symlink() and p.resolve().parent==Q and p.resolve().suffix=='.quiver'
def config(s,enable):
    data,ss=systems(); require(s in ss,'Système non compatible : '+s); old,n=ss[s]
    cmd=n.findtext('command','').strip(); ext=n.findtext('extension','').split()
    require(bool(ext),'Extensions absentes')
    if enable:
        require(RUN.is_file(),'Quiver configgen absent')
        if not WRAP.exists():
            q=next(x for x in ET.fromstring(data).findall('system') if x.findtext('name')=='quiver')
            code=WRAP_CODE.replace('FULLNAME',repr(q.findtext('fullname') or 'Quiver')); compile(code,str(WRAP),'exec'); write(WRAP,code.encode(),0o644)
        require(WRAP.is_file() and not WRAP.is_symlink(),'Lanceur Quiver non régulier')
        if '.quiver' not in ext: ext.append('.quiver')
        if cmd.startswith('batocera-launch '): cmd=PREFIX+cmd[len('batocera-launch '):]
    else:
        if '.quiver' not in ext or not cmd.startswith(PREFIX): return
        ext.remove('.quiver'); require(bool(ext),'Aucune extension restante')
        cmd='batocera-launch '+cmd[len(PREFIX):]
    import xml.sax.saxutils as sx
    new=re.sub(r'<extension>.*?</extension>',lambda _: '<extension>'+sx.escape(' '.join(ext))+'</extension>',old,count=1,flags=re.S)
    new=re.sub(r'<command>.*?</command>',lambda _: '<command>'+sx.escape(cmd)+'</command>',new,count=1,flags=re.S)
    if new!=old:
        updated=data.replace(old,new,1); ET.fromstring(updated); write(CFG,updated.encode())
def es_running():
    for p in Path('/proc').glob('[0-9]*/comm'):
        try:
            if p.read_text().strip().startswith('emulationstatio'): return True
        except OSError: pass
    return False
def metadata(s,filename,source,remove=False):
    dest=ROMS/s/'gamelist.xml'; regular(dest)
    root=xml(dest) if dest.exists() else ET.Element('gameList')
    target=ROMS/s/filename
    existing=[g for g in root.findall('game') if g.findtext('path') and os.path.normpath(str(ROMS/s/g.findtext('path')))==str(target)]
    if remove:
        if not existing:return
        for g in existing: root.remove(g)
    else:
        # Préserver les champs renseignés, compléter les fiches déjà générées par ES.
        if not (Q/'gamelist.xml').is_file(): print('[INFO] Fiche source absente'); return
        matches=[g for g in xml(Q/'gamelist.xml').findall('game') if g.findtext('path') and (Q/g.findtext('path')).resolve()==Q/source]
        if len(matches)!=1: print('[INFO] Fiche source non identifiée :',source); return
        g=deepcopy(matches[0]); g.find('path').text='./'+filename
        for f in g:
            if f.tag in MEDIA and f.text:
                p=Path(f.text)
                if p.is_absolute():
                    try:f.text='./'+str(p.relative_to(Q))
                    except ValueError:pass
        if existing:
            current=existing[0]
            for field in g:
                if field.tag=='path':continue
                old=current.find(field.tag)
                if old is None:current.append(deepcopy(field))
                elif not (old.text or '').strip():old.text=field.text
        else:root.append(g)
    write(dest,ET.tostring(root,encoding='utf-8',xml_declaration=True))
def queue(s,f,src,remove=False):
    import json
    if es_running():
        PENDING.mkdir(parents=True,exist_ok=True)
        p=PENDING/(hashlib.sha256((s+'/'+f).encode()).hexdigest()+'.json')
        write(p,json.dumps([s,f,src,remove],ensure_ascii=False).encode(),save=False)
        print('[INFO] Fiche mise en attente : ES actif. Appliquer hors ES via SSH.')
    else:
        metadata(s,f,src,remove)
        p=PENDING/(hashlib.sha256((s+'/'+f).encode()).hexdigest()+'.json')
        if p.exists():p.unlink()
def pending():
    import json
    require(not es_running(),'Arrêter EmulationStation avant cette opération.')
    for p in sorted(PENDING.glob('*.json')):
        s,f,src,remove=json.loads(p.read_text()); require(re.fullmatch(r'[A-Za-z0-9_-]+',s) and Path(f).name==f and Path(src).name==src,'File d’attente invalide')
        metadata(s,f,src,remove); p.unlink()
    print('[OK] Fiches en attente traitées.')
def change(s,src,remove=False):
    require(s in systems()[1] and (ROMS/s).is_dir(),'Système indisponible')
    require(Path(src).name==src and src.endswith('.quiver'),'Nom de jeu invalide')
    p=Q/src; dst=ROMS/s/src
    if remove:
        require(owned(dst),'Raccourci non géré : '+str(dst)); dst.unlink(); queue(s,src,src,True)
    else:
        require(p in candidates(),'Jeu Quiver non disponible')
        if os.path.lexists(dst):require(owned(dst) and dst.resolve()==p,'Conflit : '+str(dst))
        config(s,True)
        if not os.path.lexists(dst):dst.symlink_to(p)
        queue(s,src,src)
    print('[OK]',dst)
def port():
    require(APP.is_file() and PROCESS.is_file(),'Application Quiver absente')
    if PORT.exists():
        regular(PORT); require('quiver_process.py' in PORT.read_text() and 'XDG_DATA_HOME' in PORT.read_text(),'Lanceur Ports personnalisé : conservé')
    else: write(PORT,PORT_CODE.encode(),0o755)
    os.chmod(PORT,PORT.stat().st_mode|0o111)
    apps=[p for p in Q.glob('*.quiver') if is_app(p)]
    if len(apps)==1:queue('ports',PORT.name,apps[0].name)
    print('[OK] Quiver dans Ports')
def uninstall():
    _,ss=systems()
    for s,(_,n) in ss.items():
        if n.findtext('command','').strip().startswith(PREFIX):
            for p in sorted((ROMS/s).glob('*.quiver')):
                if owned(p):change(s,p.name,True)
            if not list((ROMS/s).glob('*.quiver')):config(s,False)
            else: print('[INFO] Autres .quiver conservés :',s)
    if PORT.is_file() and not PORT.is_symlink() and 'quiver_process.py' in PORT.read_text() and 'XDG_DATA_HOME' in PORT.read_text():
        backup(PORT); PORT.unlink(); queue('ports',PORT.name,'Quiver.quiver',True)
    print('[OK] Jeux originaux et moteur Quiver conservés.')
BASH=r'''
# v4.1.5 : Quiver, navigation commune, aucun service permanent.
v415_q(){ python3 /userdata/system/blondin-v4/helpers/quiver-v415.py "$@"; }
v415_q_action(){ v415_q "$@" || ui_print warning 'Opération non terminée.'; pause; }
v415_q_games(){
  local s="$1" choice i offset=0 n page=8; local -a games=()
  while :; do
    mapfile -t games < <(v415_q games "$s")
    n=${#games[@]}; (( offset<n )) || offset=0
    refresh_screen; ui_section "QUIVER — $s"
    for ((i=offset;i<n && i<offset+page;i++)); do ui_item "$((i-offset+1))) ${games[i]}"; done
    ui_item '9) Page suivante'; ui_item 'P) Page précédente'; ui_item 'T) Installer les jeux détectés'; ui_item 'S) Supprimer les raccourcis'; ui_item '0) Retour'; ui_item 'Q) Quitter'
    choice="$(read_key 'Votre choix : ')" || return 0
    case "$choice" in
      0|__ESC__) return 0;; q|Q) exit 0;; 9) ((offset+=page));; p|P) ((offset>=page)) && ((offset-=page));;
      t|T) if confirm 'Installer les jeux identifiés pour ce système ?'; then v415_q_action all "$s"; fi;;
      s|S) if confirm 'Supprimer tous les raccourcis Quiver de ce système ?'; then v415_q_action remove-all "$s"; fi;;
      [1-8]) i=$((offset+choice-1)); (( i<n )) || continue; local line="${games[i]}" file="${games[i]#* | }"; if [[ "$line" == '✓'* ]]; then confirm "Supprimer $file ?" && v415_q_action remove "$s" "$file"; else confirm "Ajouter $file à $s ?" && v415_q_action add "$s" "$file"; fi;;
    esac
  done
}
v415_q_systems(){
  local choice i offset=0 n page=8; local -a items=()
  while :; do
    mapfile -t items < <(v415_q systems); n=${#items[@]}; ((offset<n)) || offset=0
    refresh_screen; ui_section 'GESTION DES RACCOURCIS QUIVER'
    for ((i=offset;i<n && i<offset+page;i++)); do ui_item "$((i-offset+1))) ${items[i]}"; done
    ui_item '9) Page suivante'; ui_item 'P) Page précédente'; ui_item '0) Retour'; ui_item 'Q) Quitter'
    choice="$(read_key 'Votre choix : ')" || return 0
    case "$choice" in 0|__ESC__) return 0;; q|Q) exit 0;; 9) ((offset+=page));; p|P) ((offset>=page)) && ((offset-=page));; [1-8]) i=$((offset+choice-1)); ((i<n)) && v415_q_games "${items[i]%% | *}";; esac
  done
}
v415_quiver(){
  local choice
  while :; do
    refresh_screen; ui_section 'GESTION QUIVER'; v415_q status; echo
    ui_item '1) Installer le raccourci Ports'; ui_item '2) Gérer les raccourcis'; ui_item '3) Vérifier les installations'; ui_item '4) Redémarrer EmulationStation'; ui_item '5) Désinstaller les correctifs'; ui_item '0) Retour'; ui_item 'Q) Quitter'
    choice="$(read_key 'Votre choix : ')" || return 0
    case "$choice" in
      0|__ESC__) return 0;; q|Q) exit 0;; 1) v415_q_action port;; 2) v415_q_systems;; 3) v415_q_action verify;;
      4) ui_print warning 'Redémarrage graphique à effectuer depuis SSH (pas depuis Ports).'; echo '/etc/init.d/S31emulationstation stop'; echo 'python3 /userdata/system/blondin-v4/helpers/quiver-v415.py pending'; echo '/etc/init.d/S31emulationstation start'; pause;;
      5) if confirm 'Désinstaller les raccourcis et correctifs Quiver ?'; then v415_q_action uninstall; fi;;
    esac
  done
}
'''
def install():
    require(os.geteuid()==0,'Root requis'); require('batocera' in Path('/etc/os-release').read_text().lower() and re.search(r'\b44\b',Path('/etc/os-release').read_text()),'Batocera 44 requis')
    regular(MAN); require(MAN.is_file(),'Gestionnaire v4.1.4 requis')
    data=MAN.read_bytes(); require(hashlib.sha256(data).hexdigest()=='8a86f5d95e02e3da8bb8515f88014e758139e91af7deb9581a63ac9cd6afbf84','Source v4.1.4 différente : aucune modification')
    s=data.decode(); anchor="v41_apps(){ v41_menu 'APPLICATIONS'"; require(s.count(anchor)==1,'Menu Applications introuvable')
    s=s.replace(anchor,BASH+'\n'+anchor,1); a="'Syncthing' syncthing_menu -; }"; require(s.count(a)==1,'Menu Syncthing inattendu'); s=s.replace(a,"'Syncthing' syncthing_menu - 'Quiver' v415_quiver -; }",1).replace('v4.1.4 TEST','v4.1.5 TEST')
    require(subprocess.run(['bash','-n'],input=s.encode()).returncode==0,'Syntaxe Bash invalide')
    helper=Path(__file__).read_bytes(); compile(helper,str(HELP),'exec'); write(HELP,helper,0o755); write(MAN,s.encode(),0o755)
    print('[OK] Gestionnaire v4.1.5 TEST installé. Aucun redémarrage ni modification Quiver automatique.')
def main():
    cmd=sys.argv[1] if len(sys.argv)>1 else 'install'
    if cmd=='install':install();return
    if cmd=='pending':pending();return
    if cmd=='port':port();return
    if cmd=='uninstall':uninstall();return
    _,ss=systems()
    if cmd in ('status','verify'):
        print('Quiver :', '✓ installé' if APP.is_file() and RUN.is_file() else '○ absent'); print('Ports :','✓ présent' if PORT.is_file() else '○ absent')
        counts={s:sum(owned(p) for p in (ROMS/s).glob('*.quiver')) for s in ss}; print('Systèmes :',sum(v>0 for v in counts.values()),' | Raccourcis :',sum(counts.values())); print('Fiches en attente :',len(list(PENDING.glob('*.json'))))
        if cmd=='verify':
            for s,v in counts.items():
                if v:print(s,v,'raccourci(s)', '✓' if ss[s][1].findtext('command','').strip().startswith(PREFIX) and WRAP.is_file() else '⚠ lanceur à vérifier')
            print('Fiches en attente : arrêter ES via SSH puis exécuter',HELP,'pending')
        return
    if cmd=='systems':
        def score(s):return (not (any(owned(p) for p in (ROMS/s).glob('*.quiver')) or any(hint(p)==s for p in candidates())),s)
        for s in sorted(ss,key=score):
            if (ROMS/s).is_dir():print(s,'|',ss[s][1].findtext('fullname') or s)
        return
    s=sys.argv[2];require(s in ss,'Système inconnu')
    if cmd=='games':
        for p in sorted(candidates(),key=lambda p:(not owned(ROMS/s/p.name),hint(p)!=s,p.name)):
            print(('✓' if owned(ROMS/s/p.name) else '○')+' '+('['+hint(p)+']')+' | '+p.name)
    elif cmd=='add':change(s,sys.argv[3])
    elif cmd=='remove':change(s,sys.argv[3],True)
    elif cmd=='all':
        for p in candidates():
            if hint(p)==s:change(s,p.name)
    elif cmd=='remove-all':
        for p in sorted((ROMS/s).glob('*.quiver')):
            if owned(p):change(s,p.name,True)
    else:raise RuntimeError('Commande inconnue')
if __name__=='__main__':
    try:main()
    except Exception as e:print('[ERREUR]',e,file=sys.stderr);sys.exit(1)
