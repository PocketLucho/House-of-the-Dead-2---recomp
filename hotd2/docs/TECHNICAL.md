# Technical overview

## Pipeline

```
virnba.zip ──► engine boots the game (BIOS once, then boot snapshot)
                 │  at the game entry point 0x0C020500 the program is in RAM
                 ▼
          static decoder (core/hw/sh4/aot/aot_static.cpp)
            seeds: vnba_seeds.txt + every code pointer found in the program image
            follows branches / fall-through / call returns, SZ=0 and SZ=1 FPU variants
                 │  each block → Flycast SHIL IR → C++ (core/hw/sh4/dyna/aot_emit.cpp)
                 ▼
          aot_split_dump(): 32 translation units + block table
                 │  clang (llvm-mingw)
                 ▼
          vnba_game.dll  ◄── loaded by the engine (core/hw/sh4/aot/aot_module.cpp)
```

Without a boot snapshot the builder runs the BIOS on Flycast's dynarec instead of the AOT executor (which has
no blocks yet and would interpret everything); `compilePC` stops when the game entry point is first reached,
saves the snapshot and runs the generation.

`VNBA_GENERATE=<dir>` (with `VNBA_AOT=1`, `VNBA_AOT_DUMP`, `VNBA_AOT_STATIC`, `VNBA_AOT_STATIC_PTR=1`,
`VNBA_AOT_STATIC_SZ1=1`) makes the engine run this generation and exit. `vnba/builder/build_game.ps1` drives it
on Windows.

## Engine ↔ game module

The generated code only needs a handful of engine services (memory access slow paths, exceptions, SR/FPSCR
updates, interrupt check, opcode table for interpreter fallbacks, FSCA sine table). The module receives
them in an `AotHostApi` table (`core/hw/sh4/aot/aot_dll_api.h`); `aot_dll_shim.cpp` defines the matching
symbols inside the DLL, so the generated sources are identical for the linked-in and the DLL builds. The API
carries a version and `sizeof(Sh4Context)`; an incompatible module is rejected.

Block identity is `(vaddr, fpscr & 0x00180003, FNV-1a hash of the guest bytes)`. Several versions of the same
address can coexist; RAM pages holding generated code are write-protected and re-validated on change.

## Executor (core/hw/sh4/aot/aot_executor.cpp)

* Page directory dispatch `pageDir[pc >> 12][(pc & 0xfff) >> 1]` → slot with block versions.
* Cycle accounting identical to Flycast's dynarec (cycles charged up front, same block boundaries;
  the SSA optimizations that cross block boundaries are disabled when generating).
* Anything without a precompiled block runs through a cycle-exact interpreter fallback.
* Lockstep verifier against the interpreter: `VNBA_AOT_VERIFY=1` (linked-in builds only).

## Boot snapshot (core/hw/sh4/aot/aot_boot.cpp)

The first start runs the NAOMI BIOS; at the game entry point the machine state plus the BIOS windows the game
reads are saved to `data/vnba_boot_<region>.state` (jp/us/ex/kr). Later starts restore it and never need the
BIOS. A reset re-arms the restore.

## Game-specific patches

* **Widescreen**: the projection aspect literals (0x0C04F0CC, 0x0C13ACD8 → 16/9; 0x0C04F0D8, 0x0C13AE40,
  0x0C13AFA8 → 8/9) make the game render a true 16:9 view, which the frontend stretches horizontally.
  The HUD is drawn with PowerVR sprites only, so `ta_vtx.cpp` squeezes sprites by 0.75 around x = 320 and
  extends full-screen 2D pictures with their edge texel column. An experimental mode that keeps the 4:3
  projection and only widens the culling is kept as `VNBA_WS_MODE=cull` (frustum planes 0x0C2DD5F0,
  projection scale 0x0C18E860, player visibility loop 0x0C057110), but players drawn through DMA display lists
  are still culled there.
* **Cheats** (core/cheats.cpp): quarter clock (frames, 0x0C198068) and shot clock (frames, 0x0C19E008).

## Useful environment variables

| Variable | Effect |
|---|---|
| `VNBA_AOT=0/1` | force dynarec / AOT executor |
| `VNBA_GAME_MODULE_PATH` | path of the game module |
| `VNBA_BOOT_SNAPSHOT`, `VNBA_BIOS_BOOT=1` | snapshot file / ignore it |
| `VNBA_WS_MODE=off|stretch|cull`, `VNBA_HUD_STRETCH=1`, `VNBA_2D_NOFILL=1` | widescreen variants |
| `VNBA_FIXED_RTC=1` | deterministic runs |
| `VNBA_AOT_VERIFY=1`, `VNBA_AOT_STATS=1`, `VNBA_AOT_MISSES=file` | debugging |
| `VNBA_PROF=from,to`, `VNBA_PEEK`, `VNBA_POKE`, `VNBA_TA_LOG` | analysis tools |

## Test frontend

`vnba/host/lr_headless.cpp` runs the libretro core without a window (EGL), saves frames, replays input scripts
(`<frame> <port> <button> <0|1>`) and can dump RAM (`LR_RAMDUMP_FRAME`, `LR_RAMDUMP_FILE`) or hash it every frame
(`LR_RAMHASH`). The DLL build was validated against the linked-in build: identical RAM hash on every frame.
