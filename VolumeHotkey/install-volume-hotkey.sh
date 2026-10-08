#!/bin/bash

# ============================================================
# VOLUME HOTKEY - INSTALLATEUR AUTOMATIQUE BATOCERA
#
# Emplacement :
# /userdata/saves/Installscripts/install-volume-hotkey.sh
# ============================================================

PYTHON_FILE="/userdata/system/volume-hotkey.py"
SERVICE_FILE="/userdata/system/services/volume_hotkey"
LOG_FILE="/userdata/system/volume-hotkey.log"
PID_FILE="/var/run/volume-hotkey.pid"


# ============================================================
# AFFICHAGE TERMINAL
# ============================================================

clear

# Force stdout et stderr vers le terminal actif.
if [ -w /dev/tty ]; then
    exec > /dev/tty 2>&1
fi


# ============================================================
# VERIFICATION DES DROITS DE L'INSTALLATEUR
# ============================================================

INSTALLER="$(readlink -f "$0")"

echo
echo "=============================================="
echo "          VOLUME HOTKEY INSTALLER"
echo "=============================================="
echo
echo "[INFO] Verification de l'installateur..."

if [ ! -x "$INSTALLER" ]; then

    echo "[INFO] Le fichier n'est pas executable."
    echo "[INFO] Correction automatique..."

    chmod +x "$INSTALLER" 2>/dev/null

    if [ -x "$INSTALLER" ]; then
        echo "[OK] Droit d'execution ajoute."
    else
        echo "[ATTENTION] Impossible d'ajouter le droit"
        echo "d'execution a l'installateur."
    fi

else

    echo "[OK] Installateur executable."

fi


# ============================================================
# VERIFICATION ROOT
# ============================================================

echo
echo "[INFO] Verification des droits administrateur..."

if [ "$(id -u)" != "0" ]; then

    echo
    echo "=============================================="
    echo "              ERREUR"
    echo "=============================================="
    echo
    echo "L'installation doit etre lancee en root."
    echo
    read -r -p "Appuyez sur ENTREE pour terminer..." _
    exit 1

fi

echo "[OK] Execution en root."


# ============================================================
# CONFIRMATION
# ============================================================

echo
echo "=============================================="
echo "       INSTALLATION VOLUME HOTKEY"
echo "=============================================="
echo
echo "Cet installateur va :"
echo
echo " - Installer Volume Hotkey"
echo " - Remplacer une installation existante"
echo " - Creer le dossier services si necessaire"
echo " - Activer le service volume_hotkey"
echo " - Demarrer automatiquement le service"
echo

read -r -p "Installer Volume Hotkey ? [o/N] : " REPONSE

case "$REPONSE" in

    o|O|oui|OUI|Oui)

        echo
        echo "[OK] Installation confirmee."
        echo
        ;;

    *)

        echo
        echo "=============================================="
        echo "          INSTALLATION ANNULEE"
        echo "=============================================="
        echo
        echo "Aucune modification de Volume Hotkey"
        echo "n'a ete effectuee."
        echo
        read -r -p "Appuyez sur ENTREE pour terminer..." _
        exit 0
        ;;

esac


# ============================================================
# 1 - ARRET ANCIENNE VERSION
# ============================================================

echo "----------------------------------------------"
echo "[1/6] Arret d'une ancienne version eventuelle..."
echo "----------------------------------------------"

batocera-services stop volume_hotkey >/dev/null 2>&1
pkill -f "/userdata/system/volume-hotkey.py" 2>/dev/null
rm -f "$PID_FILE"

sleep 1

echo "[OK] Ancienne instance arretee."
echo


# ============================================================
# 2 - DOSSIER SERVICES
# ============================================================

echo "----------------------------------------------"
echo "[2/6] Verification du dossier services..."
echo "----------------------------------------------"

if [ -d "/userdata/system/services" ]; then

    echo "[OK] Dossier services deja present."

else

    echo "[INFO] Dossier services absent."
    echo "[INFO] Creation de /userdata/system/services..."

    mkdir -p /userdata/system/services

    if [ -d "/userdata/system/services" ]; then

        echo "[OK] Dossier services cree."

    else

        echo "[ERREUR] Impossible de creer :"
        echo "/userdata/system/services"
        echo
        read -r -p "Appuyez sur ENTREE pour terminer..." _
        exit 1

    fi

fi

echo


# ============================================================
# 3 - CREATION DE volume-hotkey.py
# ============================================================

echo "----------------------------------------------"
echo "[3/6] Installation de volume-hotkey.py..."
echo "----------------------------------------------"

cat > "$PYTHON_FILE" <<'PYTHON_EOF'
#!/usr/bin/env python3

import evdev
import subprocess
import time
import threading


