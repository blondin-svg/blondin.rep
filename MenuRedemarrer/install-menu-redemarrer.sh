#!/bin/bash

# ============================================================
# BATOCERA 42
# MODIFICATION DU TEXTE "REDEMARRER"
# + INSTALLATION DE LA COMMANDE PORTS "Redemarrer"
#
# RESTART SYSTEM
# devient :
# UTILISER REDEMARRER DANS PORTS
#
# Le fichier original est sauvegarde dans /userdata.
# ============================================================

MO_FILE="/usr/share/locale/fr/LC_MESSAGES/emulationstation2.mo"

BACKUP_DIR="/userdata/system/backup-menu-redemarrer"
BACKUP_FILE="$BACKUP_DIR/emulationstation2.mo.original"

TEMP_FILE="/tmp/emulationstation2.mo.new"

PORT_DIR="/userdata/roms/ports"
PORT_FILE="$PORT_DIR/Redemarrer.sh"
PORT_BACKUP_FILE="$BACKUP_DIR/Redemarrer.sh.original"
PORT_NO_ORIGINAL_MARKER="$BACKUP_DIR/Redemarrer.sh.no-original"


# ============================================================
# AFFICHAGE
# ============================================================

clear

# Force l'affichage vers le terminal actif
if [ -w /dev/tty ]; then
    exec > /dev/tty 2>&1
fi


echo
echo "=============================================="
echo "       MENU REDEMARRAGE - BATOCERA 42"
echo "=============================================="
echo
echo "Ce script permet de remplacer :"
echo
echo "  REDÉMARRER"
echo
echo "par :"
echo
echo "  UTILISER REDEMARRER DANS PORTS"
echo
echo "dans le menu Quitter de Batocera."
echo
echo "Le texte du menu sera modifie et la commande"
echo "Ports -> Redemarrer sera installee."
echo
echo "Le fonctionnement du menu natif de redemarrage"
echo "n'est pas modifie."
echo


# ============================================================
# VERIFICATION ROOT
# ============================================================

if [ "$(id -u)" != "0" ]; then

    echo "=============================================="
    echo "                 ERREUR"
    echo "=============================================="
    echo
    echo "Ce script doit etre execute en root."
    echo
    read -r -p "Appuyez sur ENTREE pour terminer..." _
    exit 1

fi


# ============================================================
# VERIFICATION DU FICHIER
# ============================================================

if [ ! -f "$MO_FILE" ]; then

    echo "=============================================="
    echo "                 ERREUR"
    echo "=============================================="
    echo
    echo "Fichier introuvable :"
    echo
    echo "$MO_FILE"
    echo
    read -r -p "Appuyez sur ENTREE pour terminer..." _
    exit 1

fi


echo "[OK] Traduction francaise detectee."
echo


# ============================================================
# MENU
# ============================================================

echo "=============================================="
echo "                 CHOIX"
echo "=============================================="
echo
echo "1 - Installer la modification"
echo
echo "    UTILISER REDEMARRER DANS PORTS"
echo "    + installer Ports/Redemarrer.sh"
echo
echo "2 - Restaurer REDÉMARRER"
echo
echo "3 - Annuler"
echo

read -r -p "Votre choix [1/2/3] : " CHOIX

echo


# ============================================================
# INSTALLATION
# ============================================================

