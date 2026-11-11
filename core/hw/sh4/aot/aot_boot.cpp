// BIOS-free boot for The House of the Dead 2 recompilation.
//
// The game's own NAOMI BIOS (hod2bios) only has to run once per region: when the game reaches
// its entry point the complete machine state is captured into a boot snapshot. Later launches
// restore that snapshot instead of running the BIOS, so the BIOS files are no longer needed.
// The snapshot holds the BIOS ROM image too (the game keeps reading parts of it), and one
// snapshot is kept per BIOS region (Japan, USA, Export): the region is read by the game.
// The cabinet settings (EEPROM/SRAM: coin settings, free play, gun calibration, rankings)
// are NOT taken from the snapshot: the current ones are kept, see aot_boot_hook().
//
// Environment:
//   VNBA_BOOT_SNAPSHOT=path   snapshot file (default: <data dir>/hotd2_boot_<region>.state)
//   VNBA_BIOS_BOOT=1          ignore the snapshot and boot through the BIOS
#include "aot_boot.h"
#include "aot_game.h"
#include <algorithm>
#include "hw/sh4/sh4_mem.h"
#include "types.h"
#include "serialize.h"
#include "stdclass.h"
#include <zlib.h>
#include <nowide/cstdio.hpp>
#include "hw/flashrom/nvmem.h"
#include "hw/sh4/sh4_mmr.h"
#include "hw/sh4/sh4_if.h"
#include "hw/sh4/modules/mmu.h"
#include "hw/mem/addrspace.h"
#include "cfg/option.h"
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <string>
#include <vector>
#include <iterator>
#include <cmath>

namespace {

constexpr u32 MAGIC = 0x544F4256;	// "VBOT"
constexpr u32 FORMAT = 4;
// BIOS ROM ranges the game reads after its entry point (measured with VNBA_BIOS_WATCH):
// null-pointer reads of the header, an ID string, the service-routine table and the
// BIOS identification block at the end of the ROM.
struct Window { u32 start, size; };
// The whole BIOS ROM image is kept: Virtua Tennis (GD-ROM) reads BIOS data well outside the
// windows Virtua NBA used (e.g. 0x127200 during attract), and 2 MB compress well.
constexpr Window BIOS_WINDOWS[] = {
	{ 0x000000, 0x200000 },
};
constexpr u32 windowBytes()
{
	u32 n = 0;
	for (const Window& w : BIOS_WINDOWS)
		n += w.size;
	return n;
}

struct Header {
	u32 magic;
	u32 format;
	u32 entry;
	u32 biosWindows;
	u32 biosWindowBytes;
	u32 stateSize;
	u32 compressedSize;
};

bool checked, available, captured, restored, fallbackWanted;
std::string path;

std::string forGame;

// config::Region for NAOMI: 0 Japan, 1 USA, 2 Export (hod2bios has no Korean BIOS)
int regionIndex(int region)
{
	return region >= 0 && region <= 2 ? region : 1;
}

std::string regionSnapshotPath(int region)
{
	static const char * const names[] { "jp", "us", "ex" };
	return get_writable_data_path(aot_game_id() + "_boot_" + names[regionIndex(region)] + ".state");
}

bool validSnapshot(const std::string& file);

void init()
{
	// several games can run in one session: start over when the content changes
	const std::string game = aot_game_id();
	if (checked && game == forGame)
		return;
	forGame = game;
	checked = true;
	available = captured = restored = false;
	path.clear();
	if (const char *p = getenv("VNBA_BOOT_SNAPSHOT"))
		path = p;
	else
		path = regionSnapshotPath(config::Region);
	if (getenv("VNBA_BIOS_BOOT") != nullptr)
		return;
	available = validSnapshot(path);
	if (!available && fallbackWanted && getenv("VNBA_BOOT_SNAPSHOT") == nullptr)
		for (int r : { 1, 2, 0 })
			if (validSnapshot(regionSnapshotPath(r)))
			{
				WARN_LOG(BOOT, "AOT: no boot snapshot for region %d, using %s", (int)config::Region, regionSnapshotPath(r).c_str());
				path = regionSnapshotPath(r);
				available = true;
				break;
			}
	INFO_LOG(BOOT, "AOT boot snapshot %s: %s", path.c_str(), available ? "found" : "not found");
}

bool validSnapshot(const std::string& file)
{
	FILE *f = nowide::fopen(file.c_str(), "rb");
	if (f == nullptr)
		return false;
	Header h{};
	bool ok = fread(&h, sizeof(h), 1, f) == 1 && h.magic == MAGIC && h.format == FORMAT;
	fclose(f);
	return ok;
}

} // namespace

