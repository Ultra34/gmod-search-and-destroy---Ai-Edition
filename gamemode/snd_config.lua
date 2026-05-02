--[[
	Map + loadout config. Copy to garrysmod/data/snd_mwclassic/ on server or override via ConVars.
	ARC9 MW2 Extended (arc9_mw2e_*) + one MW3 model1887 entry as provided — verify in spawn menu / gm_giveswep.
]]

SND.Config = SND.Config or {}

SND.Config.Mw2ePrimaries = {
	"arc9_mw2e_acr",
	"arc9_mw2e_ak47",
	"arc9_mw2e_f2000",
	"arc9_mw2e_fnfal",
	"arc9_mw2e_famas",
	"arc9_mw2e_m16a4",
	"arc9_mw2e_m4a1",
	"arc9_mw2e_scarh",
	"arc9_mw2e_tavor",
	"arc9_mw2e_aug",
	"arc9_mw2e_m240",
	"arc9_mw2e_mg4",
	"arc9_mw2e_m1014",
	"arc9_mw3e_m1887",
	"arc9_mw2e_akimbo_1887",
	"arc9_mw2e_ranger",
	"arc9_mw2e_spas12",
	"arc9_mw2e_cheytac",
	"arc9_mw2e_mp5k",
	"arc9_mw2e_pp2000",
	"arc9_mw2e_vector",
}

SND.Config.Mw2eSecondaries = {
	"arc9_mw2e_g17",
	"arc9_mw2e_mk23",
	"arc9_mw2e_m93r",
}

-- Launchers (not rolled into default random primary — wire pickups or data loadout if wanted)
SND.Config.Mw2eSpecial = {
	"arc9_mw2e_stinger",
	"arc9_mw2e_javelin",
	"arc9_mw2e_thumper",
}

--[[ Default loadouts: random primary + random secondary from pools unless snd_loadout_* ConVars set.
	Lethal uses stock frag unless your MW2 pack exposes an arc9 grenade class. ]]
SND.Config.DefaultLoadouts = {
	attack = {
		random_primary = true,
		random_secondary = true,
		primary = "arc9_mw2e_m4a1",
		secondary = "arc9_mw2e_g17",
		lethal = "weapon_frag",
		tactical = "",
	},
	defend = {
		random_primary = true,
		random_secondary = true,
		primary = "arc9_mw2e_ak47",
		secondary = "arc9_mw2e_mk23",
		lethal = "weapon_frag",
		tactical = "",
	},
}

-- Maps that register bomb sites (add your snd_/de_/ttt_ maps). Tune via data/snd_mwclassic/maps/<map>.lua or in-game calibration.
SND.Config.MapSites = {
	["gm_construct"] = {
		{ id = "A", plantPos = Vector(-2176, -896, -144), defuseRadius = 96 },
		{ id = "B", plantPos = Vector(2176, 896, -144), defuseRadius = 96 },
	},
}

--[[ Team spawn lists: [map] = { attack = { { pos=Vector, ang=Angle }, ... }, defend = { ... } }
	Filled by data file or auto-layout (e.g. Workshop ttt_rust_v1a). ]]
SND.Config.MapSpawns = SND.Config.MapSpawns or {}

-- Model paths for factions (change to your player models)
SND.Config.Factions = {
	attack = {
		name = "OpFor",
		models = {
			"models/player/group03/male_02.mdl",
			"models/player/group03/male_04.mdl",
		},
	},
	defend = {
		name = "TF141",
		models = {
			"models/player/group01/male_01.mdl",
			"models/player/group01/male_03.mdl",
		},
	},
}

-- Announcer sounds (place .wav/.mp3 under sound/snd_mwclassic/announcer/…)
SND.Config.Announcer = {
	prefix = "snd_mwclassic/announcer/",
	pack = "default",
	sounds = {
		round_start = "round_start.wav",
		bomb_planted = "bomb_planted.wav",
		bomb_defused = "bomb_defused.wav",
		last_alive = "last_alive.wav",
		attack_win = "attackers_win.wav",
		defend_win = "defenders_win.wav",
	},
}

function SND.Config.LoadDataFile()
	if not SERVER then return end
	local path = "snd_mwclassic/loadouts.lua"
	if file.Exists(path, "DATA") then
		local ok, err = pcall(function()
			RunString(file.Read(path, "DATA"), "snd_mwclassic/loadouts.lua")
		end)
		if not ok then
			print("[SND] Failed loading data loadouts: ", err)
		end
	end
end

--- Optional per-map overrides: garrysmod/data/snd_mwclassic/maps/<mapname>.lua returning { sites = {...}, spawns = {...} }
function SND.Config.LoadMapOverrides(map)
	if not SERVER or not map then return end
	local path = "snd_mwclassic/maps/" .. map .. ".lua"
	if not file.Exists(path, "DATA") then return end
	local src = file.Read(path, "DATA")
	if not src or src == "" then return end

	local fn = CompileString(src, path)
	if type(fn) ~= "function" then
		print("[SND] Map override compile error (" .. path .. "): ", fn)
		return
	end

	local ok, result = pcall(fn)
	if not ok then
		print("[SND] Map override run error: ", result)
		return
	end
	if type(result) ~= "table" then return end

	if result.sites and #result.sites > 0 then
		SND.Config.MapSites[map] = result.sites
		print("[SND] Loaded " .. #result.sites .. " bomb site(s) from data for " .. map)
	end
	if result.spawns and (result.spawns.attack or result.spawns.defend) then
		SND.Config.MapSpawns[map] = result.spawns
		print("[SND] Loaded team spawns from data for " .. map)
	end
end
