#!/bin/bash
# THE HOUSE OF THE DEAD 2 - RECOMP : builder (Linux / SteamOS)
# Generates the recompiled game code from YOUR The House of the Dead 2 ROM and compiles it into libhotd2_game.so.
# Genera el código recompilado del juego a partir de TU ROM y lo compila en libhotd2_game.so.
#
# Nothing has to be installed: if the system has no C++ compiler (SteamOS, for example) a portable
# one (Zig, ~45 MB) is downloaded once into builder/tools. No root/sudo needed.
# No hace falta instalar nada: si el sistema no tiene compilador de C++ (por ejemplo SteamOS) se
# descarga una vez uno portátil (Zig, ~45 MB) en builder/tools. No hace falta root/sudo.
#
#   ./build_game.sh                 generate + compile
#   ./build_game.sh --compile-only  compile the sources already in builder/gen (testing)
# Env: CXX=<compiler> forces a compiler; VNBA_USE_ZIG=1 forces the portable compiler.
set -e
cd "$(dirname "$(readlink -f "$0")")"
say() { printf '\n\033[36m== %s\033[0m\n   %s\n' "$1" "$2"; }
fail() { printf '\n\033[31mERROR: %s\n       %s\033[0m\n' "$1" "$2"; pause_exit 1; }
pause_exit() {
	# When started by double-click there is no terminal to read the message: wait for a key.
	if [ -t 0 ] && [ -z "$VNBA_NO_PAUSE" ]; then read -r -p "Pulsa Enter / Press Enter " _ || true; fi
	exit "$1"
}

ZIG_VER=0.13.0
ZIG_NAME="zig-linux-x86_64-$ZIG_VER"
ZIG_URL="https://ziglang.org/download/$ZIG_VER/$ZIG_NAME.tar.xz"
ZIG_SHA256=d45312e61ebcc48032b77bc4cf7fd6915c11fa16e4aad116b66c9468211230ea
ZIG_DIR="builder/tools/$ZIG_NAME"

COMPILE_ONLY=0
[ "$1" = "--compile-only" ] && COMPILE_ONLY=1

say "THE HOUSE OF THE DEAD 2 - RECOMP: construcción del código del juego" "THE HOUSE OF THE DEAD 2 - RECOMP: building the game code"
[ "$(uname -m)" = "x86_64" ] || fail "Sólo x86_64." "x86_64 only."

# ---------------------------------------------------------------- compiler
download() {	# url file
	if command -v curl >/dev/null; then curl -fL --retry 3 -o "$2" "$1"
	elif command -v wget >/dev/null; then wget -O "$2" "$1"
	else return 1; fi
}
get_zig() {
	if [ ! -x "$ZIG_DIR/zig" ]; then
		say "No hay compilador de C++: descargando Zig $ZIG_VER (una sola vez, ~45 MB)..." \
			"No C++ compiler found: downloading Zig $ZIG_VER (only once, ~45 MB)..."
		mkdir -p builder/tools
		local t="builder/tools/$ZIG_NAME.tar.xz"
		download "$ZIG_URL" "$t" || fail "No se pudo descargar $ZIG_URL (¿hay conexión a internet?)" \
			"Could not download $ZIG_URL (internet connection?)"
		local h; h=$(sha256sum "$t" | cut -d' ' -f1)
		if [ "$h" != "$ZIG_SHA256" ]; then rm -f "$t"; fail "El archivo descargado no es válido (sha256 $h)." \
			"The downloaded file is not valid (sha256 $h)."; fi
		tar -xJf "$t" -C builder/tools || fail "No se pudo descomprimir Zig." "Could not extract Zig."
		rm -f "$t"
	fi
	export ZIG_GLOBAL_CACHE_DIR="$PWD/builder/tools/zig-cache" ZIG_LOCAL_CACHE_DIR="$PWD/builder/tools/zig-cache"
	# glibc 2.28 baseline: the module then loads on any distribution from 2018 onwards
	CXXCMD=("$PWD/$ZIG_DIR/zig" c++ -target x86_64-linux-gnu.2.28)
	LINKFLAGS=(-shared -Wl,-Bsymbolic -Wl,-z,defs -s)
}
works() {	# test that the compiler really builds a shared library
	local d; d=$(mktemp -d)
	printf 'extern "C" int f(){return 1;}\n' > "$d/t.cpp"
	"$@" -fPIC -shared -o "$d/t.so" "$d/t.cpp" >/dev/null 2>&1; local r=$?
	rm -rf "$d"; return $r
}
if [ -n "$VNBA_USE_ZIG" ]; then get_zig
elif [ -n "$CXX" ]; then CXXCMD=($CXX); LINKFLAGS=(-shared -Wl,-Bsymbolic -Wl,--no-undefined -s)
elif command -v g++ >/dev/null && works g++; then CXXCMD=(g++); LINKFLAGS=(-shared -Wl,-Bsymbolic -Wl,--no-undefined -s)
elif command -v clang++ >/dev/null && works clang++; then CXXCMD=(clang++); LINKFLAGS=(-shared -Wl,-Bsymbolic -Wl,--no-undefined -s)
else get_zig
fi
works "${CXXCMD[@]}" || fail "El compilador no funciona: ${CXXCMD[*]}" "The compiler does not work: ${CXXCMD[*]}"

