# THE HOUSE OF THE DEAD 2 - RECOMP

A static recompilation of **The House of the Dead 2** (Sega NAOMI, 1998) for Windows and Linux.
Made by **Pocket_lucho** with Claude. [Leer en español](README.es.md)

The game's SH-4 machine code is translated ahead of time into C++ (one function per basic block)
and compiled to native code. The rest of the NAOMI hardware (PowerVR2 graphics, AICA sound,
JVS input with light guns, cartridge) is provided by a fork of [Flycast](https://github.com/flyinghead/flycast).
It uses the same engine as [Virtua NBA - Recomp](https://github.com/PocketLucho/Virtua-NBA---Recompilation).

If you want to support me: https://buymeacoffee.com/pocket_lucho

## What you need

* Your own **The House of the Dead 2** romset (`hotd2.zip`, MAME naming, program ROM `epr-21585`).
* The game's own **BIOS** (`epr-21329/21330/21331.ic27`): either inside a non-merged `hotd2.zip` or as a
  separate `hod2bios.zip`. This game does **not** use the regular `naomi.zip`. The BIOS is only needed the
  first time each region is used, to create a boot snapshot; after that the game boots without it.
* Windows 10/11 x64, or Linux x86_64 (glibc 2.35+, e.g. Ubuntu 22.04 or newer).

**No game code, graphics, sound or BIOS is included in this repository or in the releases.**
The recompiled code is generated on your PC from your own ROM (see below).

## Getting started (Windows)

1. Download the release zip and extract it.
2. Copy `hotd2.zip` (and `hod2bios.zip` if your romset does not include the BIOS files) to `roms\`.
3. Run **`BUILD_GAME.bat`** (once). It
   * downloads the free [llvm-mingw](https://github.com/mstorsjo/llvm-mingw) compiler (180 MB, first time only,
     checked by SHA-256),
   * runs the game up to its entry point and decodes its whole program into C++ (~78,000 blocks, a few seconds),
   * compiles it into `hotd2_game.dll` (3–15 minutes depending on the CPU),
   * deletes the generated sources.
4. Run **`HouseOfTheDead2-Recompiled.exe`**.

## Controls

| | |
|---|---|
| Mouse | aim (player 1 light gun, red crosshair) |
| Left button | fire |
| Right button | reload |
| Middle button / Enter | START |
| Q | insert coin (only when Free Play is disabled) |
| Tab | menu (Resume, Reset, Settings, Cheats, Exit) |
| Alt+Enter | full screen |

Player 2 (gamepad or a second mouse with "Use Raw Input") is configured in Settings → Controls.

## Features

* Native performance (recompiled code, no JIT), cycle-exact fallback for anything not precompiled.
* BIOS-free boot from a snapshot, one per BIOS region (Japan, USA, Export), with a region selector.
* **Free Play** by default (Settings → General).
* **Blood colour** selector (the cabinet's BLOOD COLOR game setting: red or green).
* **Native 16:9**: the game camera renders the real wide view while the HUD keeps its 4:3 proportions;
  the light gun aims over the whole wide picture.
* The light gun range is widened so the shot lands exactly under the mouse crosshair, up to the screen edges.
* Native depth interpolation enabled by default (fixes the floor textures).
* FXAA antialiasing (DirectX 11 / OpenGL) on top of supersampling (internal resolution).
* Built-in cheats: infinite life (per player), infinite ammo (no reload).
* Spanish and English UI (plus Flycast's other languages), reduced menus (Dreamcast-only options removed),
  Reset button.

Not possible: ray tracing. The game does not hand a 3D scene to the hardware; it sends triangles that are
already projected and lit to the PowerVR2, so there is no scene geometry, material or light information
to trace against.

## Getting started (Linux x86_64)

Download `HouseOfTheDead2-Recomp-linux-x64.tar.gz`, extract it, copy the ROM as above, then run
`./build_game.sh` once (needs `g++` and `make`: `sudo apt install build-essential`) and
`./HouseOfTheDead2-Recompiled`.

## Releases

Pushing a tag `v*` runs `.github/workflows/release.yml`, which builds both packages
(`hotd2/tools/package_windows.sh`, `hotd2/tools/package_linux.sh`) and publishes them as a GitHub release.

## Building from source

```bash
git clone --recursive https://github.com/PocketLucho/House-of-the-Dead-2---recomp
cd House-of-the-Dead-2---recomp
# Windows package (engine + builder), cross-compiled from Linux:
LLVM_MINGW=/path/to/llvm-mingw-20251104-ucrt-ubuntu-22.04-x86_64 hotd2/tools/package_windows.sh
# Linux package (see the script header for the apt dependencies):
hotd2/tools/package_linux.sh
```

Other targets:

* Libretro core for testing: `cmake -B build-lr -DLIBRETRO=ON && ninja -C build-lr`. The headless test frontend
  is `hotd2/host/lr_headless.cpp` (light gun input scripts: `hotd2/tools/gen_input_gun.py`, `run_test.sh`).
* Developer build with the blocks linked in (no DLL): generate the sources (`VNBA_GENERATE=<dir>`, see
  `hotd2/builder/build_game.ps1`) and configure with `-DVNBA_AOT_DIR=<dir>`.

Technical documentation: [hotd2/docs/TECHNICAL.md](hotd2/docs/TECHNICAL.md). Development notes:
[hotd2/docs/STATUS.md](hotd2/docs/STATUS.md).

## Legal

* This project is licensed under the **GNU GPL v2** (inherited from Flycast, see `LICENSE`).
  Flycast's original README is kept as [README.flycast.md](README.flycast.md).
* It contains **no copyrighted material from Sega**: no ROM, BIOS, graphics, sounds, music or translated
  game code. Graphics, sound and music are always read at run time from the user's own ROM, so nothing
  has to be extracted or converted; the recompiled code (`hotd2_game.dll`) and the boot snapshots
  (`data/hotd2_boot_*.state`, which contain the BIOS and the game's memory) are generated locally from the
  user's files and **must not be redistributed**.
* `hotd2/builder/hotd2_seeds.txt` only lists addresses of code entry points, used to guide the decoder.
* The program icon is an original drawing; the game's logo is not used.
* "The House of the Dead", "SEGA" and "NAOMI" are trademarks of their owners; they are used only to describe
  what this software is compatible with. This project is not affiliated with or endorsed by them.
* This is not legal advice. Dumping your own cartridge is the only way to obtain the ROM legitimately.
