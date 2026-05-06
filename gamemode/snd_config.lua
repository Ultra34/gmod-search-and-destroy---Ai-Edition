--[[ Map + loadout config — IW4 (MW2) weapon classes
     REPLACES: gamemode/snd_config.lua ]]

SND.Config = SND.Config or {}

-- ── Assault Rifles ────────────────────────────────────────────────────────
local AR = {
	"iw4_acr",
	"iw4_ak47",
	"iw4_f2000",
	"iw4_fal",
	"iw4_famas",
	"iw4_m16a4",
	"iw4_m4a1",
	"iw4_scar",
	"iw4_tavor",
}

-- ── Light Machine Guns ────────────────────────────────────────────────────
local LMG = {
	"iw4_rpd",
	"iw4_mg4",
	"iw4_m240",
	"iw4_sa80",
}

-- ── Sub-Machine Guns ──────────────────────────────────────────────────────
local SMG = {
	"iw4_miniuzi",
	"iw4_mp5",
	"iw4_p90",
	"iw4_ump45",
	"iw4_vector",
	"iw4_pp2000",
	"iw4_tmp",
}

-- ── Shotguns ──────────────────────────────────────────────────────────────
local SG = {
	"iw4_aa12",
	"iw4_m1014",
	"iw4_1887",
	"iw4_ranger",
	"iw4_spas12",
	"iw4_striker",
}

-- ── Sniper Rifles ─────────────────────────────────────────────────────────
local SR = {
	"iw4_barrett",
	"iw4_dragunov",
	"iw4_cheytac",
	"iw4_m14ebr",
	"iw4_wa2000",
}

-- ── Other / Misc primaries ────────────────────────────────────────────────
local MISC = {
	"iw4_aug",        -- assault / scoped
	"iw4_riotshield",
}

-- ── Secondaries (pistols) ─────────────────────────────────────────────────
local PISTOLS = {
	"iw4_anaconda",
	"iw4_deserteagle",
	"iw4_beretta",
	"iw4_usp",
	"iw4_glock",
	"iw4_raffica",
}

-- ── Launchers — special slot, not given on spawn by default ───────────────
local LAUNCHERS = {
	"iw4_at4",
	"iw4_javelin",
	"iw4_rpg",
	"iw4_stinger",
	"iw4_m79",
}

-- ── Merged primary pool (everything that isn't a pistol or launcher) ──────
SND.Config.Mw2ePrimaries = {}
for _, t in ipairs({ AR, LMG, SMG, SG, SR, MISC }) do
	for _, v in ipairs(t) do
		table.insert(SND.Config.Mw2ePrimaries, v)
	end
end

SND.Config.Mw2eSecondaries = PISTOLS
SND.Config.Mw2eSpecial     = LAUNCHERS   -- wire to pickups / data loadout if wanted

-- ── Default loadouts ──────────────────────────────────────────────────────
SND.Config.DefaultLoadouts = {
	attack = {
		random_primary   = true,
		random_secondary = true,
		primary          = "iw4_m4a1",
		secondary        = "iw4_deserteagle",
		lethal           = "weapon_frag",
		tactical         = "",
	},
	defend = {
		random_primary   = true,
		random_secondary = true,
		primary          = "iw4_ak47",
		secondary        = "iw4_usp",
		lethal           = "weapon_frag",
		tactical         = "",
	},
}

-- ── Loadout Slot Requirements ─────────────────────────────────────────────
SND.Config.SlotLevels = {
	1, 1, 5, 10, 15, 20, 25, 30, 40, 50 -- Slots 1-10 requirements
}

-- ── Bot loadout pools (no snipers / riot shield — keeps AI sane) ──────────
SND.Config.BotPrimaries = table.Copy(SND.Config.Mw2ePrimaries)
-- Remove riot shield from bots to prevent AI navigation issues
table.RemoveByValue(SND.Config.BotPrimaries, "iw4_riotshield")

SND.Config.BotSecondaries = table.Copy(SND.Config.Mw2eSecondaries)

-- ── Bomb sites ────────────────────────────────────────────────────────────
SND.Config.MapSites = {
	["ttt_rust_v1a"] = {
		{ id = "A", plantPos = Vector(1116, 912, -159), defuseRadius = 120 },
		{ id = "B", plantPos = Vector(10, 10, -159), defuseRadius = 120 },
	},
	["ttt_rust_v2c"] = {
		{ id = "A", plantPos = Vector(1116, 912, -159), defuseRadius = 120 },
		{ id = "B", plantPos = Vector(10, 10, -159), defuseRadius = 120 },
	}
}

SND.Config.MapSpawns = SND.Config.MapSpawns or {}

-- ── CSS faction models ────────────────────────────────────────────────────
SND.Config.Factions = {
	attack = {
		name   = "Terrorists",
		models = {
			"models/player/t_phoenix.mdl",
			"models/player/t_leet.mdl",
			"models/player/t_guerilla.mdl",
			"models/player/t_arctic.mdl",
		},
	},
	defend = {
		name   = "Counter-Terrorists",
		models = {
			"models/player/ct_urban.mdl",
			"models/player/ct_gign.mdl",
			"models/player/ct_sas.mdl",
			"models/player/ct_gsg9.mdl",
		},
	},
}

-- ── Default Bot Identity ────────────────────────────────────────────────
SND.Config.DefaultBotBanner = "" -- Transparent by default, relies on HUD's grey background
SND.Config.DefaultBotEmblem = "data/snd_mwclassic/emblems/bot_emblem.png"

-- ── Announcer ─────────────────────────────────────────────────────────────
SND.Config.Announcer = {
	prefix = "snd_mwclassic/announcer/",
	pack   = "default",
	sounds = {
		round_start  = "round_start.wav",
		bomb_planted = "bomb_planted.wav",
		bomb_defused = "bomb_defused.wav",
		last_alive   = "last_alive.wav",
		attack_win   = "attackers_win.wav",
		defend_win   = "defenders_win.wav",
	},
}

-- ── Data file loaders (unchanged) ─────────────────────────────────────────
function SND.Config.LoadDataFile()
	if not SERVER then return end
	local path = "snd_mwclassic/loadouts.lua"
	if file.Exists(path, "DATA") then
		local ok, err = pcall(function()
			RunString(file.Read(path, "DATA"), "snd_mwclassic/loadouts.lua")
		end)
		if not ok then print("[SND] Failed loading data loadouts: ", err) end
	end
end

function SND.Config.LoadMapOverrides(map)
	if not SERVER or not map then return end
	local path = "snd_mwclassic/maps/" .. map .. ".lua"
	if not file.Exists(path, "DATA") then return end
	local src = file.Read(path, "DATA")
	if not src or src == "" then return end
	local fn = CompileString(src, path)
	if type(fn) ~= "function" then
		print("[SND] Map override compile error (" .. path .. "): ", fn) return
	end
	local ok, result = pcall(fn)
	if not ok then print("[SND] Map override run error: ", result) return end
	if type(result) ~= "table" then return end
	if result.sites and #result.sites > 0 then
		SND.Config.MapSites[map] = result.sites
		print("[SND] Loaded " .. #result.sites .. " site(s) for " .. map)
	end
	if result.spawns and (result.spawns.attack or result.spawns.defend) then
		SND.Config.MapSpawns[map] = result.spawns
		print("[SND] Loaded spawns for " .. map)
	end
end
