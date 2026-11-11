#include "aot_game.h"
#include "emulator.h"
#include "hw/naomi/naomi_cart.h"
#include <cstring>
#include <algorithm>
#include <cstdio>
#include <cstdlib>

std::string aot_game_id()
{
	std::string p = settings.content.path;
	size_t slash = p.find_last_of("/\\");
	if (slash != std::string::npos)
		p = p.substr(slash + 1);
	size_t dot = p.find_last_of('.');
	if (dot != std::string::npos)
		p = p.substr(0, dot);
	std::transform(p.begin(), p.end(), p.begin(), [](unsigned char c) { return (char)std::tolower(c); });
	return p.empty() ? std::string("game") : p;
}

// Cartridges without a NAOMI ROM header. The House of the Dead 2 boots through its own BIOS
// (hod2bios: epr-21329/21330/21331), which loads the program from the cartridge without the
// usual "NAOMI" boot block: entry point and program area were measured once (VNBA_DMA_LOG +
// first block executed in the loaded area) and are listed here.
// VNBA_GAME_ENTRY / VNBA_GAME_PROG=<start>-<end> (hex) override them (discovery runs).
struct HeaderlessGame {
	const char *id;
	const char *title;
	u32 entry, progStart, progEnd;
};
static const HeaderlessGame headerlessGames[] = {
	// program image: epr-21585.ic22 [0, 0x126000) -> 0x0C020000; vectors / handlers in 0x0C000000-0x0C01FFFF
	{ "hotd2", "THE HOUSE OF THE DEAD 2", 0x0C020000, 0x0C020000, 0x0C150000 },
};

static bool headerlessInfo(AotGameInfo& info)
{
	const std::string game = aot_game_id();
	const HeaderlessGame *hg = nullptr;
	for (const HeaderlessGame& g : headerlessGames)
		if (game == g.id)
			hg = &g;
	if (hg == nullptr && getenv("VNBA_GAME_ENTRY") == nullptr)
		return false;
	if (hg != nullptr)
	{
		info.entry = hg->entry;
		info.progStart = hg->progStart;
		info.progEnd = hg->progEnd;
		strncpy(info.title, hg->title, 32);
	}
	if (const char *e = getenv("VNBA_GAME_ENTRY"))
		info.entry = strtoul(e, nullptr, 16) & 0x1FFFFFFF;
	if (const char *e = getenv("VNBA_GAME_PROG"))
	{
		unsigned a = 0, b = 0;
		if (sscanf(e, "%x-%x", &a, &b) == 2)
		{
			info.progStart = a & 0x1FFFFFFF;
			info.progEnd = b & 0x1FFFFFFF;
		}
	}
	if (info.progStart >= info.progEnd)
	{
		info.progStart = 0x0C020000;
		info.progEnd = 0x0C420000;
	}
	info.valid = info.entry != 0;
	INFO_LOG(BOOT, "AOT game '%s' (no ROM header): entry %08x, program %08x-%08x", info.title, info.entry, info.progStart, info.progEnd);
	return true;
}

const AotGameInfo& aot_game_info()
{
	static AotGameInfo info;
	static Cartridge *cachedCart;
	static std::string cachedPath;
	if (info.valid && cachedCart == CurrentCartridge && cachedPath == settings.content.path)
		return info;
	info = AotGameInfo{};
	cachedCart = CurrentCartridge;
	cachedPath = settings.content.path;
	RomBootID id;
	if (CurrentCartridge == nullptr)
		return info;
	if (headerlessInfo(info))
		return info;
	if (!CurrentCartridge->GetBootId(&id) || memcmp(id.boardName, "NAOMI", 5) != 0)
		return info;
	info.entry = id.gamePC & 0x1FFFFFFF;
	u32 lo = 0xFFFFFFFF, hi = 0;
	for (int i = 0; i < 8; i++)
	{
		if (id.gameLoad[i][0] == 0xFFFFFFFF)
			break;
		u32 start = id.gameLoad[i][1] & 0x1FFFFFFF;
		lo = std::min(lo, start);
		hi = std::max(hi, start + id.gameLoad[i][2]);
	}
	if (lo >= hi)
	{
		// Not described by the header: assume the usual NAOMI program area
		lo = 0x0C020000;
		hi = 0x0C420000;
	}
	info.progStart = lo;
	info.progEnd = hi;
	memcpy(info.title, id.gameTitle[0], 32);
	for (int i = 31; i >= 0 && (info.title[i] == ' ' || info.title[i] == '-' || info.title[i] == 0); i--)
		info.title[i] = 0;
	info.valid = info.entry != 0;
	INFO_LOG(BOOT, "AOT game '%s': entry %08x, program %08x-%08x", info.title, info.entry, info.progStart, info.progEnd);
	return info;
}
