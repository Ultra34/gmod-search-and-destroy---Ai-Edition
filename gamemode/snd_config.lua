--[[ Map + loadout config — IW4 (MW2) weapon classes
     REPLACES: gamemode/snd_config.lua ]]

SND.Config = SND.Config or {}

-- ── ARC9: Black Ops Classic (arc9_bo1_*) ──────────────────────────────
SND.Config.BO1_AR = { "arc9_bo1_ultimate_ak", "arc9_bo1_aug", "arc9_bo1_xl60", "arc9_bo1_ultimate_ar15", "arc9_bo1_famas", "arc9_bo1_fal", "arc9_bo1_g11", "arc9_bo1_galil", "arc9_bo1_m14" }
SND.Config.BO1_SMG = { "arc9_bo1_kiparis", "arc9_bo1_mac11", "arc9_bo2_mp5", "arc9_bo1_mpl", "arc9_bo1_pm63", "arc9_bo1_skorpion", "arc9_bo1_spectre", "arc9_bo1_uzi" }
SND.Config.BO1_LMG = { "arc9_bo1_stoner", "arc9_bo2_rpd", "arc9_bo1_m60", "arc9_bo1_hk21" }
SND.Config.BO1_SG = { "arc9_bo1_hs10", "arc9_bo1_ks23", "arc9_bo1_olympia", "arc9_bo1_spas12", "arc9_bo1_ithaca" }
SND.Config.BO1_SR = { "arc9_bo1_wa2000", "arc9_bo1_g3", "arc9_bo1_l96", "arc9_bo1_dragunov", "arc9_bo2_m82" }
SND.Config.BO1_PISTOLS = { "arc9_bo1_asp", "arc9_bo2_browninghp", "arc9_bo1_cz75", "arc9_bo1_m1911", "arc9_bo1_makarov", "arc9_bo1_python" }

-- ── ARC9: Black Ops II (arc9_bo2_*) ──────────────────────────────────
SND.Config.BO2_AR = { "arc9_bo2_an94", "arc9_bo2_m27", "arc9_bo2_xm8", "arc9_bo2_mtar", "arc9_bo2_scarh", "arc9_bo2_smr", "arc9_bo2_stg44", "arc9_bo2_sig556", "arc9_bo2_type95" }
SND.Config.BO2_SMG = { "arc9_bo2_scorpion", "arc9_bo2_peacekeeper", "arc9_bo2_pdw57", "arc9_bo2_msmc", "arc9_bo2_mp7", "arc9_bo2_mp40", "arc9_bo2_thompson", "arc9_bo2_chicom", "arc9_bo2_vector" }
SND.Config.BO2_LMG = { "arc9_bo2_qbb", "arc9_bo2_mk48", "arc9_bo2_mg08", "arc9_bo2_lsat", "arc9_bo2_hamr" }
SND.Config.BO2_SG = { "arc9_bo2_ksg", "arc9_bo2_m1216", "arc9_bo2_r870", "arc9_bo2_s12", "arc9_bo2_blundergat" }
SND.Config.BO2_SR = { "arc9_bo2_ballista", "arc9_bo2_dsr50", "arc9_bo2_svu", "arc9_bo2_xpr50", "arc9_bo2_stormpsr" }
SND.Config.BO2_PISTOLS = { "arc9_bo2_b23r", "arc9_bo2_judge", "arc9_bo2_fiveseven", "arc9_bo2_kard", "arc9_bo2_c96", "arc9_bo2_nma", "arc9_bo2_fnp45" }

-- ── ARC9: World at War (arc9_waw_*) ──────────────────────────────────
SND.Config.WAW_AR = { "arc9_waw_stg44", "arc9_waw_garand", "arc9_waw_svt40", "arc9_waw_g43", "arc9_waw_carbine", "arc9_waw_fg42" }
SND.Config.WAW_SMG = { "arc9_waw_mp40", "arc9_waw_ppsh41", "arc9_waw_thompson", "arc9_waw_type100" }
SND.Config.WAW_LMG = { "arc9_waw_bar", "arc9_waw_m1919", "arc9_waw_dp28", "arc9_waw_mg42", "arc9_waw_type99lmg" }
SND.Config.WAW_SG = { "arc9_waw_doublebarrel", "arc9_waw_trenchgun" }
SND.Config.WAW_SR = { "arc9_waw_arisaka", "arc9_waw_k98k", "arc9_waw_mosin", "arc9_waw_springfield", "arc9_waw_ptrs41" }
SND.Config.WAW_PISTOLS = { "arc9_waw_p38", "arc9_waw_tt33", "arc9_waw_nambu", "arc9_waw_m1911", "arc9_waw_357" }

