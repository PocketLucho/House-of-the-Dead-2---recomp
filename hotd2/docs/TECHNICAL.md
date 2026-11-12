# Technical overview

## Pipeline

```
hotd2.zip ──► engine boots the game (BIOS once, then boot snapshot)
                 │  at the game entry point 0x0C020000 the program is in RAM
                 ▼
          static decoder (core/hw/sh4/aot/aot_static.cpp)
            seeds: hotd2_seeds.txt + every code pointer found in the program image
            follows branches / fall-through / call returns, SZ=0 and SZ=1 FPU variants
                 │  each block → Flycast SHIL IR → C++ (core/hw/sh4/dyna/aot_emit.cpp)
                 ▼
          aot_split_dump(): 32 translation units + block table
                 │  clang (llvm-mingw)
                 ▼
          hotd2_game.dll  ◄── loaded by the engine (core/hw/sh4/aot/aot_module.cpp)
```

Without a boot snapshot the builder runs the BIOS on Flycast's dynarec instead of the AOT executor (which has
no blocks yet and would interpret everything); `compilePC` stops when the game entry point is first reached,
saves the snapshot and runs the generation.

`VNBA_GENERATE=<dir>` (with `VNBA_AOT=1`, `VNBA_AOT_DUMP`, `VNBA_AOT_STATIC`, `VNBA_AOT_STATIC_PTR=1`,
`VNBA_AOT_STATIC_SZ1=1`) makes the engine run this generation and exit. `hotd2/builder/build_game.ps1` drives it
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

The first start runs the game's BIOS (`hod2bios`: `epr-21329` Japan, `epr-21330` USA, `epr-21331` Export; read
from `hod2bios.zip` or from a non-merged `hotd2.zip`); at the game entry point the machine state plus the BIOS
windows the game reads are saved to `data/hotd2_boot_<region>.state` (jp/us/ex). Later starts restore it and
never need the BIOS. A reset re-arms the restore.

## What is different from Virtua NBA (core/hw/sh4/aot/aot_game.cpp)

* **No NAOMI ROM header.** `epr-21585.ic22` starts directly with SH-4 code and its BIOS boots it without
  reading a `RomBootID`. Entry point and program area come from a small table of header-less games:
  entry `0x0C020000`, program `0x0C020000–0x0C150000` (`ic22[0, 0x126000)` is copied there as is; the only
  code executed outside it are the BIOS vectors at `0x0C000600–0x0C001E16`). `VNBA_GAME_ENTRY` /
  `VNBA_GAME_PROG=a-b` override the table for other games.
* **Function discovery.** The compiler puts a literal pool between `rts` and the next function and many
  functions are only reached through jump tables of relative offsets (`braf`), so the static decoder also
  takes every function prologue (`mov.l r8..r14,@-r15` / `sts.l pr,@-r15`) whose first block decodes cleanly
  as a function start (`VNBA_AOT_STATIC_PROLOGUE=1`, development only: the result is what
  `hotd2/builder/hotd2_seeds.txt` lists, addresses only).
* **Light guns.** The JVS board reports the gun position as two analog axes. Player 1 is the mouse
  (`core/input/mouse.h`: right button = reload).

## Game-specific patches (epr-21585; all in aot_boot.cpp unless noted)

| What | Where | Notes |
|---|---|---|
| Widescreen | float 4/3 at `0x0C09A848` → 16/9 | the only aspect constant: every 3D view is projected from it. The frontend stretches the frame to 16:9; sprites (HUD) are squeezed by 0.75 around x = 320 in `ta_vtx.cpp`; the letterbox bars of the cutscenes (flat quads, z = 1) are widened back |
| Gun range | table `0x0C0FB020` (s16 x[3], y[3]) and limit literals `0x0C06BF08` | function `0x0C06BEB6` maps the raw 8-bit gun position to centred screen coordinates through three points (raw 0 / 128 / 255 → x −300 / 0 / 300, y 220 / 0 / −220) and rejects anything outside −320..319 as off-screen. Patched to ±320 × ±240 (the shot lands under the crosshair) and to ±427 in widescreen (in 4:3 units), where the shots used to stay inside the 4:3 area |
| Free play | cabinet EEPROM byte 9 (coin setting − 1, 26 = FREE PLAY) + working copy `0x0C3CFBE8` | the EEPROM system record is 20 bytes + CRC16, stored twice |
| Blood colour | byte `0x0C3D109F` (0 red, 1 green) | working copy of the game's backup data (`0x0C3D1098`): +4 difficulty, +6 life setting, +7 blood colour, +8 translucence, +11.. gun calibration |
| Cheats (`core/cheats.cpp`) | player record `0x0C3D0420 + player × 0x100` | +0x10 / +0x14 life, +0x24 bullets, +0x18 / +0x1C gun x / y (float, centred) |

Per-player gun record: `0x0C3D17CC + player × 36` (raw x, raw y, centred x, centred y, …, calibration at +24).

## Hidden content

No unlockable modes or cheat codes were found in the program (it has no text for any; the
`Stage clr / tut / end / adv` strings are internal stage names). The cabinet's own options are in the test
menu (GAME ASSIGNMENTS: difficulty, initial / maximum life, blood colour).

## Useful environment variables

| Variable | Effect |
|---|---|
| `VNBA_AOT=0/1` | force dynarec / AOT executor |
| `VNBA_GAME_MODULE_PATH` | path of the game module |
| `VNBA_BOOT_SNAPSHOT`, `VNBA_BIOS_BOOT=1` | snapshot file / ignore it |
| `VNBA_WS_MODE=off|stretch`, `VNBA_HUD_STRETCH=1`, `VNBA_2D_NOFILL=1` | widescreen variants |
| `VNBA_CHEATS=1` | start with the built-in cheats enabled (tests) |
| `VNBA_FIXED_RTC=1` | deterministic runs |
| `VNBA_AOT_VERIFY=1`, `VNBA_AOT_STATS=1`, `VNBA_AOT_MISSES=file` | debugging |
| `VNBA_PROF=from,to`, `VNBA_PEEK`, `VNBA_POKE`, `VNBA_TA_LOG` | analysis tools |

## Test frontend

`hotd2/host/lr_headless.cpp` runs the libretro core without a window (EGL), saves frames, replays input scripts
(`<frame> <port> <button> <value>`; light gun ids are libretro ids + 100 and `LR_LIGHTGUN=2` plugs the guns, see
`hotd2/tools/gen_input_gun.py`) and can dump RAM (`LR_RAMDUMP_FRAME`, `LR_RAMDUMP_FILE`) or hash it every frame
(`LR_RAMHASH`). The DLL build was validated against the linked-in build: identical RAM hash on every frame.

`hotd2/tools/sh4dis.py` is a small SH-4 disassembler for looking around a program image or a RAM dump.

The `VNBA_` prefix of the variables, `core/vnba_product.cpp` and the `VNBA_PRODUCT` CMake switch are kept from
Virtua NBA - Recomp so that both projects share the same engine code.
