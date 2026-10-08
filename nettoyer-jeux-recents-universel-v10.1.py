#!/usr/bin/env python3

import os
import json
import glob
import subprocess
import time
import datetime
import shutil
import pygame
import xml.etree.ElementTree as ET


# ============================================================
# CONFIGURATION
# ============================================================

ROM_DIR = "/userdata/roms"
BACKUP_DIR = "/userdata/system/backup_recents"
CONTROLLER_CONFIG = "/userdata/system/nettoyer-jeux-recents-controller.json"

MAX_GAMES = 50
MAX_BACKUPS = 10

COMBO_DELAY = 0.50
REPEAT_DELAY = 0.35
REPEAT_INTERVAL = 0.10


# ============================================================
# INITIALISATION PYGAME
# ============================================================

pygame.init()
pygame.joystick.init()

screen = pygame.display.set_mode(
    (0, 0),
    pygame.FULLSCREEN
)

WIDTH, HEIGHT = screen.get_size()

pygame.display.set_caption(
    "Nettoyer les jeux récents"
)


# ============================================================
# ADAPTATION DE L'INTERFACE
# ============================================================

BASE_WIDTH = 1280
BASE_HEIGHT = 800

SCALE_X = WIDTH / BASE_WIDTH
SCALE_Y = HEIGHT / BASE_HEIGHT

FONT_SCALE = min(
    SCALE_X,
    SCALE_Y
)


def sx(value):
    return int(value * SCALE_X)


def sy(value):
    return int(value * SCALE_Y)


def fs(value):
    return max(
        12,
        int(value * FONT_SCALE)
    )


font = pygame.font.Font(
    None,
    fs(34)
)

font_small = pygame.font.Font(
    None,
    fs(27)
)

font_big = pygame.font.Font(
    None,
    fs(46)
)

font_title = pygame.font.Font(
    None,
    fs(52)
)


# ============================================================
# NOMBRE DE JEUX VISIBLES
# ============================================================

LIST_TOP = sy(150)
INFO_Y = sy(610)
ROW_HEIGHT = sy(48)

COMMAND_Y1 = HEIGHT - sy(60)
COMMAND_Y2 = HEIGHT - sy(30)

VISIBLE = max(
    5,
    int(
        (INFO_Y - LIST_TOP - sy(15))
        / ROW_HEIGHT
    )
)


# ============================================================
# AFFICHAGE TEXTE
# ============================================================

def text(txt, x, y, f=font):

    surface = f.render(
        str(txt),
        True,
        (255, 255, 255)
    )

    screen.blit(
        surface,
        (x, y)
    )


def centered_text(txt, y, f=font):

    surface = f.render(
        str(txt),
        True,
        (255, 255, 255)
    )

    x = (
        WIDTH
        - surface.get_width()
    ) // 2

    screen.blit(
        surface,
        (x, y)
    )


# ============================================================
# ICÔNES DES TOUCHES
# ============================================================

BUTTON_COLORS = {
    "A": (70, 200, 90),
    "B": (220, 70, 70),
    "X": (70, 130, 220),
    "Y": (230, 190, 55),
}