-- ── ARC9: CoD4 Extended (arc9_cod4e_*) ──────────────────────────────
SND.Config.COD4E_AR = { "arc9_cod4e_ak47", "arc9_cod4e_g3", "arc9_cod4e_g36c", "arc9_cod4e_m14", "arc9_cod4e_m4m16", "arc9_cod4e_mp44" }
SND.Config.COD4E_SMG = { "arc9_cod4e_ak74u", "arc9_cod4e_uzi", "arc9_cod4e_mp5", "arc9_cod4e_p90", "arc9_cod4e_skorpion" }
SND.Config.COD4E_LMG = { "arc9_cod4e_m249", "arc9_cod4e_m60", "arc9_cod4e_rpd" }
SND.Config.COD4E_SG = { "arc9_cod4e_m1014", "arc9_cod4e_w1200" }
SND.Config.COD4E_SR = { "arc9_cod4e_m82", "arc9_cod4e_dragunov", "arc9_cod4e_m40a3", "arc9_cod4e_r700" }
SND.Config.COD4E_PISTOLS = { "arc9_cod4e_usp", "arc9_cod4e_m9", "arc9_cod4e_m1911", "arc9_cod4e_deagle" }

-- ── ARC9: MW2 Extended (arc9_mw2e_*) ──────────────────────────────
SND.Config.MW2E_AR = { "arc9_mw2e_acr", "arc9_mw2e_ak47", "arc9_mw2e_f2000", "arc9_mw2e_fnfal", "arc9_mw2e_famas", "arc9_mw2e_m16a4", "arc9_mw2e_m4a1", "arc9_mw2e_scarh", "arc9_mw2e_tavor" }
SND.Config.MW2E_SMG = { "arc9_mw2e_mp5k", "arc9_mw2e_pp2000", "arc9_mw2e_vector" }
SND.Config.MW2E_LMG = { "arc9_mw2e_mg4", "arc9_mw2e_m240", "arc9_mw2e_aug" }
SND.Config.MW2E_SG = { "arc9_mw2e_m1014", "arc9_mw3e_m1887", "arc9_mw2e_akimbo_1887", "arc9_mw2e_ranger", "arc9_mw2e_spas12" }
SND.Config.MW2E_SR = { "arc9_mw2e_cheytac" }
SND.Config.MW2E_PISTOLS = { "arc9_mw2e_g17", "arc9_mw2e_mk23", "arc9_mw2e_m93r" }

-- ── ARC9: MW3 Extended (arc9_mw3e_*) ──────────────────────────────
SND.Config.MW3E_AR = { "arc9_mw3e_acr", "arc9_mw3e_cm901", "arc9_mw3e_fad", "arc9_mw3e_g36", "arc9_mw3e_m4a1", "arc9_mw3e_mk14", "arc9_mw3e_scarl", "arc9_mw3e_qbz97", "arc9_mw3e_m16a4" }
SND.Config.MW3E_SMG = { "arc9_mw3e_ump45", "arc9_mw3e_pp90m1", "arc9_mw3e_pm9", "arc9_mw3e_p90", "arc9_mw3e_mp7", "arc9_mw3e_mp5" }
SND.Config.MW3E_LMG = { "arc9_mw3e_pkp", "arc9_mw3e_mg36", "arc9_mw3e_mk46", "arc9_mw3e_m60", "arc9_mw3e_l86" }
SND.Config.MW3E_SG = { "arc9_mw3e_aa12", "arc9_mw3e_ksg12", "arc9_mw3e_striker", "arc9_mw3e_usas12" }
SND.Config.MW3E_SR = { "arc9_mw3e_rsass", "arc9_mw3e_msr", "arc9_mw3e_awm", "arc9_mw3e_dragunov", "arc9_mw3e_barrett", "arc9_mw3e_as50" }
SND.Config.MW3E_PISTOLS = { "arc9_mw3e_anaconda", "arc9_mw3e_deagle", "arc9_mw3e_fiveseven", "arc9_mw3e_mp412", "arc9_mw3e_p99", "arc9_mw3e_usp", "arc9_mw3e_fmg9", "arc9_mw3e_glock", "arc9_mw3e_mp9" }