# ============================================================
# REGLAGES
# ============================================================

VOLUME_STEP = 5
REPEAT_DELAY = 0.3


# ============================================================
# VERIFICATION : UN JEU EST-IL LANCE ?
# ============================================================

def game_running():

    result = subprocess.run(
        ["batocera-es-swissknife", "--emupid"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True
    )

    return (
        result.returncode == 0
        and result.stdout.strip() not in ("", "0")
    )


# ============================================================
# VOLUME
# ============================================================

def volume_up():

    if game_running():

        subprocess.run(
            [
                "batocera-audio",
                "setSystemVolume",
                "+{}".format(VOLUME_STEP)
            ]
        )

        print(
            "Volume +{}%".format(VOLUME_STEP),
            flush=True
        )


def volume_down():

    if game_running():

        subprocess.run(
            [
                "batocera-audio",
                "setSystemVolume",
                "-{}".format(VOLUME_STEP)
            ]
        )

        print(
            "Volume -{}%".format(VOLUME_STEP),
            flush=True
        )


# ============================================================
# REPETITION AUTOMATIQUE
# ============================================================

def repeat_action(
    select_state,
    button_state,
    action,
    stop_event
):

    while not stop_event.is_set():

        if select_state() and button_state():

            action()
            stop_event.wait(REPEAT_DELAY)

        else:

            stop_event.wait(0.03)


# ============================================================
# 8BITDO ULTIMATE 2
#
# Bluetooth :
# Nom = 8BitDo Ultimate 2 Wireless
# SELECT = 314
# L2 = 312
# R2 = 313
#
# 2.4 GHz :
# Nom = Generic X-Box pad
# SELECT = 314
# L2 = ABS_Z  = 2
# R2 = ABS_RZ = 5
# ============================================================

ULTIMATE_BLUETOOTH = "8BitDo Ultimate 2 Wireless"
ULTIMATE_24G = "Generic X-Box pad"


def find_ultimate():

    while True:

        for path in evdev.list_devices():

            try:

                device = evdev.InputDevice(path)

                if device.name in (
                    ULTIMATE_BLUETOOTH,
                    ULTIMATE_24G
                ):

                    print(
                        "8BitDo Ultimate 2 detectee :",
                        device.name,
                        device.path,
                        flush=True
                    )

                    return device

            except:
                pass

        time.sleep(2)


def run_ultimate():

    while True:

        device = find_ultimate()
        stop_event = threading.Event()

        try:

            select_pressed = False
            l2_pressed = False
            r2_pressed = False

            bluetooth = (
                device.name == ULTIMATE_BLUETOOTH
            )

            print(
                "Mode :",
                "Bluetooth" if bluetooth else "2.4 GHz",
                flush=True
            )

            thread_down = threading.Thread(
                target=repeat_action,
                args=(
                    lambda: select_pressed,
                    lambda: l2_pressed,
                    volume_down,
                    stop_event
                ),
                daemon=True
            )

            thread_up = threading.Thread(
                target=repeat_action,
                args=(
                    lambda: select_pressed,
                    lambda: r2_pressed,
                    volume_up,
                    stop_event
                ),
                daemon=True
            )

            thread_down.start()
            thread_up.start()

            for event in device.read_loop():

                # Bluetooth
                if bluetooth:

                    if event.type != evdev.ecodes.EV_KEY:
                        continue

                    # SELECT
                    if event.code == 314:
                        select_pressed = event.value != 0

                    # L2
                    elif event.code == 312:
                        l2_pressed = event.value != 0

                    # R2
                    elif event.code == 313:
                        r2_pressed = event.value != 0

                # 2.4 GHz
                else:

                    if event.type == evdev.ecodes.EV_KEY:

                        # SELECT
                        if event.code == 314:
                            select_pressed = event.value != 0

                    elif event.type == evdev.ecodes.EV_ABS:

                        # L2
                        if event.code == 2:
                            l2_pressed = event.value > 0

                        # R2
                        elif event.code == 5:
                            r2_pressed = event.value > 0

        except Exception as e:

            print(
                "8BitDo Ultimate 2 deconnectee :",
                e,
                flush=True
            )

        finally:

            stop_event.set()

        time.sleep(2)


# ============================================================
# PRO CONTROLLER
#
# SELECT = 314
# L2 = 312
# R2 = 313
# ============================================================

PRO_CONTROLLER = "Pro Controller"


def find_pro_controller():

    while True:

        for path in evdev.list_devices():

            try:

                device = evdev.InputDevice(path)

                if device.name == PRO_CONTROLLER:

                    print(
                        "Pro Controller detectee :",
                        device.path,
                        flush=True
                    )

                    return device

            except:
                pass

        time.sleep(2)


def run_pro_controller():

    while True:

        device = find_pro_controller()
        stop_event = threading.Event()

        try:

            select_pressed = False
            l2_pressed = False
            r2_pressed = False

            thread_down = threading.Thread(
                target=repeat_action,
                args=(
                    lambda: select_pressed,
                    lambda: l2_pressed,
                    volume_down,
                    stop_event
                ),
                daemon=True
            )

            thread_up = threading.Thread(
                target=repeat_action,
                args=(
                    lambda: select_pressed,
                    lambda: r2_pressed,
                    volume_up,
                    stop_event
                ),
                daemon=True
            )

            thread_down.start()
            thread_up.start()

            for event in device.read_loop():

                if event.type != evdev.ecodes.EV_KEY:
                    continue

                if event.code == 314:
                    select_pressed = event.value != 0

                elif event.code == 312:
                    l2_pressed = event.value != 0

                elif event.code == 313:
                    r2_pressed = event.value != 0

        except Exception as e:

            print(
                "Pro Controller deconnectee :",
                e,
                flush=True
            )

        finally:

            stop_event.set()

        time.sleep(2)


# ============================================================
# 8BITDO ARCADE STICK
#
# SELECT = 314
# 307 = Volume -
# 308 = Volume +
# ============================================================

ARCADE_STICK = "8BitDo Arcade Stick"


def find_arcade_stick():

    while True:

        for path in evdev.list_devices():

            try:

                device = evdev.InputDevice(path)

                if device.name == ARCADE_STICK:

                    print(
                        "8BitDo Arcade Stick detecte :",
                        device.path,
                        flush=True
                    )

                    return device

            except:
                pass

        time.sleep(2)


def run_arcade_stick():

    while True:

        device = find_arcade_stick()
        stop_event = threading.Event()

        try:

            select_pressed = False
            down_pressed = False
            up_pressed = False

            thread_down = threading.Thread(
                target=repeat_action,
                args=(
                    lambda: select_pressed,
                    lambda: down_pressed,
                    volume_down,
                    stop_event
                ),
                daemon=True
            )

            thread_up = threading.Thread(
                target=repeat_action,
                args=(
                    lambda: select_pressed,
                    lambda: up_pressed,
                    volume_up,
                    stop_event
                ),
                daemon=True
            )

            thread_down.start()
            thread_up.start()

            for event in device.read_loop():

                if event.type != evdev.ecodes.EV_KEY:
                    continue

                if event.code == 314:
                    select_pressed = event.value != 0

                elif event.code == 307:
                    down_pressed = event.value != 0

                elif event.code == 308:
                    up_pressed = event.value != 0

        except Exception as e:

            print(
                "8BitDo Arcade Stick deconnecte :",
                e,
                flush=True
            )

        finally:

            stop_event.set()

        time.sleep(2)


# ============================================================
# SINDEN LIGHTGUN
#
# SELECT = 272
# L2 = 273
# R2 = 274
# ============================================================

SINDEN_LIGHTGUN = "Sinden lightgun"


def find_sinden():

    while True:

        for path in evdev.list_devices():

            try:

                device = evdev.InputDevice(path)

                if device.name == SINDEN_LIGHTGUN:

                    print(
                        "Sinden Lightgun detecte :",
                        device.path,
                        flush=True
                    )

                    return device

            except:
                pass

        time.sleep(2)


def run_sinden():

    while True:

        device = find_sinden()
        stop_event = threading.Event()

        try:

            select_pressed = False
            l2_pressed = False
            r2_pressed = False

            thread_down = threading.Thread(
                target=repeat_action,
                args=(
                    lambda: select_pressed,
                    lambda: l2_pressed,
                    volume_down,
                    stop_event
                ),
                daemon=True
            )

            thread_up = threading.Thread(
                target=repeat_action,
                args=(
                    lambda: select_pressed,
                    lambda: r2_pressed,
                    volume_up,
                    stop_event
                ),
                daemon=True
            )

            thread_down.start()
            thread_up.start()

            for event in device.read_loop():

                if event.type != evdev.ecodes.EV_KEY:
                    continue

                if event.code == 272:
                    select_pressed = event.value != 0

                elif event.code == 273:
                    l2_pressed = event.value != 0

                elif event.code == 274:
                    r2_pressed = event.value != 0

        except Exception as e:

            print(
                "Sinden Lightgun deconnecte :",
                e,
                flush=True
            )

        finally:

            stop_event.set()

        time.sleep(2)


# ============================================================
# LANCEMENT
# ============================================================

print(
    "Demarrage du gestionnaire de volume",
    flush=True
)


thread_ultimate = threading.Thread(
    target=run_ultimate,
    daemon=True
)

thread_pro = threading.Thread(
    target=run_pro_controller,
    daemon=True
)

thread_arcade = threading.Thread(
    target=run_arcade_stick,
    daemon=True
)

thread_sinden = threading.Thread(
    target=run_sinden,
    daemon=True
)


thread_ultimate.start()
thread_pro.start()
thread_arcade.start()
thread_sinden.start()


thread_ultimate.join()
thread_pro.join()
thread_arcade.join()
thread_sinden.join()
PYTHON_EOF


if [ -f "$PYTHON_FILE" ]; then

    echo "[OK] volume-hotkey.py installe."

else

    echo "[ERREUR] Echec de creation de volume-hotkey.py."
    echo
    read -r -p "Appuyez sur ENTREE pour terminer..." _
    exit 1

fi

echo


# ============================================================
# 4 - CREATION DU SERVICE
# ============================================================

echo "----------------------------------------------"
echo "[4/6] Installation du service volume_hotkey..."
echo "----------------------------------------------"

cat > "$SERVICE_FILE" <<'SERVICE_EOF'
#!/bin/bash

case "$1" in

    start)

        if pgrep -f "/userdata/system/volume-hotkey.py" >/dev/null; then
            exit 0
        fi

        python3 /userdata/system/volume-hotkey.py \
            > /userdata/system/volume-hotkey.log 2>&1 &

        echo $! > /var/run/volume-hotkey.pid
        ;;


    stop)

        if [ -f /var/run/volume-hotkey.pid ]; then

            PID="$(cat /var/run/volume-hotkey.pid)"

            kill "$PID" 2>/dev/null

            rm -f /var/run/volume-hotkey.pid

        else

            pkill -f "/userdata/system/volume-hotkey.py" 2>/dev/null

        fi
        ;;


    restart)

        "$0" stop

        sleep 1

        "$0" start
        ;;