def draw_button_icon(label, x, y, size=None):

    if size is None:
        size = fs(30)

    size = max(20, int(size))
    radius = size // 2

    color = BUTTON_COLORS.get(
        label,
        (120, 120, 120)
    )

    center = (
        int(x + radius),
        int(y + radius)
    )

    pygame.draw.circle(
        screen,
        (10, 10, 10),
        center,
        radius + max(2, size // 12)
    )

    pygame.draw.circle(
        screen,
        color,
        center,
        radius
    )

    pygame.draw.circle(
        screen,
        tuple(min(255, c + 35) for c in color),
        (
            center[0],
            center[1] - max(1, size // 10)
        ),
        max(2, radius // 5)
    )

    f = pygame.font.Font(
        None,
        max(14, int(size * 0.62))
    )

    surface = f.render(
        str(label),
        True,
        (255, 255, 255)
    )

    screen.blit(
        surface,
        (
            center[0] - surface.get_width() // 2,
            center[1] - surface.get_height() // 2
        )
    )

    return size


def draw_system_button(label, x, y, width=None, height=None):

    if width is None:
        width = fs(78)

    if height is None:
        height = fs(30)

    rect = pygame.Rect(
        int(x),
        int(y),
        int(width),
        int(height)
    )

    pygame.draw.rect(
        screen,
        (10, 10, 10),
        rect,
        border_radius=max(3, height // 6)
    )

    inner = rect.inflate(
        -max(2, height // 8),
        -max(2, height // 8)
    )

    pygame.draw.rect(
        screen,
        (95, 95, 95),
        inner,
        border_radius=max(2, height // 7)
    )

    f = pygame.font.Font(
        None,
        max(14, int(height * 0.55))
    )

    surface = f.render(
        label,
        True,
        (255, 255, 255)
    )

    screen.blit(
        surface,
        (
            rect.centerx - surface.get_width() // 2,
            rect.centery - surface.get_height() // 2
        )
    )


def draw_command(
    x,
    y,
    label,
    description,
    system=False
):

    if system:

        draw_system_button(
            label,
            x,
            y
        )

        offset = fs(88)

    else:

        size = draw_button_icon(
            label,
            x,
            y,
            fs(32)
        )

        offset = size + fs(8)

    text(
        description,
        x + offset,
        y + max(0, fs(3)),
        font_small
    )


def draw_combo_command(
    x,
    y,
    first,
    second,
    description
):

    if first == "SELECT":

        draw_system_button(
            first,
            x,
            y
        )

        first_width = fs(78)

    else:

        first_width = draw_button_icon(
            first,
            x,
            y,
            fs(32)
        )

    plus_x = x + first_width + fs(8)

    plus_surface = font_small.render(
        "+",
        True,
        (255, 255, 255)
    )

    screen.blit(
        plus_surface,
        (
            plus_x,
            y + max(0, fs(3))
        )
    )

    second_x = (
        plus_x
        + plus_surface.get_width()
        + fs(8)
    )

    if second == "SELECT":

        draw_system_button(
            second,
            second_x,
            y
        )

        second_width = fs(78)

    else:

        second_width = draw_button_icon(
            second,
            second_x,
            y,
            fs(32)
        )

    description_x = (
        second_x
        + second_width
        + fs(8)
    )

    text(
        description,
        description_x,
        y + max(0, fs(3)),
        font_small
    )


# ============================================================
# MANETTE
# ============================================================

controller = None
controller_index = 0

BUTTONS = {
    "A": None,
    "B": None,
    "START": None,
    "UP": None,
    "DOWN": None,
    "X": None,
    "Y": None,
    "SELECT": None
}


STEAM_DECK_GUID = "03000000de2800000512000011010000"


def is_steam_deck_controller(js):

    try:
        name = js.get_name()
    except Exception:
        name = ""

    try:
        guid = js.get_guid()
    except Exception:
        guid = ""

    return (
        name == "Steam Deck"
        or guid == STEAM_DECK_GUID
    )


def event_from_selected_controller(event):
    """
    Ignore les événements des autres manettes lorsqu'une manette
    précise a été choisie.

    Compatible avec les événements Pygame/SDL de Batocera 42/43.
    """

    try:
        return event.joy == controller_index
    except Exception:
        return True


def get_controller_identity(js):

    try:
        name = js.get_name()
    except Exception:
        name = "Manette inconnue"

    try:
        guid = js.get_guid()
    except Exception:
        guid = ""

    return {
        "name": name,
        "guid": guid
    }


def controller_config_key(identity):
    """
    Clé stable pour mémoriser plusieurs types de manettes.

    Le GUID SDL est privilégié. S'il n'est pas disponible,
    le nom de la manette sert de solution de secours.
    """

    guid = identity.get(
        "guid",
        ""
    )

    name = identity.get(
        "name",
        ""
    )

    if guid:
        return "guid:" + guid

    return "name:" + name


def read_controller_config_database():
    """
    Lit le fichier de configuration multi-manettes.

    Ancien format accepté automatiquement :
        {
            "controller": {...},
            "buttons": {...}
        }

    Nouveau format :
        {
            "version": 2,
            "controllers": {
                "guid:...": {
                    "controller": {...},
                    "buttons": {...}
                }
            }
        }
    """

    empty_database = {
        "version": 2,
        "controllers": {}
    }

    if not os.path.exists(
        CONTROLLER_CONFIG
    ):
        return empty_database

    try:

        with open(
            CONTROLLER_CONFIG,
            "r",
            encoding="utf-8"
        ) as f:

            data = json.load(f)

    except Exception as e:

        print(
            "Erreur lecture configuration:",
            e
        )

        return empty_database

    # Nouveau format multi-manettes.
    controllers = data.get(
        "controllers"
    )

    if isinstance(
        controllers,
        dict
    ):

        return {
            "version": 2,
            "controllers": controllers
        }

    # Migration automatique de l'ancien format.
    old_identity = data.get(
        "controller"
    )

    old_buttons = data.get(
        "buttons"
    )

    if (
        isinstance(old_identity, dict)
        and isinstance(old_buttons, dict)
    ):

        key = controller_config_key(
            old_identity
        )

        migrated = {
            "version": 2,
            "controllers": {
                key: {
                    "controller": old_identity,
                    "buttons": old_buttons
                }
            }
        }

        try:

            with open(
                CONTROLLER_CONFIG,
                "w",
                encoding="utf-8"
            ) as f:

                json.dump(
                    migrated,
                    f,
                    indent=2,
                    ensure_ascii=False
                )

            print(
                "Ancienne configuration manette "
                "convertie au format multi-manettes."
            )

        except Exception as e:

            print(
                "Erreur migration configuration:",
                e
            )

        return migrated

    return empty_database


def save_controller_config():

    try:

        identity = get_controller_identity(
            controller
        )

        database = (
            read_controller_config_database()
        )

        key = controller_config_key(
            identity
        )

        database[
            "controllers"
        ][key] = {
            "controller": identity,
            "buttons": BUTTONS
        }

        database["version"] = 2

        with open(
            CONTROLLER_CONFIG,
            "w",
            encoding="utf-8"
        ) as f:

            json.dump(
                database,
                f,
                indent=2,
                ensure_ascii=False
            )

        print(
            "Configuration de la manette sauvegardée."
        )

    except Exception as e:

        print(
            "Erreur sauvegarde manette:",
            e
        )


def load_controller_config(js):

    global BUTTONS

    database = (
        read_controller_config_database()
    )

    current_controller = (
        get_controller_identity(js)
    )

    key = controller_config_key(
        current_controller
    )

    profile = database.get(
        "controllers",
        {}
    ).get(
        key
    )

    if not isinstance(
        profile,
        dict
    ):

        print(
            "Nouvelle manette détectée."
        )

        return False

    saved_buttons = profile.get(
        "buttons",
        {}
    )

    if not isinstance(
        saved_buttons,
        dict
    ):

        return False

    for button_name in BUTTONS:

        BUTTONS[button_name] = (
            saved_buttons.get(
                button_name
            )
        )

    if all(
        BUTTONS[button_name] is not None
        for button_name in BUTTONS
    ):

        print(
            "Configuration manette chargée :",
            current_controller.get(
                "name",
                "Manette inconnue"
            )
        )

        return True

    return False


def draw_learning_screen(
    name,
    index,
    total
):

    screen.fill(
        (20, 20, 20)
    )

    centered_text(
        "Apprentissage de la manette",
        sy(90),
        font_title
    )

    centered_text(
        "Manette : "
        + controller.get_name(),
        sy(155),
        font_small
    )

    centered_text(
        "Appuyez sur : "
        + name,
        sy(260),
        font_big
    )

    centered_text(
        f"{index + 1} / {total}",
        sy(330),
        font
    )

    if name in (
        "UP",
        "DOWN"
    ):

        centered_text(
            "Utilisez la croix directionnelle",
            sy(390),
            font_small
        )

    else:

        centered_text(
            "Appuyez sur le bouton demandé",
            sy(390),
            font_small
        )

    pygame.display.flip()


def mapping_already_used(mapping):

    if mapping is None:
        return False

    for value in BUTTONS.values():

        if value == mapping:
            return True

    return False


def controller_learning():

    global controller
    global BUTTONS

    if controller is None:

        print(
            "Aucune manette sélectionnée."
        )

        return False

    BUTTONS = {
        "A": None,
        "B": None,
        "START": None,
        "UP": None,
        "DOWN": None,
        "X": None,
        "Y": None,
        "SELECT": None
    }

    names = [
        "A",
        "B",
        "START",
        "UP",
        "DOWN",
        "X",
        "Y",
        "SELECT"
    ]

    index = 0

    clock = pygame.time.Clock()

    pygame.event.clear()

    while index < len(names):

        name = names[index]

        draw_learning_screen(
            name,
            index,
            len(names)
        )

        for event in pygame.event.get():

            if event.type == pygame.JOYBUTTONDOWN:

                if not event_from_selected_controller(event):
                    continue

                # Certaines manettes, dont le contrôleur interne
                # du Steam Deck, exposent la croix directionnelle
                # comme de simples boutons SDL.
                mapping = {
                    "type": "button",
                    "button": event.button
                }

                if mapping_already_used(
                    mapping
                ):
                    continue

                BUTTONS[name] = mapping

                index += 1

                pygame.event.clear()

                break

            elif event.type == pygame.JOYHATMOTION:

                if not event_from_selected_controller(event):
                    continue

                if name not in (
                    "UP",
                    "DOWN"
                ):
                    continue

                x, y = event.value

                direction = None

                if name == "UP" and y > 0:
                    direction = "up"

                elif name == "DOWN" and y < 0:
                    direction = "down"

                if direction is None:
                    continue

                mapping = {
                    "type": "hat",
                    "hat": event.hat,
                    "direction": direction
                }

                if mapping_already_used(
                    mapping
                ):
                    continue

                BUTTONS[name] = mapping

                index += 1

                pygame.event.clear()

                break

            elif event.type == pygame.JOYAXISMOTION:

                if not event_from_selected_controller(event):
                    continue

                if name not in (
                    "UP",
                    "DOWN"
                ):
                    continue

                value = event.value

                if abs(value) < 0.70:
                    continue

                direction = None

                if name == "UP" and value < -0.70:
                    direction = "up"

                elif name == "DOWN" and value > 0.70:
                    direction = "down"

                if direction is None:
                    continue

                mapping = {
                    "type": "axis",
                    "axis": event.axis,
                    "direction": direction
                }

                if mapping_already_used(
                    mapping
                ):
                    continue

                BUTTONS[name] = mapping

                index += 1

                pygame.event.clear()

                break

        clock.tick(60)

    save_controller_config()

    return True


def choose_active_controller(joysticks):
    """
    Si plusieurs manettes sont visibles, attend le premier bouton pressé
    et choisit la manette qui a généré cet événement.

    Cela permet notamment de revenir au contrôleur interne du Steam Deck
    sans redémarrer Batocera, même si SDL conserve temporairement une
    manette externe déconnectée dans sa liste.
    """

    global controller_index
    global controller

    if not joysticks:
        return None

    # Une seule manette : aucun choix nécessaire.
    if len(joysticks) == 1:
        return joysticks[0]

    screen.fill(
        (15, 15, 15)
    )

    centered_text(
        "Choix de la manette",
        sy(120),
        font_title
    )

    centered_text(
        "Appuyez sur un bouton de la manette à utiliser",
        sy(250),
        font_big
    )

    pygame.display.flip()

    pygame.event.clear()

    clock = pygame.time.Clock()

    while True:

        for event in pygame.event.get():

            if event.type == pygame.JOYBUTTONDOWN:

                event_joy = getattr(
                    event,
                    "joy",
                    None
                )

                for index, js in joysticks:

                    if index == event_joy:

                        return (
                            index,
                            js
                        )

            elif event.type == pygame.KEYDOWN:

                # Échappement : par sécurité on revient à la première
                # manette visible au lieu de rester bloqué.
                if event.key == pygame.K_ESCAPE:
                    return joysticks[0]

        clock.tick(60)


def setup_controller():

    global controller
    global controller_index
    global BUTTONS

    count = pygame.joystick.get_count()

    if count == 0:

        print(
            "Aucune manette détectée."
        )

        return False

    joysticks = []

    for index in range(count):

        try:

            js = pygame.joystick.Joystick(index)

            js.init()

            joysticks.append(
                (
                    index,
                    js
                )
            )

        except Exception as e:

            print(
                "Erreur initialisation manette",
                index,
                ":",
                e
            )

    if not joysticks:
        return False

    # ========================================================
    # CHOIX DE LA MANETTE
    # ========================================================
    #
    # Une seule manette visible :
    #   -> utilisée automatiquement.
    #
    # Plusieurs manettes visibles :
    #   -> la première qui reçoit un appui bouton devient active.
    #
    # Cette méthode évite le problème d'une manette externe
    # déconnectée qui reste parfois visible dans SDL jusqu'au
    # redémarrage de Batocera.
    # ========================================================

    chosen = choose_active_controller(
        joysticks
    )

    if chosen is None:
        return False

    controller_index, controller = chosen

    identity = get_controller_identity(
        controller
    )

    print(
        "Manette sélectionnée :",
        identity.get(
            "name",
            "Inconnue"
        ),
        "(index",
        controller_index,
        ")"
    )

    # ========================================================
    # STEAM DECK : MAPPING AUTOMATIQUE
    # ========================================================

    if is_steam_deck_controller(
        controller
    ):

        BUTTONS = {
            "A": {
                "type": "button",
                "button": 3
            },
            "B": {
                "type": "button",
                "button": 4
            },
            "START": {
                "type": "button",
                "button": 12
            },
            "UP": {
                "type": "button",
                "button": 16
            },
            "DOWN": {
                "type": "button",
                "button": 17
            },
            "X": {
                "type": "button",
                "button": 5
            },
            "Y": {
                "type": "button",
                "button": 6
            },
            "SELECT": {
                "type": "button",
                "button": 11
            }
        }

        print(
            "Steam Deck détecté : "
            "mapping intégré appliqué."
        )

        return True

    # ========================================================
    # AUTRES MANETTES
    # ========================================================

    if load_controller_config(
        controller
    ):
        return True

    return controller_learning()


# ============================================================
# VERIFICATION DES TOUCHES
# ============================================================

def mapping_matches_button(
    mapping,
    button
):

    if not mapping:
        return False

    return (
        mapping.get("type") == "button"
        and mapping.get("button") == button
    )


def mapping_matches_hat(
    mapping,
    hat,
    value
):

    if not mapping:
        return False

    if mapping.get("type") != "hat":
        return False

    if mapping.get("hat") != hat:
        return False

    x, y = value

    direction = mapping.get(
        "direction"
    )

    if direction == "up":
        return y > 0

    if direction == "down":
        return y < 0

    return False


def mapping_matches_axis(
    mapping,
    axis,
    value
):

    if not mapping:
        return False

    if mapping.get("type") != "axis":
        return False

    if mapping.get("axis") != axis:
        return False

    direction = mapping.get(
        "direction"
    )

    if direction == "up":
        return value < -0.70

    if direction == "down":
        return value > 0.70

    return False


# ============================================================
# XML / JEUX
# ============================================================

def get_gamelist_files():
    """
    Retourne les gamelist.xml des systèmes Batocera sans faire
    de parcours récursif de tout /userdata/roms.

    On cherche uniquement :
        /userdata/roms/<systeme>/gamelist.xml

    Cela évite de descendre dans les dossiers de jeux Windows,
    hacks, Wine, sous-dossiers volumineux ou éventuels liens.
    """

    files = []

    try:
        with os.scandir(ROM_DIR) as entries:

            for entry in entries:

                # Le Port contenant ce programme n'a pas besoin
                # d'être inspecté pour les jeux récents.
                if entry.name == "ports":
                    continue

                try:
                    if not entry.is_dir():
                        continue
                except OSError:
                    continue

                gamelist = os.path.join(
                    entry.path,
                    "gamelist.xml"
                )

                if os.path.isfile(gamelist):
                    files.append(gamelist)

    except Exception as e:

        print(
            "Erreur recherche gamelist.xml :",
            e
        )

    return files


def get_game_path(game):

    element = game.find("path")

    if (
        element is not None
        and element.text
    ):
        return element.text

    return ""


def get_text(
    element,
    tag,
    default=""
):

    child = element.find(tag)

    if (
        child is not None
        and child.text
    ):
        return child.text

    return default


def load_games():

    games = []

    # Recherche volontairement NON récursive.
    # Les gamelist Batocera sont à la racine de chaque système.
    files = get_gamelist_files()

    for xml_file in files:

        if os.path.abspath(
            xml_file
        ).startswith(
            os.path.abspath(
                os.path.join(
                    ROM_DIR,
                    "ports"
                )
            ) + os.sep
        ):
            continue

        try:

            tree = ET.parse(
                xml_file
            )

            root = tree.getroot()

        except Exception as e:

            print(
                "Erreur lecture XML :",
                xml_file,
                e
            )

            continue

        system = os.path.basename(
            os.path.dirname(
                xml_file
            )
        )

        for game in root.findall(
            "game"
        ):

            playcount = get_text(
                game,
                "playcount",
                "0"
            )

            try:

                playcount_int = int(
                    playcount
                )

            except Exception:

                playcount_int = 0

            if playcount_int <= 0:
                continue

            name = get_text(
                game,
                "name",
                "Jeu sans nom"
            )

            path = get_game_path(
                game
            )

            lastplayed = get_text(
                game,
                "lastplayed",
                ""
            )

            games.append({
                "name": name,
                "system": system,
                "path": path,
                "lastplayed": lastplayed,
                "playcount": playcount_int,
                "xml_file": xml_file
            })

    unique = {}

    for game in games:

        key = (
            game["xml_file"],
            game["path"]
        )

        unique[key] = game

    games = list(
        unique.values()
    )

    games.sort(
        key=lambda game:
        game["lastplayed"] or "",
        reverse=True
    )

    return games[:MAX_GAMES]


def format_date(value):

    if not value:
        return "Date inconnue"

    try:

        dt = datetime.datetime.fromisoformat(
            value.replace(
                "Z",
                "+00:00"
            )
        )

        return dt.strftime(
            "%d/%m/%Y %H:%M"
        )

    except Exception:

        if len(value) >= 16:
            return value[:16]

        return value


# ============================================================
# BACKUPS
# ============================================================

def cleanup_old_backups():

    if not os.path.isdir(
        BACKUP_DIR
    ):
        return 0

    backups = []

    try:

        for name in os.listdir(
            BACKUP_DIR
        ):

            path = os.path.join(
                BACKUP_DIR,
                name
            )

            if not os.path.isdir(path):
                continue

            backup_file = os.path.join(
                path,
                "backup.json"
            )

            if os.path.isfile(
                backup_file
            ):
                backups.append(path)

    except Exception as e:

        print(
            "Erreur lecture backups :",
            e
        )

        return 0

    backups.sort(
        key=os.path.getmtime,
        reverse=True
    )

    deleted = 0

    for backup in backups[
        MAX_BACKUPS:
    ]:

        try:

            shutil.rmtree(
                backup
            )

            deleted += 1

        except Exception as e:

            print(
                "Erreur suppression backup :",
                e
            )

    return deleted


def create_backup(
    selected_games
):

    os.makedirs(
        BACKUP_DIR,
        exist_ok=True
    )

    timestamp = datetime.datetime.now().strftime(
        "%Y%m%d_%H%M%S"
    )

    backup_path = os.path.join(
        BACKUP_DIR,
        timestamp
    )

    os.makedirs(
        backup_path,
        exist_ok=True
    )

    backup_data = {
        "version": 3,
        "date": timestamp,
        "games": []
    }

    for game in selected_games:

        backup_data["games"].append({
            "name": game["name"],
            "system": game["system"],
            "path": game["path"],
            "lastplayed": game["lastplayed"],
            "playcount": game["playcount"]
        })

    backup_file = os.path.join(
        backup_path,
        "backup.json"
    )

    with open(
        backup_file,
        "w",
        encoding="utf-8"
    ) as f:

        json.dump(
            backup_data,
            f,
            indent=2,
            ensure_ascii=False
        )

    info_file = os.path.join(
        backup_path,
        "info.txt"
    )

    with open(
        info_file,
        "w",
        encoding="utf-8"
    ) as f:

        f.write(
            "Sauvegarde ciblée des jeux récents\n"
        )

        f.write(
            "===================================\n\n"
        )

        f.write(
            "Date : "
            + timestamp
            + "\n"
        )

        f.write(
            "Nombre de jeux : "
            + str(len(selected_games))
            + "\n\n"
        )

        for game in selected_games:

            f.write(
                game["system"]
                + " - "
                + game["name"]
                + "\n"
            )

            f.write(
                "Path : "
                + game["path"]
                + "\n"
            )

            f.write(
                "Playcount : "
                + str(game["playcount"])
                + "\n"
            )

            f.write(
                "Lastplayed : "
                + game["lastplayed"]
                + "\n\n"
            )

    return backup_path


def get_backup_list():

    backups = []

    if not os.path.isdir(
        BACKUP_DIR
    ):
        return backups

    try:

        for name in os.listdir(
            BACKUP_DIR
        ):

            path = os.path.join(
                BACKUP_DIR,
                name
            )

            if not os.path.isdir(path):
                continue

            backup_file = os.path.join(
                path,
                "backup.json"
            )

            if not os.path.isfile(
                backup_file
            ):
                continue

            try:

                with open(
                    backup_file,
                    "r",
                    encoding="utf-8"
                ) as f:

                    data = json.load(f)

                backups.append({
                    "path": path,
                    "name": name,
                    "date": data.get(
                        "date",
                        name
                    ),
                    "games": len(
                        data.get(
                            "games",
                            []
                        )
                    )
                })

            except Exception:
                continue

    except Exception as e:

        print(
            "Erreur lecture backups :",
            e
        )

    backups.sort(
        key=lambda x:
        os.path.getmtime(
            x["path"]
        ),
        reverse=True
    )

    return backups


def get_backup_info():

    backups = get_backup_list()

    if not backups:
        return 0, "Aucun"

    try:

        dt = datetime.datetime.fromtimestamp(
            os.path.getmtime(
                backups[0]["path"]
            )
        )

        latest = dt.strftime(
            "%d/%m/%Y %H:%M"
        )

    except Exception:

        latest = "Date inconnue"

    return len(backups), latest


def get_latest_backup():

    backups = get_backup_list()

    if not backups:
        return None

    return backups[0]["path"]


def delete_backup(
    backup
):

    try:

        shutil.rmtree(
            backup["path"]
        )

        return True

    except Exception as e:

        print(
            "Erreur suppression backup :",
            e
        )

        return False


# ============================================================
# GESTION DES SAVES
# ============================================================

def backup_management():

    backups = get_backup_list()

    if not backups:

        screen.fill(
            (15, 15, 15)
        )

        centered_text(
            "Gestion des Saves",
            sy(120),
            font_title
        )

        centered_text(
            "Aucune sauvegarde disponible",
            sy(280),
            font_big
        )

        draw_command(
            sx(545),
            sy(385),
            "B",
            "Retour"
        )

        pygame.display.flip()

        while True:

            for event in pygame.event.get():

                if event.type == pygame.KEYDOWN:

                    if event.key in (
                        pygame.K_ESCAPE,
                        pygame.K_b
                    ):
                        return

                elif event.type == pygame.JOYBUTTONDOWN:

                    if not event_from_selected_controller(event):
                        continue

                    if mapping_matches_button(
                        BUTTONS["B"],
                        event.button
                    ):
                        return

            pygame.time.wait(10)

    cursor = 0
    selected = set()

    clock = pygame.time.Clock()

    running = True

    held_direction = None
    next_repeat_time = 0

    while running:

        now = time.monotonic()

        for event in pygame.event.get():

            if event.type == pygame.KEYDOWN:

                if event.key in (
                    pygame.K_ESCAPE,
                    pygame.K_b
                ):
                    return

                elif event.key == pygame.K_UP:

                    cursor = max(
                        0,
                        cursor - 1
                    )

                elif event.key == pygame.K_DOWN:

                    cursor = min(
                        len(backups) - 1,
                        cursor + 1
                    )

                elif event.key in (
                    pygame.K_a,
                    pygame.K_DELETE
                ):

                    selected.add(
                        cursor
                    )

                elif event.key == pygame.K_RETURN:

                    if cursor in selected:

                        backup = backups[cursor]

                        confirmed = confirmation_screen(
                            "Supprimer cette sauvegarde ?",
                            f"{backup['games']} jeu(x) seront concernés."
                        )

                        if confirmed:

                            delete_backup(
                                backup
                            )

                            backups = get_backup_list()

                            selected.clear()

                            if not backups:
                                return

                            cursor = min(
                                cursor,
                                len(backups) - 1
                            )

            elif event.type == pygame.JOYBUTTONDOWN:

                if not event_from_selected_controller(event):
                    continue

                button = event.button

                if mapping_matches_button(
                    BUTTONS["UP"],
                    button
                ):

                    cursor = max(
                        0,
                        cursor - 1
                    )

                    held_direction = "up"

                    next_repeat_time = (
                        now + REPEAT_DELAY
                    )

                elif mapping_matches_button(
                    BUTTONS["DOWN"],
                    button
                ):

                    cursor = min(
                        len(backups) - 1,
                        cursor + 1
                    )

                    held_direction = "down"

                    next_repeat_time = (
                        now + REPEAT_DELAY
                    )

                elif mapping_matches_button(
                    BUTTONS["B"],
                    button
                ):
                    return

                elif mapping_matches_button(
                    BUTTONS["A"],
                    button
                ):

                    backup = backups[cursor]

                    confirmed = confirmation_screen(
                        "Supprimer cette sauvegarde ?",
                        f"{backup['games']} jeu(x) seront concernés."
                    )

                    if confirmed:

                        delete_backup(
                            backup
                        )

                        backups = get_backup_list()

                        selected.clear()

                        if not backups:
                            return

                        cursor = min(
                            cursor,
                            len(backups) - 1
                        )

            elif event.type == pygame.JOYHATMOTION:

                if not event_from_selected_controller(event):
                    continue

                if event.value == (0, 0):

                    held_direction = None

                    continue

                if mapping_matches_hat(
                    BUTTONS["UP"],
                    event.hat,
                    event.value
                ):

                    cursor = max(
                        0,
                        cursor - 1
                    )

                    held_direction = "up"

                    next_repeat_time = (
                        now + REPEAT_DELAY
                    )

                elif mapping_matches_hat(
                    BUTTONS["DOWN"],
                    event.hat,
                    event.value
                ):

                    cursor = min(
                        len(backups) - 1,
                        cursor + 1
                    )

                    held_direction = "down"

                    next_repeat_time = (
                        now + REPEAT_DELAY
                    )

            elif event.type == pygame.JOYBUTTONUP:

                if not event_from_selected_controller(event):
                    continue

                if mapping_matches_button(
                    BUTTONS["UP"],
                    event.button
                ):

                    if held_direction == "up":
                        held_direction = None

                elif mapping_matches_button(
                    BUTTONS["DOWN"],
                    event.button
                ):

                    if held_direction == "down":
                        held_direction = None

        if (
            held_direction is not None
            and now >= next_repeat_time
        ):

            if held_direction == "up":

                if cursor > 0:
                    cursor -= 1
                else:
                    held_direction = None

            elif held_direction == "down":

                if cursor < len(backups) - 1:
                    cursor += 1
                else:
                    held_direction = None

            if held_direction is not None:

                next_repeat_time = (
                    now + REPEAT_INTERVAL
                )

        screen.fill(
            (12, 12, 12)
        )

        centered_text(
            "Gestion des Saves",
            sy(30),
            font_title
        )

        centered_text(
            f"{len(backups)} / {MAX_BACKUPS} sauvegardes",
            sy(85),
            font
        )

        y = sy(150)

        for i, backup in enumerate(backups):

            marker = (
                "> "
                if i == cursor
                else "  "
            )

            prefix = (
                "[X] "
                if i in selected
                else "[ ] "
            )

            try:

                dt = datetime.datetime.fromtimestamp(
                    os.path.getmtime(
                        backup["path"]
                    )
                )

                date_text = dt.strftime(
                    "%d/%m/%Y %H:%M"
                )

            except Exception:

                date_text = "Date inconnue"

            latest = (
                " [DERNIÈRE]"
                if i == 0
                else ""
            )

            line = (
                marker
                + prefix
                + date_text
                + "   "
                + str(
                    backup["games"]
                )
                + " jeu(x)"
                + latest
            )

            if i == cursor:

                surface = font.render(
                    line,
                    True,
                    (255, 220, 80)
                )

                screen.blit(
                    surface,
                    (sx(50), y)
                )

            else:

                text(
                    line,
                    sx(50),
                    y
                )

            y += ROW_HEIGHT

        draw_command(
            sx(50),
            COMMAND_Y2 - fs(2),
            "A",
            "Supprimer"
        )

        draw_command(
            sx(250),
            COMMAND_Y2 - fs(2),
            "B",
            "Retour"
        )

        text(
            "↑↓ Naviguer",
            sx(430),
            COMMAND_Y2,
            font_small
        )

        pygame.display.flip()

        clock.tick(60)


# ============================================================
# RESTAURATION
# ============================================================

def restore_last_cleanup():

    backup_dir = get_latest_backup()

    if not backup_dir:
        return 0, 0

    backup_file = os.path.join(
        backup_dir,
        "backup.json"
    )

    if not os.path.exists(
        backup_file
    ):
        return 0, 0

    try:

        with open(
            backup_file,
            "r",
            encoding="utf-8"
        ) as f:

            backup = json.load(f)

    except Exception as e:

        print(
            "Erreur lecture backup:",
            e
        )

        return 0, 0

    if backup.get("version") != 3:
        return 0, 0

    restored = 0
    skipped = 0

    xml_cache = {}

    # Même principe que load_games() :
    # pas de parcours récursif de tout /userdata/roms.
    xml_files = get_gamelist_files()

    for item in backup.get(
        "games",
        []
    ):

        target_path = item.get(
            "path",
            ""
        )

        found = False

        for xml_file in xml_files:

            if os.path.abspath(
                xml_file
            ).startswith(
                os.path.abspath(
                    os.path.join(
                        ROM_DIR,
                        "ports"
                    )
                ) + os.sep
            ):
                continue

            if xml_file not in xml_cache:

                try:

                    tree = ET.parse(
                        xml_file
                    )

                    xml_cache[xml_file] = (
                        tree,
                        tree.getroot()
                    )

                except Exception:

                    continue

            tree, root = xml_cache[
                xml_file
            ]

            for game in root.findall(
                "game"
            ):

                current_path = get_game_path(
                    game
                )

                if current_path != target_path:
                    continue

                found = True

                current_playcount = get_text(
                    game,
                    "playcount",
                    "0"
                )

                current_lastplayed = get_text(
                    game,
                    "lastplayed",
                    ""
                )

                if (
                    current_playcount != "0"
                    or current_lastplayed != ""
                ):

                    skipped += 1

                    break

                playcount_element = game.find(
                    "playcount"
                )

                if playcount_element is None:

                    playcount_element = (
                        ET.SubElement(
                            game,
                            "playcount"
                        )
                    )

                playcount_element.text = str(
                    item.get(
                        "playcount",
                        0
                    )
                )

                old_lastplayed = item.get(
                    "lastplayed",
                    ""
                )

                if old_lastplayed:

                    lastplayed_element = (
                        game.find(
                            "lastplayed"
                        )
                    )

                    if lastplayed_element is None:

                        lastplayed_element = (
                            ET.SubElement(
                                game,
                                "lastplayed"
                            )
                        )

                    lastplayed_element.text = (
                        old_lastplayed
                    )

                tree.write(
                    xml_file,
                    encoding="UTF-8",
                    xml_declaration=True
                )

                restored += 1

                break

            if found:
                break

        if not found:
            skipped += 1

    return restored, skipped


# ============================================================
# NETTOYAGE
# ============================================================

def cleanup_games(
    selected_games
):

    if not selected_games:
        return False

    backup_dir = create_backup(
        selected_games
    )

    print(
        "Backup créé :",
        backup_dir
    )

    cleanup_old_backups()

    for game_info in selected_games:

        xml_file = game_info[
            "xml_file"
        ]

        try:

            tree = ET.parse(
                xml_file
            )

            root = tree.getroot()

        except Exception as e:

            print(
                "Erreur XML :",
                xml_file,
                e
            )

            continue

        target_path = game_info[
            "path"
        ]

        for game in root.findall(
            "game"
        ):

            path = get_game_path(
                game
            )

            if path != target_path:
                continue

            playcount_element = (
                game.find(
                    "playcount"
                )
            )

            if playcount_element is None:

                playcount_element = (
                    ET.SubElement(
                        game,
                        "playcount"
                    )
                )

            playcount_element.text = "0"

            lastplayed_element = (
                game.find(
                    "lastplayed"
                )
            )

            if lastplayed_element is not None:

                game.remove(
                    lastplayed_element
                )

            break

        try:

            tree.write(
                xml_file,
                encoding="UTF-8",
                xml_declaration=True
            )

        except Exception as e:

            print(
                "Erreur écriture:",
                xml_file,
                e
            )

    return True


# ============================================================
# REDEMARRAGE EMULATIONSTATION
# ============================================================

def restart_emulationstation():

    try:

        subprocess.Popen([
            "batocera-es-swissknife",
            "--restart"
        ])

    except Exception as e:

        print(
            "Erreur redémarrage ES:",
            e
        )


# ============================================================
# CONFIRMATION
# ============================================================

def confirmation_screen(
    title,
    message,
    yes_text="Oui",
    no_text="Non"
):

    while True:

        screen.fill(
            (15, 15, 15)
        )

        centered_text(
            title,
            sy(130),
            font_title
        )

        centered_text(
            message,
            sy(250),
            font
        )

        size = fs(38)

        yes_surface = font.render(
            str(yes_text),
            True,
            (255, 255, 255)
        )

        no_surface = font.render(
            str(no_text),
            True,
            (255, 255, 255)
        )

        gap = fs(10)

        total_w = (
            size
            + gap
            + yes_surface.get_width()
        )

        x = (
            WIDTH
            - total_w
        ) // 2

        draw_button_icon(
            "A",
            x,
            sy(345),
            size
        )

        screen.blit(
            yes_surface,
            (
                x + size + gap,
                sy(353)
            )
        )

        total_w = (
            size
            + gap
            + no_surface.get_width()
        )

        x = (
            WIDTH
            - total_w
        ) // 2

        draw_button_icon(
            "B",
            x,
            sy(395),
            size
        )

        screen.blit(
            no_surface,
            (
                x + size + gap,
                sy(403)
            )
        )

        pygame.display.flip()

        for event in pygame.event.get():

            if event.type == pygame.KEYDOWN:

                if event.key in (
                    pygame.K_RETURN,
                    pygame.K_y
                ):
                    return True

                if event.key in (
                    pygame.K_ESCAPE,
                    pygame.K_n
                ):
                    return False

            elif event.type == pygame.JOYBUTTONDOWN:

                if not event_from_selected_controller(event):
                    continue

                if mapping_matches_button(
                    BUTTONS["A"],
                    event.button
                ):
                    return True

                if mapping_matches_button(
                    BUTTONS["B"],
                    event.button
                ):
                    return False

        pygame.time.wait(10)


# ============================================================
# RECHERCHE
# ============================================================

def search_games(games):

    query = ""

    pygame.key.start_text_input()

    while True:

        screen.fill(
            (15, 15, 15)
        )

        centered_text(
            "Recherche",
            sy(100),
            font_title
        )

        text(
            query + "_ ",
            sx(80),
            sy(220),
            font_big
        )

        centered_text(
            "Entrée = valider",
            sy(320),
            font_small
        )

        size = fs(30)

        b_surface = font_small.render(
            "Annuler",
            True,
            (255, 255, 255)
        )

        total_w = (
            size
            + fs(10)
            + b_surface.get_width()
        )

        x = (
            WIDTH
            - total_w
        ) // 2

        draw_button_icon(
            "B",
            x,
            sy(350),
            size
        )

        screen.blit(
            b_surface,
            (
                x + size + fs(10),
                sy(355)
            )
        )

        pygame.display.flip()

        for event in pygame.event.get():

            if event.type == pygame.TEXTINPUT:

                query += event.text

            elif event.type == pygame.KEYDOWN:

                if event.key == pygame.K_BACKSPACE:

                    query = query[:-1]

                elif event.key == pygame.K_RETURN:

                    pygame.key.stop_text_input()

                    q = query.lower().strip()

                    if not q:
                        return games, ""

                    filtered = [
                        g
                        for g in games
                        if (
                            q in g["name"].lower()
                            or q in g["system"].lower()
                        )
                    ]

                    return filtered, query

                elif event.key == pygame.K_ESCAPE:

                    pygame.key.stop_text_input()

                    return games, ""

            elif event.type == pygame.JOYBUTTONDOWN:

                if not event_from_selected_controller(event):
                    continue

                if mapping_matches_button(
                    BUTTONS["B"],
                    event.button
                ):

                    pygame.key.stop_text_input()

                    return games, ""

        pygame.time.wait(10)


# ============================================================
# AFFICHAGE MENU PRINCIPAL
# ============================================================

def draw_menu(
    games,
    selected,
    cursor,
    total_recent_games,
    search_text=""
):

    screen.fill(
        (12, 12, 12)
    )

    centered_text(
        "Nettoyer les jeux récents",
        sy(20),
        font_title
    )

    centered_text(
        f"{total_recent_games} jeux récents",
        sy(75),
        font
    )

    backup_count, backup_date = (
        get_backup_info()
    )

    backup_text = (
        f"Sauvegardes : "
        f"{backup_count}/{MAX_BACKUPS}"
        f"   Dernière : "
        f"{backup_date}"
    )

    surface = font_small.render(
        backup_text,
        True,
        (180, 220, 180)
    )

    screen.blit(
        surface,
        (
            WIDTH
            - surface.get_width()
            - sx(30),
            sy(105)
        )
    )

    if search_text:

        centered_text(
            "Recherche : "
            + search_text,
            sy(132),
            font_small
        )

    count = len(games)

    if count == 0:

        centered_text(
            "Aucun jeu récent",
            sy(280),
            font_big
        )

    if count <= VISIBLE:

        start = 0

    else:

        start = min(
            max(
                0,
                cursor - VISIBLE // 2
            ),
            count - VISIBLE
        )

    end = min(
        count,
        start + VISIBLE
    )

    y = LIST_TOP

    playcount_x = int(
        WIDTH * 0.57
    )

    date_x = int(
        WIDTH * 0.735
    )

    for i in range(
        start,
        end
    ):

        game = games[i]

        prefix = (
            "[X] "
            if i in selected
            else "[ ] "
        )

        marker = (
            "> "
            if i == cursor
            else "  "
        )

        name = game["name"]

        max_name_chars = max(
            25,
            int(
                48
                * SCALE_X
                / max(
                    1.0,
                    FONT_SCALE
                )
            )
        )

        if len(name) > max_name_chars:

            name = (
                name[
                    :max_name_chars - 3
                ]
                + "..."
            )

        line = (
            marker
            + prefix
            + name
        )

        if i == cursor:

            surface = font.render(
                line,
                True,
                (255, 220, 80)
            )

            screen.blit(
                surface,
                (
                    sx(50),
                    y
                )
            )

        else:

            text(
                line,
                sx(50),
                y
            )

        text(
            "Joué : "
            + str(
                game["playcount"]
            )
            + " fois",
            playcount_x,
            y,
            font_small
        )

        text(
            format_date(
                game["lastplayed"]
            ),
            date_x,
            y,
            font_small
        )

        y += ROW_HEIGHT

    if (
        games
        and 0 <= cursor < len(games)
    ):

        game = games[cursor]

        info_path = game["path"]

        max_path_chars = max(
            40,
            int(
                80
                * SCALE_X
                / max(
                    1.0,
                    FONT_SCALE
                )
            )
        )

        if len(info_path) > max_path_chars:

            info_path = (
                "..."
                + info_path[
                    -(max_path_chars - 3):
                ]
            )

        # ----------------------------------------------------
        # Informations système / chemin
        #
        # Le début du chemin est calculé d'après la largeur réelle
        # du nom du système afin d'éviter les chevauchements avec
        # des noms longs comme "windowsretro".
        # ----------------------------------------------------

        system_text = (
            "Système : "
            + game["system"]
        )

        system_surface = font_small.render(
            system_text,
            True,
            (255, 255, 255)
        )

        system_x = sx(50)

        screen.blit(
            system_surface,
            (
                system_x,
                INFO_Y
            )
        )

        path_x = max(
            sx(250),
            system_x
            + system_surface.get_width()
            + sx(25)
        )

        path_prefix = "Chemin : "

        available_width = max(
            sx(120),
            WIDTH
            - path_x
            - sx(30)
        )

        displayed_path = info_path

        # Réduit le chemin depuis la gauche jusqu'à ce qu'il tienne
        # réellement dans l'espace disponible.
        while displayed_path:

            candidate = (
                path_prefix
                + displayed_path
            )

            if (
                font_small.size(
                    candidate
                )[0]
                <= available_width
            ):
                break

            if displayed_path.startswith(
                "..."
            ):

                displayed_path = (
                    "..."
                    + displayed_path[4:]
                )

            else:

                displayed_path = (
                    "..."
                    + displayed_path[1:]
                )

        text(
            path_prefix
            + displayed_path,
            path_x,
            INFO_Y,
            font_small
        )

    else:

        text(
            f"{len(selected)} / "
            f"{total_recent_games} sélectionnés",
            sx(50),
            INFO_Y,
            font
        )

    draw_command(
        sx(50),
        COMMAND_Y1 - fs(2),
        "A",
        "Sélection"
    )

    draw_command(
        sx(300),
        COMMAND_Y1 - fs(2),
        "X",
        "Tout"
    )

    draw_command(
        sx(500),
        COMMAND_Y1 - fs(2),
        "Y",
        "Aucun"
    )

    draw_command(
        sx(700),
        COMMAND_Y1 - fs(2),
        "SELECT",
        "Recherche",
        system=True
    )

    if search_text:

        draw_command(
            sx(50),
            COMMAND_Y2 - fs(2),
            "B",
            "Retour"
        )

    else:

        draw_command(
            sx(50),
            COMMAND_Y2 - fs(2),
            "B",
            "Quitter"
        )

    draw_command(
        sx(250),
        COMMAND_Y2 - fs(2),
        "START",
        "Nettoyer",
        system=True
    )

    draw_combo_command(
        sx(470),
        COMMAND_Y2 - fs(2),
        "SELECT",
        "START",
        "Restaurer"
    )

    draw_combo_command(
        sx(800),
        COMMAND_Y2 - fs(2),
        "SELECT",
        "X",
        "Gestion des Saves"
    )

    pygame.display.flip()


# ============================================================
# PROGRAMME PRINCIPAL
# ============================================================

def main():

    if not setup_controller():
        return

    all_games = load_games()

    games = all_games[:]

    total_recent_games = len(
        all_games
    )

    selected = set()

    cursor = 0

    current_search = ""

    clock = pygame.time.Clock()

    select_pending = False
    start_pending = False

    select_time = 0
    start_time = 0

    held_direction = None
    next_repeat_time = 0

    running = True

    while running:

        now = time.monotonic()

        do_search = False
        do_cleanup = False
        do_restore = False
        do_backup_management = False

        events = pygame.event.get()

        for event in events:

            # =================================================
            # CLAVIER
            # =================================================

            if event.type == pygame.KEYDOWN:

                if event.key == pygame.K_ESCAPE:

                    running = False

                elif event.key == pygame.K_UP:

                    if games:

                        cursor = max(
                            0,
                            cursor - 1
                        )

                elif event.key == pygame.K_DOWN:

                    if games:

                        cursor = min(
                            len(games) - 1,
                            cursor + 1
                        )

                elif event.key == pygame.K_a:

                    if games:

                        if cursor in selected:

                            selected.remove(
                                cursor
                            )

                        else:

                            selected.add(
                                cursor
                            )

                elif event.key == pygame.K_x:

                    selected = set(
                        range(
                            len(games)
                        )
                    )

                elif event.key == pygame.K_y:

                    # =========================================
                    # Y SEUL = AUCUN
                    #
                    # SELECT + X avec Pad2Key :
                    # Select = KEY_S
                    # X      = KEY_Y
                    # =========================================

                    if select_pending:

                        select_pending = False
                        start_pending = False

                        do_backup_management = True

                    else:

                        selected.clear()

                elif event.key == pygame.K_r:

                    do_restore = True

                elif event.key == pygame.K_RETURN:

                    # =========================================
                    # START SEUL = NETTOYER
                    #
                    # SELECT + START :
                    # KEY_S puis KEY_ENTER
                    # =========================================

                    if select_pending:

                        select_pending = False
                        start_pending = False

                        do_restore = True

                    else:

                        do_cleanup = True

                elif event.key == pygame.K_s:

                    # =========================================
                    # SELECT AVEC PAD2KEY
                    #
                    # On ne lance plus immédiatement
                    # la recherche.
                    #
                    # On attend COMBO_DELAY afin de laisser
                    # le temps à X ou START d'arriver.
                    # =========================================

                    if start_pending:

                        start_pending = False
                        select_pending = False

                        do_restore = True

                    else:

                        select_pending = True
                        select_time = now

                elif event.key == pygame.K_g:

                    do_backup_management = True

            # =================================================
            # MANETTE
            # =================================================

            elif event.type == pygame.JOYBUTTONDOWN:

                if not event_from_selected_controller(event):
                    continue

                button = event.button

                if mapping_matches_button(
                    BUTTONS["UP"],
                    button
                ):

                    if games:

                        cursor = max(
                            0,
                            cursor - 1
                        )

                        held_direction = "up"

                        next_repeat_time = (
                            now + REPEAT_DELAY
                        )

                elif mapping_matches_button(
                    BUTTONS["DOWN"],
                    button
                ):

                    if games:

                        cursor = min(
                            len(games) - 1,
                            cursor + 1
                        )

                        held_direction = "down"

                        next_repeat_time = (
                            now + REPEAT_DELAY
                        )

                elif mapping_matches_button(
                    BUTTONS["SELECT"],
                    button
                ):

                    if start_pending:

                        start_pending = False
                        select_pending = False

                        do_restore = True

                    else:

                        select_pending = True
                        select_time = now

                elif mapping_matches_button(
                    BUTTONS["START"],
                    button
                ):

                    if select_pending:

                        select_pending = False
                        start_pending = False

                        do_restore = True

                    else:

                        start_pending = True
                        start_time = now

                elif mapping_matches_button(
                    BUTTONS["X"],
                    button
                ):

                    if select_pending:

                        select_pending = False
                        start_pending = False

                        do_backup_management = True

                    else:

                        selected = set(
                            range(
                                len(games)
                            )
                        )

                elif mapping_matches_button(
                    BUTTONS["A"],
                    button
                ):

                    if games:

                        if cursor in selected:

                            selected.remove(
                                cursor
                            )

                        else:

                            selected.add(
                                cursor
                            )

                elif mapping_matches_button(
                    BUTTONS["B"],
                    button
                ):

                    if current_search:

                        games = all_games[:]

                        current_search = ""

                        cursor = 0

                        selected.clear()

                    else:

                        running = False

                elif mapping_matches_button(
                    BUTTONS["Y"],
                    button
                ):

                    selected.clear()

            # =================================================
            # CROIX DIRECTIONNELLE
            # =================================================

            elif event.type == pygame.JOYHATMOTION:

                if not event_from_selected_controller(event):
                    continue

                if event.value == (0, 0):

                    held_direction = None

                    continue

                if mapping_matches_hat(
                    BUTTONS["UP"],
                    event.hat,
                    event.value
                ):

                    if games:

                        cursor = max(
                            0,
                            cursor - 1
                        )

                        held_direction = "up"

                        next_repeat_time = (
                            now + REPEAT_DELAY
                        )

                elif mapping_matches_hat(
                    BUTTONS["DOWN"],
                    event.hat,
                    event.value
                ):

                    if games:

                        cursor = min(
                            len(games) - 1,
                            cursor + 1
                        )

                        held_direction = "down"

                        next_repeat_time = (
                            now + REPEAT_DELAY
                        )

            # =================================================
            # AXES
            # =================================================

            elif event.type == pygame.JOYAXISMOTION:

                if not event_from_selected_controller(event):
                    continue

                value = event.value

                if abs(value) < 0.30:

                    mapping_up = BUTTONS.get(
                        "UP"
                    )

                    mapping_down = BUTTONS.get(
                        "DOWN"
                    )

                    if (
                        mapping_up
                        and mapping_up.get(
                            "type"
                        ) == "axis"
                        and mapping_up.get(
                            "axis"
                        ) == event.axis
                    ):

                        held_direction = None

                    if (
                        mapping_down
                        and mapping_down.get(
                            "type"
                        ) == "axis"
                        and mapping_down.get(
                            "axis"
                        ) == event.axis
                    ):

                        held_direction = None

                    continue

                if mapping_matches_axis(
                    BUTTONS["UP"],
                    event.axis,
                    value
                ):

                    if games:

                        cursor = max(
                            0,
                            cursor - 1
                        )

                        held_direction = "up"

                        next_repeat_time = (
                            now + REPEAT_DELAY
                        )

                elif mapping_matches_axis(
                    BUTTONS["DOWN"],
                    event.axis,
                    value
                ):

                    if games:

                        cursor = min(
                            len(games) - 1,
                            cursor + 1
                        )

                        held_direction = "down"

                        next_repeat_time = (
                            now + REPEAT_DELAY
                        )

            # =================================================
            # RELACHEMENT
            # =================================================

            elif event.type == pygame.JOYBUTTONUP:

                if not event_from_selected_controller(event):
                    continue

                button = event.button

                if mapping_matches_button(
                    BUTTONS["UP"],
                    button
                ):

                    if held_direction == "up":
                        held_direction = None

                elif mapping_matches_button(
                    BUTTONS["DOWN"],
                    button
                ):

                    if held_direction == "down":
                        held_direction = None

        # =====================================================
        # COMBINAISONS SELECT / START
        # =====================================================

        if not (
            do_restore
            or do_backup_management
        ):

            if (
                select_pending
                and now - select_time
                >= COMBO_DELAY
            ):

                select_pending = False

                do_search = True

            if (
                start_pending
                and now - start_time
                >= COMBO_DELAY
            ):

                start_pending = False

                do_cleanup = True

        # =====================================================
        # REPETITION DIRECTIONNELLE
        # =====================================================

        if (
            held_direction is not None
            and games
            and now >= next_repeat_time
        ):

            if held_direction == "up":

                if cursor > 0:

                    cursor -= 1

                else:

                    held_direction = None

            elif held_direction == "down":

                if cursor < len(games) - 1:

                    cursor += 1

                else:

                    held_direction = None

            if held_direction is not None:

                next_repeat_time = (
                    now + REPEAT_INTERVAL
                )

        # =====================================================
        # GESTION DES SAVES
        # =====================================================

        if do_backup_management:

            select_pending = False
            start_pending = False
            held_direction = None

            backup_management()

            all_games = load_games()

            games = all_games[:]

            total_recent_games = len(
                all_games
            )

            if games:

                cursor = min(
                    cursor,
                    len(games) - 1
                )

            else:

                cursor = 0

            selected.clear()

        # =====================================================
        # RESTAURATION
        # =====================================================

        if do_restore:

            select_pending = False
            start_pending = False
            held_direction = None

            confirmed = confirmation_screen(
                "Restaurer le dernier nettoyage ?",
                "Seuls les jeux du dernier nettoyage seront restaurés."
            )

            if confirmed:

                restored, skipped = (
                    restore_last_cleanup()
                )

                screen.fill(
                    (15, 15, 15)
                )

                centered_text(
                    "Restauration terminée",
                    sy(200),
                    font_title
                )

                centered_text(
                    f"{restored} jeu(x) restauré(s)",
                    sy(290),
                    font
                )

                centered_text(
                    f"{skipped} jeu(x) ignoré(s)",
                    sy(340),
                    font
                )

                centered_text(
                    "Redémarrage d'EmulationStation...",
                    sy(430),
                    font_small
                )

                pygame.display.flip()

                pygame.time.wait(1800)

                restart_emulationstation()

                return

        # =====================================================
        # RECHERCHE
        # =====================================================

        if do_search:

            select_pending = False
            start_pending = False
            held_direction = None

            games, current_search = (
                search_games(
                    all_games
                )
            )

            cursor = 0

            selected.clear()

        # =====================================================
        # NETTOYAGE
        # =====================================================

        if do_cleanup:

            select_pending = False
            start_pending = False
            held_direction = None

            if not selected:

                screen.fill(
                    (15, 15, 15)
                )

                centered_text(
                    "Aucun jeu sélectionné",
                    sy(280),
                    font_big
                )

                pygame.display.flip()

                pygame.time.wait(1200)

            else:

                number = len(selected)

                confirmed = confirmation_screen(
                    "Confirmer le nettoyage ?",
                    f"{number} jeu(x) seront retiré(s) des récents."
                )

                if confirmed:

                    selected_games = [
                        games[i]
                        for i in selected
                        if i < len(games)
                    ]

                    cleanup_games(
                        selected_games
                    )

                    screen.fill(
                        (15, 15, 15)
                    )

                    centered_text(
                        "Nettoyage terminé",
                        sy(200),
                        font_title
                    )

                    centered_text(
                        f"{number} jeu(x) nettoyé(s)",
                        sy(290),
                        font
                    )

                    centered_text(
                        "Les ROMs n'ont pas été supprimées.",
                        sy(350),
                        font_small
                    )

                    centered_text(
                        "Redémarrage d'EmulationStation...",
                        sy(430),
                        font_small
                    )

                    pygame.display.flip()

                    pygame.time.wait(1800)

                    restart_emulationstation()

                    return

        # =====================================================
        # AFFICHAGE
        # =====================================================

        draw_menu(
            games,
            selected,
            cursor,
            total_recent_games,
            current_search
        )

        clock.tick(60)

    pygame.quit()


# ============================================================
# LANCEMENT
# ============================================================

if __name__ == "__main__":

    try:

        main()

    except KeyboardInterrupt:

        pygame.quit()

    except Exception as e:

        pygame.quit()

        print("")
        print("ERREUR :")
        print(e)
        print("")

        raise
