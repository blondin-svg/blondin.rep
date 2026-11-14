#!/usr/bin/env bash
# Sauvegarde 1fichier ★ BLONDIN EDITION ★ — v2.0.2 TEST, Batocera 44
# Mise a jour non destructive. Correction manuelle ; rapports persistants.
# N'efface jamais dossiers.json, les clefs Rclone, journaux, ntfy ou garde V3.
set -Eeuo pipefail
[[ "${EUID:-$(id -u)}" -eq 0 ]] || { echo '[ERREUR] Lancer depuis SSH en root.' >&2; exit 1; }
for exe in python3 bash cp mv flock sha256sum curl; do
  command -v "$exe" >/dev/null 2>&1 || { echo "[ERREUR] Outil manquant : $exe" >&2; exit 1; }
done
ROOT="${BLONDIN_TEST_ROOT:-/userdata}"
BASE="$ROOT/system/1fichier-blondin"
APP="$BASE/app.py"
LOG="$ROOT/system/logs"
PORT="$ROOT/roms/ports/Sauvegarde 1fichier - BLONDIN EDITION.sh"
ES_STOPPED=0
SUCCESS=0
TMPPATCH=''
TMPAPP=''
BASE_URL='https://raw.githubusercontent.com/blondin-svg/blondin.rep/main/Sauvegarde1fichier'
V201_SHA256='154a44b6a22e35dfaf7f44627d8e127acf9c5b82b72f08bed254c7f71a605274'
clean_exit() {
  local rc=$?
  [[ -z "$TMPPATCH" ]] || rm -f -- "$TMPPATCH"
  [[ -z "$TMPAPP" ]] || rm -f -- "$TMPAPP"
  if [[ "$ES_STOPPED" -eq 1 && "$SUCCESS" -eq 0 && -z "${BLONDIN_TEST_ROOT:-}" ]]; then
    echo '[ATTENTION] Installation non terminee : relance d EmulationStation.' >&2
    /etc/init.d/S31emulationstation start || true
  fi
  exit "$rc"
}
trap clean_exit EXIT
mkdir -p -- "$BASE" "$LOG"
if [[ -e "$APP" ]]; then
  # Refuser toute version modifiee ou non reconnue AVANT d'arreter EmulationStation.
  set +e
  python3 - "$APP" <<'PY_VALIDATE'
import hashlib, pathlib, sys
p=pathlib.Path(sys.argv[1]); b=p.read_bytes()
git=hashlib.sha1(('blob %s\0'%len(b)).encode()+b).hexdigest()
known={'5b199901ea99949536b5a303ccc23306245850fa'}  # source v2.0.1
if git not in known and hashlib.sha256(b).hexdigest() != '3244c8f90f8d49de6066399005dcd79120d7e522c85d9388de52a6fc2f3c074a':
    if 'v2.0.2 TEST' in b.decode('utf8','replace') and b'def launch_repair(' in b:
        print('[OK] v2.0.2 TEST deja installee : aucune modification.')
        sys.exit(44)
    print('[ERREUR] Source locale inconnue. SHA256='+hashlib.sha256(b).hexdigest())
    sys.exit(1)
PY_VALIDATE
  validation=$?
  set -e
  if [[ "$validation" -ne 0 && "$validation" -ne 44 ]]; then exit "$validation"; fi
  [[ "$validation" != 44 ]] || { SUCCESS=1; trap - EXIT; exit 0; }
fi
# Eviter toute mise a jour pendant un transfert : le verrou est partage avec la garde V3.
if ! flock -n -x "$BASE/transfert.lock" -c 'true'; then
  echo '[ERREUR] Transfert, verification ou correction en cours. Reessayer apres.' >&2
  exit 1
fi
if [[ -z "${BLONDIN_TEST_ROOT:-}" ]]; then
  echo '[INFO] Arret d EmulationStation pour mise a jour.'
  /etc/init.d/S31emulationstation stop
  ES_STOPPED=1
fi
if [[ ! -f "$APP" ]]; then
  if [[ -n "${BLONDIN_TEST_ROOT:-}" ]]; then
    echo '[ERREUR] Installation de base absente dans le dossier de test.' >&2; exit 1
  fi
  echo '[INFO] Installation de base v2.0.1 depuis GitHub (Batocera vierge).'
  TMPPATCH=$(mktemp "$ROOT/.v201-base.XXXXXX.sh")
  curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 \
       --max-time 240 "$BASE_URL/install-sauvegarde-1fichier-blondin-v2.0.1.sh" -o "$TMPPATCH"
  printf '%s  %s\n' "$V201_SHA256" "$TMPPATCH" | sha256sum -c --status || {
    echo '[ERREUR] Empreinte officielle v2.0.1 incorrecte.' >&2; exit 1;
  }
  bash "$TMPPATCH"
  rm -f -- "$TMPPATCH"; TMPPATCH=''
