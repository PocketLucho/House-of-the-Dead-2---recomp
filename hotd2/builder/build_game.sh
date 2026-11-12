#!/bin/bash
# THE HOUSE OF THE DEAD 2 - RECOMP : builder (Linux)
# Generates the recompiled game code from YOUR The House of the Dead 2 ROM and compiles it into libhotd2_game.so.
# Genera el código recompilado del juego a partir de TU ROM y lo compila en libhotd2_game.so.
# Needs / necesita: g++ and make  (Debian/Ubuntu: sudo apt install build-essential)
set -e
cd "$(dirname "$(readlink -f "$0")")"
say() { printf '\n\033[36m== %s\033[0m\n   %s\n' "$1" "$2"; }
fail() { printf '\n\033[31mERROR: %s\n       %s\033[0m\n' "$1" "$2"; exit 1; }

say "THE HOUSE OF THE DEAD 2 - RECOMP: construcción del código del juego" "THE HOUSE OF THE DEAD 2 - RECOMP: building the game code"
[ -f roms/hotd2.zip ] || [ -f hotd2.zip ] || fail "No se encuentra roms/hotd2.zip. Copia tu romset en la carpeta 'roms'." "roms/hotd2.zip not found. Copy your romset to the 'roms' folder."
command -v "${CXX:-g++}" >/dev/null || fail "Falta el compilador: sudo apt install build-essential" "Compiler missing: sudo apt install build-essential"
command -v make >/dev/null || fail "Falta make: sudo apt install build-essential" "make missing: sudo apt install build-essential"

say "Generando el código C++ a partir de tu ROM..." "Generating C++ code from your ROM..."
rm -rf builder/gen builder/obj && mkdir -p builder/gen builder/obj
VNBA_AOT=1 VNBA_GENERATE=builder/gen VNBA_AOT_DUMP=builder/gen/dump.cpp VNBA_AOT_STATIC=builder/hotd2_seeds.txt \
VNBA_AOT_STATIC_PTR=1 VNBA_AOT_STATIC_SZ1=1 ./HouseOfTheDead2-Recompiled || true
[ -f builder/gen/aot_gen_table.cpp ] || fail "La generación ha fallado. La primera vez hace falta la BIOS del juego: hod2bios.zip en la carpeta 'roms' (o un hotd2.zip que la incluya)." "Generation failed. The first time, the game's BIOS is needed: hod2bios.zip in the 'roms' folder (or a hotd2.zip that includes it)."
rm -f builder/gen/dump.cpp

say "Compilando ($(nproc) núcleos, de 3 a 15 minutos)..." "Compiling ($(nproc) cores, 3 to 15 minutes)..."
make -C builder -f Makefile.linux -j"$(nproc)" --no-print-directory

rm -rf builder/gen builder/obj	# generated sources contain code derived from the game
say "¡Listo! Ya puedes ejecutar ./HouseOfTheDead2-Recompiled" "Done! You can now run ./HouseOfTheDead2-Recompiled"