// ---- Native widescreen (Virtua Tennis 1 and 2) ----
// Every 3D camera of both games is set up from a literal pool holding far = 3000, near = 0.3 and
// aspect = 4/3 (VT1 match camera 0x0C029E64, VT2 0x0C026ED8, plus replay / attract / menu
// cameras). Replacing the aspect with 16/9 makes the game project and cull a Hor+ 16:9 view
// itself (net, crowd and players stay visible at the sides); the renderer then stretches the
// 4:3 frame to 16:9 and the 2D sprites (HUD, menus) are squeezed back to their 4:3 proportions.
// VT1 loads its final program after the entry point, so the program area is rescanned
// periodically and any camera pool that (re)appears is patched.
//
// The House of the Dead 2: the projection of every 3D view is built from one aspect constant,
// 4/3 (0x3FAAAAAA) at 0x0C09A848 in the program (epr-21585). Same treatment: 16/9 there, the
// frame stretched to 16:9, sprites / HUD squeezed back. Flycast's light gun mapping and the
// crosshair already follow the horizontal stretching.
//   VNBA_WS_MODE=stretch|off   (product: Settings -> Video -> Widescreen)
bool aot_ws_active;
constexpr u32 HOTD2_ASPECT_ADDR = 0x0C09A848;
constexpr u32 ASPECT_4_3 = 0x3FAAAAAA;
struct Vertex; struct PolyParam;
extern void (*vnba_poly_hook)(Vertex *v, u32 count, u32 listType, PolyParam *pp);
static void wsPolyHook(Vertex *v, u32 count, u32 listType, PolyParam *pp);
// Games whose 3D cameras are known (see above); other games keep Flycast's own options
static bool wsNativeSupported()
{
	const std::string g = aot_game_id();
	return g == "vtennisg" || g == "vtenis2c" || g == "hotd2";
}
static bool wsEnabled()
{
	if (!wsNativeSupported())
		return false;
	if (const char *e = getenv("VNBA_WS_MODE"))
		return strcmp(e, "stretch") == 0;
#ifdef VNBA_PRODUCT
	static bool requested = config::Widescreen;	// the checkbox selects the native mode
	return requested;
#else
	return false;
#endif
}

static u32 wsPatched;
void aot_ws_tick()
{
	static u32 n;
	if ((n++ & 0x3FFF) != 0)	// ~ every 2 frames
		return;
	constexpr u32 FAR_3000 = 0x453B8000;
	constexpr float WIDE = 16.f / 9.f;
	u32 wide;
	memcpy(&wide, &WIDE, 4);
	const AotGameInfo& g = aot_game_info();
	if (!g.valid)
		return;
	const bool hotd2 = aot_game_id() == "hotd2";
	if (hotd2)
	{
		if (*(const u32 *)&mem_b[HOTD2_ASPECT_ADDR & RAM_MASK] == ASPECT_4_3)
		{
			addrspace::write32(HOTD2_ASPECT_ADDR, wide);
			if (wsPatched++ == 0)
				INFO_LOG(BOOT, "AOT: widescreen aspect patched at %08x", HOTD2_ASPECT_ADDR);
		}
		return;
	}
	const u32 start = std::max(g.progStart, 0x0C000000u) + 8;
	const u32 end = std::min(g.progEnd, 0x0C000000u + RAM_SIZE);
	for (u32 a = start; a < end; a += 4)
	{
		const u32 *w = (const u32 *)&mem_b[(a - 8) & RAM_MASK];
		if (w[0] != FAR_3000 || (w[2] & 0xFFFFFFF0) != 0x3FAAAAA0)
			continue;
		float nearPlane;
		memcpy(&nearPlane, &w[1], 4);
		if (nearPlane < 0.25f || nearPlane > 0.35f)
			continue;
		addrspace::write32(a, wide);	// through the bus: write protection re-verifies the page
		wsPatched++;
		static int logged;
		if (logged++ < 32)
			INFO_LOG(BOOT, "AOT: widescreen camera aspect patched at %08x", a);
	}
}

