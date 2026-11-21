THE HOUSE OF THE DEAD 2 - RECOMP for Linux x86_64 and SteamOS  (Made by Pocket_lucho with Claude)
=================================================================================================

If you want to support me: https://buymeacoffee.com/pocket_lucho

REQUIREMENTS: nothing to install. Works on SteamOS (Steam Deck, Legion Go S...), Ubuntu,
Fedora, Arch, etc. If the system has no C++ compiler, build_game.sh downloads a portable
one (Zig, ~45 MB) the first time, inside this folder. No sudo needed.
An internet connection is only needed the first time if you do not have g++.

SETUP
1. Copy your hotd2.zip romset to the "roms" folder. The game has its own BIOS
   (epr-21329/21330/21331.ic27, NOT naomi.zip): if your hotd2.zip does not include those
   files, copy hod2bios.zip to "roms" too (only needed the first time).
2. Open a terminal in this folder and run ONCE:   ./build_game.sh
   It generates the game code from YOUR ROM and compiles it into libhotd2_game.so.
3. To play run:   ./HouseOfTheDead2.sh
   (if it fails, the reason is shown in a window and saved to hotd2.log)

CONTROLS
  Mouse = player 1 light gun: left button fire, right button reload, middle / Enter START.
  Gamepad: left stick aims, A or R2 fire, B or L2 reload, Start = START, Back = menu.
  Tab: menu (Resume, Reset, Settings, Cheats, Exit).

STEAMOS (Steam Deck / Legion Go S)
1. Switch to Desktop Mode (Steam button > Power > Switch to Desktop).
2. Extract the .tar.gz (for example to ~/Games/HouseOfTheDead2-Recomp) and copy the ROM.
3. In the file manager (Dolphin), inside the folder: right click > "Open Terminal Here"
   and type:
       chmod +x build_game.sh HouseOfTheDead2.sh HouseOfTheDead2-Recompiled
       ./build_game.sh
4. Test the game with ./HouseOfTheDead2.sh
5. To play in Game Mode: open Steam on the desktop > "Add a Game" > "Add a Non-Steam Game"
   > Browse > pick HouseOfTheDead2.sh (set the filter to "All Files"). Go back to Game Mode
   and it will be in your library.
6. Aiming: the left stick works directly. For more precise aiming, in the game's controller
   settings in Steam set the right trackpad (or the gyro) to "As Mouse"; R2 and L2 keep
   firing and reloading.

This package contains nothing from the game. libhotd2_game.so and data/hotd2_boot_*.state are
generated from your files: do not share them. GPL v2 license (based on Flycast).
Source code: https://github.com/PocketLucho/House-of-the-Dead-2---recomp
