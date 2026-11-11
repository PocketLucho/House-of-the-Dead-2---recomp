# VIRTUA NBA - RECOMP : builder
# Generates the recompiled game code from YOUR Virtua NBA ROM and compiles it into vnba_game.dll.
# Genera el código recompilado del juego a partir de TU ROM y lo compila en vnba_game.dll.
#
# Nothing derived from the game is distributed: this runs on your PC with your own files.
# No se distribuye nada derivado del juego: todo se hace en tu PC con tus propios archivos.

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$builder = $PSScriptRoot
$root = Split-Path -Parent $builder
$exe = Join-Path $root 'VirtuaNBA-Recompiled.exe'
$toolsDir = Join-Path $builder 'tools'
$tcName = 'llvm-mingw-20251104-ucrt-x86_64'
$tcUrl = "https://github.com/mstorsjo/llvm-mingw/releases/download/20251104/$tcName.zip"
$tcSha256 = '171b298f46fa4b5653dc7b01cc5e709caca645991be8e1b0724466c4a282a1ac'
$genDir = Join-Path $builder 'gen'
$objDir = Join-Path $builder 'obj'

function Say($es, $en) { Write-Host ""; Write-Host "== $es" -ForegroundColor Cyan; Write-Host "   $en" -ForegroundColor DarkCyan }
function Fail($es, $en) { Write-Host ""; Write-Host "ERROR: $es" -ForegroundColor Red; Write-Host "       $en" -ForegroundColor Red; exit 1 }

Say 'VIRTUA NBA - RECOMP: construcción del código del juego' 'VIRTUA NBA - RECOMP: building the game code'

# 1. ROM
$rom = @((Join-Path $root 'roms\virnba.zip'), (Join-Path $root 'virnba.zip')) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $rom) {
	Fail "No se encuentra roms\virnba.zip. Copia tu romset de Virtua NBA en la carpeta 'roms'." "roms\virnba.zip not found. Copy your Virtua NBA romset to the 'roms' folder."
}
if (-not (Test-Path $exe)) { Fail "No se encuentra $exe" "$exe not found" }

# 2. Compiler (llvm-mingw, free, ~180 MB, only once)
$tcBin = Join-Path $toolsDir "$tcName\bin"
if (-not (Test-Path (Join-Path $tcBin 'x86_64-w64-mingw32-clang++.exe'))) {
	Say "Descargando el compilador llvm-mingw (180 MB, sólo la primera vez)..." "Downloading the llvm-mingw compiler (180 MB, first time only)..."
	New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
	$zip = Join-Path $toolsDir "$tcName.zip"
	Invoke-WebRequest -Uri $tcUrl -OutFile $zip -UseBasicParsing
	$hash = (Get-FileHash -Algorithm SHA256 $zip).Hash.ToLower()
	if ($hash -ne $tcSha256) { Remove-Item $zip; Fail "El archivo descargado no es correcto (SHA-256)." "Downloaded file is corrupt (SHA-256 mismatch)." }
	Say "Descomprimiendo..." "Extracting..."
	$tar = Get-Command tar.exe -ErrorAction SilentlyContinue
	if ($tar) { & tar.exe -xf $zip -C $toolsDir } else { Expand-Archive -Path $zip -DestinationPath $toolsDir -Force }
	Remove-Item $zip
}
$env:PATH = "$tcBin;$env:PATH"

# 3. Generate C++ from the ROM (runs the game up to its entry point and decodes its code)
Say "Generando el código C++ a partir de tu ROM..." "Generating C++ code from your ROM..."
if (Test-Path $genDir) { Remove-Item -Recurse -Force $genDir }
New-Item -ItemType Directory -Force -Path $genDir | Out-Null
$env:VNBA_AOT = '1'
# relative to the game folder (the executable runs there): avoids problems with non-ASCII paths
$env:VNBA_GENERATE = 'builder\gen'
$env:VNBA_AOT_DUMP = 'builder\gen\dump.cpp'
$env:VNBA_AOT_STATIC = 'builder\vnba_seeds.txt'
$env:VNBA_AOT_STATIC_PTR = '1'
$env:VNBA_AOT_STATIC_SZ1 = '1'
$p = Start-Process -FilePath $exe -WorkingDirectory $root -PassThru -Wait
Remove-Item Env:VNBA_AOT, Env:VNBA_GENERATE, Env:VNBA_AOT_DUMP, Env:VNBA_AOT_STATIC, Env:VNBA_AOT_STATIC_PTR, Env:VNBA_AOT_STATIC_SZ1
if (-not (Test-Path (Join-Path $genDir 'aot_gen_table.cpp'))) {
	Fail "La generación ha fallado (código $($p.ExitCode)). La primera vez hace falta la BIOS naomi.zip en la carpeta 'data'." "Generation failed (code $($p.ExitCode)). The first time, the NAOMI BIOS naomi.zip is needed in the 'data' folder."
}
Remove-Item (Join-Path $genDir 'dump.cpp') -ErrorAction SilentlyContinue

# 4. Compile
$jobs = [Math]::Max(1, [int]$env:NUMBER_OF_PROCESSORS)
Say "Compilando (puede tardar de 3 a 15 minutos, $jobs núcleos)..." "Compiling (3 to 15 minutes, $jobs cores)..."
if (Test-Path $objDir) { Remove-Item -Recurse -Force $objDir }
New-Item -ItemType Directory -Force -Path $objDir | Out-Null
Push-Location $builder
try {
	& mingw32-make.exe "-j$jobs" --no-print-directory
	if ($LASTEXITCODE -ne 0) { Fail "Error de compilación." "Compilation error." }
} finally { Pop-Location }

# 5. Clean up the generated sources (they contain code derived from the game)
Remove-Item -Recurse -Force $genDir, $objDir
Say "¡Listo! Ya puedes ejecutar VirtuaNBA-Recompiled.exe" "Done! You can now run VirtuaNBA-Recompiled.exe"
