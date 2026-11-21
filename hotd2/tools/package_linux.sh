#!/bin/bash
# Builds the distributable Linux x86_64 package: the engine (no game code) + the builder that
# turns each user's own ROM into libhotd2_game.so. Nothing derived from the game is included.
#   hotd2/tools/package_linux.sh [outdir]
# Build dependencies (Ubuntu): build-essential cmake ninja-build libsdl2-dev libudev-dev libpulse-dev
#   libasound2-dev libgl-dev zlib1g-dev  (libsdl2-dev only to pull SDL's X11/Wayland headers)
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:-$ROOT/dist}"
BUILD="$ROOT/build-linux-engine"

cmake -S "$ROOT" -B "$BUILD" -G Ninja -DCMAKE_BUILD_TYPE=Release \
	-DVNBA_PRODUCT=ON -DUSE_BREAKPAD=OFF -DUSE_LUA=OFF \
	-DUSE_HOST_SDL=OFF -DUSE_HOST_LIBZIP=OFF -DUSE_LIBAO=OFF -DUSE_OPENMP=OFF \
	-DCMAKE_EXE_LINKER_FLAGS="-static-libstdc++ -static-libgcc"
ninja -C "$BUILD"

# Portability check: the binary may only depend on libraries every desktop Linux has
# (SteamOS, Arch, Fedora, Debian...). SDL and libzip are linked statically, libcurl/libao not used.
ALLOWED='^(linux-vdso|libc|libm|libdl|libpthread|librt|libgcc_s|libstdc\+\+|libz|libzstd|libGL|libOpenGL|libGLX|libEGL|libudev|libpulse|libasound|libpng16|ld-linux-x86-64)\.so'
BAD=$(objdump -p "$BUILD/HouseOfTheDead2-Recompiled" | awk '/NEEDED/{print $2}' | grep -Ev "$ALLOWED" || true)
objdump -p "$BUILD/HouseOfTheDead2-Recompiled" | awk '/NEEDED/{print "  needs " $2}'
if [ -n "$BAD" ]; then echo "ERROR: non-portable dependencies: $BAD"; exit 1; fi
GLIBC=$(objdump -T "$BUILD/HouseOfTheDead2-Recompiled" | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -1)
echo "  highest glibc symbol: $GLIBC"

PKG="$OUT/HouseOfTheDead2-Recomp"
rm -rf "$PKG"
mkdir -p "$PKG/builder" "$PKG/roms" "$PKG/data"
cp "$BUILD/HouseOfTheDead2-Recompiled" "$PKG/"
strip "$PKG/HouseOfTheDead2-Recompiled"
cp "$ROOT/hotd2/builder/build_game.sh" "$ROOT/hotd2/builder/HouseOfTheDead2.sh" "$PKG/"
chmod +x "$PKG/build_game.sh" "$PKG/HouseOfTheDead2.sh" "$PKG/HouseOfTheDead2-Recompiled"
cp "$ROOT/hotd2/builder/hotd2_seeds.txt" "$PKG/builder/"
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
