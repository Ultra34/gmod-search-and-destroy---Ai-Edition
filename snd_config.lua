--[[
	Map + loadout config.
	CHANGES vs original:
	  - Faction models swapped to Counter-Strike: Source player models
	  - All other settings unchanged so existing weapon pools / sites still work
]]
-- REPLACES: gamemode/snd_config.lua

SND.Config = SND.Config or {}

-- ── ARC9 MW2 weapon pools (unchanged from original) ──────────────────────
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

SND.Config.Mw2eSpecial = {
	"arc9_mw2e_stinger",
	"arc9_mw2e_javelin",
	"arc9_mw2e_thumper",
}

-- ── Default loadouts (unchanged) ──────────────────────────────────────────
SND.Config.DefaultLoadouts = {
	attack = {
		random_primary   = true,
		random_secondary = true,
		primary          = "arc9_mw2e_m4a1",
		secondary        = "arc9_mw2e_g17",
		lethal           = "weapon_frag",
		tactical         = "",
	},
	defend = {
		random_primary   = true,
		random_secondary = true,
		primary          = "arc9_mw2e_ak47",
		secondary        = "arc9_mw2e_mk23",
		lethal           = "weapon_frag",
		tactical         = "",
	},
}

-- ── Bomb sites (unchanged) ────────────────────────────────────────────────
SND.Config.MapSites = {
	["gm_construct"] = {
		{ id = "A", plantPos = Vector(-2176, -896, -144), defuseRadius = 96 },
		{ id = "B", plantPos = Vector(2176,   896, -144), defuseRadius = 96 },
	},
}

SND.Config.MapSpawns = SND.Config.MapSpawns or {}

-- ── CSS PLAYER MODELS ─────────────────────────────────────────────────────
-- These ship with Counter-Strike: Source which Garry's Mod can mount.
-- If you don't have CS:S mounted the models will show as ERROR — either
-- mount CS:S in GMod options, or replace the paths with any installed models.
--
-- Attackers  → Terrorist faction models (T-side)
-- Defenders  → Counter-Terrorist faction models (CT-side)
SND.Config.Factions = {
	attack = {
		name   = "Terrorists",
		models = {
			"models/player/t_phoenix.mdl",   -- Phoenix Connexion (red)
			"models/player/t_leet.mdl",      -- Elite Crew
			"models/player/t_guerilla.mdl",  -- Guerilla Warfare
			"models/player/t_arctic.mdl",    -- Arctic Avengers
		},
	},
	defend = {
		name   = "Counter-Terrorists",
		models = {
			"models/player/ct_urban.mdl",    -- SEAL Team 6 / Urban
			"models/player/ct_gign.mdl",     -- GIGN (French)
			"models/player/ct_sas.mdl",      -- SAS (British)
			"models/player/ct_gsg9.mdl",     -- GSG-9 (German)
		},
	},
}

-- ── Announcer (unchanged) ─────────────────────────────────────────────────
SND.Config.Announcer = {
	prefix = "snd_mwclassic/announcer/",
	pack   = "default",
	sounds = {
		round_start   = "round_start.wav",
		bomb_planted  = "bomb_planted.wav",
		bomb_defused  = "bomb_defused.wav",
		last_alive    = "last_alive.wav",
		attack_win    = "attackers_win.wav",
		defend_win    = "defenders_win.wav",
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
		print("[SND] Map override compile error (" .. path .. "): ", fn)
		return
	end

	local ok, result = pcall(fn)
	if not ok then print("[SND] Map override run error: ", result) return end
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