# ---------------------------------------------------------------- generate
if [ $COMPILE_ONLY = 0 ]; then
	[ -f roms/hotd2.zip ] || [ -f hotd2.zip ] || fail "No se encuentra roms/hotd2.zip. Copia tu romset en la carpeta 'roms'." \
		"roms/hotd2.zip not found. Copy your romset to the 'roms' folder."
	chmod +x HouseOfTheDead2-Recompiled 2>/dev/null || true
	say "Generando el código C++ a partir de tu ROM..." "Generating C++ code from your ROM..."
	rm -rf builder/gen builder/obj && mkdir -p builder/gen
	VNBA_AOT=1 VNBA_GENERATE=builder/gen VNBA_AOT_DUMP=builder/gen/dump.cpp VNBA_AOT_STATIC=builder/hotd2_seeds.txt \
	VNBA_AOT_STATIC_PTR=1 VNBA_AOT_STATIC_SZ1=1 ./HouseOfTheDead2-Recompiled || true
	[ -f builder/gen/aot_gen_table.cpp ] || fail "La generación ha fallado. La primera vez hace falta la BIOS del juego: hod2bios.zip en la carpeta 'roms' (o un hotd2.zip que la incluya)." \
		"Generation failed. The first time, the game's BIOS is needed: hod2bios.zip in the 'roms' folder (or a hotd2.zip that includes it)."
	rm -f builder/gen/dump.cpp
fi
[ -f builder/gen/aot_gen_table.cpp ] || fail "No hay código generado en builder/gen." "No generated code in builder/gen."

# ---------------------------------------------------------------- compile (no make needed)
JOBS=$(nproc 2>/dev/null || echo 4)
say "Compilando con ${CXXCMD[0]##*/} ($JOBS núcleos, de 3 a 20 minutos)..." "Compiling with ${CXXCMD[0]##*/} ($JOBS cores, 3 to 20 minutes)..."
rm -rf builder/obj && mkdir -p builder/obj
CXXFLAGS=(-std=c++17 -O2 -fPIC -fno-strict-aliasing -fvisibility=hidden -w -DNDEBUG
	-Ibuilder/sdk/core -Ibuilder/sdk/core/deps -Ibuilder/sdk/core/deps/nowide/include)
export VNBA_CC_CMD
VNBA_CC_CMD=$(printf '%q ' "${CXXCMD[@]}" "${CXXFLAGS[@]}")
SRCS=(builder/gen/aot_gen_*.cpp builder/sdk/core/hw/sh4/aot/aot_dll_shim.cpp)
printf '%s\0' "${SRCS[@]}" | xargs -0 -n1 -P"$JOBS" bash -c '
	o="builder/obj/$(basename "${1%.cpp}").o"
	eval "$VNBA_CC_CMD -c \"\$1\" -o \"\$o\"" || { echo "FAILED: $1" >&2; exit 255; }
	echo "  ok  $(basename "$1")"' _ \
	|| fail "La compilación ha fallado (mira los mensajes de arriba)." "Compilation failed (see the messages above)."
"${CXXCMD[@]}" "${LINKFLAGS[@]}" -o libhotd2_game.so builder/obj/*.o -lm \
	|| fail "El enlazado ha fallado." "Linking failed."

rm -rf builder/gen builder/obj	# generated sources contain code derived from the game
say "¡Listo! Ya puedes ejecutar ./HouseOfTheDead2.sh (o ./HouseOfTheDead2-Recompiled)" "Done! You can now run ./HouseOfTheDead2.sh (or ./HouseOfTheDead2-Recompiled)"
pause_exit 0
