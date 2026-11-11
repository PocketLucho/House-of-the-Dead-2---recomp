# VIRTUA NBA - RECOMP

A static recompilation of **Virtua NBA** (Sega NAOMI, 2000) for Windows and Linux.
Made by **Pocket_lucho** with Claude. [Leer en español](README.es.md)

The game's SH-4 machine code is translated ahead of time into C++ (one function per basic block)
and compiled to native code. The rest of the NAOMI hardware (PowerVR2 graphics, AICA sound,
Maple/JVS input, cartridge) is provided by a fork of [Flycast](https://github.com/flyinghead/flycast).

If you want to support me: https://buymeacoffee.com/pocket_lucho

## What you need

* Your own **Virtua NBA** romset (`virnba.zip`, MAME naming).
* The **NAOMI BIOS** (`naomi.zip`) — only for the first start, to create a boot snapshot. After that,
  the game boots straight to the SEGA logo without it.
* Windows 10/11 x64, or Linux x86_64 (glibc 2.35+, e.g. Ubuntu 22.04 or newer).

**No game code, graphics, sound or BIOS is included in this repository or in the releases.**
The recompiled code is generated on your PC from your own ROM (see below).

## Getting started (Windows)

1. Download the release zip and extract it.
2. Copy `virnba.zip` to `roms\` and `naomi.zip` to `data\`.
3. Run **`BUILD_GAME.bat`** (once). It
   * downloads the free [llvm-mingw](https://github.com/mstorsjo/llvm-mingw) compiler (180 MB, first time only,
     checked by SHA-256),
   * runs the game up to its entry point and decodes its whole program into C++ (~76,000 blocks, a few seconds),
   * compiles it into `vnba_game.dll` (3–15 minutes depending on the CPU),
   * deletes the generated sources.
4. Run **`VirtuaNBA-Recompiled.exe`**. Tab / the Settings menu opens the options.

## Features

* Native performance (recompiled code, no JIT), cycle-exact fallback for anything not precompiled.
* BIOS-free boot from a snapshot, one per BIOS region (Japan, USA, Export, Korea), region selector.
* **Native 16:9**: the game camera renders the real wide view (no culled players at the edges) while the HUD
  keeps its 4:3 proportions; 2D screens are pillarboxed with stretched edge pixels.
* FXAA antialiasing (DirectX 11 / OpenGL) on top of supersampling (internal resolution).
* Built-in cheats: infinite game clock, infinite shot clock.
* Spanish and English UI (plus Flycast's other languages), reduced menus (Dreamcast-only options removed),
  Reset button.
* Online play through Flycast's GGPO rollback netcode (experimental; both players need the same build,
  the same romset and the same widescreen setting).

## Getting started (Linux x86_64)

Download `VirtuaNBA-Recomp-linux-x64.tar.gz`, extract it, copy the ROM and BIOS as above, then run
`./build_game.sh` once (needs `g++` and `make`: `sudo apt install build-essential`) and `./VirtuaNBA-Recompiled`.

## Releases

Pushing a tag `v*` runs `.github/workflows/release.yml`, which builds both packages
(`vnba/tools/package_windows.sh`, `vnba/tools/package_linux.sh`) and publishes them as a GitHub release.

## Building from source

```bash
git clone --recursive https://github.com/PocketLucho/Virtua-NBA---Recompilation
cd Virtua-NBA---Recompilation
# Windows package (engine + builder), cross-compiled from Linux:
LLVM_MINGW=/path/to/llvm-mingw-20251104-ucrt-ubuntu-22.04-x86_64 vnba/tools/package_windows.sh
# Linux package (see the script header for the apt dependencies):
vnba/tools/package_linux.sh
```

Other targets:

* Libretro core for testing: `cmake -B build-lr -DLIBRETRO=ON && ninja -C build-lr`. The headless test frontend
  is `vnba/host/lr_headless.cpp`.
* Developer build with the blocks linked in (no DLL): generate the sources (`VNBA_GENERATE=<dir>`, see
  `vnba/builder/build_game.ps1`) and configure with `-DVNBA_AOT_DIR=<dir>`.

Technical documentation: [vnba/docs/TECHNICAL.md](vnba/docs/TECHNICAL.md). Development log (Spanish):
[vnba/docs/STATUS.es.md](vnba/docs/STATUS.es.md).

## Legal

* This project is licensed under the **GNU GPL v2** (inherited from Flycast, see `LICENSE`).
  Flycast's original README is kept as [README.flycast.md](README.flycast.md).
* It contains **no copyrighted material from Sega or the NBA**: no ROM, BIOS, graphics, sounds, music or
  translated game code. Graphics, sound and music are always read at run time from the user's own ROM;
  the recompiled code (`vnba_game.dll`) and the boot snapshot are generated locally from the user's files
  and **must not be redistributed**.
* `vnba/builder/vnba_seeds.txt` only lists addresses of code entry points, used to guide the decoder.
* "Virtua NBA", "SEGA", "NAOMI" and "NBA" are trademarks of their owners; they are used only to describe
  what this software is compatible with. This project is not affiliated with or endorsed by them.
* This is not legal advice. Dumping your own cartridge is the only way to obtain the ROM legitimately.
