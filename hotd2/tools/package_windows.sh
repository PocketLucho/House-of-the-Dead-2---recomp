#!/bin/bash
# Builds the distributable Windows package: the engine (no game code) + the builder that turns
# each user's own ROM into vnba_game.dll. Nothing derived from the game is included.
#
#   LLVM_MINGW=/opt/llvm-mingw-20251104-ucrt-ubuntu-22.04-x86_64 vnba/tools/package_windows.sh [outdir]
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
	-DCMAKE_TOOLCHAIN_FILE="$ROOT/vnba/tools/mingw-toolchain.cmake" \
	-DVNBA_PRODUCT=ON -DUSE_BREAKPAD=OFF -DUSE_LUA=OFF -DUSE_OPENMP=OFF
ninja -C "$BUILD"

PKG="$OUT/VirtuaNBA-Recomp"
rm -rf "$PKG"
mkdir -p "$PKG/builder" "$PKG/roms" "$PKG/data"
cp "$BUILD/VirtuaNBA-Recompiled.exe" "$PKG/"
cp "$LLVM_MINGW/x86_64-w64-mingw32/bin/libwinpthread-1.dll" "$PKG/"
cp "$ROOT/vnba/builder/CONSTRUIR_JUEGO.bat" "$ROOT/vnba/builder/BUILD_GAME.bat" "$PKG/"
cp "$ROOT/vnba/builder/build_game.ps1" "$ROOT/vnba/builder/Makefile" "$ROOT/vnba/builder/vnba_seeds.txt" "$PKG/builder/"
while read -r f; do
	mkdir -p "$PKG/builder/sdk/$(dirname "$f")"
	cp "$ROOT/$f" "$PKG/builder/sdk/$f"
done < "$ROOT/vnba/builder/sdk_files.txt"
cp "$ROOT/vnba/docs/LEEME.txt" "$ROOT/vnba/docs/README.txt" "$PKG/"
cp "$ROOT/LICENSE" "$PKG/LICENSE.txt"
echo "Copy your virnba.zip here / Copia aquí tu virnba.zip" > "$PKG/roms/PUT_virnba.zip_HERE.txt"
echo "Copy naomi.zip here (first start only) / Copia aquí naomi.zip (sólo el primer arranque)" > "$PKG/data/PUT_naomi.zip_HERE.txt"
(cd "$OUT" && rm -f VirtuaNBA-Recomp-win64.zip && zip -q -r -9 VirtuaNBA-Recomp-win64.zip VirtuaNBA-Recomp)
echo "Package: $OUT/VirtuaNBA-Recomp-win64.zip"