-- ── ARC9: Modern Warfare Classic (arc9_mw3_*) ──────────────────────────
SND.Config.MW3_AR = { "arc9_mw3_acr", "arc9_mw3_m4a1", "arc9_mw3_ak47", "arc9_mw3_m16", "arc9_mw3_scar", "arc9_mw3_g36c", "arc9_mw3_cm901", "arc9_mw3_fad", "arc9_mw3_mk14", "arc9_mw3_type95" }
SND.Config.MW3_SMG = { "arc9_mw3_mp5", "arc9_mw3_ump45", "arc9_mw3_p90", "arc9_mw3_mp7", "arc9_mw3_pp90m1", "arc9_mw3_pm9" }
SND.Config.MW3_LMG = { "arc9_mw3_m60", "arc9_mw3_mg36", "arc9_mw3_pkp", "arc9_mw3_mk46", "arc9_mw3_l86" }
SND.Config.MW3_SG = { "arc9_mw3_spas12", "arc9_mw3_striker", "arc9_mw3_model1887", "arc9_mw3_aa12", "arc9_mw3_usas12", "arc9_mw3_ksg" }
SND.Config.MW3_SR = { "arc9_mw3_msr", "arc9_mw3_barrett", "arc9_mw3_l118a", "arc9_mw3_rsass", "arc9_mw3_as50" }
SND.Config.MW3_PISTOLS = { "arc9_mw3_usp", "arc9_mw3_p99", "arc9_mw3_magnum", "arc9_mw3_deserteagle", "arc9_mw3_fiveseven", "arc9_mw3_mp412", "arc9_mw3_glock", "arc9_mw3_fmg9" }