extern u32 aot_hook_pc, aot_hook_pc2;
void aot_run_hook(u32 pc, Sh4Context *ctx)
{
}

static void applyGamePatches()
{
	extern float vnba_sprite_squeeze, vnba_sprite_keep_z;
	extern bool vnba_sprite_fill_edges;
	aot_ws_active = wsEnabled();
	if (!aot_ws_active)
	{
		vnba_sprite_squeeze = 1.f;
		if (vnba_poly_hook == wsPolyHook)
			vnba_poly_hook = nullptr;
		return;
	}
	config::Widescreen.override(false);	// the game now renders the wide view itself
	config::ScreenStretching.override(133);	// 4:3 frame -> 16:9 display
	vnba_sprite_squeeze = getenv("VNBA_HUD_STRETCH") ? 1.f : 0.75f;
	vnba_sprite_fill_edges = getenv("VNBA_2D_NOFILL") == nullptr;
	vnba_sprite_keep_z = 0.f;
	extern bool vnba_sprite_keep_fullscreen;
	vnba_sprite_keep_fullscreen = true;
	if (getenv("VNBA_HUD_STRETCH") == nullptr)
		vnba_poly_hook = wsPolyHook;
	aot_ws_tick();
	NOTICE_LOG(BOOT, "AOT: native widescreen (16:9 cameras, 4:3 sprites)");
}

static bool writeSnapshot(const std::string& path)
{
	Serializer dry;
	dc_serialize(dry);
	std::vector<u8> state(dry.size());
	Serializer ser(state.data(), state.size());
	dc_serialize(ser);

	uLongf packedLen = compressBound(state.size());
	std::vector<u8> packed(packedLen);
	if (compress2(packed.data(), &packedLen, state.data(), state.size(), 6) != Z_OK)
		return false;
	Header h{ MAGIC, FORMAT, aot_game_info().entry, (u32)std::size(BIOS_WINDOWS), windowBytes(), (u32)state.size(), (u32)packedLen };
	std::vector<u8> window;
	for (const Window& w : BIOS_WINDOWS)
		window.insert(window.end(), nvmem::getBiosData() + w.start, nvmem::getBiosData() + w.start + w.size);
	FILE *raw = nowide::fopen(path.c_str(), "wb");
	if (raw == nullptr)
	{
		WARN_LOG(BOOT, "AOT: cannot write boot snapshot %s", path.c_str());
		return false;
	}
	bool ok = fwrite(&h, sizeof(h), 1, raw) == 1
			&& fwrite(window.data(), 1, window.size(), raw) == window.size()
			&& fwrite(packed.data(), 1, packedLen, raw) == packedLen;
	fclose(raw);
	if (!ok)
	{
		WARN_LOG(BOOT, "AOT: error writing boot snapshot %s", path.c_str());
		remove(path.c_str());
		return false;
	}
	NOTICE_LOG(BOOT, "AOT: boot snapshot saved to %s (%zu bytes of state, %lu compressed)", path.c_str(), state.size(), (unsigned long)packedLen);
	return true;
}

// Experiments: save a snapshot (same format) at an arbitrary point, e.g. in the middle of a match
void aot_boot_save_snapshot(const char *file)
{
	writeSnapshot(file);
}