if [ "$CHOIX" = "1" ]; then

    echo "=============================================="
    echo "             INSTALLATION"
    echo "=============================================="
    echo


    # --------------------------------------------------------
    # SAUVEGARDE
    # --------------------------------------------------------

    echo "[1/6] Verification des sauvegardes..."

    mkdir -p "$BACKUP_DIR"

    if [ ! -f "$BACKUP_FILE" ]; then

        cp -p "$MO_FILE" "$BACKUP_FILE"

        if [ $? -ne 0 ]; then

            echo
            echo "[ERREUR] Impossible de sauvegarder"
            echo "le fichier original."
            echo
            read -r -p "Appuyez sur ENTREE pour terminer..." _
            exit 1

        fi

        echo "[OK] Traduction originale sauvegardee."

    else

        echo "[OK] Sauvegarde originale deja presente."
        echo "[INFO] Elle ne sera pas ecrasee."

    fi

    echo

    # Sauvegarde eventuelle d'un Redemarrer.sh deja present
    mkdir -p "$PORT_DIR"

    if [ ! -f "$PORT_BACKUP_FILE" ] && [ ! -f "$PORT_NO_ORIGINAL_MARKER" ]; then

        if [ -f "$PORT_FILE" ]; then

            cp -p "$PORT_FILE" "$PORT_BACKUP_FILE"

            if [ $? -ne 0 ]; then

                echo
                echo "[ERREUR] Impossible de sauvegarder"
                echo "le fichier Redemarrer.sh existant."
                echo
                read -r -p "Appuyez sur ENTREE pour terminer..." _
                exit 1

            fi

            echo "[OK] Redemarrer.sh existant sauvegarde."

        else

            touch "$PORT_NO_ORIGINAL_MARKER"
            echo "[OK] Aucun Redemarrer.sh original a sauvegarder."

        fi

    else

        echo "[OK] Etat original de Redemarrer.sh deja sauvegarde."

    fi

    echo


    # --------------------------------------------------------
    # MODIFICATION DU FICHIER MO
    # --------------------------------------------------------

    echo "[2/6] Modification de la traduction..."

    python3 - "$MO_FILE" "$TEMP_FILE" <<'PYTHON_EOF'

import sys
import struct


source = sys.argv[1]
destination = sys.argv[2]

TARGET = b"RESTART SYSTEM"
NEW_TRANSLATION = b"UTILISER REDEMARRER DANS PORTS"


# ============================================================
# LECTURE DU .MO
# ============================================================

with open(source, "rb") as f:
    data = f.read()


if len(data) < 28:
    raise SystemExit("Fichier MO invalide.")


magic_le = struct.unpack("<I", data[0:4])[0]


if magic_le == 0x950412de:

    endian = "<"

elif magic_le == 0xde120495:

    endian = ">"

else:

    raise SystemExit("Format MO non reconnu.")


magic, revision, count, off_orig, off_trans, hash_size, hash_offset = \
    struct.unpack(endian + "7I", data[:28])


# ============================================================
# EXTRACTION DES ENTREES
# ============================================================

originals = []
translations = []


for i in range(count):

    length, offset = struct.unpack(
        endian + "2I",
        data[
            off_orig + i * 8:
            off_orig + i * 8 + 8
        ]
    )

    originals.append(
        data[offset:offset + length]
    )


for i in range(count):

    length, offset = struct.unpack(
        endian + "2I",
        data[
            off_trans + i * 8:
            off_trans + i * 8 + 8
        ]
    )

    translations.append(
        data[offset:offset + length]
    )


# ============================================================
# MODIFICATION UNIQUEMENT DE RESTART SYSTEM
# ============================================================

found = False


for i, original in enumerate(originals):

    if original == TARGET:

        print(
            "Traduction actuelle :",
            translations[i].decode(
                "utf-8",
                errors="replace"
            )
        )

        translations[i] = NEW_TRANSLATION

        found = True

        break


if not found:

    raise SystemExit(
        "ERREUR : RESTART SYSTEM introuvable."
    )


# ============================================================
# RECONSTRUCTION COMPLETE DU FICHIER MO
# ============================================================

count = len(originals)

header_size = 28

orig_table_offset = header_size

trans_table_offset = (
    orig_table_offset + count * 8
)

strings_offset = (
    trans_table_offset + count * 8
)


orig_table = []
trans_table = []

string_data = bytearray()

current_offset = strings_offset


# ------------------------------------------------------------
# Chaines originales
# ------------------------------------------------------------

for value in originals:

    orig_table.append(
        (len(value), current_offset)
    )

    string_data.extend(value)
    string_data.append(0)

    current_offset += len(value) + 1


# ------------------------------------------------------------
# Traductions
# ------------------------------------------------------------

