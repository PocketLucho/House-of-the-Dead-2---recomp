# THE HOUSE OF THE DEAD 2 - RECOMP

Recompilación estática de **The House of the Dead 2** (Sega NAOMI, 1998) para Windows y Linux.
Hecho por **Pocket_lucho** con Claude. [Read in English](README.md)

El código máquina SH-4 del juego se traduce de antemano a C++ (una función por bloque básico) y se
compila a código nativo. El resto del hardware de NAOMI (gráficos PowerVR2, sonido AICA, entradas JVS con
pistolas, cartucho) lo aporta un fork de [Flycast](https://github.com/flyinghead/flycast). Usa el mismo
motor que [Virtua NBA - Recomp](https://github.com/PocketLucho/Virtua-NBA---Recompilation).

Si quieres apoyarme: https://buymeacoffee.com/pocket_lucho

## Qué necesitas

* Tu propio romset de **The House of the Dead 2** (`hotd2.zip`, nombre de MAME, ROM de programa `epr-21585`).
* La **BIOS propia del juego** (`epr-21329/21330/21331.ic27`): dentro de un `hotd2.zip` no fusionado o en un
  `hod2bios.zip` aparte. Este juego **no** usa el `naomi.zip` normal. Sólo hace falta la primera vez que se
  usa cada región, para crear una instantánea de arranque; después el juego arranca sin ella.
* Windows 10/11 x64, o Linux x86_64 (glibc 2.35+, p. ej. Ubuntu 22.04 o posterior).

**Ni este repositorio ni las versiones publicadas incluyen código, gráficos, sonido o BIOS del juego.**
El código recompilado se genera en tu PC a partir de tu propia ROM.

## Primeros pasos (Windows)

1. Descarga el zip de la versión y descomprímelo.
2. Copia `hotd2.zip` (y `hod2bios.zip` si tu romset no trae la BIOS) en `roms\`.
3. Ejecuta **`CONSTRUIR_JUEGO.bat`** (una vez). El script:
   * descarga el compilador libre [llvm-mingw](https://github.com/mstorsjo/llvm-mingw) (180 MB, sólo la primera
     vez, comprobado por SHA-256),
   * arranca el juego hasta su punto de entrada y decodifica todo el programa a C++ (~78.000 bloques, unos segundos),
   * lo compila en `hotd2_game.dll` (de 3 a 15 minutos según la CPU),
   * borra las fuentes generadas.
4. Ejecuta **`HouseOfTheDead2-Recompiled.exe`**.

## Controles

| | |
|---|---|
| Ratón | apuntar (pistola del jugador 1, punto de mira rojo) |
| Botón izquierdo | disparar |
| Botón derecho | recargar |
| Botón central / Enter | START |
| Q | insertar moneda (sólo con el juego libre desactivado) |
| Tab | menú (Continuar, Reiniciar, Ajustes, Trucos, Salir) |
| Alt+Enter | pantalla completa |

El jugador 2 (mando o un segundo ratón con "Use Raw Input") se configura en Ajustes → Controles.

## Características

* Rendimiento nativo (código recompilado, sin JIT); lo que no esté precompilado lo ejecuta un intérprete
  con el mismo coste en ciclos.
* Arranque sin BIOS desde una instantánea, una por región (Japón, EE. UU., Exportación), con selector de región.
* **Juego libre (Free Play)** activado por defecto (Ajustes → General).
* Selector de **color de la sangre** (el ajuste BLOOD COLOR de la máquina: rojo o verde). No depende de la región.
* **16:9 nativo**: la cámara del juego genera la vista panorámica real y el HUD mantiene sus proporciones 4:3;
  la pistola apunta en toda la imagen panorámica.
* Rango de la pistola ampliado: el disparo cae exactamente bajo el punto de mira del ratón, hasta los bordes.
* Interpolación nativa de profundidad activada por defecto (arregla las texturas de los suelos).
* Antialiasing FXAA (DirectX 11 / OpenGL) además del supermuestreo (resolución interna).
* Trucos integrados: vida infinita (por jugador) y munición infinita (sin recargar).
* Interfaz en español e inglés (más los otros idiomas de Flycast), menús reducidos y botón Reiniciar.

No es posible: ray tracing. El juego no entrega una escena 3D al hardware; envía al PowerVR2 triángulos ya
proyectados e iluminados, así que no hay geometría, materiales ni luces contra los que trazar rayos.

## Primeros pasos (Linux x86_64)

Descarga `HouseOfTheDead2-Recomp-linux-x64.tar.gz`, descomprímelo, copia la ROM como arriba, ejecuta una vez
`./build_game.sh` (necesita `g++` y `make`: `sudo apt install build-essential`) y después
`./HouseOfTheDead2-Recompiled`.

## Compilar desde el código fuente

Ver [README.md](README.md#building-from-source). Documentación técnica (en inglés):
[hotd2/docs/TECHNICAL.md](hotd2/docs/TECHNICAL.md) y [hotd2/docs/STATUS.md](hotd2/docs/STATUS.md).

## Legal

* Licencia **GNU GPL v2** (heredada de Flycast, ver `LICENSE`). El README original de Flycast se conserva en
  [README.flycast.md](README.flycast.md).
* No contiene **ningún material con copyright de Sega**: ni ROM, ni BIOS, ni gráficos, sonidos, música o código
  del juego traducido. Gráficos, sonido y música se leen siempre en tiempo de ejecución de la ROM del
  usuario, así que no hay nada que extraer ni convertir; el código recompilado (`hotd2_game.dll`) y las
  instantáneas de arranque (`data/hotd2_boot_*.state`, que contienen la BIOS y la memoria del juego) se generan
  en el PC del usuario con sus archivos y **no deben redistribuirse**.
* `hotd2/builder/hotd2_seeds.txt` sólo contiene direcciones de puntos de entrada de código, para guiar al decodificador.
* El icono del programa es un dibujo original; no se usa el logotipo del juego.
* "The House of the Dead", "SEGA" y "NAOMI" son marcas de sus propietarios y sólo se usan para indicar con qué es
  compatible este software. Este proyecto no está afiliado a ellos ni cuenta con su respaldo.
* Esto no es asesoramiento legal. La única forma legítima de obtener la ROM es volcar tu propio cartucho.
