// "The House of the Dead 2 Recompiled" product layer for the standalone (SDL) build.
// - starts the game directly (no emulator menu) from roms/hotd2.zip next to the executable
// - explains clearly which user files are missing
// - window title / branding
#include "vnba_product.h"
#include "types.h"
#include "stdclass.h"
#include "oslib/oslib.h"
#include "hw/sh4/aot/aot_boot.h"
#include "hw/sh4/aot/aot_dll_api.h"
#include "archive/archive.h"
#include "cfg/option.h"
#include <memory>
#include <nowide/cstdio.hpp>
#include <string>
#include <vector>
#ifdef USE_SDL
#include <SDL.h>
#endif

namespace {

bool fileExists(const std::string& path)
{
	FILE *f = nowide::fopen(path.c_str(), "rb");
	if (f == nullptr)
		return false;
	fclose(f);
	return true;
}

void showError(const std::string& msg)
{
	ERROR_LOG(BOOT, "%s", msg.c_str());
#ifdef USE_SDL
	SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_ERROR, VNBA_PRODUCT_NAME, msg.c_str(), nullptr);
#else
	fprintf(stderr, "%s\n", msg.c_str());
#endif
}

} // namespace

// Returns false if the game cannot start (the caller should exit).
bool vnba_product_init()
{
	if (settings.content.path.empty())
	{
		const std::vector<std::string> candidates = {
			get_writable_config_path("roms/hotd2.zip"),
			get_writable_config_path("hotd2.zip"),
			get_writable_data_path("hotd2.zip"),
			"roms/hotd2.zip",
			"hotd2.zip",
		};
		for (const std::string& c : candidates)
			if (fileExists(c))
			{
				settings.content.path = c;
				break;
			}
		if (settings.content.path.empty())
		{
			showError("No se encuentra el juego / Game not found.\n\n"
				"Copia tu romset de The House of the Dead 2 (hotd2.zip) en la carpeta \"roms\" junto a este ejecutable.\n"
				"Copy your The House of the Dead 2 romset (hotd2.zip) to the \"roms\" folder next to this executable:\n\n" + get_writable_config_path("roms/hotd2.zip"));
			return false;
		}
	}
	// The recompiled game code is not distributed: each user builds hotd2_game.dll from their own
	// ROM with the builder (CONSTRUIR_JUEGO.bat / build_game.ps1).
	if (aot_table_count() == 0 && getenv("VNBA_GENERATE") == nullptr && getenv("VNBA_AOT") == nullptr)
	{
		showError("Falta el código del juego (" VNBA_GAME_MODULE ").\n"
			"Game code module (" VNBA_GAME_MODULE ") not found.\n\n"
#ifdef _WIN32
			"Ejecuta CONSTRUIR_JUEGO.bat (una sola vez) para generarlo a partir de tu ROM.\n"
			"Run BUILD_GAME.bat once to build it from your own ROM.");
#else
			"Ejecuta ./build_game.sh (una sola vez) para generarlo a partir de tu ROM.\n"
			"Run ./build_game.sh once to build it from your own ROM.");
#endif
		return false;
	}
	// The game has its own BIOS (hod2bios: epr-21329/21330/21331.ic27), needed only the first time
	// a region is used, to create its boot snapshot. It is either a separate hod2bios.zip (data/
	// or roms/) or inside a non-merged hotd2.zip.
	{
		std::vector<std::string> paths = config::ContentPath.get();
		paths.push_back(get_writable_config_path("roms"));
		config::ContentPath.override(paths);
	}
	if (!aot_boot_snapshot_available())
	{
		bool bios = fileExists(get_writable_data_path("hod2bios.zip")) || fileExists(get_writable_config_path("roms/hod2bios.zip"));
		if (!bios)
		{
			static const char * const regionBios[] { "epr-21329.ic27", "epr-21330.ic27", "epr-21331.ic27" };
			std::unique_ptr<Archive> zip(OpenArchive(settings.content.path));
			const int region = config::Region >= 0 && config::Region <= 2 ? (int)config::Region : 1;
			if (zip != nullptr)
				bios = std::unique_ptr<ArchiveFile>(zip->OpenFile(regionBios[region])) != nullptr;
		}
		if (!bios && !aot_boot_use_fallback())
		{
			showError("Primer arranque: falta la BIOS de The House of the Dead 2 (hod2bios.zip, o un hotd2.zip que la incluya). "
				"Sólo se necesita una vez por región, para crear la instantánea de arranque.\n"
				"First start: the House of the Dead 2 BIOS is missing (hod2bios.zip, or a hotd2.zip that includes it). "
				"It is only needed once per region, to create the boot snapshot.\n\n" + get_writable_config_path("roms/hod2bios.zip"));
			return false;
		}
	}
	NOTICE_LOG(BOOT, "%s: content %s", VNBA_PRODUCT_NAME, settings.content.path.c_str());
	return true;
}
