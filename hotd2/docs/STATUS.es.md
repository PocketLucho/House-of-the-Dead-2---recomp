# Estado — Virtua NBA Recomp

Última actualización: 2026-11-07

## Funciona

- **Pipeline de recompilación completo**: dynarec de Flycast (decodificador SH-4 → SHIL) +
  emisor C++ (`aot_emit.cpp`) → ~30.000 bloques C++ → compilados en el binario.
- **Ejecutor AOT sin JIT** (`aot_executor.cpp`): ejecuta los bloques precompilados; el
  intérprete sólo actúa como red de seguridad para código no cubierto, con el mismo coste en
  ciclos que tendría el bloque del dynarec (timing idéntico).
- **Juego completo jugable en la build AOT**: arranque de BIOS NAOMI, logos, attract mode,
  selección, partido completo con marcador y reloj (verificado con entrada simulada durante
  12.000 frames ≈ 3 min 20 s de juego).
- **Overlays / código que se reescribe**: soportado. Virtua NBA sobreescribe código dentro de
  la región del programa; hay ≥235 direcciones con varias versiones. Versión por hash FNV-1a
  y páginas de 4 KB protegidas contra escritura para re-verificar.
- **Verificación**:
  - *Lockstep por bloque* (`VNBA_AOT_VERIFY=1`): AOT vs intérprete, reproduciendo los accesos
    a memoria. Sin discrepancias reales (sólo 2 conocidas y benignas: bit Q en la fusión de
    `div1` del dynarec, y una interrupción que el intérprete toma dentro de `ldc sr`).
  - *Traza por timeslice* (`VNBA_SLICE_TRACE` / `VNBA_SLICE_DIGEST`): registros, PC, ciclos y
    hash de la RAM en tiempo de guest; idéntica a Flycast en 360.000 timeslices.
- **Build de Windows** por compilación cruzada (llvm-mingw, clang 21) del frontend standalone
  de Flycast con el AOT dentro.

## Novedades (2026-11-07, noche)

- **Primer arranque rápido en el constructor.** Sin instantánea, la BIOS se ejecutaba en el intérprete del
  ejecutor AOT (aún no hay código recompilado) y era varias veces más lenta. Ahora el constructor arranca la BIOS
  con el dynarec de Flycast; al compilar por primera vez el bloque del punto de entrada (0x0C020500, en
  `compilePC`, con todo el estado en memoria) guarda la instantánea, genera el código y termina. En pruebas:
  24 s → 12 s sin limitar la velocidad, y el código generado es idéntico byte a byte.

## Novedades (2026-11-07)

- **Distribución legal: motor + constructor.** El .exe ya no lleva código del juego. Cada usuario ejecuta
  `CONSTRUIR_JUEGO.bat`: descarga llvm-mingw (comprobado por SHA-256), el propio .exe arranca el juego hasta su
  punto de entrada y vuelca todo el programa a C++ (76.057 bloques en ~2 s; `VNBA_GENERATE`), y se compila
  `vnba_game.dll`. El motor la carga con `aot_module.cpp` y le pasa los servicios por `AotHostApi`
  (`aot_dll_api.h`, `aot_dll_shim.cpp`). Validado en Linux con el .so: hash de RAM idéntico en todos los
  fotogramas frente a la versión con los bloques enlazados. Gráficos, sonido y música nunca estuvieron en el
  .exe: se leen de la ROM del usuario.
- **Región**: selector Japón / EE. UU. / Exportación / Corea; una instantánea de arranque por región
  (`vnba_boot_<jp|us|ex|kr>.state`). Japón cambia de verdad las pantallas de aviso y licencia.
- **Trucos**: reloj de partido infinito (0x0C198068, en fotogramas) y reloj de posesión infinito (0x0C19E008).
  El código "All-NBA team" (Start sobre Cleveland, Nueva York, Boston y Atlanta) se probó en la selección de
  equipos y no aparece ningún equipo nuevo en esta versión arcade.
- **Menú**: botón Reiniciar (vuelve a arrancar desde la instantánea), Salir a la izquierda.
- **Idioma español** completo (705 textos de Flycast + los propios).
- **FXAA** (DirectX 11 y OpenGL), además del supermuestreo de la resolución interna.
- **Créditos**: enlace a https://buymeacoffee.com/pocket_lucho en Acerca de.
- Documentación y comentarios en inglés (README.md, vnba/docs/TECHNICAL.md); repositorio en GitHub.
- Descartado: ray tracing (el juego no describe la escena en 3D, envía triángulos ya proyectados al PowerVR) e
  interpolación a más de 60 fps (la lógica va a 60 Hz; inventar fotogramas intermedios produciría artefactos).

## Novedades (2026-10-31, noche)

- Icono propio (pelota de baloncesto) en el .exe (`shell/windows/vnba/vnba.rc`, con versión =
  fecha de compilación y autoría en las propiedades del archivo) y en la ventana/barra de tareas
  (`core/vnba_icon.h`, 64×64).

