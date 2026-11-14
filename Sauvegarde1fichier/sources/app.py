#!/usr/bin/env python3
"""Sauvegarde 1fichier - BLONDIN EDITION - v2.0 / Batocera 44.
Manual, non-destructive uploads. Background jobs protected by a shared flock lock.
"""
import fcntl
import configparser
import json
import struct
import select
import signal
import termios
import tty
import contextlib
import os
import re
import shutil
import subprocess
import sys
import time
import uuid
import urllib.request
import urllib.error
from datetime import datetime
from pathlib import Path

BASE = Path(os.environ.get('BLONDIN_1FICHIER_HOME', '/userdata/system/1fichier-blondin'))
CONFIG = BASE / 'dossiers.json'
LOCK = BASE / 'transfert.lock'
ACTIVE = BASE / 'transfert-actif.json'
LAST = BASE / 'dernier-resultat.json'
LOG_DIR = Path(os.environ.get('BLONDIN_1FICHIER_LOG_DIR', '/userdata/system/logs'))
LOG = LOG_DIR / 'sauvegarde-1fichier-blondin.log'
HISTORY = BASE / 'historique.json'
# Les rapports de verification sont persistants et lisibles pendant le controle.
RUN_DIR = LOG_DIR / '1fichier-blondin'
RCLONE_CONFIG = Path(os.environ.get('BLONDIN_1FICHIER_RCLONE_CONFIG', '/userdata/system/.config/rclone/rclone.conf'))
RCLONE = os.environ.get('BLONDIN_1FICHIER_RCLONE', '/usr/bin/rclone')
TRIGGER = Path(os.environ.get('BLONDIN_1FICHIER_TRIGGER', '/userdata/system/configs/emulationstation/scripts/screensaver-start/shutdown-trigger.sh'))
CANCEL = Path(os.environ.get('BLONDIN_1FICHIER_CANCEL', '/userdata/system/configs/emulationstation/scripts/screensaver-stop/shutdown-cancel.sh'))
MARKER = '1FICHIER-BLONDIN-GUARD-V1'


def timestamp():
    return datetime.now().strftime('%Y-%m-%d %H:%M:%S')


def atomic_json(path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name('.' + path.name + '.' + uuid.uuid4().hex)
    try:
        with open(tmp, 'w', encoding='utf-8') as out:
            json.dump(obj, out, ensure_ascii=False, indent=2)
            out.write('\n')
            out.flush()
            os.fsync(out.fileno())
        os.chmod(tmp, 0o600)
        os.replace(tmp, path)
    finally:
        try:
            tmp.unlink()
        except FileNotFoundError:
            pass


def read_json(path, default):
    try:
        with open(path, encoding='utf-8') as f:
            return json.load(f)
    except FileNotFoundError:
        return default


def account_info():
    """Read-only 1fichier account query; never print or persist the API key."""
    parser = configparser.ConfigParser(interpolation=None)
    if not RCLONE_CONFIG.is_file():
        raise RuntimeError('Configuration Rclone introuvable.')
    try:
        parser.read(RCLONE_CONFIG, encoding='utf-8')
        if parser.get('1fichier', 'type', fallback='') != 'fichier':
            raise ValueError('Le remote 1fichier est incorrect.')
        key = parser.get('1fichier', 'api_key', fallback='').strip()
    except (configparser.Error, UnicodeError) as exc:
        raise RuntimeError('Configuration Rclone illisible.') from exc
    if not key or any(ch in key for ch in '\r\n'):
        raise RuntimeError('Cle API 1fichier absente ou invalide.')
    req = urllib.request.Request('https://api.1fichier.com/v1/user/info.cgi',
        data=b'{}', method='POST', headers={
            'Authorization': 'Bearer ' + key,
            'Content-Type': 'application/json',
            'Accept': 'application/json',
        })
    try:
        with urllib.request.urlopen(req, timeout=12) as response:
            data = json.loads(response.read(65536).decode('utf-8'))
    except (OSError, ValueError, urllib.error.URLError) as exc:
        raise RuntimeError('API 1fichier indisponible ou reponse invalide.') from exc
    if not isinstance(data, dict) or data.get('status') != 'OK':
        raise RuntimeError('1fichier a refuse la consultation du compte.')
    return data


def show_account_storage():
    clear()
    title('COMPTE ET COLD STORAGE 1FICHIER — v2.0')
    print('  Consultation uniquement : aucun transfert ni modification.')
    try:
        info = account_info()
        used = max(0, int(info['cold_storage']))
        # L'API exprime les volumes en octets; available_cold_storage est le quota total.
        total = int(info['available_cold_storage'])
        if total <= 0:
            raise ValueError('Quota Cold Storage non communique.')
        free = max(0, total - used)
        ratio = 100 * used / total
        offer = str(info.get('offer', '?'))
        # Codes d'offre numeriques : ne pas inventer le nom d'un forfait.
        label = 'Premium (code {})'.format(offer) if offer != '?' else 'Non communique'
        end = str(info.get('subscription_end') or '-')
        try:
            end = datetime.strptime(end[:19], '%Y-%m-%d %H:%M:%S').strftime('%d/%m/%Y')
        except ValueError:
            pass
        def volume(n):
            return '{:.2f} {}'.format(n / (1024 ** 4), 'To') if n >= 1024 ** 4 else '{:.2f} Go'.format(n / (1024 ** 3))
        print('\n  Abonnement       : ' + label)
        print('  Expiration       : ' + end)
        print('\n  COLD STORAGE')
        print('  Utilise          : ' + volume(used))
        print('  Quota total      : ' + volume(total))
        print('  Disponible       : ' + volume(free))
        filled = min(30, int(ratio * 30 / 100))
        color = '1;31' if ratio >= 90 else '1;33' if ratio >= 70 else '1;32'
        print('  ' + paint('█' * filled + '░' * (30 - filled), color) + '  {:.2f} %'.format(ratio))
        print('  ' + paint('QUOTA DEPASSE' if used > total else
              'ATTENTION : QUOTA PRESQUE ATTEINT' if ratio >= 90 else
              'SURVEILLANCE DU QUOTA' if ratio >= 70 else 'STOCKAGE DISPONIBLE', color))
        print('\n  Mise a jour : ' + timestamp())
    except (RuntimeError, ValueError, KeyError, TypeError) as exc:
        print('\n  ' + paint('INFORMATIONS INDISPONIBLES', '1;33'))
        print('  ' + str(exc))
        print('  Aucun fichier distant n a ete modifie.')
    pause()


def entries():
    data = read_json(CONFIG, None)
    if not isinstance(data, list):
        raise ValueError('Configuration des dossiers absente ou invalide.')
    return data


def save_entries(data):
    atomic_json(CONFIG, data)


def remote_path(s):
    """Only paths beneath one fixed rclone remote (never arbitrary remotes)."""
    s = s.strip().replace('\\', '/')
    if s.lower().startswith('1fichier:'):
        s = s[9:]
    if not s or s.startswith('/') or ':' in s or '\x00' in s:
        raise ValueError('Indiquer un dossier relatif sur 1fichier, par exemple Sauvegarde-TeknoParrot.')
    parts = s.split('/')
    if any(p in ('', '.', '..') or p.strip() != p or any(ord(c) < 32 for c in p) for p in parts):
        raise ValueError('Nom de destination non valide.')
    return '/'.join(parts)


def _mounted_volumes():
    """Points de montage effectifs (kernel mountinfo, aucun nom de disque suppose).

    Un montage virtuel ou le volume racine ne peut jamais servir de
    justification pour accepter un chemin externe a /userdata.
    """
    mounts = []
    try:
        with open('/proc/self/mountinfo', encoding='utf-8') as stream:
            for line in stream:
                left, separator, right = line.partition(' - ')
                if not separator:
                    continue
                fields = left.split()
                fs_fields = right.split()
                if len(fields) < 5 or len(fs_fields) < 1:
                    continue
                # mountinfo encode les espaces et les caracteres speciaux en octal.
                raw = re.sub(r'\\([0-7]{3})',
                             lambda m: chr(int(m.group(1), 8)), fields[4])
                mounts.append((Path(raw), fs_fields[0]))
    except OSError as exc:
        raise ValueError('Impossible de verifier les volumes montes.') from exc
    return mounts


def _mount_for(real, mounts=None):
    mounts = _mounted_volumes() if mounts is None else mounts
    candidates = [(mp, fstype) for mp, fstype in mounts
                  if real == mp or mp in real.parents]
    if not candidates:
        return None, None
    return max(candidates, key=lambda item: len(item[0].parts))


def source_info(s, expected_mount=None, mounts=None):
    """Valide un dossier et retourne le vrai chemin a transmettre a Rclone.

    Les chemins /userdata ordinaires restent autorises. Hors /userdata,
    un vrai montage de donnees est obligatoire (pas simplement un repertoire
    vide laisse par un disque debranche). Aucune option --copy-links globale.
    """
    p = Path(str(s).strip()).expanduser()
    if not p.is_absolute():
        raise ValueError('Le chemin source doit etre absolu.')
    try:
        real = p.resolve(strict=True)
        if not real.is_dir():
            raise ValueError('La source ne pointe pas vers un dossier.')
        device = real.stat().st_dev
    except (OSError, RuntimeError) as exc:
        raise ValueError('Dossier inaccessible (lien casse ou disque absent) : ' + str(p)) from exc
    if real in (Path('/'), Path('/userdata')):
        raise ValueError('Choisir un dossier, pas la racine du systeme ou /userdata.')
    if real == BASE.resolve() or BASE.resolve() in real.parents:
        raise ValueError('Impossible de sauvegarder le dossier interne du logiciel.')
    in_userdata = Path('/userdata') in real.parents
    mp, fstype = _mount_for(real, mounts)
    virtual = {'proc','sysfs','devtmpfs','devpts','tmpfs','ramfs','overlay',
               'cgroup','cgroup2','securityfs','debugfs','tracefs','configfs',
               'fusectl','efivarfs','bpf','pstore','autofs','mqueue','hugetlbfs',
               'nsfs','binfmt_misc','rpc_pipefs'}
    for restricted in ('/proc', '/sys', '/dev'):
        if real == Path(restricted) or Path(restricted) in real.parents:
            raise ValueError('Un dossier systeme ne peut pas etre sauvegarde.')
    external = bool(mp and mp != Path('/') and mp != Path('/userdata')
                    and fstype not in virtual)
    if not in_userdata and not external:
        raise ValueError('Source hors /userdata : aucun disque de donnees monte valide detecte (' + str(real) + ').')
    if not in_userdata and real == mp:
        raise ValueError('Choisir un dossier dans le disque externe, pas sa racine : ' + str(mp))
    if expected_mount:
        expected = Path(expected_mount)
        if not external or mp != expected:
            raise ValueError('Disque externe attendu non monte : ' + str(expected))
    return {'original':str(p), 'real':str(real),
            'mount':str(mp) if external else '', 'dev':device,
            'linked':p.is_symlink() or p != real}


def local_path(s):
    # Le dossier logique reste dans dossiers.json; seul le chemin resolu va a Rclone.
    return source_info(s)['original']


def preflight():
    if not os.path.isfile(RCLONE_CONFIG):
        raise RuntimeError('Configuration Rclone introuvable : ' + str(RCLONE_CONFIG))
    if not os.path.isfile(RCLONE) or not os.access(RCLONE, os.X_OK):
        raise RuntimeError('Rclone introuvable : ' + RCLONE)
    if TRIGGER.is_file() and MARKER not in TRIGGER.read_text(encoding='utf-8', errors='replace'):
        raise RuntimeError('Protection extinction absente du script actif : relancer l installateur avant toute sauvegarde.')
    if TRIGGER.is_file() and not shutil.which('flock'):
        raise RuntimeError('Commande flock absente. Protection contre extinction indisponible.')
    res = subprocess.run([RCLONE, 'listremotes', '--config', str(RCLONE_CONFIG)],
                         capture_output=True, text=True, timeout=25)
    if res.returncode != 0 or '1fichier:' not in res.stdout.splitlines():
        raise RuntimeError('Le compte distant 1fichier n est pas configure dans Rclone.')


def get_lock(nonblocking=True):
    BASE.mkdir(parents=True, exist_ok=True)
    fd = os.open(str(LOCK), os.O_CREAT | os.O_RDWR, 0o600)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | (fcntl.LOCK_NB if nonblocking else 0))
        return fd
    except BlockingIOError:
        os.close(fd)
        return None