esac
SERVICE_EOF


if [ -f "$SERVICE_FILE" ]; then

    echo "[OK] Service volume_hotkey installe."

else

    echo "[ERREUR] Echec de creation du service."
    echo
    read -r -p "Appuyez sur ENTREE pour terminer..." _
    exit 1

fi

echo


# ============================================================
# 5 - PERMISSIONS
# ============================================================

echo "----------------------------------------------"
echo "[5/6] Application des permissions..."
echo "----------------------------------------------"

chmod +x "$PYTHON_FILE"
chmod +x "$SERVICE_FILE"

if [ -x "$PYTHON_FILE" ]; then
    echo "[OK] volume-hotkey.py executable."
else
    echo "[ERREUR] volume-hotkey.py non executable."
fi

if [ -x "$SERVICE_FILE" ]; then
    echo "[OK] Service volume_hotkey executable."
else
    echo "[ERREUR] Service volume_hotkey non executable."
fi

echo


# ============================================================
# 6 - ACTIVATION ET DEMARRAGE
# ============================================================

echo "----------------------------------------------"
echo "[6/6] Activation et demarrage du service..."
echo "----------------------------------------------"

if batocera-services enable volume_hotkey >/dev/null 2>&1; then

    echo "[OK] Service active au demarrage."

else

    echo "[ERREUR] Impossible d'activer le service."
    echo
    read -r -p "Appuyez sur ENTREE pour terminer..." _
    exit 1