// ---- Cabinet EEPROM (system record of the hod2bios BIOS: CRC16 + 20 bytes, stored twice) ----
//   byte 9 = coin/credit setting - 1 (26 = #27, FREE PLAY), byte 14 = credits to start
extern u8 *EEPROM;
static u16 eepromCrc(const u8 *buf, int size)
{
	u32 n = 0xdebdeb00;
	for (int i = 0; i <= size; i++)
	{
		n = (n & 0xffffff00) + (i < size ? buf[i] : 0);
		if (i == size)
			n &= 0xffffff00;
		for (int c = 0; c < 8; c++)
			n = (n & 0x80000000) ? (n << 1) + 0x10210000 : n << 1;
	}
	return n >> 16;
}
static bool eepromValid(const u8 *e)
{
	return e[0] + (e[1] << 8) == eepromCrc(e + 2, 20) && memcmp(e, e + 22, 22) == 0;
}
static void applyFreePlay()
{
	if (EEPROM == nullptr || !eepromValid(EEPROM) || aot_game_id() != "hotd2")
		return;
	constexpr u8 FREE_PLAY = 26;
	u8 coin = EEPROM[9];
	if (config::ForceFreePlay)
		coin = FREE_PLAY;
	else if (coin == FREE_PLAY)
		coin = 0;	// 1 coin 1 credit
	if (coin == EEPROM[9])
		return;
	EEPROM[9] = coin;
	const u16 crc = eepromCrc(EEPROM + 2, 20);
	EEPROM[0] = (u8)crc;
	EEPROM[1] = (u8)(crc >> 8);
	memcpy(EEPROM + 22, EEPROM, 22);
	NOTICE_LOG(BOOT, "AOT: cabinet EEPROM set to %s", coin == FREE_PLAY ? "free play" : "1 coin 1 credit");
}

bool aot_boot_snapshot_available()
{
	init();
	return available;
}

// No snapshot for the selected region and no BIOS to create it: boot from another region's
// snapshot instead. Returns false if there is none at all.
bool aot_boot_use_fallback()
{
	init();
	if (available || getenv("VNBA_BOOT_SNAPSHOT") != nullptr)
		return available;
	fallbackWanted = true;
	checked = false;
	init();
	if (!available)
		fallbackWanted = false;
	return available;
}

// Called before every block dispatch until the snapshot is captured or restored.
// Returns true if the machine state was replaced (the caller must re-read the context).
bool aot_boot_hook(u32 pc)
{
	init();
	if (available && !restored)
	{
		restored = true;
		FILE *raw = nowide::fopen(path.c_str(), "rb");
		Header h{};
		if (raw == nullptr || fread(&h, sizeof(h), 1, raw) != 1)
		{
			if (raw) fclose(raw);
			throw FlycastException("Cannot read boot snapshot " + path);
		}
		if (h.biosWindows != std::size(BIOS_WINDOWS) || h.biosWindowBytes != windowBytes()
				|| (aot_game_info().valid && h.entry != aot_game_info().entry))
		{
			fclose(raw);
			throw FlycastException("Incompatible boot snapshot " + path);
		}
		std::vector<u8> window(h.biosWindowBytes);
		std::vector<u8> packed(h.compressedSize);
		std::vector<u8> state(h.stateSize);
		bool ok = fread(window.data(), 1, window.size(), raw) == window.size()
				&& fread(packed.data(), 1, packed.size(), raw) == packed.size();
		fclose(raw);
		uLongf outLen = state.size();
		if (!ok || uncompress(state.data(), &outLen, packed.data(), packed.size()) != Z_OK || outLen != state.size())
			throw FlycastException("Corrupted boot snapshot " + path);

		// The cabinet's own settings must survive the restore: system EEPROM (coin settings,
		// free play) and battery-backed SRAM (game settings, gun calibration, rankings).
		u8 userEeprom[128];
		std::vector<u8> userSram;
		const bool keepSettings = EEPROM != nullptr && eepromValid(EEPROM);
		if (keepSettings)
		{
			memcpy(userEeprom, EEPROM, sizeof(userEeprom));
			userSram.assign(nvmem::getFlashData(), nvmem::getFlashData() + settings.platform.flash_size);
		}
		Deserializer deser(state.data(), state.size());
		dc_deserialize(deser);
		mmu_set_state();
		if (keepSettings && EEPROM != nullptr)
		{
			memcpy(EEPROM, userEeprom, sizeof(userEeprom));
			if (userSram.size() == settings.platform.flash_size)
				memcpy(nvmem::getFlashData(), userSram.data(), userSram.size());
		}
		applyFreePlay();
		u8 *bios = nvmem::getBiosData();
		u32 off = 0;
		for (const Window& w : BIOS_WINDOWS)
		{
			memcpy(bios + w.start, window.data() + off, w.size);
			off += w.size;
		}
		NOTICE_LOG(BOOT, "AOT: booted from snapshot (BIOS-free), pc %08x", Sh4cntx.pc);
		applyGamePatches();
		return true;
	}
	if (!available && !captured && aot_game_info().valid && (pc & 0x1FFFFFFF) == aot_game_info().entry)
	{
		captured = true;
		struct PatchAfterCapture { ~PatchAfterCapture() { applyGamePatches(); applyFreePlay(); } } patchAfter;	// keep the snapshot pristine
		writeSnapshot(path);
	}
	return false;
}

