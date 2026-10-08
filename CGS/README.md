# CGS multi-sources

Installateurs CGS personnels pour Batocera.

## Fichiers à placer dans ce dossier

- `CGS_MiniPC.zip`
- `CGS_SteamDeck.zip`

## Mini PC / Batocera 42

```bash
wget -qO- https://raw.githubusercontent.com/blondin-svg/blondin.rep/main/CGS/install-minipc.sh | bash
```

## Steam Deck OLED / Batocera 43.1

```bash
wget -qO- https://raw.githubusercontent.com/blondin-svg/blondin.rep/main/CGS/install-steamdeck.sh | bash
```

Les lanceurs téléchargent le ZIP correspondant dans `/tmp`, exécutent l'installation puis suppriment les fichiers temporaires. Il n'est donc plus nécessaire de conserver l'installateur dans `/userdata/saves/Installscripts`.

Le dépôt est public : `auth.json` n'est volontairement jamais publié. Le compte CGS déjà présent sur la machine est conservé ; après une installation neuve, la connexion se fait normalement dans CGS.