fi


echo "[INFO] Demarrage de volume_hotkey..."

batocera-services restart volume_hotkey >/dev/null 2>&1

sleep 2


# ============================================================
# VERIFICATION FINALE
# ============================================================

echo
echo "=============================================="

if pgrep -f "/userdata/system/volume-hotkey.py" >/dev/null; then

    echo "          INSTALLATION REUSSIE"
    echo "=============================================="
    echo
    echo "[OK] volume-hotkey.py installe"
    echo "[OK] Service volume_hotkey installe"
    echo "[OK] Service active au demarrage"
    echo "[OK] Service actuellement demarre"
    echo
    echo "----------------------------------------------"
    echo "              COMMANDES"
    echo "----------------------------------------------"
    echo
    echo "SELECT + L2 = Volume -"
    echo "SELECT + R2 = Volume +"
    echo
    echo "Pas volume : 5 %"
    echo "Repetition : 0.3 seconde"
    echo
    echo "Le service demarrera automatiquement"
    echo "avec Batocera."

else

    echo "              ERREUR"
    echo "=============================================="
    echo
    echo "[ERREUR] Le service volume_hotkey"
    echo "n'a pas demarre."
    echo
    echo "Consulte le journal avec :"
    echo
    echo "cat $LOG_FILE"

fi


echo
echo "=============================================="
echo
read -r -p "Appuyez sur ENTREE pour terminer..." _
echo