def running():
    fd = get_lock()
    if fd is None:
        return True
    os.close(fd)
    return False


def logline(line):
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    with open(LOG, 'a', encoding='utf-8') as f:
        f.write(f'[{timestamp()}] {line}\n')


def cancel_old_timer():
    """Cancel an already scheduled worker which may have loaded an older script.
    The event-based timer is re-armed on completion if the screensaver is active.
    """
    state = Path('/tmp/shutdown.screensaver')
    if not state.exists():
        return
    if not CANCEL.is_file():
        raise RuntimeError('Minuteur actif, script annulation absent : securite non garantie.')
    res = subprocess.run(['/bin/bash', str(CANCEL), '--timer-only'],
                         capture_output=True, text=True, timeout=12)
    if res.returncode != 0 or state.exists():
        raise RuntimeError('Impossible d annuler le minuteur actuel : ' + (res.stderr or res.stdout).strip())
    logline('Minuteur deja actif annule avant transfert (sans toucher au marqueur de veille).')


def rearm_if_needed():
    """Re-arm after a transfer, but only if the V3 screensaver marker exists."""
    mark = Path('/tmp/batocera-screensaver-active')
    state = Path('/tmp/shutdown.screensaver')
    if mark.is_file() and not state.exists() and TRIGGER.is_file():
        res = subprocess.run(['/bin/bash', str(TRIGGER), '--manual'],
                             capture_output=True, text=True, timeout=12)
        if res.returncode == 0:
            logline('Minuteur extinction relance apres sauvegarde (delai preserve).')
        else:
            logline('INFO : relance minuteur impossible, l economiseur le relancera au prochain cycle : ' + (res.stderr or res.stdout).strip())



# Centrage horizontal des ecrans (menus, suivis, confirmations, saisies).
# Ne s'active que dans le processus de menu ; le worker en arriere-plan
# garde ses journaux et sa sortie Rclone strictement inchanges.
_NATIVE_PRINT = print
_NATIVE_INPUT = input
_UI_CENTER = False
_UI_PANEL_COLS = 76
_ANSI_CONTROLS_ONLY = re.compile(r'^(?:\x1b\[[0-9;?]*[A-Za-z])+$')

