VIRTUA NBA - RECOMP for Linux x86_64  (Made by Pocket_lucho with Claude)
=======================================================================

If you want to support me: https://buymeacoffee.com/pocket_lucho

REQUIREMENTS: SDL2, libcurl, PulseAudio/ALSA (present on any desktop), and to build the
game code: g++ and make   ->   sudo apt install build-essential libsdl2-2.0-0

SETUP
1. Copy your virnba.zip romset to the "roms" folder.
2. Copy the NAOMI BIOS naomi.zip to the "data" folder (only needed the first time).
3. Run ONCE:   ./build_game.sh
   It generates the game code from YOUR ROM and compiles it into libvnba_game.so.
4. Run:   ./VirtuaNBA-Recompiled

This package contains nothing from the game. libvnba_game.so and data/vnba_boot_*.state are
generated from your files: do not share them. GPL v2 license (based on Flycast).
Source code: https://github.com/PocketLucho/Virtua-NBA---Recompilation
