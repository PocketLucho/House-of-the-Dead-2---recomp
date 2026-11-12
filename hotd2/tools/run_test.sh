#!/bin/bash
# Headless test run of the libretro build with the game module (light gun input script).
# usage: run_test.sh <name> <frames> <save every> ; input script in <name>/in.txt (see gen_input_gun.py)
#   CORE=build-lr/flycast_libretro.so  MODULE=libhotd2_game.so  ROM=roms/hotd2.zip  SNAP=hotd2_boot_us.state
#   extra VNBA_* variables pass through (VNBA_WS_MODE=stretch, VNBA_CHEATS=1, VNBA_POKE=...)
n=$1; rm -rf "$n/out"; mkdir -p "$n/sys" "$n/out"
export LR_LIGHTGUN=2 VNBA_FIXED_RTC=1
export VNBA_GAME_MODULE_PATH="${MODULE:?path of libhotd2_game.so}"
VNBA_BOOT_SNAPSHOT="${SNAP:?boot snapshot}" "${HEADLESS:-./lr_headless}" "${CORE:?path of flycast_libretro.so}" \
	"${ROM:-roms/hotd2.zip}" "$PWD/$n/sys" "$2" "$n/out" "$3" "$n/in.txt" > "$n/log.txt" 2>&1