fi
[[ -f "$APP" && -f "$PORT" && -f "$BASE/dossiers.json" ]] || {
  echo '[ERREUR] Installation v2.0.1 incomplete ; aucune modification.' >&2; exit 1;
}
# Installer les seuls changements du moteur Python. Aucune touche aux services de veille.
mkdir -p -- "$BASE/backups"
STAMP=$(date +'%Y%m%d-%H%M%S')
BACKUP="$BASE/backups/app-pre-v2.0.2-TEST-$STAMP-$$.py"
cp -p -- "$APP" "$BACKUP"
TMPAPP=$(mktemp "$BASE/.app-v2.0.2-TEST.XXXXXXXX.py")
cp -p -- "$APP" "$TMPAPP"
TMPPATCH=$(mktemp "$BASE/.patch-v2.0.2-TEST.XXXXXXXX.py")
cat > "$TMPPATCH" <<'PY_PATCH_202'
#!/usr/bin/env python3
"""Patch v2.0.2 TEST against installed v2.0.1 app.py, guards exact anchors."""
import sys, pathlib, ast, os

APP=pathlib.Path(sys.argv[1])
s=APP.read_text(encoding='utf-8')
if 'v2.0.2 TEST' in s and 'def launch_repair' in s:
    print('[OK] v2.0.2 TEST deja installee.'); sys.exit(0)
if 'Batocera 44' not in s or 'def worker(fd, mode, job, ids):' not in s:
    raise SystemExit('Version source incompatible : aucune modification.')

def change(needle, replace):
    global s
    n=s.count(needle)
    if n!=1: raise SystemExit('Ancre non reconnue (%s fois): %r' %(n,needle[:115]))
    s=s.replace(needle,replace,1)

change(' - v2.0 / Batocera 44.', ' - v2.0.2 TEST / Batocera 44.')
change("MARKER = '1FICHIER-BLONDIN-GUARD-V1'", "MARKER = '1FICHIER-BLONDIN-GUARD-V1'\nDIFFERENCES = BASE / 'differences-v2.0.2.json'")
change("    return yesno(bool(record.get('ok')))\n", "    if record.get('ok') and record.get('ecarts', 0):\n        return paint('TERMINE AVEC DIFFERENCES', '1;33')\n    return yesno(bool(record.get('ok')))\n")
change("    elif ok and record.get('mode') == 'check':", "    elif ok and record.get('ecarts', 0):\n        headline, detail, color = ('TERMINE AVEC DIFFERENCES', 'Autres transferts termines ; correction manuelle disponible.', '1;33')\n    elif ok and record.get('mode') == 'check':")