for value in translations:

    trans_table.append(
        (len(value), current_offset)
    )

    string_data.extend(value)
    string_data.append(0)

    current_offset += len(value) + 1


# ============================================================
# ECRITURE
# ============================================================

output = bytearray()


output.extend(
    struct.pack(
        endian + "7I",
        magic,
        revision,
        count,
        orig_table_offset,
        trans_table_offset,
        0,
        0
    )
)


for length, offset in orig_table:

    output.extend(
        struct.pack(
            endian + "2I",
            length,
            offset
        )
    )


for length, offset in trans_table:

    output.extend(
        struct.pack(
            endian + "2I",
            length,
            offset
        )
    )


output.extend(string_data)


with open(destination, "wb") as f:

    f.write(output)


print(
    "Nouvelle traduction :",
    NEW_TRANSLATION.decode("utf-8")
)

PYTHON_EOF


    if [ $? -ne 0 ]; then

        echo
        echo "[ERREUR] La modification a echoue."
        echo
        rm -f "$TEMP_FILE"
        echo
        read -r -p "Appuyez sur ENTREE pour terminer..." _
        exit 1

    fi

    echo "[OK] Nouveau fichier MO cree."
    echo


    # --------------------------------------------------------
    # VERIFICATION AVANT INSTALLATION
    # --------------------------------------------------------

    echo "[3/6] Verification de la nouvelle traduction..."

    RESULTAT="$(
        python3 - "$TEMP_FILE" <<'PYTHON_EOF'
import gettext
import sys

path = sys.argv[1]

with open(path, "rb") as f:
    tr = gettext.GNUTranslations(f)

print(
    tr.gettext("RESTART SYSTEM")
)
PYTHON_EOF
    )"


    echo "Traduction detectee :"
    echo
    echo "  $RESULTAT"
    echo


    if [ "$RESULTAT" != "UTILISER REDEMARRER DANS PORTS" ]; then

        echo "[ERREUR] Verification incorrecte."
        echo
        echo "Le fichier original n'a pas ete modifie."

        rm -f "$TEMP_FILE"

        echo
        read -r -p "Appuyez sur ENTREE pour terminer..." _
        exit 1

    fi


    echo "[OK] Traduction valide."
    echo


    # --------------------------------------------------------
    # INSTALLATION
    # --------------------------------------------------------

    echo "[4/6] Installation du nouveau fichier..."

    cp "$TEMP_FILE" "$MO_FILE"

    if [ $? -ne 0 ]; then

        echo
        echo "[ERREUR] Impossible d'installer"
        echo "le nouveau fichier."
        echo
        read -r -p "Appuyez sur ENTREE pour terminer..." _
        exit 1

    fi

    chmod 644 "$MO_FILE"

    rm -f "$TEMP_FILE"

    echo "[OK] Nouveau fichier installe."
    echo


    # --------------------------------------------------------
    # INSTALLATION DU PORT REDEMARRER
    # --------------------------------------------------------

    echo "[5/6] Installation de Ports/Redemarrer.sh..."

    mkdir -p "$PORT_DIR"

    cat > "$PORT_FILE" <<'PORT_EOF'
#!/bin/bash

nohup /usr/bin/env sh -c 'sleep 1; batocera-es-swissknife --reboot' >/dev/null 2>&1 </dev/null &

