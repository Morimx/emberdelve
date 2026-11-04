# Emberdelve

A pixel-art dungeon roguelite for the browser. Lead a Warrior, a Cleric and an Assassin
through torch-lit dungeons. Combat plays out on its own, so the game is about the choices:
which door to open, which reward to take, when to rest and when to retreat before the
torch burns out.

Built with Godot 4 (typed GDScript) and exported to HTML5 for web portals such as
CrazyGames and itch.io.

## Features

- **Expeditions of 9 rooms**: combat, elites, events, camps and a boss at the end.
- **Torch as a resource**: every room costs light. Run out and the party gets lost.
- **Keep what you bring back**: retreat or win to keep your loot; fall or get lost in the dark and you keep half.
- **Three dungeons**: Catacombs, Flooded Crypt and Sunken Forge, each with its own enemies, boss and look.
- **Permanent progression**: a talent constellation, skill upgrades per hero and class gear
  (weapon, armor and charm for each hero).
- **Score and high scores**: points for rooms, beating the boss and speed, with a local top 10.
- **English and Spanish**, synthesized sound with no audio files, and cloud saves on CrazyGames.

## Controls

| Key | Action |
|---|---|
| Mouse / `1`-`9` | Pick a card |
| `S` | Change combat speed |
| `M` | Mute |
| `-` / `+` | Volume |
| `B` | Back (talents, armory) |

## Running the project

Open the folder with Godot 4.7 and press Play. The main scene is `scenes/main.tscn`.

From the command line (replace `godot` with the path to your Godot binary):

```bash
# Import assets after adding new classes
godot --headless --path . --import

# Logic tests (exit code 1 if any check fails)
godot --headless --path . --script res://tests/run_tests.gd

# Balance simulation: win rates per dungeon and progress level
godot --headless --path . --script res://tests/balance_sim.gd

# Web export (needs the 4.7 web export templates)
godot --headless --path . --export-release "Web" build/web/index.html
```

The web build is single-threaded, so it runs without COOP/COEP headers. To try it locally,
serve `build/web/` with any static file server and open `index.html`.

## Project layout

| Path | Contents |
|---|---|
| `scripts/core/` | Game logic: expeditions, combat, loot, score, saves and translations |
| `scripts/data/` | Resource classes for heroes, enemies, dungeons, items, boons and talents |
| `data/` | `.tres` data for heroes, enemies, dungeons, boons and talents |
| `scripts/ui/` | Screens, cards, unit views, backdrops and procedurally drawn sprites |
| `scripts/audio/` | Synthesized music and sound effects |
| `scripts/platform/` | CrazyGames SDK bridge (does nothing outside the web) |
| `scenes/` | Main scene and reusable components |
| `tests/` | Headless tests, balance simulation and UI capture |
| `tools/` | Cover, preview video and backdrop preview generators |

## Saves

Player data is stored in the `Torchbound` user folder (the game's former name, kept so
existing saves are not lost). On CrazyGames the save is also synced to the cloud and the
newest copy wins on startup.

## Credits

All rights reserved: see [LICENSE](LICENSE). Fonts and a few decoration sprites (banners, columns,
fountains, chest and spikes from 0x72's CC0 16x16 DungeonTileset II) are third-party and
listed in [LICENSES.md](LICENSES.md). Characters, icons and backdrops are drawn in code
by the project itself.
