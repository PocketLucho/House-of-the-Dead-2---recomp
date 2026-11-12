THE HOUSE OF THE DEAD 2 - RECOMP for Linux x86_64  (Made by Pocket_lucho with Claude)
======================================================================================

If you want to support me: https://buymeacoffee.com/pocket_lucho

REQUIREMENTS: SDL2, libcurl, PulseAudio/ALSA (present on any desktop), and to build the
game: g++ and make   ->   sudo apt install build-essential libsdl2-2.0-0

SETUP
1. Copy your hotd2.zip romset to the "roms" folder. The game has its own BIOS
   (epr-21329/21330/21331.ic27, NOT naomi.zip): if your hotd2.zip does not include those
   files, copy hod2bios.zip to "roms" too (only needed the first time).
2. Run ONCE:   ./build_game.sh
   It generates the game code from YOUR ROM and compiles it into libhotd2_game.so.
3. Run:   ./HouseOfTheDead2-Recompiled

Mouse = player 1 light gun (left: fire, right: reload, middle / Enter: START, Tab: menu).

This package contains nothing from the game. libhotd2_game.so and data/hotd2_boot_*.state are
generated from your files: do not share them. GPL v2 license (based on Flycast).
Source code: https://github.com/PocketLucho/House-of-the-Dead-2---recomp
