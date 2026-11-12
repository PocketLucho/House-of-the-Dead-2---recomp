THE HOUSE OF THE DEAD 2 - RECOMP  (Made by Pocket_lucho with Claude)
====================================================================

Static recompilation of The House of the Dead 2 (Sega NAOMI, 1998).
If you want to support me: https://buymeacoffee.com/pocket_lucho

SETUP
1. Copy your hotd2.zip romset to the "roms" folder. The game has its own BIOS
   (epr-21329/21330/21331.ic27, NOT naomi.zip): if your hotd2.zip does not include
   those files, copy hod2bios.zip to "roms" too. It is only needed the first time.
2. Run BUILD_GAME.bat ONCE. It downloads the free llvm-mingw compiler (180 MB, first time
   only), generates the game code from YOUR ROM and compiles it into hotd2_game.dll
   (3 to 15 minutes).
3. Run HouseOfTheDead2-Recompiled.exe.

This package contains nothing from the game: no ROM, BIOS, graphics, sound or code.
hotd2_game.dll and data\hotd2_boot_*.state are generated from your files: do not share them.

CONTROLS (player 1 = mouse as light gun)
  Mouse                  aim (red crosshair)
  Left button            fire
  Right button           reload
  Middle button / Enter  START
  Q                      insert coin (only if Free Play is disabled)
  Tab                    menu: Resume, Reset, Settings, Cheats, Exit
  Alt+Enter              full screen
Player 2 (gamepad or second mouse) and the crosshairs: Settings -> Controls.

OPTIONS (Tab key)
- General: Region (Japan, USA, Export), Blood Color (red / green), Free Play (on by default).
- Video: "Widescreen 16:9" (real 16:9 camera, 4:3 HUD, the gun aims over the whole picture),
  "Antialiasing (FXAA)", Internal Resolution (supersampling), Native Depth Interpolation.
- Cheats: infinite life (player 1 / player 2), infinite ammo (no reload).
- The game's own test menu (difficulty, lives, gun calibration) is reached with the Test
  button (see Settings -> Controls).

TROUBLESHOOTING
- "Game code module not found": run BUILD_GAME.bat.
- After updating the .exe to a new version: run BUILD_GAME.bat again.
- Boot problems: delete data\hotd2_boot_*.state (recreated with the BIOS files).

GPL v2 license (based on Flycast). Source code:
https://github.com/PocketLucho/House-of-the-Dead-2---recomp