helpers='''

def relative_file(value):
    """Valider le chemin Rclone, sans injection ni traversal."""
    if not isinstance(value, str) or not value or value.startswith('/') or '\\\\' in value or ':' in value:
        raise ValueError('Chemin relatif non autorise.')
    parts = value.split('/')
    if any(z in ('', '.', '..') or any(ord(c) < 32 for c in z) for z in parts):
        raise ValueError('Chemin relatif non autorise.')
    return '/'.join(parts)


def report_issues(path):
    """Les rapports Rclone sont lisibles apres extinction/redemarrage."""
    results = []
    if not path or not Path(path).is_file():
        return results
    with open(path, encoding='utf-8', errors='replace') as fh:
        for line in fh:
            if len(line) < 3 or line[1] != ' ' or line[0] not in ('*', '+', '!'):
                continue
            try:
                name = relative_file(line[2:].rstrip('\\r\\n'))
            except ValueError:
                continue
            results.append({'type': line[0], 'chemin': name})
    return results


def save_issues(x, report, etat, job):
    """Remplacer uniquement le bilan de ce dossier, sous le verrou actif."""
    state = read_json(DIFFERENCES, {})
    if not isinstance(state, dict):
        state = {}
    issues = report_issues(report)
    state[x['id']] = {'nom': x['nom'], 'source': x['source'],
                      'destination': x['destination'], 'date': timestamp(),
                      'etat': etat, 'rapport': report, 'job': job,
                      'fichiers': issues}
    atomic_json(DIFFERENCES, state)
    return issues


def repairable_issues(x):
    state = read_json(DIFFERENCES, {})
    rec = state.get(x['id'], {}) if isinstance(state, dict) else {}
    if not isinstance(rec, dict) or rec.get('etat') != 'verifie':
        return [], rec
    if rec.get('source') != x['source'] or rec.get('destination') != x['destination']:
        return [], rec
    return [v for v in rec.get('fichiers', []) if isinstance(v, dict) and v.get('type') in ('*', '+')], rec


def local_regular_file(source, relative):
    """Ne jamais suivre de lien symbolique imbrique dans la source."""
    base = Path(source).resolve(strict=True)
    parts = relative_file(relative).split('/')
    p = base
    for part in parts:
        p = p / part
        if p.is_symlink():
            raise ValueError('Lien symbolique imbrique refuse : ' + relative)
    real = p.resolve(strict=True)
    if not real.is_file() or base not in real.parents:
        raise ValueError('Fichier non regulier ou hors source.')
    return real


def launch_repair(x, item):
    """Correction en arriere-plan, sans bloquer la manette ni l'extinction V3."""
    fd = get_lock()
    if fd is None:
        print('  [ATTENTION] Une operation est deja active.')
        return
    started = False
    try:
        preflight()
        source = source_info(x['source'], x.get('volume_montage') or None)
        relative = relative_file(item['chemin'])
        local_regular_file(source['real'], relative)
        # Ne pas faire confiance a un bilan qui a change entre menu et lancement.
        items, _ = repairable_issues(x)
        if item not in items:
            raise ValueError('Cette anomalie ne figure plus dans le dernier rapport.')
        cancel_old_timer()
        job = uuid.uuid4().hex[:16]
        atomic_json(ACTIVE, {'pid': None, 'job': job, 'mode': 'repair',
                    'ids': [x['id']], 'started': timestamp(),
                    'dossiers': [x['nom']], 'fichier': relative})
        LOG_DIR.mkdir(parents=True, exist_ok=True)
        with open(LOG, 'ab', buffering=0) as log:
            proc = subprocess.Popen([sys.executable, '-u', str(Path(__file__).resolve()),
                     '--repair-worker', str(fd), job, x['id'], relative],
                     stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
                     start_new_session=True, close_fds=True, pass_fds=(fd,), cwd=str(BASE))
        state = read_json(ACTIVE, {})
        state['pid'] = proc.pid
        atomic_json(ACTIVE, state)
        started = True
        print('  [OK] Correction lancee en arriere-plan (PID {}).'.format(proc.pid))
        print('  La fermeture du menu ne stoppe pas cette operation.')
    except Exception as exc:
        print('  [ERREUR] ' + str(exc))
    finally:
        os.close(fd)
        if not started:
            rearm_if_needed()


def repair_worker(fd, job, entry_id, relative):
    """Archive l'ancienne version sur 1fichier avant d'envoyer la nouvelle."""
    ok = False
    label = relative
    try:
        os.fstat(fd)
        x = next((z for z in entries() if z['id'] == entry_id), None)
        if not x:
            raise ValueError('Dossier supprime ou renomme.')
        label = x['nom'] + ' / ' + relative
        src = source_info(x['source'], x.get('volume_montage') or None)
        local = local_regular_file(src['real'], relative)
        before = local.stat()
        dest = '1fichier:' + remote_path(x['destination']) + '/' + relative
        # Revision unique ; aucune ancienne version effacee automatiquement.
        version_dir = '1fichier:' + remote_path(x['destination']) + '/.blondin-versions/' + \\
                      datetime.now().strftime('%Y%m%d-%H%M%S') + '-' + job
        print('[{}] CORRECTION {} (ancien fichier archive sous {})'.format(timestamp(), label, version_dir), flush=True)
        # --backup-dir : Rclone deplace d'abord l'ancien objet vers l'archive.
        # Si le backend refuse l'archivage, la correction echoue sans fallback destructif.
        cmd = [RCLONE, 'copyto', str(local), dest, '--config', str(RCLONE_CONFIG),
               '--backup-dir', version_dir, '--stats', '5s', '--stats-one-line',
               '--stats-log-level', 'NOTICE', '--log-level', 'INFO']
        rc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, errors='replace')
        print(rc.stdout[-12000:], flush=True)
        if rc.returncode != 0:
            raise RuntimeError('Upload refuse ou incomplet (code {}). Archive distante a examiner.'.format(rc.returncode))
        after = local.stat()
        if (before.st_size, before.st_mtime_ns, before.st_dev, before.st_ino) != \\
           (after.st_size, after.st_mtime_ns, after.st_dev, after.st_ino):
            raise RuntimeError('Source modifiee pendant transfert ; refaire la verification.')
        remote_stat = subprocess.run([RCLONE, 'lsjson', '--stat', dest,
                          '--config', str(RCLONE_CONFIG)], capture_output=True,
                          text=True, timeout=120)
        if remote_stat.returncode != 0 or int(json.loads(remote_stat.stdout)['Size']) != before.st_size:
            raise RuntimeError('Taille distante non confirmee apres copie.')
        # Refresh du dossier, sans remplacement ni suppression supplementaire.
        snap = source_info(x['source'], x.get('volume_montage') or None)
        if snap['real'] != src['real'] or snap['dev'] != src['dev'] or snap['mount'] != src['mount']:
            raise RuntimeError('Volume source modifie pendant la correction.')
        report = str(RUN_DIR / ('verification-repair-' + job + '.txt'))
        check = subprocess.run([RCLONE, 'check', src['real'],
              '1fichier:' + remote_path(x['destination']), '--config', str(RCLONE_CONFIG),
              '--size-only', '--one-way', '--combined', report, '--checkers', '2'],
              capture_output=True, text=True)
        summary = count_report(report)
        if (check.returncode not in (0, 1) or summary['erreurs'] or
                (check.returncode == 1 and not report_issues(report))):
            raise RuntimeError('Reverification distante non concluante : ' + check.stderr[-400:])
        issues = save_issues(x, report, 'verifie', job)
        if any(v['chemin'] == relative for v in issues):
            raise RuntimeError('Le fichier reste different apres correction.')
        ok = True
        print('[{}] CORRECTION CONFIRMEE : {}'.format(timestamp(), label), flush=True)
        print('[INFO] Ancienne version preservee sous : ' + version_dir, flush=True)
    except Exception as exc:
        print('[{}] ERREUR CORRECTION {} : {}'.format(timestamp(), label, exc), flush=True)
    finally:
        try:
            append_history({'id': entry_id, 'nom': label, 'date': timestamp(),
                            'mode': 'repair', 'ok': ok, 'etat': 'ok' if ok else 'erreur',
                            'version': 'v2.0.2 TEST'})
            atomic_json(LAST, {'date': timestamp(), 'job': job, 'mode': 'repair',
                               'ok': ok, 'etat': 'ok' if ok else 'erreur',
                               'details': [{'nom': label, 'ok': ok, 'copies': 1 if ok else 0}]})
        finally:
            fcntl.flock(fd, fcntl.LOCK_UN)
            os.close(fd)
            rearm_if_needed()


def menu_differences():
    """Consultation persistante apres reboot, choix manuel d'UN fichier a la fois."""
    x = select_entry(entries())
    if not x:
        return
    if running():
        print('  Operation en cours : consulter le rapport apres la fin.'); return
    items, rec = repairable_issues(x)
    print('\\n  Rapport : {} | Etat : {}'.format(rec.get('date', 'absent'), rec.get('etat', 'non verifie')))
    print('  Seuls les fichiers DIFFERENTS ou MANQUANTS sont corrigeables.')
    for item in rec.get('fichiers', []) if isinstance(rec, dict) else []:
        if isinstance(item, dict):
            print('  {} {}'.format(item.get('type', '?'), item.get('chemin', '?')))
    if not items:
        print('  Rien a corriger, ou rapport incomplet. Lancer une verification.'); return
    options = [(str(i), ('DIFFERENT  ' if z['type'] == '*' else 'MANQUANT   ') + z['chemin'])
               for i, z in enumerate(items, 1)]
    options.append(('0', 'Retour'))
    answer = NAV.choose(options, 'CORRIGER UN FICHIER (MANUEL)')
    if answer in (None, '0'):
        return
    item = items[int(answer)-1]
    source = source_info(x['source'], x.get('volume_montage') or None)
    local = local_regular_file(source['real'], item['chemin'])
    print('  Fichier local : {} octets'.format(local.stat().st_size))
    print('  Destination : 1fichier:{}/{}'.format(remote_path(x['destination']), item['chemin']))
    try:
        pre = subprocess.run([RCLONE, 'lsjson', '--stat',
            '1fichier:' + remote_path(x['destination']) + '/' + item['chemin'],
            '--config', str(RCLONE_CONFIG)], capture_output=True, text=True, timeout=40)
        if pre.returncode == 0:
            print('  Fichier distant : {} octets'.format(json.loads(pre.stdout)['Size']))
        else:
            print('  Fichier distant : non disponible / absent')
    except (ValueError, OSError, subprocess.TimeoutExpired, KeyError):
        print('  Fichier distant : taille indisponible')
    print('  Le fichier distant existant sera ARCHIVE avant remplacement.')
    print('  Aucune suppression des autres jeux ou sauvegardes.')
    if NAV.confirm('Archiver l ancienne version puis corriger ce fichier ?'):
        launch_repair(x, item)

'''
change('def count_local_files(path):', helpers + 'def count_local_files(path):')

