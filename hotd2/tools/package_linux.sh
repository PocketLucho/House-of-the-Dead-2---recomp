#!/bin/bash
# Builds the distributable Linux x86_64 package: the engine (no game code) + the builder that
# turns each user's own ROM into libhotd2_game.so. Nothing derived from the game is included.
#   hotd2/tools/package_linux.sh [outdir]
# Build dependencies (Ubuntu): build-essential cmake ninja-build libsdl2-dev libcurl4-openssl-dev
#   libudev-dev libpulse-dev libasound2-dev libgl-dev libzip-dev zlib1g-dev
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:-$ROOT/dist}"
BUILD="$ROOT/build-linux-engine"

cmake -S "$ROOT" -B "$BUILD" -G Ninja -DCMAKE_BUILD_TYPE=Release \
	-DVNBA_PRODUCT=ON -DUSE_BREAKPAD=OFF -DUSE_LUA=OFF
ninja -C "$BUILD"

PKG="$OUT/HouseOfTheDead2-Recomp"
rm -rf "$PKG"
mkdir -p "$PKG/builder" "$PKG/roms" "$PKG/data"
cp "$BUILD/HouseOfTheDead2-Recompiled" "$PKG/"
strip "$PKG/HouseOfTheDead2-Recompiled"
cp "$ROOT/hotd2/builder/build_game.sh" "$PKG/"
cp "$ROOT/hotd2/builder/Makefile.linux" "$ROOT/hotd2/builder/hotd2_seeds.txt" "$PKG/builder/"
while read -r f; do
	mkdir -p "$PKG/builder/sdk/$(dirname "$f")"
	cp "$ROOT/$f" "$PKG/builder/sdk/$f"
done < "$ROOT/hotd2/builder/sdk_files.txt"
cp "$ROOT/hotd2/docs/LEEME-linux.txt" "$ROOT/hotd2/docs/README-linux.txt" "$PKG/"
cp "$ROOT/LICENSE" "$PKG/LICENSE.txt"
echo "Copy your hotd2.zip here / Copia aquí tu hotd2.zip" > "$PKG/roms/PUT_hotd2.zip_HERE.txt"
echo "hod2bios.zip also goes here if your hotd2.zip does not include the BIOS files (first start only) / hod2bios.zip también va aquí si tu hotd2.zip no incluye la BIOS (sólo el primer arranque)" > "$PKG/roms/PUT_hod2bios.zip_HERE_IF_NEEDED.txt"
(cd "$OUT" && rm -f HouseOfTheDead2-Recomp-linux-x64.tar.gz && tar -czf HouseOfTheDead2-Recomp-linux-x64.tar.gz HouseOfTheDead2-Recomp)
echo "Package: $OUT/HouseOfTheDead2-Recomp-linux-x64.tar.gz"