-- Categorized Primary weapons for UI display
SND.Config.WeaponGroups = {
	-- MW3 (Modern Warfare Classic)
	{ name = "MW Classic: Assault Rifles", weapons = SND.Config.MW3_AR, cid = "mw3_ar", icon = "game_icons/mw3.png" },
	{ name = "MW Classic: SMGs", weapons = SND.Config.MW3_SMG, cid = "mw3_smg", icon = "game_icons/mw3.png" },
	{ name = "MW Classic: Sniper Rifles", weapons = SND.Config.MW3_SR, cid = "mw3_sr", icon = "game_icons/mw3.png" },
	{ name = "MW Classic: LMGs", weapons = SND.Config.MW3_LMG, cid = "mw3_lmg", icon = "game_icons/mw3.png" },
	{ name = "MW Classic: Shotguns", weapons = SND.Config.MW3_SG, cid = "mw3_sg", icon = "game_icons/mw3.png" },
	{ name = "MW Classic: Pistols", weapons = SND.Config.MW3_PISTOLS, isSecondary = true, cid = "mw3_pistol", icon = "game_icons/mw3.png" },

	-- BO1 (Black Ops Classic)
	{ name = "BO Classic: Assault Rifles", weapons = SND.Config.BO1_AR, cid = "bo1_ar", icon = "game_icons/bo1.png" },
	{ name = "BO Classic: SMGs", weapons = SND.Config.BO1_SMG, cid = "bo1_smg", icon = "game_icons/bo1.png" },
	{ name = "BO Classic: Sniper Rifles", weapons = SND.Config.BO1_SR, cid = "bo1_sr", icon = "game_icons/bo1.png" },
	{ name = "BO Classic: LMGs", weapons = SND.Config.BO1_LMG, cid = "bo1_lmg", icon = "game_icons/bo1.png" },
	{ name = "BO Classic: Shotguns", weapons = SND.Config.BO1_SG, cid = "bo1_sg", icon = "game_icons/bo1.png" },
	{ name = "BO Classic: Pistols", weapons = SND.Config.BO1_PISTOLS, isSecondary = true, cid = "bo1_pistol", icon = "game_icons/bo1.png" },

	-- BO2 (Black Ops II)
	{ name = "Black Ops II: Assault Rifles", weapons = SND.Config.BO2_AR, cid = "bo2_ar", icon = "game_icons/bo2.png" },
	{ name = "Black Ops II: SMGs", weapons = SND.Config.BO2_SMG, cid = "bo2_smg", icon = "game_icons/bo2.png" },
	{ name = "Black Ops II: Sniper Rifles", weapons = SND.Config.BO2_SR, cid = "bo2_sr", icon = "game_icons/bo2.png" },
	{ name = "Black Ops II: LMGs", weapons = SND.Config.BO2_LMG, cid = "bo2_lmg", icon = "game_icons/bo2.png" },
	{ name = "Black Ops II: Shotguns", weapons = SND.Config.BO2_SG, cid = "bo2_sg", icon = "game_icons/bo2.png" },
	{ name = "Black Ops II: Pistols", weapons = SND.Config.BO2_PISTOLS, isSecondary = true, cid = "bo2_pistol", icon = "game_icons/bo2.png" },

	-- WaW (World at War)
	{ name = "World at War: Rifles", weapons = SND.Config.WAW_AR, cid = "waw_ar", icon = "game_icons/waw.png" },
	{ name = "World at War: SMGs", weapons = SND.Config.WAW_SMG, cid = "waw_smg", icon = "game_icons/waw.png" },
	{ name = "World at War: Sniper Rifles", weapons = SND.Config.WAW_SR, cid = "waw_sr", icon = "game_icons/waw.png" },
	{ name = "World at War: LMGs", weapons = SND.Config.WAW_LMG, cid = "waw_lmg", icon = "game_icons/waw.png" },
	{ name = "World at War: Shotguns", weapons = SND.Config.WAW_SG, cid = "waw_sg", icon = "game_icons/waw.png" },
	{ name = "World at War: Pistols", weapons = SND.Config.WAW_PISTOLS, isSecondary = true, cid = "waw_pistol", icon = "game_icons/waw.png" },

	-- CoD4E (CoD4 Extended)
	{ name = "CoD4 Extended: Assault Rifles", weapons = SND.Config.COD4E_AR, cid = "cod4e_ar", icon = "game_icons/cod4.png" },
	{ name = "CoD4 Extended: SMGs", weapons = SND.Config.COD4E_SMG, cid = "cod4e_smg", icon = "game_icons/cod4.png" },
	{ name = "CoD4 Extended: Sniper Rifles", weapons = SND.Config.COD4E_SR, cid = "cod4e_sr", icon = "game_icons/cod4.png" },
	{ name = "CoD4 Extended: LMGs", weapons = SND.Config.COD4E_LMG, cid = "cod4e_lmg", icon = "game_icons/cod4.png" },
	{ name = "CoD4 Extended: Shotguns", weapons = SND.Config.COD4E_SG, cid = "cod4e_sg", icon = "game_icons/cod4.png" },
	{ name = "CoD4 Extended: Pistols", weapons = SND.Config.COD4E_PISTOLS, isSecondary = true, cid = "cod4e_pistol", icon = "game_icons/cod4.png" },

	-- MW2E (MW2 Extended)
	{ name = "MW2 Extended: Assault Rifles", weapons = SND.Config.MW2E_AR, cid = "mw2e_ar", icon = "game_icons/mw2.png" },
	{ name = "MW2 Extended: SMGs", weapons = SND.Config.MW2E_SMG, cid = "mw2e_smg", icon = "game_icons/mw2.png" },
	{ name = "MW2 Extended: Sniper Rifles", weapons = SND.Config.MW2E_SR, cid = "mw2e_sr", icon = "game_icons/mw2.png" },
	{ name = "MW2 Extended: LMGs", weapons = SND.Config.MW2E_LMG, cid = "mw2e_lmg", icon = "game_icons/mw2.png" },
	{ name = "MW2 Extended: Shotguns", weapons = SND.Config.MW2E_SG, cid = "mw2e_sg", icon = "game_icons/mw2.png" },
	{ name = "MW2 Extended: Pistols", weapons = SND.Config.MW2E_PISTOLS, isSecondary = true, cid = "mw2e_pistol", icon = "game_icons/mw2.png" },

	-- MW3E (MW3 Extended)
	{ name = "MW3 Extended: Assault Rifles", weapons = SND.Config.MW3E_AR, cid = "mw3e_ar", icon = "game_icons/mw3.png" },
	{ name = "MW3 Extended: SMGs", weapons = SND.Config.MW3E_SMG, cid = "mw3e_smg", icon = "game_icons/mw3.png" },
	{ name = "MW3 Extended: Sniper Rifles", weapons = SND.Config.MW3E_SR, cid = "mw3e_sr", icon = "game_icons/mw3.png" },
	{ name = "MW3 Extended: LMGs", weapons = SND.Config.MW3E_LMG, cid = "mw3e_lmg", icon = "game_icons/mw3.png" },
	{ name = "MW3 Extended: Shotguns", weapons = SND.Config.MW3E_SG, cid = "mw3e_sg", icon = "game_icons/mw3.png" },
	{ name = "MW3 Extended: Pistols", weapons = SND.Config.MW3E_PISTOLS, isSecondary = true, cid = "mw3e_pistol", icon = "game_icons/mw3.png" },

	{ name = "Miscellaneous", weapons = { "arc9_mw3_riotshield", "arc9_mw3e_riotshield" }, cid = "misc", icon = "game_icons/misc.png", default = "0" },
}

