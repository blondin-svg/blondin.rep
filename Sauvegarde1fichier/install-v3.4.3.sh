#!/usr/bin/env bash
# Sauvegarde 1fichier ★ BLONDIN EDITION ★ v3.4.3 — correctif Web
# Batocera 44 / mise à jour ciblée, base v3.3 nécessaire.
# Corrige la fin de liste sur une ligne dense de v3.0/v3.3.
# Ne touche ni aux donnees locales ni aux archives 1fichier.
set -Eeuo pipefail
[[ "$(id -u)" -eq 0 ]] || { echo '[ERREUR] Executer en root.' >&2; exit 1; }
for c in python3 bash; do command -v "$c" >/dev/null || { echo "[ERREUR] $c manquant." >&2; exit 1; }; done
WORK=$(mktemp -d /tmp/blondin-web-v343.XXXXXXXX)
trap 'rm -rf -- "$WORK"' EXIT
SRC="${BASH_SOURCE[0]%/*}/install-v3.4.sh"
if [[ -f "$SRC" && "$SRC" != "$0" ]]; then
  cp -f -- "$SRC" "$WORK/install-v3.4.sh"
else
  command -v curl >/dev/null || { echo '[ERREUR] curl manquant.' >&2; exit 1; }
  SRC_URL='https://raw.githubusercontent.com/blondin-svg/blondin.rep/7d612bb96601c039193e9e2d0d4adeb8a91fd59c/Sauvegarde1fichier/install-v3.4.sh'
  curl -fLsS --retry 3 --connect-timeout 20 "$SRC_URL" -o "$WORK/install-v3.4.sh"
fi
bash "$WORK/install-v3.4.sh" --extract "$WORK/web-v3.4-patch.py"
python3 - "$WORK/web-v3.4-patch.py" <<'PY_FIX_ANCHORS'
from pathlib import Path
import sys
path=Path(sys.argv[1]);code=path.read_text(encoding='utf-8')
start=code.find('    begin = "const folders=$(\'folders\');let focused=document.activeElement;"')
end_key="    js = js[:a] + 'renderFolderListStable(s);' + js[b:]"
end=code.find(end_key,start)
if start<0 or end<0 or code.count(end_key)!=1:
    raise SystemExit('[ERREUR] Correctif v3.4 non reconnu : aucun changement.')
replacement=r'''    # v3.4.3 : trouver la section de rendu par sa structure, pas par ses espaces.
    render = re.search(r"\bfunction\s+render\s*\(\s*s\s*\)\s*\{", js)
    if not render or len(re.findall(r"\bfunction\s+render\s*\(\s*s\s*\)\s*\{",js))!=1:
        raise RuntimeError('Rendu Web : fonction render(s) non reconnue.')
    section = js[render.end():]
    begin_match = re.search(r"\b(?:const|let)\s+folders\s*=\s*\$\(\s*['\"]folders['\"]\s*\)\s*;", section)
    if not begin_match:
        raise RuntimeError('Rendu Web : debut de liste introuvable.')
    a = render.end() + begin_match.start()
    pivot = js.find('folders.replaceChildren()', a)
    if pivot < 0 or pivot-a > 16000:
        raise RuntimeError('Rendu Web : reconstruction des cases introuvable.')
    # Chercher la section de commandes qui suit le rendu, avec espaces variables.
    following = re.search(r"\bfor\s*\(\s*const\s+id\s+of\s*\[\s*['\"]testAccountBtn['\"]", js[pivot:pivot+16000])
    if not following:
        raise RuntimeError('Rendu Web : debut des controles du compte introuvable.')
    # Dans le code d'origine, updateSelectedUI() est a la fin d'une longue ligne.
    # Le dernier appel AVANT les controles du compte termine le rendu de la liste.
    section_end = js[pivot:pivot+following.start()]
    candidates = list(re.finditer(r'updateSelectedUI\s*\(\s*\)\s*;', section_end))
    if not candidates:
        raise RuntimeError('Rendu Web : fin de liste introuvable.')
    if section_end[candidates[-1].end():].strip():
        raise RuntimeError('Rendu Web : fin de liste ambigue, abandon.')
    b = pivot + candidates[-1].end()
    old_block = js[a:b]
    if not re.search(r"\bfor\s*\(\s*const\s+x\s+of\s+s\.entries\s*\)", old_block):
        raise RuntimeError('Rendu Web : iteration des systemes differente, abandon.')
    if old_block.count('folders.replaceChildren()')!=1:
        raise RuntimeError('Rendu Web : reconstruction ambigue, abandon.')
'''
code=code[:start]+replacement+code[end:]

