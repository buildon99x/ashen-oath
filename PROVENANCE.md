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
