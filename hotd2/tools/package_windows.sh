#!/bin/bash
# Builds the distributable Windows package: the engine (no game code) + the builder that turns
# each user's own ROM into hotd2_game.dll. Nothing derived from the game is included.
#
#   LLVM_MINGW=/opt/llvm-mingw-20251104-ucrt-ubuntu-22.04-x86_64 hotd2/tools/package_windows.sh [outdir]
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:-$ROOT/dist}"
BUILD="$ROOT/build-win-engine"
: "${LLVM_MINGW:?set LLVM_MINGW to the llvm-mingw toolchain folder}"
export LLVM_MINGW
# Flycast includes some Windows headers with their MSVC capitalisation: add case aliases
INC="$LLVM_MINGW/generic-w64-mingw32/include"
for h in D3Dcompiler.h:d3dcompiler.h Commctrl.h:commctrl.h Windows.h:windows.h Shellapi.h:shellapi.h \
	Psapi.h:psapi.h SDKDDKVer.h:sdkddkver.h TlHelp32.h:tlhelp32.h WinSock2.h:winsock2.h ShlObj.h:shlobj.h; do
	[ -e "$INC/${h%%:*}" ] || ln -s "${h##*:}" "$INC/${h%%:*}"
done

cmake -S "$ROOT" -B "$BUILD" -G Ninja -DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_TOOLCHAIN_FILE="$ROOT/hotd2/tools/mingw-toolchain.cmake" \
	-DVNBA_PRODUCT=ON -DUSE_BREAKPAD=OFF -DUSE_LUA=OFF -DUSE_OPENMP=OFF
ninja -C "$BUILD"

PKG="$OUT/HouseOfTheDead2-Recomp"
rm -rf "$PKG"
mkdir -p "$PKG/builder" "$PKG/roms" "$PKG/data"
cp "$BUILD/HouseOfTheDead2-Recompiled.exe" "$PKG/"
cp "$LLVM_MINGW/x86_64-w64-mingw32/bin/libwinpthread-1.dll" "$PKG/"
cp "$ROOT/hotd2/builder/CONSTRUIR_JUEGO.bat" "$ROOT/hotd2/builder/BUILD_GAME.bat" "$PKG/"
cp "$ROOT/hotd2/builder/build_game.ps1" "$ROOT/hotd2/builder/Makefile" "$ROOT/hotd2/builder/hotd2_seeds.txt" "$PKG/builder/"
while read -r f; do
	mkdir -p "$PKG/builder/sdk/$(dirname "$f")"
	cp "$ROOT/$f" "$PKG/builder/sdk/$f"
done < "$ROOT/hotd2/builder/sdk_files.txt"
cp "$ROOT/hotd2/docs/LEEME.txt" "$ROOT/hotd2/docs/README.txt" "$PKG/"
cp "$ROOT/LICENSE" "$PKG/LICENSE.txt"
echo "Copy your hotd2.zip here / Copia aquí tu hotd2.zip" > "$PKG/roms/PUT_hotd2.zip_HERE.txt"
echo "hod2bios.zip also goes here if your hotd2.zip does not include the BIOS files (first start only) / hod2bios.zip también va aquí si tu hotd2.zip no incluye la BIOS (sólo el primer arranque)" > "$PKG/roms/PUT_hod2bios.zip_HERE_IF_NEEDED.txt"
(cd "$OUT" && rm -f HouseOfTheDead2-Recomp-win64.zip && zip -q -r -9 HouseOfTheDead2-Recomp-win64.zip HouseOfTheDead2-Recomp)
echo "Package: $OUT/HouseOfTheDead2-Recomp-win64.zip"