# v3.4.3 : verifier les cases independantes meme si les lignes JS sont compactees.
case_start = code.find('    js = once(js, "cb.addEventListener(')
case_end = code.find('    js = js.rstrip()', case_start)
if case_start < 0 or case_end < 0 or case_start >= case_end:
    raise SystemExit('[ERREUR] Correctif v3.4 : section Verification introuvable, aucun changement.')
cases = r'''    # v3.4.3 : ancrages de Verification independants des retours a la ligne.
    event_re = re.compile(
        r"cb\s*\.\s*addEventListener\s*\(\s*['\"]change['\"]\s*,\s*\(\s*\)\s*=>\s*\{\s*"
        r"if\s*\(\s*cb\s*\.\s*checked\s*\)\s*selected\s*\.\s*add\s*\(\s*x\s*\.\s*id\s*\)\s*;\s*"
        r"else\s*selected\s*\.\s*delete\s*\(\s*x\s*\.\s*id\s*\)\s*;"
        r"(?=\s*(?:const|let)\s+original\s*=)"
    )
    matches = list(event_re.finditer(js))
    if len(matches) != 1:
        raise RuntimeError('Cases Verification : structure non reconnue (%d blocs), abandon.' % len(matches))
    m = matches[0]
    changed = re.sub(r"\bselected(?=\s*\.\s*(?:add|delete)\s*\()", 'verifySelected', m.group(0))
    if changed == m.group(0):
        raise RuntimeError('Cases Verification : aucune selection remplacee.')
    js = js[:m.start()] + changed + js[m.end():]
    # Ne plus recopier la selection Verification dans les cases Sauvegarder.
    sync_re = re.compile(
        r"\bif\s*\(\s*original\s*\)\s*original\s*\.\s*checked\s*=\s*cb\s*\.\s*checked\s*;"
    )
    sync_matches = list(sync_re.finditer(js))
    if len(sync_matches) != 1:
        raise RuntimeError('Synchronisation Verification : structure non reconnue (%d blocs).' % len(sync_matches))
    sm = sync_matches[0]
    js = js[:sm.start()] + js[sm.end():]
    # Restauration de l'etat des cases propre a Verification apres un rafraichissement.
    checked_re = re.compile(
        r"(\bcb\s*\.\s*checked\s*=\s*)selected\s*\.\s*has\s*\(\s*cb\s*\.\s*dataset\s*\.\s*verifyId\s*\)"
    )
    js, nchecked = checked_re.subn(r"\1verifySelected.has(cb.dataset.verifyId)", js)
    if nchecked != 1:
        raise RuntimeError('Etat des coches Verification : structure non reconnue (%d blocs).' % nchecked)
'''
code = code[:case_start] + cases + code[case_end:]

compile(code,str(path),'exec')
path.write_text(code,encoding='utf-8')
print('[OK] Ancrages Web adaptes pour v3.4.3 (controle syntaxique valide).')
PY_FIX_ANCHORS
python3 "$WORK/web-v3.4-patch.py" --check
python3 "$WORK/web-v3.4-patch.py"
echo '[OK] Correctif Web v3.4.3 applique. Actualiser la page sur Android.'
