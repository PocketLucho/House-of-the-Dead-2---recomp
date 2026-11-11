# VIRTUA NBA - RECOMP

Recompilación estática de **Virtua NBA** (Sega NAOMI, 2000) para Windows y Linux.
Hecho por **Pocket_lucho** con Claude. [Read in English](README.md)

El código máquina SH-4 del juego se traduce por adelantado a C++ (una función por bloque) y se compila
a código nativo. El resto del hardware de NAOMI (gráficos PowerVR2, sonido AICA, controles Maple/JVS,
cartucho) lo pone un fork de [Flycast](https://github.com/flyinghead/flycast).

Si quieres apoyarme: https://buymeacoffee.com/pocket_lucho

## Qué necesitas

* Tu propio romset de **Virtua NBA** (`virnba.zip`, nombre de MAME).
* La **BIOS de NAOMI** (`naomi.zip`), sólo para el primer arranque (crea una instantánea; después
  arranca sin BIOS directamente en el logo de SEGA).
* Windows 10/11 de 64 bits, o Linux x86_64 (glibc 2.35+, p. ej. Ubuntu 22.04 o posterior).

**Ni este repositorio ni las versiones publicadas incluyen código, gráficos, sonido o BIOS del juego.**
El código recompilado se genera en tu PC a partir de tu ROM.

## Primeros pasos (Windows)

1. Descarga el zip de la versión y descomprímelo.
2. Copia `virnba.zip` en `roms\` y `naomi.zip` en `data\`.
3. Ejecuta **`CONSTRUIR_JUEGO.bat`** (una vez). Este programa:
   * descarga el compilador gratuito [llvm-mingw](https://github.com/mstorsjo/llvm-mingw) (180 MB, sólo la
     primera vez, comprobado con SHA-256),
   * arranca el juego hasta su punto de entrada y decodifica todo su programa a C++ (~76.000 bloques, segundos),
   * lo compila en `vnba_game.dll` (de 3 a 15 minutos según la CPU),
   * borra los fuentes generados.
4. Ejecuta **`VirtuaNBA-Recompiled.exe`**. Tab o el menú abre las opciones.

## Primeros pasos (Linux x86_64)

Descarga `VirtuaNBA-Recomp-linux-x64.tar.gz`, descomprímelo, copia la ROM y la BIOS como arriba, ejecuta una vez
`./build_game.sh` (necesita `g++` y `make`: `sudo apt install build-essential`) y después `./VirtuaNBA-Recompiled`.

## Versiones

Al subir una etiqueta `v*`, `.github/workflows/release.yml` compila los dos paquetes y los publica como release.

## Funciones

* Rendimiento nativo (código recompilado, sin JIT) y respaldo exacto al ciclo para lo no precompilado.
* Arranque sin BIOS con instantánea por región (Japón, EE. UU., Exportación, Corea) y selector de región.
* **16:9 nativo**: la cámara genera la vista panorámica real (sin jugadores cortados en los bordes) y el HUD
  conserva sus proporciones 4:3; las pantallas 2D se centran rellenando los lados con los píxeles del borde.
* Antialiasing FXAA (DirectX 11 / OpenGL) además del supermuestreo (resolución interna).
* Trucos integrados: reloj de partido infinito y reloj de posesión infinito.
* Menús en español e inglés (y el resto de idiomas de Flycast), menús reducidos y botón Reiniciar.
* Juego online con el netcode de rollback GGPO de Flycast (experimental; los dos jugadores necesitan la misma
  versión, el mismo romset y la misma opción de panorámico).

## Compilar desde el código

Ver [README.md](README.md#building-from-source) y [vnba/docs/TECHNICAL.md](vnba/docs/TECHNICAL.md).
Historial de desarrollo: [vnba/docs/STATUS.es.md](vnba/docs/STATUS.es.md).

## Aspectos legales

* Licencia **GNU GPL v2** (heredada de Flycast, ver `LICENSE`).
* **No contiene material con copyright de Sega ni de la NBA**: ni ROM, ni BIOS, ni gráficos, sonidos, música o
  código del juego traducido. Gráficos, sonido y música se leen siempre en tiempo de ejecución de la ROM del
  usuario; el código recompilado (`vnba_game.dll`) y la instantánea de arranque se generan en el PC del usuario
  y **no deben redistribuirse**.
* `vnba/builder/vnba_seeds.txt` sólo contiene direcciones de puntos de entrada de código.
* "Virtua NBA", "SEGA", "NAOMI" y "NBA" son marcas de sus propietarios y sólo se usan para indicar con qué es
  compatible este software. El proyecto no está afiliado ni respaldado por ellos.
* Esto no es asesoramiento legal.