# Snapshot verifier integrated with normal check and copy; never prompts inside worker.
needle="            verification = count_report(report) if mode == 'check' else None\n            ok = rc == 0 and not cancelled"
replacement="""            verification = count_report(report) if mode == 'check' else None
            ok = rc == 0 and not cancelled
            ecarts = 0
            # Contrôle automatique APRES la copie : continue meme avec anciens fichiers differents.
            # Le verrou protege aussi ce controle ; aucune saisie ni interruption de sauvegarde.
            if mode == 'copy' and ok:
                snap['etat'] = 'controle_final'
                atomic_json(copy_progress_path(job), snap)
                report = str(RUN_DIR / ('verification-copie-' + job + '-' + safe_id + '.txt'))
                audit_cmd = [RCLONE, 'check', source['real'], dest, '--config', str(RCLONE_CONFIG),
                             '--size-only', '--one-way', '--checkers', '2',
                             '--combined', report, '--stats', '10s', '--stats-log-level', 'NOTICE']
                print('[{}] {} : controle final des noms et tailles (sans interruption)'.format(timestamp(), x['nom']), flush=True)
                try:
                    audit = subprocess.Popen(audit_cmd, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                             stderr=subprocess.STDOUT, text=True, errors='replace')
                    child_proc = audit
                    with journal.open('a', encoding='utf-8') as details:
                        for audit_line in audit.stdout:
                            details.write(audit_line)
                            print(audit_line, end='', flush=True)
                    audit_rc = audit.wait()
                    child_proc = None
                    audit_stats = count_report(report)
                    ecarts = audit_stats['differents']
                    total_local = count_local_files(source['real'])
                    audit_valid = (not cancelled and audit_stats['erreurs'] == 0 and
                          audit_stats['manquants'] == 0 and
                          (audit_rc == 0 or (audit_rc == 1 and ecarts > 0)) and
                          (not total_local or audit_stats['examines'] > 0))
                    if audit_valid:
                        save_issues(x, report, 'verifie', job)
                        print('[{}] {} : {} OK, {} ancien(s) fichier(s) different(s) ; autres transferts termines.'.format(
                              timestamp(), x['nom'], audit_stats['valides'], ecarts), flush=True)
                    else:
                        save_issues(x, report, 'incomplet', job)
                        ok = False
                        print('[ERREUR] Controle final incomplet : {} (code {}).'.format(x['nom'], audit_rc), flush=True)
                except Exception as exc:
                    ok = False
                    print('[ERREUR] Controle final indisponible : ' + str(exc), flush=True)
            elif mode == 'check' and not cancelled:
                # Les rapports existants v2.0.1 sont conserves ; ce registre sera persistent.
                total_local = count_local_files(source['real'])
                if report and Path(report).is_file() and (verification['examines'] or not total_local):
                    save_issues(x, report, 'verifie' if verification['erreurs'] == 0 and
                                rc in (0, 1) else 'incomplet', job)
"""
change(needle, replacement.rstrip())
# Ensure failed or aborted copy is marked incomplete in registry, never silently says no diff.
change("            if mode == 'copy':\n                snap['etat'] = 'annule' if cancelled else 'termine' if ok else 'erreur'",
"            if mode == 'copy' and not ok and (cancelled or rc != 0):\n                save_issues(x, report if report else '', 'incomplet', job)\n            if mode == 'copy':\n                snap['etat'] = 'annule' if cancelled else 'termine' if ok else 'erreur'")
change("'verification': verification, 'rapport': report, 'version': 'v2.0',",
       "'verification': verification, 'rapport': report, 'version': 'v2.0.2 TEST', 'ecarts': ecarts,")
