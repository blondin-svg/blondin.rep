#!/usr/bin/env python3
# Gestionnaire Batocera BLONDIN EDITION v4.0.1 TEST - mise a jour ciblee.
import argparse, base64, gzip, hashlib, os, re, shutil, subprocess, tempfile
from datetime import datetime
from pathlib import Path

BASE = Path('/userdata/system')
MANAGER = BASE / 'gestionnaire-batocera.sh'
ENGINE = BASE / 'blondin-1fichier/onefichier.py'
ORIGINAL = 'https://raw.githubusercontent.com/blondin-svg/blondin.rep/main/GestionnaireBatocera/v4.0/install-v4.0.sh'
OLD = b"--port',type=int,default=8765"
NEW = b"--port',type=int,default=8766"

def digest(data):
    return hashlib.sha256(data).hexdigest()

def require(ok, message):
    if not ok:
        raise RuntimeError(message)

def regular(path):
    return path.is_file() and not path.is_symlink()

def patch_manager(src):
    header = '# Gestionnaire Batocera BLONDIN EDITION v4.0 TEST'
    banner = 'v4.0 TEST  •  BATOCERA 44'
    require(src.count(header) == 1 and src.count(banner) == 1,
            'Source v4.0 non reconnue : aucune modification.')
    start = src.index("ONEF_DIR='/userdata/system/blondin-1fichier'")
    before, module = src[:start], src[start:]
    module, count = re.subn(r'(?<=--port )876[56]\b|(?<=:)876[56]\b', '8766', module)
    require(count == 8, f'Nombre de references Web inattendu : {count} (8 attendues).')
    pattern = r"(?m)^payload='''([A-Za-z0-9+/=]+)'''$"
    matches = list(re.finditer(pattern, module))
    # Le moteur concerne se trouve dans le heredoc PYONEF_INSTALL.
    matches = [m for m in matches if module.rfind("<<'PYONEF_INSTALL'", 0, m.start()) >= 0
               and module.rfind('\nPYONEF_INSTALL\n', 0, m.start()) < module.rfind("<<'PYONEF_INSTALL'", 0, m.start())]
    require(len(matches) == 1, 'Moteur embarque non reconnu.')
    m = matches[0]
    original = gzip.decompress(base64.b64decode(m.group(1), validate=True))
    require(original.count(OLD) == 1, 'Port du moteur embarque non reconnu.')
    corrected = original.replace(OLD, NEW)
    compile(corrected, 'onefichier.py', 'exec')
    old_hash, new_hash = digest(original), digest(corrected)
    eq = f'== \'{old_hash}\''
    neq = f'!= \'{old_hash}\''
    require(module.count(eq) == 1 and module.count(neq) == 1,
            'Controle d\'integrite du moteur non reconnu.')
    packed = base64.b64encode(gzip.compress(corrected, mtime=0)).decode('ascii')
    module = module[:m.start(1)] + packed + module[m.end(1):]
    module = module.replace(eq, f"== '{new_hash}'", 1)
    module = module.replace(neq, neq + f" && \"$previous_hash\" != '{new_hash}'", 1)
    result = (before + module).replace(header, header.replace('v4.0', 'v4.0.1'), 1)
    result = result.replace(banner, banner.replace('v4.0', 'v4.0.1'), 1)
    return result, original, corrected

def stage(path, data):
    fd, name = tempfile.mkstemp(prefix='.blondin-v401-', dir=path.parent)
    tmp = Path(name)
    try:
        with os.fdopen(fd, 'wb') as f:
            f.write(data)
            f.flush()
            os.fsync(f.fileno())
        shutil.copystat(path, tmp)
        return tmp
    except BaseException:
        tmp.unlink(missing_ok=True)
        raise

def main():
    p = argparse.ArgumentParser(description='Gestionnaire Batocera v4.0.1 TEST')
    p.add_argument('--online', action='store_true', help='Installer la base v4.0 si absente, puis appliquer la mise a jour')
    args = p.parse_args()
    require(os.geteuid() == 0, 'Executer en root.')
    release = Path('/etc/os-release').read_text()
    require('batocera' in release.lower() and re.search(r'(?<!\d)44(?!\d)', release), 'Reserve a Batocera 44.')
    require(not MANAGER.is_symlink() and not ENGINE.is_symlink(), 'Lien symbolique refuse.')
    if not MANAGER.exists() and args.online:
        with tempfile.TemporaryDirectory(prefix='blondin-v401-') as folder:
            installer = Path(folder) / 'install-v4.0.sh'
            subprocess.run(['curl','-fsSL','--connect-timeout','10','--max-time','90',ORIGINAL,'-o',str(installer)], check=True)
            subprocess.run(['bash', str(installer), '--online'], check=True)
    require(regular(MANAGER), 'Gestionnaire v4.0 absent. Installer la base v4.0 ou utiliser --online.')
    src = MANAGER.read_bytes().decode('utf-8')
    if '# Gestionnaire Batocera BLONDIN EDITION v4.0.1 TEST' in src:
        print('[INFO] Gestionnaire v4.0.1 TEST deja installe.')
        return
    updated, original, corrected = patch_manager(src)
    changes = [(MANAGER, updated.encode('utf-8'))]
    if regular(ENGINE):
        current = ENGINE.read_bytes()
        if current == original:
            changes.append((ENGINE, corrected))
        elif current == corrected:
            print('[OK] Moteur 1fichier deja configure sur 8766.')
        else:
            print('[ATTENTION] Moteur 1fichier personnalise ou autre version : conserve. Le gestionnaire impose 8766.')
    else:
        require(not ENGINE.exists(), 'Moteur 1fichier non regulier.')
    staged = []
    try:
        for path, data in changes:
            staged.append((path, stage(path, data)))
        subprocess.run(['bash','-n',str(staged[0][1])], check=True)
        backup = BASE / 'backup-gestionnaire-ports' / ('v4.0.1-' + datetime.now().strftime('%Y%m%d-%H%M%S') + '-' + str(os.getpid()))
        backup.mkdir(mode=0o700, parents=True)
        for path, _ in staged:
            shutil.copy2(path, backup / path.name)
        applied = []
        try:
            for path, tmp in reversed(staged):
                os.replace(tmp, path)
                applied.append(path)
        except BaseException:
            for path in reversed(applied):
                os.replace(stage(path, (backup / path.name).read_bytes()), path)
            raise
        print('[OK] Gestionnaire Batocera BLONDIN EDITION v4.0.1 TEST installe.')
        print('[OK] Telechargement HTTPS : 8766. Sauvegarde : 8765. Ntfy : 18765.')
        print('[OK] Patch LinuxLoader Lindbergh, Sinden et ordre des systemes conserves.')
        print('[INFO] Sauvegarde :', backup)
        print('[INFO] Quitter puis relancer le gestionnaire. Si le Web de telechargement utilisait 8765, le redemarrer depuis son menu.')
    finally:
        for _, tmp in staged:
            tmp.unlink(missing_ok=True)

if __name__ == '__main__':
    try:
        main()
    except (Exception, KeyboardInterrupt) as exc:
        print('[ERREUR]', exc)
        raise SystemExit(1)
