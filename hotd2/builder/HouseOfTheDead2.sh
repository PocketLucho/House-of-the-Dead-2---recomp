#!/bin/bash
# THE HOUSE OF THE DEAD 2 - RECOMP launcher (Linux / SteamOS).
# Use this file to start the game, also as the "non-Steam game" in Steam (Game Mode).
# Usa este archivo para arrancar el juego, también como "juego no de Steam" en Steam (Modo Juego).
# If something fails, the reason is written to hotd2.log and shown in a window.
cd "$(dirname "$(readlink -f "$0")")"
chmod +x HouseOfTheDead2-Recompiled build_game.sh 2>/dev/null

message() {	# title text
	if command -v kdialog >/dev/null; then kdialog --title "$1" --error "$2"
	elif command -v zenity >/dev/null; then zenity --error --title "$1" --text "$2"
	elif command -v notify-send >/dev/null; then notify-send "$1" "$2"
	fi
	printf '%s\n%s\n' "$1" "$2" >&2
}
in_terminal() {	# open a terminal window running the given script
	for t in konsole gnome-terminal xfce4-terminal xterm; do
		command -v $t >/dev/null || continue
		case $t in
			gnome-terminal) gnome-terminal -- bash "$1"; return 0 ;;
			*) $t -e bash "$1"; return 0 ;;
		esac
	done
	return 1
}

if [ ! -f libhotd2_game.so ]; then
	if [ -t 1 ]; then exec ./build_game.sh; fi
	in_terminal ./build_game.sh && [ -f libhotd2_game.so ] || {
		message "THE HOUSE OF THE DEAD 2 - RECOMP" "Falta libhotd2_game.so: ejecuta build_game.sh una vez (Modo Escritorio, en una terminal).

libhotd2_game.so is missing: run build_game.sh once (Desktop Mode, in a terminal)."
		exit 1; }
fi

./HouseOfTheDead2-Recompiled "$@" 2> >(tee hotd2.log >&2)
rc=$?
# 130/137/143 = closed by the user or the system (Ctrl+C, kill): no message
if [ $rc -ne 0 ] && [ $rc -ne 130 ] && [ $rc -ne 137 ] && [ $rc -ne 143 ]; then
	message "THE HOUSE OF THE DEAD 2 - RECOMP" "El juego se ha cerrado con un error ($rc). / The game exited with an error ($rc).

$(tail -n 15 hotd2.log)"
fi
exit $rc