change("'copies': copied, 'journal': str(journal), 'verification': verification,",
       "'copies': copied, 'journal': str(journal), 'verification': verification, 'ecarts': ecarts,")
change("            final_status = 'ANNULE' if cancelled else 'OK' if ok else 'ERREUR, code ' + str(rc)",
       "            final_status = 'ANNULE' if cancelled else 'OK - {} FICHIER(S) DIFFERENT(S)'.format(ecarts) if ok and ecarts else 'OK' if ok else 'ERREUR, code ' + str(rc)")
change("        atomic_json(LAST, {'date': timestamp(), 'mode': mode, 'job': job, 'ok': ok,",
       "        atomic_json(LAST, {'date': timestamp(), 'mode': mode, 'job': job, 'ok': ok,\n                           'ecarts': sum(z.get('ecarts', 0) for z in results),")
change("        print('  Fichiers copies  : {}'.format(snap.get('copies', 0)))",
       "        print('  Fichiers copies  : {}'.format(snap.get('copies', 0)))") if False else None
change("                        print('  Erreurs detectees: {}'.format(snap.get('erreurs', 0)))",
       "                        print('  Erreurs detectees: {}'.format(snap.get('erreurs', 0)))\n                        if snap.get('etat') == 'controle_final':\n                            print('  Controle final des noms et tailles en cours...')")
