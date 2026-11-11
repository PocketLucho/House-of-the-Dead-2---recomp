#!/bin/bash
# VIRTUA NBA - RECOMP : builder (Linux)
# Generates the recompiled game code from YOUR Virtua NBA ROM and compiles it into libvnba_game.so.
# Genera el código recompilado del juego a partir de TU ROM y lo compila en libvnba_game.so.
# Needs / necesita: g++ and make  (Debian/Ubuntu: sudo apt install build-essential)
set -e
cd "$(dirname "$(readlink -f "$0")")"
say() { printf '\n\033[36m== %s\033[0m\n   %s\n' "$1" "$2"; }
fail() { printf '\n\033[31mERROR: %s\n       %s\033[0m\n' "$1" "$2"; exit 1; }

say "VIRTUA NBA - RECOMP: construcción del código del juego" "VIRTUA NBA - RECOMP: building the game code"
[ -f roms/virnba.zip ] || [ -f virnba.zip ] || fail "No se encuentra roms/virnba.zip. Copia tu romset en la carpeta 'roms'." "roms/virnba.zip not found. Copy your romset to the 'roms' folder."
command -v "${CXX:-g++}" >/dev/null || fail "Falta el compilador: sudo apt install build-essential" "Compiler missing: sudo apt install build-essential"
command -v make >/dev/null || fail "Falta make: sudo apt install build-essential" "make missing: sudo apt install build-essential"

say "Generando el código C++ a partir de tu ROM..." "Generating C++ code from your ROM..."
rm -rf builder/gen builder/obj && mkdir -p builder/gen builder/obj
VNBA_AOT=1 VNBA_GENERATE=builder/gen VNBA_AOT_DUMP=builder/gen/dump.cpp VNBA_AOT_STATIC=builder/vnba_seeds.txt \
VNBA_AOT_STATIC_PTR=1 VNBA_AOT_STATIC_SZ1=1 ./VirtuaNBA-Recompiled || true
[ -f builder/gen/aot_gen_table.cpp ] || fail "La generación ha fallado. La primera vez hace falta la BIOS naomi.zip en la carpeta 'data'." "Generation failed. The first time, the NAOMI BIOS naomi.zip is needed in the 'data' folder."
rm -f builder/gen/dump.cpp

say "Compilando ($(nproc) núcleos, de 3 a 15 minutos)..." "Compiling ($(nproc) cores, 3 to 15 minutes)..."
make -C builder -f Makefile.linux -j"$(nproc)" --no-print-directory

rm -rf builder/gen builder/obj	# generated sources contain code derived from the game
say "¡Listo! Ya puedes ejecutar ./VirtuaNBA-Recompiled" "Done! You can now run ./VirtuaNBA-Recompiled"