## Novedades (2026-10-31, mañana)

- Pantallas 2D en 4:3: los laterales se rellenan con la columna de píxeles del borde de la
  imagen (se añade un sprite extra por cada sprite que toca el borde de la pantalla).
  `VNBA_2D_NOFILL=1` lo desactiva.
- Ventana titulada "VIRTUA NBA - RECOMP"; en Settings → About, datos de esta compilación
  (versión = fecha de compilación, autor Pocket_lucho con Claude, nº de bloques recompilados),
  además de la información de Flycast en que se basa.

## Novedades (2026-10-31)

- **Panorámico limpio: cámara 16:9 + HUD 4:3.** El juego vuelve a generar la vista 16:9 él
  mismo (sin descartes en los bordes) y el HUD ya no sale estirado. El HUD de Virtua NBA se
  dibuja entero con *sprites* del PowerVR (marcador, nombres, logos, reloj, minimapa, textos);
  los marcadores 1P/COM y el 3D son polígonos normales. Así que al decodificar cada sprite
  (`ta_vtx.cpp`, `AppendSpriteVertexB`) se comprime su X hacia el centro (×0,75); al estirar la
  imagen a 16:9 recupera sus proporciones. Las pantallas 2D salen centradas en 4:3.
  `VNBA_HUD_STRETCH=1` vuelve al HUD estirado.
- **Por qué no la otra vía** (dejar la cámara en 4:3 y ensanchar sólo el descarte): el juego
  descarta en varios sitios distintos. Localizados y documentados: planos laterales del
  frustum (`0x0C2DD5F0`, función `0x0C0C1E36`), escala de proyección de recorte
  (`0x0C18E860` → `0x0C2DD630`, usada por los renderizadores `0x0C0C91F0` y `0x0C0CCxxx` que
  escriben en el TA por store queues) y el bucle de visibilidad de jugadores para las flechas de
  borde (`0x0C057110`, fr14/fr15 = tan del FOV). Aun ensanchando todo eso, los jugadores (que
  van por listas DMA) se seguían cortando. Queda como modo experimental `VNBA_WS_MODE=cull`.
- **Menús de Flycast limpiados** en el producto: fuera idioma/emisión/región/cable de
  Dreamcast, puertos Dreamcast y VMU, carpeta de juegos y carátulas, carpetas de BIOS/VMU,
  RetroAchievements, trucos, "Insertar disco", pestaña Advanced (CPU/dynarec/depuración),
  VMU en pantalla, framebuffer completo, video routing y los ajustes genéricos de panorámico
  (sustituidos por una sola casilla "Widescreen 16:9").
- **Online (GGPO)**: compatible con el ejecutor AOT. El rollback de GGPO protege toda la RAM
  por páginas igual que el AOT protege las páginas de código: las escrituras del código
  recompilado fallan, GGPO guarda la página y luego el AOT invalida lo que toque. Al restaurar un
  estado, GGPO copia páginas sin pasar por esa vigilancia, así que ahora el AOT re-valida las
  versiones de bloque tras cada rollback. Requisito: los dos jugadores con el mismo .exe, romset
  y opción de panorámico (el panorámico parchea datos del juego en RAM). Pendiente de probar
  entre dos PCs.

## Novedades (2026-10-30, noche)

- **Bloqueo del attract corregido.** No era del juego: cuando aparecía código sin recompilar, el
  fallback lo decodificaba con el decodificador del dynarec y éste lo registraba en su gestor de
  páginas con un puntero a un objeto temporal; la siguiente escritura en esa página disparaba un
  `verify` (en Windows, un debug break = cuelgue). Ahora el fallback no registra nada. El attract
  completa ciclos enteros (intro, título, aviso, ranking, demos, tutoriales) sin colgarse.
- **Extracción del código desde la ROM**: el código del juego es `program.bin` tal cual (sin
  compresión ni overlays). Las "versiones distintas" vistas en `0x0C020000–0x0C05FFFF` eran el
  programa propio de la BIOS (pantalla NAOMI), que usa esa zona antes de cargar el juego.
  `aot_static.cpp` (`VNBA_AOT_STATIC=semillas.txt`) decodifica todo lo alcanzable desde las
  funciones de Ghidra, los bloques observados y los punteros a código válidos (cadenas sin
  opcodes inválidos), siguiendo saltos, caídas y retornos. Resultado: **63.459 bloques**
  (33.000 nunca vistos en ejecución). 0 fallbacks en attract; 4 en una partida con entradas
  nunca vistas (una función a la que se llega por una dirección calculada).
- Los bloques del código propio de la BIOS se excluyen (en modo sin BIOS no se ejecutan; el
  primer arranque con BIOS los ejecuta por el fallback, correcto y con el mismo timing).

## Hallazgos que corrigen el análisis anterior

- (Corregido) `program.bin` **sí** es el código del juego. Lo que difería en `0x0C020000–0x0C05FFFF`
  durante los primeros ~650 frames era el programa de la BIOS, que usa esa zona antes de cargar
  el juego.