exit 0
PORT_EOF

    if [ $? -ne 0 ]; then

        echo
        echo "[ERREUR] Impossible de creer :"
        echo "$PORT_FILE"
        echo
        read -r -p "Appuyez sur ENTREE pour terminer..." _
        exit 1

    fi

    chmod +x "$PORT_FILE"

    if [ ! -x "$PORT_FILE" ]; then

        echo
        echo "[ERREUR] Redemarrer.sh n'est pas executable."
        echo
        read -r -p "Appuyez sur ENTREE pour terminer..." _
        exit 1

    fi

    echo "[OK] Redemarrer.sh installe dans Ports."
    echo


    # --------------------------------------------------------
    # OVERLAY BATOCERA
    # --------------------------------------------------------

    echo "[6/6] Sauvegarde dans l'overlay Batocera..."
    echo
    echo "Cette operation peut prendre quelques secondes..."
    echo

    batocera-save-overlay

    if [ $? -eq 0 ]; then

        echo
        echo "[OK] Overlay Batocera sauvegarde."

    else

        echo
        echo "[ATTENTION]"
        echo "batocera-save-overlay a retourne une erreur."

    fi


    echo
    echo "=============================================="
    echo "          MODIFICATION TERMINEE"
    echo "=============================================="
    echo
    echo "L'entree :"
    echo
    echo "  REDÉMARRER"
    echo
    echo "est maintenant :"
    echo
    echo "  UTILISER REDEMARRER DANS PORTS"
    echo
    echo "La modification sera visible apres"
    echo "redemarrage d'EmulationStation ou de Batocera."
    echo
    echo "La commande suivante a aussi ete installee :"
    echo
    echo "  /userdata/roms/ports/Redemarrer.sh"
    echo
    echo "Utilise Ports -> Redemarrer pour redemarrer."
    echo
    echo "La fonction du bouton natif de redemarrage"
    echo "n'a pas ete modifiee."
    echo
    read -r -p "Appuyez sur ENTREE pour terminer..." _
    exit 0

fi


# ============================================================
# RESTAURATION
# ============================================================

if [ "$CHOIX" = "2" ]; then

    echo "=============================================="
    echo "              RESTAURATION"
    echo "=============================================="
    echo

    if [ ! -f "$BACKUP_FILE" ]; then

        echo "[ERREUR]"
        echo
        echo "Aucune sauvegarde originale trouvee :"
        echo
        echo "$BACKUP_FILE"
        echo
        read -r -p "Appuyez sur ENTREE pour terminer..." _
        exit 1

    fi


    echo "[INFO] Restauration de la traduction originale..."

    cp -p "$BACKUP_FILE" "$MO_FILE"

    if [ $? -ne 0 ]; then

        echo
        echo "[ERREUR] La restauration a echoue."
        echo
        read -r -p "Appuyez sur ENTREE pour terminer..." _
        exit 1

    fi


    echo "[OK] Traduction originale restauree."
    echo

    echo "[INFO] Restauration de Ports/Redemarrer.sh..."

    if [ -f "$PORT_BACKUP_FILE" ]; then

        mkdir -p "$PORT_DIR"
        cp -p "$PORT_BACKUP_FILE" "$PORT_FILE"
        chmod +x "$PORT_FILE"
        echo "[OK] Redemarrer.sh original restaure."

    elif [ -f "$PORT_NO_ORIGINAL_MARKER" ]; then

        rm -f "$PORT_FILE"
        echo "[OK] Redemarrer.sh installe par ce script supprime."

    else

        echo "[INFO] Aucun etat original de Redemarrer.sh enregistre."
        echo "[INFO] Le fichier actuel est laisse en place."

    fi

    echo
    echo "[INFO] Sauvegarde de l'overlay Batocera..."
    echo

    batocera-save-overlay

    if [ $? -eq 0 ]; then

        echo
        echo "[OK] Overlay sauvegarde."

    else

        echo
        echo "[ATTENTION]"
        echo "batocera-save-overlay a retourne une erreur."

    fi


    echo
    echo "=============================================="
    echo "          RESTAURATION TERMINEE"
    echo "=============================================="
    echo
    echo "Le texte original REDÉMARRER"
    echo "a ete restaure."
    echo
    echo "Le fichier Ports/Redemarrer.sh a egalement"
    echo "ete restaure ou supprime selon son etat original."
    echo
    echo "Redemarre EmulationStation ou Batocera"
    echo "pour voir le changement."
    echo
    read -r -p "Appuyez sur ENTREE pour terminer..." _
    exit 0

fi


# ============================================================
# ANNULATION
# ============================================================

echo "=============================================="
echo "               ANNULE"
echo "=============================================="
echo
echo "Aucune modification n'a ete effectuee."
echo
read -r -p "Appuyez sur ENTREE pour terminer..." _
exit 0