change("    print('\\n  Un controle de noms et tailles n est pas un controle des octets.')",
       "    print('\\n  Un controle de noms et tailles n est pas un controle des octets.')") if False else None
change("        kind = 'SAUV.' if rec.get('mode') == 'copy' else 'VERIF.'",
       "        kind = 'SAUV.' if rec.get('mode') == 'copy' else 'CORR.' if rec.get('mode') == 'repair' else 'VERIF.'")
change("    options = [('1', 'Verifier noms et tailles d une sauvegarde'),\n               ('2', 'Historique et bilans'),\n               ('3', 'Journaux'),",
       "    options = [('1', 'Verifier noms et tailles d une sauvegarde'),\n               ('2', 'Historique et bilans'),\n               ('3', 'Journaux'),\n               ('4', 'Differences et correction manuelle'),")
change("        elif choice == '3':\n            show_log()\n        pause()\n\n\ndef menu():",
       "        elif choice == '3':\n            show_log()\n        elif choice == '4':\n            menu_differences()\n        pause()\n\n\ndef menu():")
change("    if len(sys.argv) > 1 and sys.argv[1] == '--worker':\n",
       "    if len(sys.argv) > 1 and sys.argv[1] == '--repair-worker':\n        if len(sys.argv) != 6:\n            raise SystemExit(2)\n        repair_worker(int(sys.argv[2]), sys.argv[3], sys.argv[4], sys.argv[5])\n    elif len(sys.argv) > 1 and sys.argv[1] == '--worker':\n")
s=s.replace('— v2.0', '— v2.0.2 TEST').replace(' ★  v2.0\'', ' ★  v2.0.2 TEST\'')
# Preserve all existing logic; require syntactic correctness before updating.
ast.parse(s, filename=str(APP))
APP.write_text(s, encoding='utf-8')
print('[OK] Source v2.0.2 TEST genere :',APP)
PY_PATCH_202
python3 "$TMPPATCH" "$TMPAPP"
python3 - "$TMPAPP" <<'PY_COMPILE'
import ast,pathlib,sys
p=pathlib.Path(sys.argv[1]);ast.parse(p.read_text(encoding='utf8'));print('[OK] Compilation et structure Python verifiees.')
PY_COMPILE
chmod 700 "$TMPAPP"
# Ne remplacer que lorsque le script de test a ete entierement valide.
mv -f -- "$TMPAPP" "$APP"
TMPAPP=''
sync
SUCCESS=1
echo '[OK] Sauvegarde 1fichier ★ BLONDIN EDITION ★ v2.0.2 TEST installee.'
echo '[OK] dossiers.json, historique, ntfy, Rclone et extinction V3 conserves.'
echo '[OK] Verification finale automatique ; correction manuelle avec archivage.'
echo '[OK] Sauvegarde locale de la source precedente : '"$BACKUP"
if [[ -z "${BLONDIN_TEST_ROOT:-}" ]]; then
  trap - EXIT
  echo '[OK] Redemarrage complet de Batocera.'
  reboot
fi