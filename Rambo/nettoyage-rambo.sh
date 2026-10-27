#!/bin/bash
JEU="$2"
CHEMIN="$1"
DOSSIER='/userdata/system/configs/linuxloader'
LOG='/userdata/system/logs/nettoyage-rambo.log'
if [[ "${JEU,,}" == 'rambo' && "${CHEMIN,,}" == *'/lindbergh/rambo/'* ]]; then
    mkdir -p /userdata/system/logs
    if [[ -d "$DOSSIER" && ! -L "$DOSSIER" ]]; then
        if find "$DOSSIER" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +; then
            echo "$(date) : RAMBO - Nettoyage effectué" >> "$LOG"
        else
            echo "$(date) : RAMBO - Erreur de nettoyage" >> "$LOG"
        fi
    else
        echo "$(date) : RAMBO - Dossier absent ou lien symbolique, aucun nettoyage" >> "$LOG"
    fi
fi