bool aot_boot_pending()
{
	init();
	return available ? !restored : !captured;
}

bool aot_boot_bios_free()
{
	return restored;
}

bool aot_bios_window(u32 addr)
{
	for (const Window& w : BIOS_WINDOWS)
		if (addr >= w.start && addr < w.start + w.size)
			return true;
	return false;
}

// Game (re)load or machine reset: decide again between restoring and capturing a snapshot
void aot_boot_reset()
{
	checked = false;
}

// ---- Diagnostics: VNBA_POLY_LOG=file logs every polygon strip (screen space) ----
#include "hw/pvr/ta_ctx.h"
extern void (*vnba_poly_hook)(Vertex *v, u32 count, u32 listType, PolyParam *pp);
static FILE *polyLog;
#include "hw/sh4/sh4_sched.h"
static void polyLogHook(Vertex *v, u32 count, u32 listType, PolyParam *pp)
{
	static const u64 from = getenv("VNBA_POLY_LOG_FROM") ? atoll(getenv("VNBA_POLY_LOG_FROM")) * (SH4_MAIN_CLOCK / 60) : 0;
	static const u64 to = getenv("VNBA_POLY_LOG_TO") ? atoll(getenv("VNBA_POLY_LOG_TO")) * (SH4_MAIN_CLOCK / 60) : ~0ull;
	const u64 now = sh4_sched_now64();
	if (now < from || now > to)
		return;
	float x0 = v[0].x, x1 = v[0].x, y0 = v[0].y, y1 = v[0].y, z0 = v[0].z, z1 = v[0].z;
	for (u32 i = 1; i < count; i++)
	{
		x0 = std::min(x0, v[i].x); x1 = std::max(x1, v[i].x);
		y0 = std::min(y0, v[i].y); y1 = std::max(y1, v[i].y);
		z0 = std::min(z0, v[i].z); z1 = std::max(z1, v[i].z);
	}
	fprintf(polyLog, "L%u n%u x %.1f %.1f y %.1f %.1f z %g %g pcw %08x isp %08x tsp %08x tcw %08x\n", listType, count, x0, x1, y0, y1, z0, z1,
			pp->pcw.full, pp->isp.full, pp->tsp.full, pp->tcw.full);
}
static struct PolyLogInit {
	PolyLogInit() {
		if (const char *p = getenv("VNBA_POLY_LOG"))
		{
			polyLog = fopen(p, "w");
			vnba_poly_hook = polyLogHook;
			extern void (*vnba_sprite_hook)(Vertex *v, u32 count, u32 listType, PolyParam *pp);
			vnba_sprite_hook = polyLogHook;
		}
	}
} polyLogInit;