-- ── Merged primary pool (everything that isn't a pistol or launcher) ──────
SND.Config.Mw2ePrimaries = {}
for _, group in ipairs(SND.Config.WeaponGroups) do
	if group.isSecondary then continue end
	for _, v in ipairs(group.weapons) do
		table.insert(SND.Config.Mw2ePrimaries, v)
	end
end

SND.Config.Mw2eSecondaries = {}
table.Add(SND.Config.Mw2eSecondaries, SND.Config.MW3_PISTOLS)
table.Add(SND.Config.Mw2eSecondaries, SND.Config.BO1_PISTOLS)
table.Add(SND.Config.Mw2eSecondaries, SND.Config.BO2_PISTOLS)
table.Add(SND.Config.Mw2eSecondaries, SND.Config.WAW_PISTOLS)
table.Add(SND.Config.Mw2eSecondaries, SND.Config.COD4E_PISTOLS)
table.Add(SND.Config.Mw2eSecondaries, SND.Config.MW2E_PISTOLS)
table.Add(SND.Config.Mw2eSecondaries, SND.Config.MW3E_PISTOLS)

SND.Config.Mw2eSpecial     = { "arc9_cod4e_rpg7", "arc9_cod4e_at4", "arc9_mw2e_stinger", "arc9_mw2e_javelin", "arc9_mw2e_thumper", "arc9_mw3e_m320glm", "arc9_mw3e_smaw", "arc9_mw3e_xm25", "arc9_bo2_fhj", "arc9_bo2_usrpg", "arc9_bo2_m32", "arc9_bo2_titus", "arc9_bo2_raygunmk2", "arc9_bo2_gau19", "arc9_waw_bazooka", "arc9_waw_panzerschreck", "arc9_waw_flamethrower", "arc9_bo1_raygun" }

-- ── Default loadouts ──────────────────────────────────────────────────────
SND.Config.DefaultLoadouts = {
	attack = {
		random_primary   = true, -- Only applies to bots
		random_secondary = true, -- Only applies to bots
		primary          = "arc9_bo1_ultimate_ak",
		secondary        = "arc9_bo1_python",
		lethal           = "arc9_bo1_m67frag",
		tactical         = "",
	},
	defend = {
		random_primary   = true, -- Only applies to bots
		random_secondary = true, -- Only applies to bots
		primary          = "arc9_bo1_ultimate_ar15",
		secondary        = "arc9_bo1_m1911",
		lethal           = "arc9_bo1_m67frag",
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
table.RemoveByValue(SND.Config.BotPrimaries, "arc9_mw3_riotshield")
table.RemoveByValue(SND.Config.BotPrimaries, "arc9_mw3e_riotshield")
table.RemoveByValue(SND.Config.BotPrimaries, "arc9_bo2_ballistic_shield")

SND.Config.BotSecondaries = table.Copy(SND.Config.Mw2eSecondaries)

-- ── Bomb sites ────────────────────────────────────────────────────────────
SND.Config.MapSites = SND.Config.MapSites or {}
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
	map = string.lower(tostring(map))
	local path = "snd_mwclassic/maps/" .. map .. ".json"

	-- Always initialize the tables in memory even if the file is missing
	SND.Config.MapSites[map] = {}
	SND.Config.MapSpawns[map] = { attack = {}, defend = {} }

	if not file.Exists(path, "DATA") then 
		-- Fallback to legacy .lua check for existing setups
		local legacy = "snd_mwclassic/maps/" .. map .. ".lua"
		if file.Exists(legacy, "DATA") then
			local fn = CompileString(file.Read(legacy, "DATA") or "", legacy)
			if type(fn) == "function" then
				local ok, res = pcall(fn)
				if ok and type(res) == "table" then
					SND.Config.MapSites[map] = res.sites or {}
					SND.Config.MapSpawns[map] = res.spawns or { attack = {}, defend = {} }
					print("[SND] Imported legacy Lua Map Config: " .. legacy)
					return
				end
			end
		end
		return 
	end

	local data = util.JSONToTable(file.Read(path, "DATA") or "{}")
	if not data then return end

	-- Convert JSON strings back to Vectors/Angles
	if data.sites then
		for _, s in ipairs(data.sites) do
			if s.plantPos then s.plantPos = Vector(s.plantPos) end
		end
	end
	if data.spawns then
		for team, spawnList in pairs(data.spawns) do
			for _, s in ipairs(spawnList) do
				if s.pos then s.pos = Vector(s.pos) end
				if s.ang then s.ang = Angle(s.ang) end
			end
		end
	end

	SND.Config.MapSites[map] = data.sites or {}
	SND.Config.MapSpawns[map] = data.spawns or { attack = {}, defend = {} }
	
	local sCount = #SND.Config.MapSites[map]
	local aCount = SND.Config.MapSpawns[map].attack and #SND.Config.MapSpawns[map].attack or 0
	local dCount = SND.Config.MapSpawns[map].defend and #SND.Config.MapSpawns[map].defend or 0
	
	print(string.format("[SND] Loaded Map Config (%s): %d Sites, %d Attack Spawns, %d Defend Spawns", map, sCount, aCount, dCount))
end

if SERVER then
	-- Create ConVars for weapon categories
	for _, group in ipairs(SND.Config.WeaponGroups) do
		if group.cid then
			local default = group.default or "1"
			CreateConVar("snd_cat_" .. group.cid, default, { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY })
		end
	end

	-- Automatically add a map name to the voting rotation file
	function SND.Config.RegisterMapForVoting(map)
		local path = "snd_mwclassic/maps.txt"
		local content = file.Exists(path, "DATA") and file.Read(path, "DATA") or ""

		local found = false
		for line in string.gmatch(content, "[^\r\n]+") do
			if string.Trim(line) == map then
				found = true
				break
			end
		end

		if not found then
			file.CreateDir("snd_mwclassic")
			local lastChar = string.sub(content, -1)
			local prefix = (content ~= "" and lastChar ~= "\n" and lastChar ~= "") and "\n" or ""
			file.Append(path, prefix .. map .. "\n")
			print("[SND] Map " .. map .. " auto-registered in maps.txt for voting.")
		end
	end

    function SND.Config.SaveMapData(map)
        map = string.lower(tostring(map))
        local sites = SND.Config.MapSites[map] or {}
        local spawns = SND.Config.MapSpawns[map] or { attack = {}, defend = {} }

		-- Prepare a clone for JSON serialization
		local saveObj = {
			sites = {},
			spawns = { attack = {}, defend = {} }
		}

		for _, s in ipairs(sites) do
			table.insert(saveObj.sites, {
				id = s.id,
				plantPos = tostring(s.plantPos or s.pos),
				defuseRadius = s.defuseRadius or 120
			})
		end

		for teamKey, spawnList in pairs(spawns) do
			for _, s in ipairs(spawnList or {}) do
				table.insert(saveObj.spawns[teamKey], {
					pos = tostring(s.pos),
					ang = tostring(s.ang)
				})
			end
		end

        local path = "snd_mwclassic/maps/" .. map .. ".json"
        local dir = string.GetPathFromFilename(path)
        if dir and dir ~= "" then file.CreateDir(dir) end

        file.Write(path, util.TableToJSON(saveObj, true))
        
        -- Verify the write worked and print success to console
        if file.Exists(path, "DATA") then
            print(string.format("[SND] SUCCESS: Saved %d Sites, %d Attack Spawns, %d Defend Spawns to %s", #saveObj.sites, #saveObj.spawns.attack, #saveObj.spawns.defend, path))
            
            -- Notify admins in-game
            for _, p in ipairs(player.GetAll()) do
                if p:IsSuperAdmin() then p:EmitSound("buttons/button14.wav", 60, 100) end
            end
        else
            print("[SND] CRITICAL ERROR: Failed to write file to DATA/" .. path .. ". Check folder permissions!")
        end

        -- Ensure this map is eligible for the end-of-match vote
        SND.Config.RegisterMapForVoting(map)
    end

	concommand.Add("snd_map_save", function(ply)
		if IsValid(ply) and not (ply:IsSuperAdmin() or ply:IsListenServerHost()) then return end
		SND.Config.SaveMapData(game.GetMap())
		if IsValid(ply) then ply:ChatPrint("[SND] Map configuration saved to disk.") end
	end)

	concommand.Add("snd_map_reload", function(ply)
		if IsValid(ply) and not (ply:IsSuperAdmin() or ply:IsListenServerHost()) then return end
		local map = game.GetMap()
		SND.Config.LoadMapOverrides(map)
		if SND.Sites and SND.Sites.Sync then SND.Sites.Sync() end
		if SND.Sites and SND.Sites.RefreshEntities then SND.Sites.RefreshEntities() end
	end)
end
