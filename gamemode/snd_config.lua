--[[ Map + loadout config — IW4 (MW2) weapon classes
     REPLACES: gamemode/snd_config.lua ]]

SND.Config = SND.Config or {}

-- ── CoD4: Modern Warfare (IW3) ──────────────────────────────────────────
local IW3_AR = { "iw3_ak47", "iw3_g3", "iw3_g36c", "iw3_m14", "iw3_m16a4", "iw3_m4a1", "iw3_mp44" }
local IW3_SMG = { "iw3_skorpion", "iw3_p90", "iw3_mp5", "iw3_miniuzi", "iw3_ak74u" }
local IW3_LMG = { "iw3_m249", "iw3_m60e4", "iw3_rpd" }
local IW3_SG = { "iw3_m1014", "iw3_w1200" }
local IW3_SR = { "iw3_barrett", "iw3_dragunov", "iw3_m21", "iw3_m40a3", "iw3_r700" }
local IW3_PISTOLS = { "iw3_usp", "iw3_beretta", "iw3_colt45", "iw3_deserteagle" }
local IW3_LAUNCHERS = { "iw3_at4", "iw3_rpg" }

-- ── MW2: Modern Warfare 2 (IW4) ──────────────────────────────────────────
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

-- ── MW3: Modern Warfare 3 (IW5) ──────────────────────────────────────────
local IW5_AR = { "iw5_acr", "iw5_ak47", "iw5_cm901", "iw5_fad", "iw5_g36c", "iw5_m16a4", "iw5_m4a1", "iw5_mk14", "iw5_type95", "iw5_scar" }
local IW5_SMG = { "iw5_ak74u", "iw5_mp5", "iw5_mp7", "iw5_p90", "iw5_pm9", "iw5_ump45", "iw5_pp90m1" }
local IW5_LMG = { "iw5_sa80", "iw5_m60e4", "iw5_mg36", "iw5_mk46", "iw5_pecheneg" }
local IW5_SG = { "iw5_aa12", "iw5_ksg", "iw5_1887", "iw5_spas12", "iw5_striker", "iw5_usas12" }
local IW5_SR = { "iw5_rsass", "iw5_msr", "iw5_mk12spr", "iw5_l96a1", "iw5_dragunov", "iw5_barrett", "iw5_as50" }
local IW5_PISTOLS = { "iw5_anaconda", "iw5_deserteagle", "iw5_fiveseven", "iw5_mp412", "iw5_p99", "iw5_usp", "iw5_skorpion", "iw5_tmp", "iw5_glock", "iw5_fmg" }
local IW5_LAUNCHERS = { "iw5_xm25", "iw5_stinger", "iw5_smaw", "iw5_rpg", "iw5_m320", "iw5_javelin" }

-- ── Merged Secondaries ───────────────────────────────────────────────────
local PISTOLS = {}
table.Add(PISTOLS, IW3_PISTOLS)
table.Add(PISTOLS, { "iw4_anaconda", "iw4_deserteagle", "iw4_beretta", "iw4_usp", "iw4_glock", "iw4_raffica" })
table.Add(PISTOLS, IW5_PISTOLS)

-- ── Launchers — special slot, not given on spawn by default ───────────────
local LAUNCHERS = {}
table.Add(LAUNCHERS, IW3_LAUNCHERS)
table.Add(LAUNCHERS, { "iw4_at4", "iw4_javelin", "iw4_rpg", "iw4_stinger", "iw4_m79" })
table.Add(LAUNCHERS, IW5_LAUNCHERS)