def _ui_margin():
    if not _UI_CENTER or not sys.stdout.isatty():
        return 0
    columns = shutil.get_terminal_size(fallback=(100, 28)).columns
    return max(0, (columns - _UI_PANEL_COLS) // 2)

def _center_output(text):
    if not text or _ANSI_CONTROLS_ONLY.fullmatch(text):
        return text
    margin = ' ' * _ui_margin()
    if not margin:
        return text
    # Traiter les vrais retours a la ligne ; les sequences de nettoyage
    # ANSI seules (clear/hide cursor) ne sont jamais espacees.
    lines = text.splitlines(keepends=True)
    return ''.join(margin + part if part.rstrip('\r\n') else part
                   for part in lines)

def print(*values, sep=' ', end='\n', file=None, flush=False):
    if not _UI_CENTER or (file is not None and file is not sys.stdout):
        return _NATIVE_PRINT(*values, sep=sep, end=end, file=file, flush=flush)
    separator = ' ' if sep is None else sep
    ending = '\n' if end is None else end
    text = separator.join(str(v) for v in values) + ending
    return _NATIVE_PRINT(_center_output(text), end='', file=file, flush=flush)

def input(prompt=''):
    if not _UI_CENTER:
        return _NATIVE_INPUT(prompt)
    return _NATIVE_INPUT(_center_output(str(prompt)))

# Couleurs sobres pour xterm ; texte lisible aussi depuis SSH.
COLOR = sys.stdout.isatty() and os.environ.get('NO_COLOR') is None

def paint(text, code):
    return f'\033[{code}m{text}\033[0m' if COLOR else text


def title(text):
    print(paint('\u2550' * 76, '36'))
    print(paint('  ' + text, '1;33'))
    print(paint('\u2550' * 76, '36'))


def section(text):
    print(paint('  ' + text, '1;36'))


def yesno(value):
    return paint('OK', '1;32') if value else paint('ERREUR', '1;31')


def result_status(record):
    if record.get('etat') == 'annule':
        return paint('ANNULE', '1;33')
    return yesno(bool(record.get('ok')))



def colored_log(line):
    """Colorize status lines at display time only (never alter saved logs)."""
    text = line.rstrip('\n')
    m = re.match(r'^(\[[0-9-]+ [0-9:]+\]\s+)([^:]+?)(\s*:\s*)(OK|ANNULE|ERREUR(?:.*))$', text)
    if m:
        prefix, system, sep, status = m.groups()
        return (prefix + paint(system, '1;36') + sep +
                paint(status, '1;32' if status == 'OK' else '1;33' if status == 'ANNULE' else '1;31'))
    if '===== FIN : ANNULE =====' in text:
        return text.replace('===== FIN : ANNULE =====', paint('===== FIN : ANNULE =====', '1;33'))
    if '===== FIN : OK =====' in text:
        return text.replace('===== FIN : OK =====', paint('===== FIN : OK =====', '1;32'))
    if '===== FIN : ERREURS' in text or 'ERREUR FATALE' in text:
        return paint(text, '1;31')
    return text


def show_folder_log_result(record):
    """Bilan lisible depuis l'historique, meme pour les journaux plus anciens.

    Un transfert termine sans erreur ne prouve pas une verification des octets.
    """
    cancelled = record.get('etat') == 'annule'
    ok = bool(record.get('ok')) and not cancelled
    if cancelled:
        headline, detail, color = ('ANNULE', 'Operation annulee, extinction non declenchee.', '1;33')
    elif ok and record.get('mode') == 'check':
        headline, detail, color = ('VERIFICATION REUSSIE', 'Controle des noms et tailles termine sans anomalie.', '1;32')
    elif ok:
        headline, detail, color = ('SAUVEGARDE TERMINEE SANS ERREUR',
                                   'Transfert Rclone reussi (integrite du contenu non controlee).', '1;32')
    else:
        headline, detail, color = ('ECHEC OU ERREURS',
                                   'Consulter les messages du journal pour le diagnostic.', '1;31')
    print('\n  ' + paint('─' * 62, '36'))
    print('  ' + paint('BILAN FINAL : ' + headline, color))
    print('  ' + detail)


def action_row(n1, label1, n2, label2):
    """Fixed-width two-column layout, independent of ANSI color bytes."""
    print('  ' + paint(n1, '1;33') + '  ' + label1.ljust(31) +
          '  ' + paint(n2, '1;33') + '  ' + label2)

def load_history():
    data = read_json(HISTORY, [])
    return data if isinstance(data, list) else []


def append_history(record):
    data = load_history()
    data.append(record)
    atomic_json(HISTORY, data[-300:])


def latest_for(entry):
    for item in reversed(load_history()):
        if item.get('id') == entry.get('id'):
            return item
    return None


def transfer_size(line):
    # Donnee indicative tiree du dernier compteur rclone, jamais une verification d'integrite.
    m = re.search(r'NOTICE:\s*([0-9.,]+\s*[TGMK]?i?B)\s*/\s*([0-9.,]+\s*[TGMK]?i?B)', line)
    if not m:
        return None
    return m.group(1).strip(), m.group(2).strip()


def copy_progress_path(job):
    """Etat temporaire de l'envoi en cours, isole par numero d'operation."""
    if not re.fullmatch(r'[0-9a-f]{16}', str(job)):
        raise ValueError('Identifiant de suivi non valide.')
    return RUN_DIR / ('progression-' + job + '.json')


def parse_copy_progress(line):
    """Extrait une statistique rclone de sauvegarde (ne prouve pas l'integrite)."""
    if 'NOTICE:' not in line:
        return None
    volume = transfer_size(line)
    if not volume:
        return None
    m = re.search(r'/\s*[0-9.,]+\s*[TGMK]?i?B\s*,\s*(\d{1,3})%\s*,\s*([^,]+),\s*ETA\s*([^,()\n]+)', line)
    if not m:
        return None
    counters = re.search(r'\(xfr#(\d+)/(\d+)\)', line)
    return {
        'envoye': volume[0], 'total': volume[1],
        'pourcentage': min(100, int(m.group(1))),
        'vitesse': m.group(2).strip(), 'eta': m.group(3).strip(),
        'fichiers': int(counters.group(1)) if counters else None,
        'fichiers_total': int(counters.group(2)) if counters else None,
    }


def bar(value, width=38):
    value = max(0, min(100, int(value)))
    done = (value * width) // 100
    return '[' + paint('█' * done, '1;36') + '░' * (width - done) + ']  {}%'.format(value)


def request_batocera_poweroff():
    """Demande l'arret seulement depuis le menu actif, apres succes confirme.

    Aucun ordre d'arret n'est place dans le worker : quitter le logiciel
    desactive necessairement l'extinction, sans arreter la sauvegarde.
    """
    cmd = shutil.which('shutdown')
    if cmd:
        args = [cmd, '-h', 'now']
    else:
        cmd = shutil.which('poweroff')
        if not cmd:
            raise RuntimeError('Commande shutdown/poweroff introuvable.')
        args = [cmd]
    logline('Demande extinction Batocera apres sauvegarde reussie (session du logiciel ouverte).')
    subprocess.Popen(args, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True, close_fds=True)


def shutdown_choice():
    """Choix ponctuel : non par defaut, aucun reglage permanent."""
    print('\n  ' + paint('EXTINCTION APRES SAUVEGARDE', '1;36'))
    print('  Si activee, garder ce logiciel ouvert pendant toute la sauvegarde.')
    print('  Quitter le logiciel annule l extinction mais PAS le transfert.')
    choice = NAV.choose([
        ('0', 'Non, conserver Batocera allume (defaut)'),
        ('1', 'Oui, eteindre Batocera apres succes (30 secondes)')
    ], 'Eteindre Batocera apres la sauvegarde ?', default=0)
    return choice == '1'


def monitor_status(auto_shutdown_job=None):
    """Suivi direct. Auto-extinction uniquement tant que CE suivi reste ouvert."""
    if not sys.stdin.isatty():
        job_state()
        if auto_shutdown_job:
            print('  Extinction non activee : interface interactive indisponible.')
        return
    auto = bool(auto_shutdown_job)
    initial = read_json(ACTIVE, {})
    job = auto_shutdown_job if auto else initial.get('job', '') if running() else ''
    countdown_started = None
    with NAV._raw_stdin():
        print('\033[?25l', end='', flush=True)
        try:
            while True:
                active = running()
                state = read_json(ACTIVE, {})
                last = read_json(LAST, {})
                # Le worker libere le verrou uniquement apres son bilan.
                # Ne jamais prendre un ancien bilan pour un succes du job suivi.
                success = bool(auto and job and not active and
                    isinstance(last, dict) and last.get('job') == job and
                    last.get('mode') == 'copy' and last.get('etat') == 'ok' and
                    last.get('ok') is True)
                if success and countdown_started is None:
                    countdown_started = time.monotonic()
                    logline('Compte a rebours de 30 s lance pour le job ' + job)
                if not success:
                    countdown_started = None
                # Ne revalider l'arret qu'apres 30 s sans interruption.
                if countdown_started is not None and time.monotonic() - countdown_started >= 30:
                    newest = read_json(LAST, {})
                    if (not running() and newest.get('job') == job and
                            newest.get('mode') == 'copy' and newest.get('etat') == 'ok' and
                            newest.get('ok') is True):
                        print('\033[H\033[J', end='')
                        title('EXTINCTION BATOCERA — BLONDIN EDITION')
                        print('  Sauvegarde terminee avec succes.')
                        print('  Extinction demandee maintenant...')
                        sys.stdout.flush()
                        try:
                            request_batocera_poweroff()
                        except Exception as exc:
                            logline('ERREUR demande extinction : ' + str(exc))
                            print('  ' + paint('ERREUR EXTINCTION : ' + str(exc), '1;31'))
                            NAV.wait()
                        return
                    countdown_started = None
                    auto = False
                # Ne jamais afficher les statistiques d'une ancienne sauvegarde.
                if not job and active:
                    job = state.get('job', '')
                current = bool(job and state.get('job') == job)
                snap = {}
                if current and state.get('mode') == 'copy':
                    try:
                        snap = read_json(copy_progress_path(job), {})
                        if not isinstance(snap, dict) or snap.get('job') != job:
                            snap = {}
                    except ValueError:
                        pass
                print('\033[H\033[J', end='')
                title('ETAT ET PROGRESSION EN DIRECT — v2.0')
                if not current:
                    print('  Aucune operation a suivre actuellement.')
                    if last:
                        print('  Dernier bilan : ' + str(last.get('date', '-')) + ' — ' + result_status(last))
                else:
                    mode = state.get('mode')
                    print('  Operation        : ' + ('SAUVEGARDE' if mode == 'copy' else 'VERIFICATION'))
                    print('  Etat             : ' + (paint('EN COURS', '1;33') if active else result_status(last) if last.get('job') == job and not active else paint('TERMINE', '1;32')))
                    print('  Debut            : ' + str(state.get('started', '-')))
                    guard = TRIGGER.is_file() and MARKER in TRIGGER.read_text(encoding='utf8', errors='replace')
                    print('  Extinction       : ' + (paint('SUSPENDUE (verrou)', '1;32') if active and guard else
                                                      paint('ATTENTION : garde absent', '1;31') if active else
                                                      'Minuteur normal'))
                    if mode == 'copy':
                        name = snap.get('dossier', ', '.join(state.get('dossiers', [])))
                        current_no = snap.get('index', 1)
                        total_no = snap.get('nombre_dossiers', len(state.get('dossiers', [])))
                        print('  Dossier          : {} ({}/{})'.format(name, current_no, total_no))
                        stats = snap.get('progression') or {}
                        print('')
                        if stats:
                            print('  ' + bar(stats.get('pourcentage', 0)))
                            print('  Donnees          : {} / {}'.format(stats.get('envoye', '-'), stats.get('total', '-')))
                            print('  Vitesse          : {}'.format(stats.get('vitesse', '-')))
                            print('  Temps restant    : {} (estimation)'.format(stats.get('eta', '-')))
                            if stats.get('fichiers_total') is not None:
                                print('  Fichiers envoyes : {} / {}'.format(stats['fichiers'], stats['fichiers_total']))
                        elif active:
                            print('  Preparation / attente des premieres statistiques Rclone...')
                        print('  Fichiers copies  : {}'.format(snap.get('copies', 0)))
                        print('  Erreurs detectees: {}'.format(snap.get('erreurs', 0)))
                        if active and stats.get('pourcentage') == 100:
                            print('  ' + paint('Finalisation des fichiers en cours...', '1;33'))
                        if active:
                            print('  Actualisation automatique toutes les secondes.')
                    else:
                        total = state.get('total_local', 0)
                        checked = count_report(state.get('report',''))
                        extra = latest_check_stats() if active else None
                        done = max(checked['examines'], extra[0] if extra else 0)
                        print('  Fichiers examines: {} / {}'.format(done, total if total else '?'))
                        if total:
                            print('  ' + bar(100 * done // total))
                        print('  Conformes: {} | Manquants: {} | Tailles: {} | Erreurs: {}'.format(
                            checked['valides'], checked['manquants'], checked['differents'], checked['erreurs']))
                    if not active:
                        if last.get('job') == job:
                            print('\n  BILAN FINAL : ' + result_status(last))
                            if last.get('erreur'):
                                print('  ' + str(last['erreur'])[:125])
                        else:
                            print('\n  ' + paint('Operation interrompue ou bilan indisponible', '1;31'))
                print('')
                if auto and active:
                    print('  ' + paint('EXTINCTION AUTOMATIQUE ACTIVEE', '1;33'))
                    print('  ' + paint('Rester dans le logiciel pour permettre l extinction.', '1;33'))
                    print('  Quitter ce suivi ou le logiciel desactive l extinction.')
                    print('  La sauvegarde continuera en arriere-plan.')
                    print('  B / Echap / Start : demander le retour SANS extinction.')
                elif auto and countdown_started is not None:
                    remaining = max(0, int(30.999 - (time.monotonic() - countdown_started)))
                    print('  ' + paint('SAUVEGARDE REUSSIE — EXTINCTION DANS {:02d} s'.format(remaining), '1;33'))
                    print('  ' + bar((30 - remaining) * 100 / 30, width=30))
                    print('  A / B / Entree / Echap / Start : ANNULER L EXTINCTION.')
                elif auto and not active:
                    print('  ' + paint('Sauvegarde non confirmee OK : PAS D EXTINCTION.', '1;31'))
                    print('  A / B / Entree : retour au menu.')
                else:
                    print('  B / Echap / Start : retour (le transfert continue).')
                    if not active:
                        print('  A / Entree : retour au menu.')
                sys.stdout.flush()
                action = NAV._get_action(timeout=0.5 if auto else 1.0)
                if auto and active and action in ('back', 'home'):
                    if NAV.confirm('Retour au menu et ANNULER l extinction (transfert maintenu) ?'):
                        logline('Extinction apres sauvegarde desactivee par retour au menu (job '+job+').')
                        return
                    continue
                if auto and countdown_started is not None and action in ('accept','back','home'):
                    logline('Extinction apres sauvegarde annulee pendant le compte a rebours (job '+job+').')
                    print('  Extinction annulee, Batocera reste allume.')
                    return
                if action in ('back', 'home') or (not active and action == 'accept'):
                    return
        finally:
            print('\033[?25h', end='', flush=True)


def migrate_v1_history():
    """Reprend les anciens bilans OK de la v1 sans toucher au journal originel."""
    if HISTORY.exists() or not LOG.is_file():
        return
    try:
        saved_entries = entries()
        mapping = {x['nom'].casefold(): x for x in saved_entries}
        saved = []
        current = None
        with LOG.open(encoding='utf-8', errors='replace') as stream:
            for line in stream:
                line = line.strip()
                start = re.match(r'^\[([0-9-]+ [0-9:]+)\] (.*?) : (/userdata/.*?) -> 1fichier:(.*?)$', line)
                if start:
                    name = start.group(2)
                    entry = mapping.get(name.casefold())
                    current = {'id': entry['id'] if entry else name, 'nom': name,
                               'source': start.group(3), 'destination': start.group(4),
                               'date_debut': start.group(1), 'mode': 'copy', 'volume': '-',
                               'total': '-', 'copies': 0, 'erreurs': 0, 'journal': '',
                               'version': 'v1.0'}
                    continue
                if current is None:
                    continue
                progress = transfer_size(line)
                if progress:
                    current['volume'], current['total'] = progress
                if 'Copied (new)' in line:
                    current['copies'] += 1
                if ' ERROR ' in line or ' ERROR:' in line:
                    current['erreurs'] += 1
                done = re.match(r'^\[([0-9-]+ [0-9:]+)\] (.*?) : (OK|ERREUR.*)$', line)
                if done and done.group(2) == current['nom']:
                    current['date'] = done.group(1)
                    current['ok'] = done.group(3) == 'OK'
                    current['code'] = 0 if current['ok'] else 1
                    saved.append(current)
                    current = None
        atomic_json(HISTORY, saved[-300:])
    except Exception as exc:
        # L'historique ne doit jamais empecher l'acces au lanceur.
        print('[INFO] Ancien historique non importe : ' + str(exc))


def tail_lines(path, count=35, only_errors=False):
    if not path.is_file():
        return ['Aucun journal disponible.']
    with path.open('rb') as f:
        f.seek(0, os.SEEK_END)
        size = f.tell()
        f.seek(max(0, size - 350000))
        lines = f.read().decode('utf-8', errors='replace').splitlines()
    if only_errors:
        lines = [line for line in lines if re.search(r'ERROR|ERREUR|Failed|FATAL', line, re.I)]
    return lines[-count:] or ['Aucune ligne correspondante.']


def latest_progress():
    for line in reversed(tail_lines(LOG, count=100)):
        if transfer_size(line):
            return line.strip()
    return None


def count_local_files(path):
    """Nombre indicatif de fichiers reguliers (les liens symboliques sont ignores)."""
    total = 0
    for parent, dirs, files in os.walk(path, followlinks=False):
        dirs[:] = [d for d in dirs if not os.path.islink(os.path.join(parent, d))]
        for name in files:
            if os.path.isfile(os.path.join(parent, name)) and not os.path.islink(os.path.join(parent, name)):
                total += 1
    return total


def count_report(path):
    """Analyse les symboles de --combined rclone sans toucher aux fichiers."""
    result = {'valides': 0, 'manquants': 0, 'differents': 0, 'erreurs': 0, 'examines': 0}
    if not path or not Path(path).is_file():
        return result
    with open(path, encoding='utf-8', errors='replace') as stream:
        for line in stream:
            if len(line) < 2 or line[1] != ' ':
                continue
            key = {'=': 'valides', '+': 'manquants', '*': 'differents', '!': 'erreurs'}.get(line[0])
            if key:
                result[key] += 1
                result['examines'] += 1
    return result


def check_result_line(nom, result, ok):
    status = paint('OK', '1;32') if ok else paint('PROBLEMES', '1;31')
    return ('  ' + paint(nom, '1;36') + ' : ' + status +
            ' | {} verifies | {} manquants | {} tailles differentes | {} erreurs'.format(
              result.get('valides', 0), result.get('manquants', 0),
              result.get('differents', 0), result.get('erreurs', 0)))


def latest_check_stats():
    """Compteur de controle rclone utilise si le rapport --combined est bufferise."""
    lines = tail_lines(LOG, count=350)
    start = next((i for i in range(len(lines)-1, -1, -1)
                  if '===== VERIFICATION :' in lines[i]), -1)
    if start < 0:
        return None
    for line in reversed(lines[start+1:]):
        if 'NOTICE:' not in line:
            continue
        m = re.search(r'\b(\d+)\s*/\s*(\d+)\s*,\s*(\d+)%', line)
        if m:
            return int(m.group(1)), int(m.group(2)), int(m.group(3))
    return None


def monitor_check(job):
    """Affiche le bilan pendant/apres la verification. B quitte sans arreter Rclone."""
    if not job:
        return
    def fmt_state():
        state = read_json(ACTIVE, {})
        last = read_json(LAST, {})
        if state.get('job') != job:
            return None, None, False
        report = state.get('report', '')
        stats = count_report(report)
        alive = running()
        if not alive and last.get('job') == job:
            details = last.get('details', [])
            if details:
                stats = details[0].get('verification', stats)
        return state, stats, alive
    if not sys.stdin.isatty():
        print('  Consulter Etat et progression ou Historique pour le bilan.')
        return
    with NAV._raw_stdin():
        print('\033[?25l', end='', flush=True)
        try:
            while True:
                state, stats, alive = fmt_state()
                print('\033[H\033[J', end='')
                title('VERIFICATION DES NOMS ET TAILLES — v2.0')
                if state is None:
                    print('  Aucun controle en cours associe a cette session.')
                    break
                print('  Dossier : ' + ', '.join(state.get('dossiers', [])))
                print('  Source / destination : comparaison SANS transfert')
                print('  ' + paint('EN COURS' if alive else 'TERMINE', '1;33' if alive else '1;32'))
                total = state.get('total_local', 0)
                done = stats.get('examines', 0)
                extra = latest_check_stats() if alive else None
                if extra and extra[0] > done:
                    done = extra[0]
                print('')
                print('  Fichiers examines     : {} / {}'.format(done, total if total else '?'))
                print('  Noms / tailles OK     : ' + paint(str(stats['valides']), '1;32'))
                print('  Manquants sur 1fichier: ' + paint(str(stats['manquants']), '1;31' if stats['manquants'] else '1;32'))
                print('  Tailles differentes   : ' + paint(str(stats['differents']), '1;31' if stats['differents'] else '1;32'))
                print('  Erreurs de lecture    : ' + paint(str(stats['erreurs']), '1;31' if stats['erreurs'] else '1;32'))
                if extra and stats['examines'] < done:
                    print('  Details des fichiers : en cours de consolidation...')
                if total:
                    frac = min(1.0, done / total)
                    width = 38
                    print('  [' + paint('█' * int(frac * width), '1;36') + '░' * (width - int(frac * width)) + ']  {:.0f}%'.format(frac * 100))
                else:
                    print('  Analyse des fichiers en cours...')
                print('')
                if alive:
                    print('  Comparaison en cours (aucun fichier transfere).')
                    print('  B / Echap : quitter ce suivi, verification maintenue en fond.')
                else:
                    outcome = read_json(LAST, {})
                    if outcome.get('job') == job:
                        good = outcome.get('ok', False)
                        print('  BILAN FINAL : ' + (paint('OK', '1;32') if good else paint('ANOMALIES', '1;31')))
                        print('  Details dans Historique et bilans / Journaux.')
                    else:
                        print('  Verification terminee : ouvrir Historique pour le bilan.')
                    print('  A / B / Entree : retour au menu')
                sys.stdout.flush()
                action = NAV._get_action(timeout=1.0)
                if action in ('back', 'home') or (not alive and action == 'accept'):
                    return
                if not alive and action in ('key:0',):
                    return
        finally:
            print('\033[?25h', end='', flush=True)


def start(ids, mode):
    fd = get_lock()
    if fd is None:
        print('\nUn transfert ou une verification est deja actif.')
        return None
    try:
        preflight()
        all_entries = entries()
        selected = [next((x for x in all_entries if x['id'] == i), None) for i in ids]
        if any(x is None for x in selected) or not selected:
            raise RuntimeError('Selection de dossiers invalide.')
        for x in selected:
            source_info(x['source'], x.get('volume_montage') or None)
            remote_path(x['destination'])
        cancel_old_timer()
        job = uuid.uuid4().hex[:16]
        RUN_DIR.mkdir(parents=True, exist_ok=True)
        report = str(RUN_DIR / ('verification-' + job + '.txt')) if mode == 'check' else ''
        total_local = count_local_files(source_info(selected[0]['source'], selected[0].get('volume_montage') or None)['real']) if mode == 'check' and len(selected) == 1 else 0
        payload = {'pid': None, 'job': job, 'mode': mode, 'ids': ids, 'started': timestamp(),
                   'dossiers': [x['nom'] for x in selected], 'report': report,
                   'total_local': total_local}
        atomic_json(ACTIVE, payload)
        LOG_DIR.mkdir(parents=True, exist_ok=True)
        with open(LOG, 'ab', buffering=0) as fout:
            proc = subprocess.Popen(
                [sys.executable, '-u', str(Path(__file__).resolve()), '--worker', str(fd), mode, job, *ids],
                stdin=subprocess.DEVNULL, stdout=fout, stderr=subprocess.STDOUT,
                start_new_session=True, close_fds=True, pass_fds=(fd,), cwd=str(BASE))
        payload['pid'] = proc.pid
        atomic_json(ACTIVE, payload)
        print('\n' + ('Sauvegarde' if mode == 'copy' else 'Verification') +
              ' lancee en arriere-plan. PID : ' + str(proc.pid))
        print('  La fermeture du menu ne stoppe pas l operation.')
        return job
    except Exception as exc:
        print('\n[ERREUR] ' + str(exc))
        return None
    finally:
        os.close(fd)



def cancel_active():
    """Request controlled cancellation of *our own* worker, never generic rclone PIDs."""
    if not running():
        print('\n  Aucune sauvegarde en cours.')
        return False
    state = read_json(ACTIVE, {})
    if not isinstance(state, dict) or state.get('mode') != 'copy':
        print('\n  Aucune sauvegarde active a annuler (une verification peut etre en cours).')
        return False
    pid = state.get('pid')
    job = state.get('job')
    if not isinstance(pid, int) or pid < 2 or not isinstance(job, str) or not re.fullmatch(r'[a-f0-9]{16}', job):
        print('\n  Etat actif incomplet : annulation refusee par securite.')
        return False
    # The worker is created as a new session, with a unique job UUID.
    # Check its complete argv before sending a signal (PID reuse protection).
    try:
        argv = Path(f'/proc/{pid}/cmdline').read_bytes().rstrip(b'\0').split(b'\0')
        expected_app = str(Path(__file__).resolve()).encode()
        if (len(argv) < 7 or argv[1] != b'-u' or argv[2] != expected_app or
            argv[3] != b'--worker' or argv[5] != b'copy' or
            argv[6] != job.encode() or os.getpgid(pid) != pid):
            raise ValueError('Processus non reconnu')
        if argv[0] not in (sys.executable.encode(), str(Path(sys.executable).resolve()).encode()):
            raise ValueError('Interpreteur non reconnu')
    except (OSError, ValueError, ProcessLookupError) as exc:
        print('\n  [ATTENTION] Impossible de confirmer le processus de sauvegarde : ' + str(exc))
        print('  Aucun signal envoye.')
        return False
    print('\n  Sauvegarde en cours : ' + ', '.join(state.get('dossiers', [])))
    print('  Les fichiers deja envoyes sur 1fichier seront conserves.')
    print('  Un fichier en cours de transfert peut necessiter un nouveau controle.')
    if not NAV.confirm('Annuler cette sauvegarde en cours ?'):
        print('  Annulation abandonnee : transfert maintenu.')
        return False
    # Re-check the PID and UUID immediately before signalling to guard races.
    try:
        argv2 = Path(f'/proc/{pid}/cmdline').read_bytes().rstrip(b'\0').split(b'\0')
        if argv2 != argv or os.getpgid(pid) != pid or not running():
            raise ValueError('La sauvegarde a change ou est terminee')
        # Signal only the confirmed worker: its signal handler interrupts rclone
        # and waits for it to exit before releasing the guard lock.
        os.kill(pid, signal.SIGINT)
        print('\n  [OK] Demande d annulation envoyee.')
        print('  Suivre l arret dans Etat et progression puis Historique.')
        return True
    except (OSError, ValueError, ProcessLookupError) as exc:
        print('\n  [ATTENTION] Aucun signal envoye : ' + str(exc))
        return False


def worker(fd, mode, job, ids):
    """Processus detache; le verrou existant protege sauvegarde et extinction."""
    cancelled = False
    child_proc = None
    def on_cancel(_signum, _frame):
        nonlocal cancelled, child_proc
        cancelled = True
        if child_proc is not None and child_proc.poll() is None:
            try:
                child_proc.send_signal(signal.SIGINT)
            except ProcessLookupError:
                pass
    signal.signal(signal.SIGINT, on_cancel)
    signal.signal(signal.SIGTERM, on_cancel)
    try:
        os.fstat(fd)
        selected_data = entries()
        selected = [next((x for x in selected_data if x['id'] == i), None) for i in ids]
        if not selected or any(x is None for x in selected):
            raise RuntimeError('Configuration modifiee depuis le lancement.')
        print('[{}] ===== {} : {} dossier(s) ====='.format(
            timestamp(), 'SAUVEGARDE' if mode == 'copy' else 'VERIFICATION', len(selected)), flush=True)
        results = []
        RUN_DIR.mkdir(parents=True, exist_ok=True)
        for position, x in enumerate(selected, 1):
            if cancelled:
                break
            # Revalider ici, car le volume peut avoir ete retire apres le menu.
            source = source_info(x['source'], x.get('volume_montage') or None)
            if source['linked']:
                print('[INFO] Lien suivi : {} -> {}'.format(x['source'], source['real']), flush=True)
            if source['mount']:
                print('[INFO] Volume monte : {}'.format(source['mount']), flush=True)
            snap = {'job': job, 'mode': mode, 'dossier': x['nom'],
                    'index': position, 'nombre_dossiers': len(selected),
                    'etat': 'en_cours', 'copies': 0, 'erreurs': 0, 'progression': {}}
            if mode == 'copy':
                atomic_json(copy_progress_path(job), snap)
            dest = '1fichier:' + x['destination']
            started = timestamp()
            print('[{}] {} : {} -> {}'.format(started, x['nom'], x['source'], dest), flush=True)
            safe_id = re.sub(r'[^a-zA-Z0-9_-]', '_', x['id'])[:32]
            journal = RUN_DIR / (datetime.now().strftime('%Y%m%d-%H%M%S') + '-' + safe_id + '-' + mode + '-' + uuid.uuid4().hex[:5] + '.log')
            report = str(RUN_DIR / ('verification-' + job + '.txt')) if mode == 'check' else ''
            # Le vrai chemin est indispensable pour suivre un lien de dossier racine.
            # Les liens imbriques restent ignores par Rclone par securite.
            cmd = [RCLONE, 'copy' if mode == 'copy' else 'check', source['real'], dest,
                   '--config', str(RCLONE_CONFIG), '--transfers', '1', '--checkers', '2',
                   '--stats', '10s' if mode == 'check' else '5s',
                   '--stats-one-line', '--stats-log-level', 'NOTICE', '--log-level', 'INFO']
            if mode == 'copy':
                cmd += ['--ignore-existing']
            else:
                cmd += ['--size-only', '--one-way', '--combined', report]
            transferred, total = '-', '-'
            copied, errors = 0, 0
            try:
                with journal.open('w', encoding='utf-8', buffering=1) as log:
                    log.write('[{}] {} : {} -> {}\n'.format(started, x['nom'], x['source'], dest))
                    proc = subprocess.Popen(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                            stderr=subprocess.STDOUT, text=True, encoding='utf-8',
                                            errors='replace', bufsize=1)
                    child_proc = proc
                    if cancelled and proc.poll() is None:
                        proc.send_signal(signal.SIGINT)
                    if proc.stdout is not None:
                        for line in proc.stdout:
                            print(line, end='', flush=True)
                            log.write(line)
                            progress = transfer_size(line)
                            if progress:
                                transferred, total = progress
                            if 'Copied (new)' in line:
                                copied += 1
                            if re.search(r'\b(ERROR|Failed)\b', line, re.I):
                                errors += 1
                            if mode == 'copy':
                                snapshot = parse_copy_progress(line)
                                if snapshot:
                                    snap['progression'] = snapshot
                                if snapshot or 'Copied (new)' in line or re.search(r'\b(ERROR|Failed)\b', line, re.I):
                                    snap['copies'], snap['erreurs'] = copied, errors
                                    atomic_json(copy_progress_path(job), snap)
                        proc.stdout.close()
                    rc = proc.wait()
                    child_proc = None
            except Exception as exc:
                rc = 127
                errors += 1
                print('[ERREUR] ' + str(exc), flush=True)
            verification = count_report(report) if mode == 'check' else None
            ok = rc == 0 and not cancelled
            # Un disque retire ou un lien change pendant Rclone annule le succes.
            try:
                after = source_info(x['source'], x.get('volume_montage') or None)
                if (after['real'] != source['real'] or after['dev'] != source['dev']
                        or after['mount'] != source['mount']):
                    raise ValueError('Source ou volume modifie pendant l operation.')
            except (ValueError, OSError) as exc:
                ok = False
                errors += 1
                print('[ERREUR] Controle final du volume : ' + str(exc), flush=True)
                try:
                    with journal.open('a', encoding='utf-8') as log:
                        log.write('[ERREUR] Controle final du volume : ' + str(exc) + '\n')
                except OSError:
                    pass
            if verification is not None:
                if any(verification[k] for k in ('manquants','differents','erreurs')):
                    ok = False
                # Un rapport vide n'est acceptable que si le dossier local est vide.
                total_local = count_local_files(source['real'])
                if total_local and verification['examines'] == 0:
                    ok = False
                    errors += 1
                print('[{}] {} : {} fichier(s) OK, {} manquant(s), {} taille(s) differente(s), {} erreur(s) de lecture'.format(
                    timestamp(), x['nom'], verification['valides'], verification['manquants'],
                    verification['differents'], verification['erreurs']), flush=True)
                print('[{}] Rapport : {}'.format(timestamp(), report), flush=True)
            if mode == 'copy':
                snap['etat'] = 'annule' if cancelled else 'termine' if ok else 'erreur'
                snap['copies'], snap['erreurs'] = copied, errors
                atomic_json(copy_progress_path(job), snap)
            rec = {'id': x['id'], 'nom': x['nom'], 'source': x['source'],
                   'destination': x['destination'], 'date_debut': started, 'date': timestamp(),
                   'mode': mode, 'volume': transferred, 'total': total, 'copies': copied,
                   'erreurs': errors, 'code': rc, 'ok': ok, 'journal': str(journal),
                   'verification': verification, 'rapport': report, 'version': 'v2.0',
                   'etat': 'annule' if cancelled else ('ok' if ok else 'erreur')}
            append_history(rec)
            results.append({'nom': x['nom'], 'code': rc, 'ok': ok, 'volume': transferred,
                            'copies': copied, 'journal': str(journal), 'verification': verification,
                            'etat': 'annule' if cancelled else ('ok' if ok else 'erreur')})
            final_status = 'ANNULE' if cancelled else 'OK' if ok else 'ERREUR, code ' + str(rc)
            final_line = '[{}] {} : {}'.format(timestamp(), x['nom'], final_status)
            # Les anciennes versions n'avaient pas de bilan dans le journal individuel.
            # Inscrire la conclusion apres tous les controles, pas avant.
            try:
                with journal.open('a', encoding='utf-8') as log:
                    log.write(final_line + '\n')
            except OSError as exc:
                print('[INFO] Impossible d inscrire le bilan dans le journal individuel : ' + str(exc), flush=True)
            print(final_line, flush=True)
            if cancelled:
                break
        ok = not cancelled and len(results) == len(selected) and all(z['ok'] for z in results)
        atomic_json(LAST, {'date': timestamp(), 'mode': mode, 'job': job, 'ok': ok,
                           'etat': 'annule' if cancelled else ('ok' if ok else 'erreur'),
                           'details': results})
        print('[{}] ===== FIN : {} ====='.format(timestamp(),
              'ANNULE' if cancelled else 'OK' if ok else 'ERREURS - voir le journal'), flush=True)
    except Exception as exc:
        print('[{}] ERREUR FATALE : {}'.format(timestamp(), exc), flush=True)
        atomic_json(LAST, {'date': timestamp(), 'mode': mode, 'job': job, 'ok': False, 'erreur': str(exc)})
    finally:
        try:
            fcntl.flock(fd, fcntl.LOCK_UN)
            os.close(fd)
            rearm_if_needed()
        except Exception as exc:
            print('[INFO] Verification minuteur : {}'.format(exc), flush=True)


# ============================================================
# Interface v2.0 : clavier + manette Batocera (evdev natif).
# Le moteur Rclone, les sauvegardes et le verrou restent inchanges.
# ============================================================

class Navigation:
    """Interface sans dependance Python externe (selection via evdev + clavier).

    Lit seulement les evdev ayant des boutons de manette et ne fait aucun grab,
    afin de ne pas perturber la gestion des manettes dans Batocera.
    """
    EVENT_FORMAT = 'llHHi' if struct.calcsize('l') == 8 else 'llHHi'
    EVENT_SIZE = struct.calcsize(EVENT_FORMAT)
    EV_KEY, EV_ABS = 1, 3
    BTN_A, BTN_B, BTN_START = 304, 305, 315
    DPAD_UP, DPAD_DOWN = 544, 545
    DPAD_LEFT, DPAD_RIGHT = 546, 547
    AXES = (0, 1, 16, 17)

    def __init__(self):
        self.fds = {}
        self.axis_state = {}
        self.abs_bounds = {}
        self.selected = 0
        self._last_scan = 0.0
        self._last_event = (None, 0.0)
        self.scan(force=True)

    @staticmethod
    def _capable(entry):
        key_file = Path('/sys/class/input') / entry.name / 'device/capabilities/key'
        try:
            mask = int(key_file.read_text().replace(' ', '').strip(), 16)
            return bool(mask & ((1 << 304) | (1 << 305)))
        except (OSError, ValueError):
            return False

    def scan(self, force=False):
        # Dans Ports, la manette est traduite en clavier via le .sh.keys.
        # Eviter une double lecture (evdev + clavier) au meme appui.
        if os.environ.get('BLONDIN_PORTS_PAD') == '1':
            for path in list(self.fds):
                self._drop(path)
            return
        now = time.monotonic()
        if not force and now - self._last_scan < 3:
            return
        self._last_scan = now
        directory = Path('/dev/input')
        if not directory.is_dir():
            return
        present = set()
        for entry in directory.glob('event*'):
            if not self._capable(entry):
                continue
            present.add(str(entry))
            if str(entry) not in self.fds:
                try:
                    fd = os.open(entry, os.O_RDONLY | os.O_NONBLOCK | os.O_CLOEXEC)
                    self.fds[str(entry)] = fd
                except OSError:
                    pass
        for path in set(self.fds) - present:
            self._drop(path)

    def _drop(self, path):
        fd = self.fds.pop(path, None)
        if fd is not None:
            try:
                os.close(fd)
            except OSError:
                pass

    def close(self):
        for path in list(self.fds):
            self._drop(path)

    def _bounds(self, fd, code):
        key = (fd, code)
        if key not in self.abs_bounds:
            try:
                # EVIOCGABS(code) : _IOR('E', 0x40+code, struct input_absinfo)
                req = (2 << 30) | (24 << 16) | (ord('E') << 8) | (0x40 + code)
                raw = fcntl.ioctl(fd, req, bytes(24))
                _value, minimum, maximum, _fuzz, _flat, _resolution = struct.unpack('6i', raw)
                self.abs_bounds[key] = (minimum, maximum)
            except (OSError, ValueError, struct.error):
                self.abs_bounds[key] = (-32768, 32767) if code in (0, 1) else (-1, 1)
        return self.abs_bounds[key]

    def _event_to_action(self, fd, data):
        if len(data) != self.EVENT_SIZE:
            return None
        _sec, _usec, event_type, code, value = struct.unpack(self.EVENT_FORMAT, data)
        if event_type == self.EV_KEY and value == 1:
            if code == self.BTN_A:
                return 'accept'
            if code == self.BTN_B:
                return 'back'
            if code == self.BTN_START:
                return 'home'
            if code == self.DPAD_UP:
                return 'up'
            if code == self.DPAD_DOWN:
                return 'down'
            if code == self.DPAD_LEFT:
                return 'left'
            if code == self.DPAD_RIGHT:
                return 'right'
        if event_type != self.EV_ABS or code not in self.AXES:
            return None
        minimum, maximum = self._bounds(fd, code)
        span = max(1, maximum - minimum)
        position = (value - (minimum + maximum) / 2) / (span / 2)
        direction = -1 if position < -0.55 else 1 if position > 0.55 else 0
        prior = self.axis_state.get((fd, code), 0)
        self.axis_state[(fd, code)] = direction
        if not direction or direction == prior:
            return None
        if code in (1, 17):
            return 'up' if direction < 0 else 'down'
        return 'left' if direction < 0 else 'right'

    @staticmethod
    def _keyboard_action(fd):
        try:
            chunk = os.read(fd, 1)
        except OSError:
            return None
        if not chunk:
            return 'back'
        char = chunk.decode('latin1')
        if char in ('\r', '\n', ' '):
            return 'accept'
        if char in ('h', 'H'):
            return 'home'
        if char in ('w', 'W', 'k', 'K'):
            return 'up'
        if char in ('s', 'S', 'j', 'J'):
            return 'down'
        if char in ('q', 'Q', '\x7f'):
            return 'back'
        if char == '\x1b':
            # Escape sequences for keyboard arrows, Escape alone = back.
            seq = b''
            for _ in range(2):
                ready, _, _ = select.select([fd], [], [], 0.035)
                if not ready:
                    break
                seq += os.read(fd, 1)
            if seq in (b'[A', b'OA'):
                return 'up'
            if seq in (b'[B', b'OB'):
                return 'down'
            if seq in (b'[C', b'[D', b'OC', b'OD'):
                return 'right' if seq[-1:] == b'C' else 'left'
            return 'back'
        if char.isdigit():
            return 'key:' + char
        return None

    def _get_action(self, timeout=0.5):
        self.scan()
        reads = list(self.fds.values())
        fdin = None
        if sys.stdin.isatty():
            fdin = sys.stdin.fileno()
            reads.append(fdin)
        if not reads:
            time.sleep(timeout)
            return None
        try:
            ready, _, _ = select.select(reads, [], [], timeout)
        except (OSError, ValueError):
            self.scan(force=True)
            return None
        for fd in ready:
            if fd == fdin:
                action = self._keyboard_action(fd)
                if action:
                    return action
                continue
            try:
                # Un evenement par lecture ; les axes ignorent les repetitions.
                chunk = os.read(fd, self.EVENT_SIZE)
                action = self._event_to_action(fd, chunk)
            except OSError:
                path = next((p for p, d in self.fds.items() if d == fd), None)
                if path:
                    self._drop(path)
                continue
            if action:
                # Protection supplementaire contre certains doubles evenements.
                previous, t = self._last_event
                now = time.monotonic()
                if previous == action and now - t < 0.12:
                    continue
                self._last_event = (action, now)
                return action
        return None

    @contextlib.contextmanager
    def _raw_stdin(self):
        fd = sys.stdin.fileno() if sys.stdin.isatty() else None
        attrs = None
        if fd is not None:
            try:
                attrs = termios.tcgetattr(fd)
                tty.setcbreak(fd)
            except (termios.error, OSError):
                attrs = None
        try:
            yield
        finally:
            if attrs is not None:
                termios.tcsetattr(fd, termios.TCSADRAIN, attrs)

    def choose(self, options, prompt_text=None, default=0, allow_back=True):
        """options: [(key, label), ...]; return key or None (B/Retour)."""
        if prompt_text:
            print('\n' + paint('  ' + prompt_text, '1;36'))
        if not options:
            return None
        if not sys.stdin.isatty():
            for key, label in options:
                print('  ' + str(key) + '  ' + label)
            try:
                response = input('  Choix [0 retour] : ').strip()
            except (EOFError, KeyboardInterrupt):
                return None
            return next((key for key, _ in options if str(key) == response), None)
        if default is None:
            default = 0
        selected = max(0, min(len(options) - 1, int(default)))
        print(paint('  Croix/stick : naviguer   A/Entree : valider   B/Echap : retour   START : menu', '2;37'))
        width = max(42, min(_UI_PANEL_COLS - 2, shutil.get_terminal_size(fallback=(80, 24)).columns - 2 * _ui_margin() - 2))

        def draw(idx, active):
            key, name = options[idx]
            prefix = '  > ' if active else '    '
            label = f'{str(key):>2}  {name}'
            max_len = max(12, width - len(prefix))
            if len(label) > max_len:
                label = label[:max_len - 1] + '…'
            line = (prefix + label).ljust(width)
            return paint(line, '1;30;46') if active else paint(line, '0;37')

        for idx in range(len(options)):
            print(draw(idx, idx == selected))
        print('\033[?25l', end='', flush=True)
        def refresh(idx, active):
            up = len(options) - idx
            sys.stdout.write(f'\033[{up}A\r\033[2K' + ' ' * _ui_margin() + draw(idx, active) + f'\033[{up}B\r')
            sys.stdout.flush()
        try:
            with self._raw_stdin():
                while True:
                    action = self._get_action()
                    if action is None:
                        continue
                    if action in ('back', 'home') and allow_back:
                        return None
                    if action == 'accept':
                        return options[selected][0]
                    if action.startswith('key:'):
                        digit = action[4:]
                        return next((key for key, _ in options if str(key) == digit), None)
                    # Menu vertical : seules les commandes haut/bas changent la selection.
                    # Gauche et droite sont recues mais volontairement ignorees.
                    if action in ('up', 'down'):
                        old = selected
                        selected = (selected + (-1 if action == 'up' else 1)) % len(options)
                        if selected != old:
                            refresh(old, False)
                            refresh(selected, True)
        finally:
            print('\033[?25h', end='', flush=True)

    def confirm(self, prompt_text):
        return self.choose([('0', 'Non, annuler'), ('1', 'Oui, confirmer')], prompt_text) == '1'

    def wait(self):
        if not sys.stdin.isatty():
            try:
                input('\nEntrée pour continuer... ')
            except EOFError:
                pass
            return
        print('\n' + paint('  A / B / Entree : continuer…', '2;37'), end='', flush=True)
        with self._raw_stdin():
            while True:
                action = self._get_action()
                if action in ('accept', 'back', 'home'):
                    break
        print()


NAV = None


def clear():
    print('\033[2J\033[H', end='')


def prompt(label, default=None):
    """Le clavier reste necessaire pour les nouveaux chemins/destinations."""
    if default is None:
        return input(label + ' : ').strip()
    s = input(f'{label} [{default}] : ').strip()
    return s if s else default


def prompt_new_local_source():
    """Chemin ROMs pre-insere, mais modifiable en entier dans xterm.

    Sur une distribution sans module readline, autoriser un simple nom relatif
    au dossier ROMs, ou n'importe quel chemin absolu.
    """
    base = '/userdata/roms/'
    print('  Chemin predefini : ' + base)
    print('  Vous pouvez effacer ou modifier toute la ligne pour un autre disque.')
    try:
        import readline
    except ImportError:
        readline = None
    if readline is not None and sys.stdin.isatty():
        def prefill():
            readline.insert_text(base)
            readline.redisplay()
        readline.set_startup_hook(prefill)
        try:
            source = input('Dossier local : ').strip()
        finally:
            readline.set_startup_hook(None)
    else:
        source = input('Dossier local (nom dans /userdata/roms/ ou chemin absolu) : ').strip()
        if not source:
            source = base
        elif not source.startswith('/'):
            source = base + source
    if source.rstrip('/') == base.rstrip('/'):
        raise ValueError('Completer le chemin avec le nom du dossier a sauvegarder.')
    return source


def pause():
    if NAV:
        NAV.wait()
    else:
        input('\nEntree pour continuer... ')


def select_entry(data):
    if not data:
        print('\nAucun dossier configure.'); return None
    options = [(str(i), f'{x["nom"]}  ({x["source"]} -> 1fichier:{x["destination"]})')
               for i, x in enumerate(data, 1)]
    answer = NAV.choose(options, 'CHOISIR UN DOSSIER')
    return data[int(answer)-1] if answer is not None else None


def add_entry():
    print('\n' + paint('  AJOUTER UNE CORRESPONDANCE (saisie au clavier)', '1;36'))
    nom = prompt('Nom affiche')
    if not nom or len(nom) > 70:
        print('Nom invalide.'); return
    try:
        info = source_info(prompt_new_local_source())
        source = info['original']
        dest = remote_path(prompt('Dossier sur 1fichier, ex. Sauvegarde-FBNeo'))
        data = entries()
        if any(x['source'] == source and x['destination'] == dest for x in data):
            print('Cette correspondance existe deja.'); return
        new_entry = {'id': uuid.uuid4().hex[:12], 'nom': nom, 'source': source, 'destination': dest}
        if info['mount']:
            new_entry['volume_montage'] = info['mount']
        data.append(new_entry)
        save_entries(data)
        if info['linked']:
            print('  Lien suivi : ' + info['real'])
        if info['mount']:
            print('  Volume monte : ' + info['mount'])
        print(paint('Correspondance ajoutee. Aucun transfert lance.', '1;32'))
    except Exception as e:
        print('[ERREUR] ' + str(e))


def edit_entry():
    data = entries()
    x = select_entry(data)
    if x is None:
        return
    try:
        x['nom'] = prompt('Nom', x['nom'])
        info = source_info(prompt('Source', x['source']))
        x['source'] = info['original']
        if info['mount']:
            x['volume_montage'] = info['mount']
        else:
            x.pop('volume_montage', None)
        x['destination'] = remote_path(prompt('Destination', x['destination']))
        save_entries(data)
        print('Correspondance modifiee. Aucun fichier deplace ou supprime.')
    except Exception as e:
        print('[ERREUR] ' + str(e))


def delete_entry():
    data = entries()
    x = select_entry(data)
    if x is None:
        return
    print('\nCette action supprime UNIQUEMENT la configuration : ' + x['nom'])
    if NAV.confirm('Confirmer le retrait de cette configuration ?'):
        save_entries([z for z in data if z['id'] != x['id']])
        print('Configuration retiree. Aucun fichier local ou distant efface.')


def job_state():
    active = running()
    data = read_json(ACTIVE, {})
    last = read_json(LAST, {})
    guard = TRIGGER.is_file() and MARKER in TRIGGER.read_text(encoding='utf-8', errors='replace')
    print('\n' + paint('  ETAT GENERAL', '1;36'))
    print('  Operation        : ' + (paint('EN COURS', '1;33') if active else paint('AU REPOS', '1;32')))
    print('  Extinction       : ' + (
        paint('SUSPENDUE (verrou actif)', '1;32') if active and guard else
        paint('ATTENTION : garde absent', '1;31') if active and not guard else
        'Minuteur normal (garde installe)' if guard else 'Pas de garde V3 detecte'))
    if active and data:
        print('  Depuis           : ' + str(data.get('started', '-')))
        print('  Dossier(s)       : ' + ', '.join(data.get('dossiers', [])))
        if data.get('mode') == 'check':
            stats = count_report(data.get('report'))
            print('  Verification     : {} / {} fichier(s) examine(s)'.format(stats['examines'], data.get('total_local', '?')))
            print('  OK : {} | Manquants : {} | Tailles differentes : {} | Erreurs : {}'.format(
                stats['valides'], stats['manquants'], stats['differents'], stats['erreurs']))
        else:
            p = latest_progress()
            if p:
                print('  Progression : ' + p[-160:])
    if last:
        print('\n  Derniere operation : ' + str(last.get('date', '-')))
        print('  Resultat          : ' + result_status(last))
        for d in last.get('details', []):
            stats = d.get('verification')
            if stats is not None:
                print(check_result_line(d.get('nom','?'),stats,d.get('ok',False)))
            else:
                print('  - {} : {} | {} | {} fichier(s) envoye(s)'.format(
                    d.get('nom', '?'), yesno(d.get('ok', d.get('code') == 0)),
                    d.get('volume', '-'), d.get('copies', '-')))
        if last.get('erreur'):
            print('  ' + str(last['erreur']))
    print('\n  Verification = noms + tailles uniquement, sans controle du contenu.')


def show_log():
    options = [('1', 'Dernieres lignes du journal general'),
               ('2', 'Dernieres erreurs du journal general'),
               ('3', 'Dernier journal d un dossier'), ('0', 'Retour')]
    choice = NAV.choose(options, 'JOURNAUX')
    if choice in ('1', '2'):
        for line in tail_lines(LOG, count=32, only_errors=choice == '2'):
            print('  ' + colored_log(line))
    elif choice == '3':
        x = select_entry(entries())
        if x:
            hist = next((z for z in reversed(load_history())
                         if z.get('id') == x.get('id') and z.get('journal')), None)
            if hist:
                print('\n  ' + hist.get('date', '-') + '  ' + hist.get('nom', '-'))
                for line in tail_lines(Path(hist['journal']), count=36):
                    print('  ' + colored_log(line))
                show_folder_log_result(hist)
            else:
                print('  Aucun journal individuel (version 1.0 : utiliser le journal general).')


def show_history():
    hist = load_history()
    print('\n' + paint('  HISTORIQUE DES OPERATIONS (20 DERNIERES)', '1;36'))
    if not hist:
        print('  Aucun resultat enregistre.')
    for rec in reversed(hist[-20:]):
        kind = 'SAUV.' if rec.get('mode') == 'copy' else 'VERIF.'
        status = result_status(rec)
        print('  {}  {:6}  {}  {}'.format(
            rec.get('date', '-')[-16:], kind,
            paint(rec.get('nom', '-')[:18].ljust(18), '1;36'),status))
        stats = rec.get('verification')
        if isinstance(stats, dict):
            print('    {} OK | {} manquants | {} tailles differentes | {} erreurs'.format(
                stats.get('valides', 0), stats.get('manquants',0),
                stats.get('differents',0), stats.get('erreurs',0)))
        else:
            print('    {} fichier(s) envoye(s) | Volume : {} / {} | erreurs : {}'.format(
                rec.get('copies','-'), rec.get('volume','-'), rec.get('total','-'), rec.get('erreurs','-')))
    print('\n  Un controle de noms et tailles n est pas un controle des octets.')


def menu_backup(data):
    """Sauvegardes : les choix de confirmation et d'extinction restent inchanges."""
    options = [('1', 'Sauvegarder un dossier'),
               ('2', 'Sauvegarder tous les dossiers'),
               ('0', 'Retour au menu principal')]
    while True:
        clear()
        title('SAUVEGARDES — BLONDIN EDITION v2.0')
        choice = NAV.choose(options, 'SAUVEGARDES')
        if choice in (None, '0'):
            return
        if choice == '1':
            x = select_entry(entries())
            if x:
                print(f'\n  Source : {x["source"]}\n  Destination : 1fichier:{x["destination"]}')
                print('  Seulement les fichiers absents seront envoyes.')
                if NAV.confirm('Lancer manuellement cette sauvegarde ?'):
                    poweroff = shutdown_choice()
                    job = start([x['id']], 'copy')
                    if job and poweroff:
                        monitor_status(auto_shutdown_job=job)
        elif choice == '2':
            data = entries()
            if not data:
                print('  Aucun dossier configure.')
            elif NAV.confirm('Lancer TOUS les dossiers dans l ordre ?'):
                poweroff = shutdown_choice()
                job = start([x['id'] for x in data], 'copy')
                if job and poweroff:
                    monitor_status(auto_shutdown_job=job)
        pause()


def menu_folders():
    """Regroupe exclusivement les operations sur dossiers configures."""
    options = [('1', 'Ajouter un dossier (clavier pour saisie)'),
               ('2', 'Modifier un dossier (clavier pour saisie)'),
               ('3', 'Retirer une configuration'),
               ('0', 'Retour au menu principal')]
    while True:
        clear()
        title('GESTION DES DOSSIERS — BLONDIN EDITION v2.0')
        choice = NAV.choose(options, 'DOSSIERS')
        if choice in (None, '0'):
            return
        if running():
            print('  Configuration bloquee pendant un transfert.')
        elif choice == '1':
            add_entry()
        elif choice == '2':
            edit_entry()
        elif choice == '3':
            delete_entry()
        pause()


def menu_progress():
    """Suivi en temps reel et annulation manuelle (confirmation existante)."""
    options = [('1', 'Progression en direct'),
               ('2', 'Annuler la sauvegarde en cours'),
               ('0', 'Retour au menu principal')]
    while True:
        clear()
        title('ETAT ET PROGRESSION — BLONDIN EDITION v2.0')
        choice = NAV.choose(options, 'ETAT ET PROGRESSION')
        if choice in (None, '0'):
            return
        if choice == '1':
            monitor_status()
        elif choice == '2':
            cancel_active()
            pause()


def menu_controls():
    """Rassemble verification, historique et journaux sans modifier le moteur."""
    options = [('1', 'Verifier noms et tailles d une sauvegarde'),
               ('2', 'Historique et bilans'),
               ('3', 'Journaux'),
               ('0', 'Retour au menu principal')]
    while True:
        clear()
        title('CONTROLES ET JOURNAUX — BLONDIN EDITION v2.0')
        choice = NAV.choose(options, 'CONTROLES ET JOURNAUX')
        if choice in (None, '0'):
            return
        if choice == '1':
            x = select_entry(entries())
            if x and NAV.confirm('Verifier sans transferer ?'):
                job = start([x['id']], 'check')
                if job:
                    monitor_check(job)
        elif choice == '2':
            show_history()
        elif choice == '3':
            show_log()
        pause()


def menu():
    global NAV, _UI_CENTER
    migrate_v1_history()
    NAV = Navigation()
    _UI_CENTER = True
    try:
        while True:
            clear()
            title('SAUVEGARDE 1FICHIER  ★ BLONDIN EDITION ★  v2.0')
            active = running()
            guard = TRIGGER.is_file() and MARKER in TRIGGER.read_text(encoding='utf-8', errors='replace')
            print('  BATOCERA 44  |  MODE MANUEL  |  RCLONE 1FICHIER  |  MANETTE + CLAVIER')
            print('  Transfert : ' + (paint('EN COURS', '1;33') if active else paint('AU REPOS', '1;32')) +
                  '   |   Extinction : ' + (
                    paint('SUSPENDUE', '1;32') if active and guard else
                    paint('GARDE ABSENT', '1;31') if active and not guard else
                    'MINUTEUR NORMAL' if guard else 'NON GEREE'))
            print(paint('─' * 76, '36'))
            data = entries()
            section('DOSSIERS CONFIGURES  ({})'.format(len(data)))
            for i, x in enumerate(data, 1):
                hist = latest_for(x)
                if hist:
                    status = result_status(hist) + ' ' + str(hist.get('date', '-'))[-16:]
                else:
                    status = 'AUCUN BILAN'
                print('  {:2}. {:20}  '.format(i, x['nom'][:20]) + status)
                print('      ' + x['source'])
                print('      -> 1fichier:' + x['destination'])
            if not data:
                print('      Aucun dossier configure')
            print(paint('─' * 76, '36'))
            options = [
                ('1', 'Sauvegardes'),
                ('2', 'Gestion des dossiers'),
                ('3', 'Etat et progression'),
                ('4', 'Controles et journaux'),
                ('5', 'Compte 1fichier'),
            ]
            if active and read_json(ACTIVE, {}).get('mode') == 'copy':
                options.append(('9', 'Annuler le transfert en cours'))
            options.append(('0', 'Quitter'))
            choice = NAV.choose(options, 'MENU PRINCIPAL', default=NAV.selected)
            if choice is None:  # B / Start au menu principal : rester au menu
                continue
            NAV.selected = next((i for i, (key, _) in enumerate(options) if key == choice), 0)
            if choice == '0':
                return
            elif choice == '1':
                menu_backup(data)
            elif choice == '2':
                menu_folders()
            elif choice == '3':
                menu_progress()
            elif choice == '4':
                menu_controls()
            elif choice == '5':
                show_account_storage()
            elif choice == '9':
                cancel_active()
                pause()
    finally:
        _UI_CENTER = False
        NAV.close()


def main():
    if len(sys.argv) > 1 and sys.argv[1] == '--worker':
        if len(sys.argv) < 6:
            raise SystemExit(2)
        worker(int(sys.argv[2]), sys.argv[3], sys.argv[4], sys.argv[5:])
    else:
        if not CONFIG.exists():
            atomic_json(CONFIG, [{'id': 'teknoparrot', 'nom': 'TeknoParrot',
                'source': '/userdata/roms/teknoparrot',
                'destination': 'Sauvegarde-TeknoParrot'}])
        try:
            menu()
        except (EOFError, KeyboardInterrupt):
            print('\nFermeture du menu. Les transferts en cours continuent.')
        except Exception as e:
            print('\n[ERREUR] ' + str(e))
            try: pause()
            except (EOFError, KeyboardInterrupt): pass


if __name__ == '__main__':
    main()
