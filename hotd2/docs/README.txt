VIRTUA NBA - RECOMP  (Made by Pocket_lucho with Claude)
=======================================================

Static recompilation of Virtua NBA (Sega NAOMI, 2000).
If you want to support me: https://buymeacoffee.com/pocket_lucho

SETUP
1. Copy your virnba.zip romset to the "roms" folder.
2. Copy the NAOMI BIOS naomi.zip to the "data" folder (only needed the first time).
3. Run BUILD_GAME.bat ONCE. It downloads the free llvm-mingw compiler (180 MB, first time
   only), generates the game code from YOUR ROM and compiles it into vnba_game.dll
   (3 to 15 minutes).
4. Run VirtuaNBA-Recompiled.exe.

This package contains nothing from the game: no ROM, BIOS, graphics, sound or code.
vnba_game.dll and data\vnba_boot_*.state are generated from your files: do not share them.

OPTIONS (Tab key or the menu)
- Video: "Widescreen 16:9" (real 16:9 camera, 4:3 scoreboard), "Antialiasing (FXAA)",
  Internal Resolution (supersampling).
- General: Region (Japan, USA, Export, Korea). naomi.zip is needed the first time a region
  is used.
- Menu: Reset, Cheats (infinite game clock, infinite shot clock).
- Network: online play with GGPO (experimental). Both players need the same version, the
  same romset and the same widescreen setting.

TROUBLESHOOTING
- "Game code module not found": run BUILD_GAME.bat.
- After updating the .exe to a new version: run BUILD_GAME.bat again.
- Boot problems: delete data\vnba_boot_*.state (recreated with naomi.zip).

GPL v2 license (based on Flycast). Source code:
https://github.com/PocketLucho/Virtua-NBA---Recompilation
