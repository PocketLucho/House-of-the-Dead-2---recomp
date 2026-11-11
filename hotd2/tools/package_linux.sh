#!/bin/bash
# Builds the distributable Linux x86_64 package: the engine (no game code) + the builder that
# turns each user's own ROM into libvnba_game.so. Nothing derived from the game is included.
#   vnba/tools/package_linux.sh [outdir]
# Build dependencies (Ubuntu): build-essential cmake ninja-build libsdl2-dev libcurl4-openssl-dev
#   libudev-dev libpulse-dev libasound2-dev libgl-dev libzip-dev zlib1g-dev
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:-$ROOT/dist}"
BUILD="$ROOT/build-linux-engine"

cmake -S "$ROOT" -B "$BUILD" -G Ninja -DCMAKE_BUILD_TYPE=Release \
	-DVNBA_PRODUCT=ON -DUSE_BREAKPAD=OFF -DUSE_LUA=OFF
ninja -C "$BUILD"

PKG="$OUT/VirtuaNBA-Recomp"
rm -rf "$PKG"
mkdir -p "$PKG/builder" "$PKG/roms" "$PKG/data"
cp "$BUILD/VirtuaNBA-Recompiled" "$PKG/"
strip "$PKG/VirtuaNBA-Recompiled"
cp "$ROOT/vnba/builder/build_game.sh" "$PKG/"
cp "$ROOT/vnba/builder/Makefile.linux" "$ROOT/vnba/builder/vnba_seeds.txt" "$PKG/builder/"
while read -r f; do
	mkdir -p "$PKG/builder/sdk/$(dirname "$f")"
	cp "$ROOT/$f" "$PKG/builder/sdk/$f"
done < "$ROOT/vnba/builder/sdk_files.txt"
cp "$ROOT/vnba/docs/LEEME-linux.txt" "$ROOT/vnba/docs/README-linux.txt" "$PKG/"
cp "$ROOT/LICENSE" "$PKG/LICENSE.txt"
echo "Copy your virnba.zip here / Copia aquí tu virnba.zip" > "$PKG/roms/PUT_virnba.zip_HERE.txt"
echo "Copy naomi.zip here (first start only) / Copia aquí naomi.zip (sólo el primer arranque)" > "$PKG/data/PUT_naomi.zip_HERE.txt"
(cd "$OUT" && rm -f VirtuaNBA-Recomp-linux-x64.tar.gz && tar -czf VirtuaNBA-Recomp-linux-x64.tar.gz VirtuaNBA-Recomp)
echo "Package: $OUT/VirtuaNBA-Recomp-linux-x64.tar.gz"
