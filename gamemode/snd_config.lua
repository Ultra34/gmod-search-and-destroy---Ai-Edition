--[[
	Map + loadout config. Copy to garrysmod/data/snd_mwclassic/ on server or override via ConVars.
	ARC9 weapon class names MUST match your MW Classic pack (spawn with gm_giveswep or ARC9 spawn menu to verify).
]]

SND.Config = SND.Config or {}

-- Default ARC9 class strings (placeholders — replace with your pack's printed class names)
SND.Config.DefaultLoadouts = {
	attack = {
		primary = "arc9_mwclassic_m4a1",
		secondary = "arc9_mwclassic_glock",
		lethal = "weapon_frag",
		tactical = "weapon_smokegrenade",
	},
	defend = {
		primary = "arc9_mwclassic_ak47",
		secondary = "arc9_mwclassic_usp",
		lethal = "weapon_frag",
		tactical = "weapon_smokegrenade",
	},
}

-- Maps that register bomb sites (add your snd_/de_ maps). Positions are approximate — tune per map.
SND.Config.MapSites = {
	["gm_construct"] = {
		{ id = "A", plantPos = Vector(-2176, -896, -144), defuseRadius = 96 },
		{ id = "B", plantPos = Vector(2176, 896, -144), defuseRadius = 96 },
	},
}

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
