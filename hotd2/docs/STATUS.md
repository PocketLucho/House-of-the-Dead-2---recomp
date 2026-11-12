# Development notes — The House of the Dead 2 Recomp

Last update: 2026-11-12

## Working

* Engine + builder distribution (same as Virtua NBA - Recomp): the released engine has no game code; the
  builder generates ~78,500 blocks from the user's ROM and compiles them into `hotd2_game.dll` /
  `libhotd2_game.so`. Validated on Linux end to end (generation, module build, game running from the module).
* BIOS boot once per region (own BIOS, `hod2bios`), then BIOS-free boot from the snapshot.
* Played with scripted light gun input (headless libretro build): logos, attract mode, intro, chapter 1 with
  one and two players, reloads, continue / game over, chapter 1 boss, chapter 2.
* Lockstep verification against the interpreter (linked-in build): only the differences already known from
  Virtua NBA (M/Q bits of the fused division, an interrupt taken inside a block after `ldc sr`, store queue
  journal artefact).

## 2026-11-12

* **Free play** works: the cabinet EEPROM is set to coin setting #27 before the boot and the game's working
  copy is kept in step (a blank EEPROM gets the default system record first). On by default.
* **Gun aim in widescreen** fixed: the game clamped the gun to the 4:3 area (see TECHNICAL.md, gun range).
  The same table is used in 4:3 to make the shot land exactly under the crosshair up to the screen edges
  (the original mapping stops 20 pixels short of them).
* **Blood colour** is not tied to the region: it is the BLOOD COLOR game assignment (green by default with
  every BIOS). New option in Settings → General.
* **Cheats**: infinite life for each player, infinite ammo. No unlockables were found in the program.
* **Native depth interpolation** on by default (floor textures of the first building).
* Own icon (original drawing), executable version info.
* Region selector: Japan / USA / Export (the three BIOS ROMs of the set).
* Spanish UI texts for all the new options; Reset button and FXAA come from the shared engine.
* Not possible: ray tracing (the game sends already projected triangles to the PowerVR2).

## Pending

1. Test on Windows with a real GPU, a real mouse and a second player.
2. The title screen is a full-screen 2D picture: in 16:9 its sides are filled with the stretched edge column.
3. Other program revisions (`hotd2o` `epr-21385`, `hotd2e` `epr-21805`, `hotd2p`): they need their own entry
   in the header-less table and their own patch addresses; only `epr-21585` is supported.
4. Coverage of chapters 3–6 was not exercised by the scripted runs; anything the static decoder missed runs
   through the interpreter fallback (correct, slower).
