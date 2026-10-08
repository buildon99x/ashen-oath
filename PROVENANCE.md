# Provenance and scope

Research checked 2026-10-07:
- Topebox's official Steam store page, app 3755930, identifies The Severed Gods and describes height-based three-part combat, break/sever mechanics, reincarnation, karma, hero-specific interactions and relic builds. https://store.steampowered.com/app/3755930/The_Severed_Gods/
- Developer's itch.io page corroborates the core feature descriptions. Some content counts differ from the current Steam page, so none were treated as an exact implementation specification. https://topeboxgames.itch.io/the-severed-gods
- Later, official Steam appdetails screenshot URLs were retrieved successfully and screenshots 1–2 were visually inspected. Reference images remain in a separate research folder and are not bundled as game assets. No trailer watch-through or visual-equivalence claim is made.

All delivered gameplay code, character and location names, writing, procedural landscape/colossus/hero artwork, generated audio waveforms and UI are original to this project. No source-game download, asset extraction, purchase or account creation was performed.

The implementation reproduces a small set of general gameplay ideas in an original self-contained campaign. It does not reproduce the commercial game's assets, content inventory, story, exact formulas, controls or complete feature set. Heights are selectable body zones here; there is no animation-timing or physical height-reach simulation. NPC encounters provide choices with karma consequences; negative karma increases enemy starting shields. Evolving villages and persistent NPC storylines are not implemented. Audio is synthesized feedback, not a soundtrack. Gamepad support is not implemented. Full journey save/resume was added and tested in both model checks and actual native UI restart.

Godot 4.6.3 was already installed in the execution environment. Official export templates were downloaded by range requests, checked against archive CRC, and used to produce separate Windows/Linux distributables. Godot license notices accompany them. The source ZIP does not bundle the engine. Windows runtime testing remains pending.

## Checkpoint 2 art
Every environment, titan layer and hero sprite in assets/ was newly drawn by tools/generate_art.py using authored shapes and deterministic texture. The script does not read or transform any third-party image. Original Steam screenshots were comparison references only. The artwork remains visibly simpler than the commercial reference.

## Checkpoint 4: independently authored directional art and UI
The supplied character sheet was viewed as a visual reference only; it is not included in this public repository. `tools/generate_directional_heroes.py` draws every pixel of the three original 4-facing, 5-state heroes without opening any reference image or flipping an opposite-facing frame. `tools/generate_environments.py` creates three original layered scenes, and `tools/generate_ui.py` creates panel borders and combat icons. Their manifests document dimensions, palette, frames and timing.

Craftpix's public four-direction female-base page was reviewed for animation structure only: https://craftpix.net/freebies/free-base-4-direction-female-character-pixel-art/ . Its license forbids raw asset redistribution and restricts AI uses: https://craftpix.net/file-licenses/ . No Craftpix asset was downloaded, transformed or bundled.

The Apache-2.0 sprite-gen repository https://github.com/aldegad/sprite-gen was reviewed for facing-anchor, fixed-canvas and contact-sheet QA ideas. It was not installed or run; no API credentials or paid generation services were used. The generator/runtime in this game is independently written.

Pixelify Sans is the only newly bundled third-party visual asset: unmodified font from https://github.com/google/fonts/tree/main/ofl/pixelifysans , distributed under SIL Open Font License 1.1. Its complete notice is `assets/fonts/OFL.txt` and is copied into native archives as `PIXELIFY_OFL.txt`.

## Checkpoint 5: consistent interludes
`tools/generate_vignettes.py` independently draws four transparent 256×192 illustrations (camp, relic shrine, oathless pilgrim, reward coffer) from a 128×96 logical canvas. No image inputs, external assets or generation services are used. The manifest records per-image hashes and transparent bounds. They render at 512×384 logical game units. Map/event phases now reuse the existing original biome backgrounds and pixel UI. No gameplay system or story content was added.

## Checkpoint 6: generated battle arena
The user-provided dungeon reference was visually inspected (isometric ruined corridor, indigo shadows, teal paving, orange firelight). The built-in image_gen tool produced one new 1586×992 wide courtyard with a different layout and clear combat floor. It is not a procedural substitute and not a crop of the supplied reference. The original output is retained separately; `assets/environments/firelit_arena.webp` is a same-dimension quality90 WebP encoding for game delivery. No recoloring or hand-painted reconstruction was performed. The metadata JSON records provenance, prompt summary and hashes. The supplied reference itself is excluded from this public repository. Existing authored actors/UI remain separate runtime layers. The full generator prompt is in `assets/environments/firelit_arena_prompt.txt`.