-- Categorized Primary weapons for UI display
SND.Config.WeaponGroups = {
	-- COD4
	{ name = "CoD4: Assault Rifles", weapons = IW3_AR },
	{ name = "CoD4: SMGs", weapons = IW3_SMG },
	{ name = "CoD4: Sniper Rifles", weapons = IW3_SR },
	{ name = "CoD4: LMGs & Shotguns", weapons = table.Add(table.Copy(IW3_LMG), IW3_SG) },
	{ name = "CoD4: Pistols", weapons = IW3_PISTOLS, isSecondary = true },

	-- MW2
	{ name = "MW2: Assault Rifles", weapons = AR },
	{ name = "MW2: SMGs", weapons = SMG },
	{ name = "MW2: Sniper Rifles", weapons = SR },
	{ name = "MW2: LMGs", weapons = LMG },
	{ name = "MW2: Shotguns", weapons = SG },
	{ name = "MW2: Pistols", weapons = { "iw4_anaconda", "iw4_deserteagle", "iw4_beretta", "iw4_usp", "iw4_glock", "iw4_raffica" }, isSecondary = true },

	-- MW3
	{ name = "MW3: Assault Rifles", weapons = IW5_AR },
	{ name = "MW3: SMGs", weapons = IW5_SMG },
	{ name = "MW3: Sniper Rifles", weapons = IW5_SR },
	{ name = "MW3: LMGs & Shotguns", weapons = table.Add(table.Copy(IW5_LMG), IW5_SG) },
	
	{ name = "Miscellaneous", weapons = MISC },
}

-- ── Merged primary pool (everything that isn't a pistol or launcher) ──────
SND.Config.Mw2ePrimaries = {}
for _, group in ipairs(SND.Config.WeaponGroups) do
	for _, v in ipairs(group.weapons) do
		table.insert(SND.Config.Mw2ePrimaries, v)
	end
end

SND.Config.Mw2eSecondaries = PISTOLS
SND.Config.Mw2eSpecial     = LAUNCHERS   -- wire to pickups / data loadout if wanted

-- ── Default loadouts ──────────────────────────────────────────────────────
SND.Config.DefaultLoadouts = {
	attack = {
		random_primary   = true, -- Only applies to bots
		random_secondary = true, -- Only applies to bots
		primary          = "iw4_m4a1",
		secondary        = "iw4_deserteagle",
		lethal           = "weapon_frag",
		tactical         = "",
	},
	defend = {
		random_primary   = true, -- Only applies to bots
		random_secondary = true, -- Only applies to bots
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

SND.Config.MapSpawns = SND.Config.MapSpawns or {
	["ttt_rust_v2c"] = {
		defend = {
			{ pos = Vector(-2570.527588, 1319.567383, 147.059326), ang = Angle(0, 0, 0) },
			{ pos = Vector(-2570.527588, 1319.567383, 147.059326), ang = Angle(0, 0, 0) },
			{ pos = Vector(-2613.168457, 1399.106201, 140.516693), ang = Angle(0, 0, 0) },
			{ pos = Vector(-2690.790283, 1426.989746, 133.994644), ang = Angle(0, 0, 0) },
			{ pos = Vector(-2755.063721, 1428.191284, 135.288757), ang = Angle(0, 0, 0) },
			{ pos = Vector(-2829.149658, 1426.294434, 137.193253), ang = Angle(0, 0, 0) },
			{ pos = Vector(-2828.301514, 1363.662964, 142.696136), ang = Angle(0, 0, 0) },
		},
		attack = {
			{ pos = Vector(-4048.160645, 3264.419189, 143.669830), ang = Angle(0, 0, 0) },
			{ pos = Vector(-4118.790039, 3246.260498, 144.481812), ang = Angle(0, 0, 0) },
			{ pos = Vector(-4195.282715, 3239.670654, 148.363342), ang = Angle(0, 0, 0) },
			{ pos = Vector(-4188.635254, 3167.535889, 139.509430), ang = Angle(0, 0, 0) },
			{ pos = Vector(-4095.966553, 3167.609619, 139.759811), ang = Angle(0, 0, 0) },
			{ pos = Vector(-4046.409668, 3172.174805, 143.584793), ang = Angle(0, 0, 0) },
			{ pos = Vector(-4178.496094, 3059.424561, 138.180389), ang = Angle(0, 0, 0) },
		}
	}
}

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