- El runtime anterior (`runtime/`) no ejecutaba el juego: 354 funciones, el resto stubs, bucle
  principal fijo de 5 frames, y el `frame.bmp` era un triángulo de prueba.
- Flycast lee el reloj del host al arrancar (RTC de AICA); para comparar ejecuciones hay que
  fijarlo (`VNBA_FIXED_RTC=1`).
- Queda una sensibilidad de Flycast a la velocidad del host: la palabra de RAM `0x0C2993D4`
  vale 5 o 7 según lo rápido que corra la emulación (afecta igual a la referencia y al AOT).
  Bajo las mismas condiciones, referencia y AOT dan RAM idéntica byte a byte. Pendiente de
  localizar para tener comparaciones largas 100 % deterministas.

## Novedades (2026-10-30, tarde)

- **Rendimiento**: el ejecutor AOT era ~40 % más lento que el dynarec de Flycast (build -O1 +
  `unordered_map` por bloque + memoria siempre por `addrspace`). Ahora: tabla de despacho directa
  (directorio de páginas → slot por dirección), lectura/escritura de RAM en línea sobre la vista
  protegida de la memoria, y -O2 en el código generado → a la par con el dynarec en la medición
  (21–23 s frente a 21 s para 1.500 frames). Traza idéntica a la referencia en 897.000 timeslices.
- **Arranque sin BIOS** (`aot_boot.cpp`): la primera vez arranca con la BIOS y, en `gamePC`
  (0x0C020500), guarda el estado completo de la máquina (`data/vnba_boot.state`, 1,5 MB). Las
  siguientes veces arranca desde ahí sin `naomi.zip`: directo al logo de SEGA.
  Tras la entrada el juego no ejecuta código de la BIOS; sólo lee 4 zonas de datos (tabla de
  servicios en 0x60000–0x66FFF, bloque de identificación 0x1FFD00, una cadena en 0x10FAB y dos
  bytes por punteros nulos), que se guardan en la instantánea. Si alguna vez lee fuera de esas
  ventanas se registra un aviso. Verificado: la traza arrancando sin BIOS es idéntica a la
  continuación de la traza con BIOS durante 6,6 millones de timeslices (salvo el instante del
  próximo evento del planificador en 8 de ellos, sin efecto en registros ni RAM).
- **Lanzador / producto** (`-DVNBA_PRODUCT=ON`): `VirtuaNBA-Recompiled.exe`, título propio, abre
  `roms/virnba.zip` sin pasar por el menú del emulador, mensajes claros si falta el juego o (sólo
  la primera vez) la BIOS.
- **Panorámico y resolución** por defecto en el producto: 16:9 (Hor+, el 3D del juego llena los
  lados y el HUD queda centrado sin deformar), resolución interna 960p, anisotrópico 4x.
  Pantallas 2D (logos, selección de equipo) quedan en 4:3.
- **Cobertura**: 31.568 bloques. Cada pabellón/equipo carga su propio código; 3 pasadas
  aleatorias añadieron 751 bloques. 0 bloques sin cubrir en 6.000 frames de una partida repetida.

## Panorámico nativo (2026-10-30, noche)

- Causa de que público, jugadores y canasta desaparecieran en los bordes: el **culling** del juego
  usa su campo de visión 4:3; el suelo es una pieza grande y siempre se dibuja.
- La cámara rellena descriptores de viewport (`0x0C13ACA4` pantalla completa, `0x0C13AE0C` y
  `0x0C13AF74` medias pantallas) con un **aspecto** tomado de literales (`0x0C04F0CC` = 4/3,
  `0x0C04F0D8` = 2/3) en `0x0C04EFA0`. Poniendo 16/9 y 8/9 el propio juego proyecta y descarta con
  un campo Hor+; el renderizador estira 4:3→16:9 (`ScreenStretching` 133). Activo por defecto en el
  producto (`VNBA_NATIVE_WS=0` para el modo anterior). Las flechas "1P/COM" quedan en el borde real.
- Contrapartida: HUD y pantallas 2D salen 33 % más anchos. El HUD usa la misma transformación de
  viewport que el 3D (comprobado: ampliar el viewport desplaza/escala el HUD; las variables globales
  `0x0C2E19D0..DC` = 1/alto, 1/ancho, alto, ancho escalan el HUD de forma uniforme en x e y).
  Para un HUD sin estirar hace falta un hook en el código recompilado al dibujar el HUD.
- Herramientas: `VNBA_POKE` / `VNBA_PEEK` (forzar/leer RAM cada timeslice), `VNBA_TA_LOG`
  (envíos al TA con el bloque de origen).

## Pendiente (por orden)

1. **HUD sin estirar en panorámico nativo**: hook al dibujar el HUD para restaurar la escala 4:3
   (o anclarlo a los bordes sin deformar); pantallas 2D a 4:3 con bandas.
2. **Rendimiento**: encadenar bloques con salto estático; medir en Windows con GPU real.
3. **Linux**: empaquetado (AppImage) del producto.