// Widescreen: the HUD of both games also uses ordinary polygons (score panels, speed meter)
// drawn at a constant, very near depth (1/w >= 1; the 3D scene is around 0.005). Squeeze them
// like the sprites so the whole HUD keeps its 4:3 proportions.
static void wsPolyHook(Vertex *v, u32 count, u32 listType, PolyParam *pp)
{
	const float z = v[0].z;
	static const bool dbg3 = getenv("VNBA_WS_DEBUG") && getenv("VNBA_WS_DEBUG")[0] == '3';
	if (dbg3 && count == 4 && z == 1.f)
		fprintf(stderr, "WS z1 x %.1f %.1f %.1f %.1f y %.1f %.1f %.1f %.1f z %g %g %g\n", v[0].x, v[1].x, v[2].x, v[3].x, v[0].y, v[1].y, v[2].y, v[3].y, v[1].z, v[2].z, v[3].z);
	float minx = v[0].x, maxx = v[0].x, miny = v[0].y, maxy = v[0].y;
	for (u32 i = 1; i < count; i++)
	{
		if (std::fabs(v[i].z - z) > z * 1e-4f)
			return;
		minx = std::min(minx, v[i].x);
		maxx = std::max(maxx, v[i].x);
		miny = std::min(miny, v[i].y);
		maxy = std::max(maxy, v[i].y);
	}
	extern float vnba_sprite_squeeze;
	static const bool dbgAll = getenv("VNBA_WS_DEBUG") && getenv("VNBA_WS_DEBUG")[0] == '2';
	if (dbgAll && maxx - minx > 300.f)
		fprintf(stderr, "WS flat n%u x %.1f-%.1f y %.1f-%.1f z %g\n", count, minx, maxx, miny, maxy, z);
	// Full-screen layers drawn through the 3D camera (VT1 attract blur / grey fade: flat quads
	// in front of the camera sized for the 4:3 view): with the 16:9 camera they cover only the
	// middle 3/4 of the frame. Widen them back to the full frame. Also full-width bands touching
	// the top or bottom edge (HOTD2 cutscene letterbox bars: z = 1, x 72.8-567.2).
	if ((miny <= 1.f || maxy >= 479.f) && std::fabs((minx + maxx) * 0.5f - 320.f) < 2.f
			&& minx > 1.f && maxx - minx >= 640.f * vnba_sprite_squeeze - 8.f)
	{
		for (u32 i = 0; i < count; i++)
			v[i].x = 320.f + (v[i].x - 320.f) / vnba_sprite_squeeze;
		static int dbg = getenv("VNBA_WS_DEBUG") ? 100000 : 0;
		if (dbg > 0) { dbg--; fprintf(stderr, "WS widen n%u x %.1f-%.1f z %g\n", count, minx, maxx, z); }
		return;
	}
	if (z < 1.f)
		return;
	if (minx <= 1.f && maxx >= 639.f)
		return;	// full-screen 2D layer (fade)
	for (u32 i = 0; i < count; i++)
		v[i].x = 320.f + (v[i].x - 320.f) * vnba_sprite_squeeze;
}


// --- Builder without a boot snapshot: BIOS on the dynarec ---------------------------------
bool aot_dynarec_boot_watch;
u32 aot_dynarec_boot_entry;

bool aot_generate_with_dynarec()
{
	static const bool v = [] {
		if (getenv("VNBA_GENERATE") == nullptr || getenv("VNBA_AOT_STATIC") == nullptr || getenv("VNBA_BIOS_BOOT") != nullptr)
			return false;
		std::string file;
		if (const char *p = getenv("VNBA_BOOT_SNAPSHOT"))
			file = p;
		else
			file = regionSnapshotPath(config::Region);
		return !validSnapshot(file);
	}();
	aot_dynarec_boot_watch = v;
	return v;
}

// Called by the dynarec when it first reaches the game entry point.
void aot_dynarec_entry_hook(u32 pc)
{
	aot_dynarec_boot_watch = false;
	Sh4cntx.pc = pc;
	aot_boot_hook(pc);	// saves the snapshot
	NOTICE_LOG(BOOT, "AOT: BIOS boot done on the dynarec, generating the game code");
	void aot_run_generation();
	aot_run_generation();
}
