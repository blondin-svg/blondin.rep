#!/bin/bash
python3 - <<'PY'
import subprocess

with open("/tmp/kodi-detache-v5.log", "ab", buffering=0) as log:
    subprocess.Popen(
        ["/userdata/saves/Installscripts/kodi-detache-TEST.sh"],
        stdin=subprocess.DEVNULL,
        stdout=log,
        stderr=subprocess.STDOUT,
        start_new_session=True,
        close_fds=True
    )
PY
exit 0
