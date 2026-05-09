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

-- ── World at War (Robotnik) ─────────────────────────────────────────────
local WAW_AR = { "robotnik_waw_stg", "robotnik_waw_grd", "robotnik_waw_g43", "robotnik_waw_svt", "robotnik_waw_crb", "robotnik_waw_t99", "robotnik_waw_bar" }
local WAW_SMG = { "robotnik_waw_mp40", "robotnik_waw_ppsh", "robotnik_waw_tom", "robotnik_waw_tomd", "robotnik_waw_t100" }
local WAW_LMG = { "robotnik_waw_mg42", "robotnik_waw_fg", "robotnik_waw_30c", "robotnik_waw_dp", "robotnik_waw_mgm" }
local WAW_SG = { "robotnik_waw_tg", "robotnik_waw_db" }
local WAW_SR = { "robotnik_waw_kar_s", "robotnik_waw_moss", "robotnik_waw_spr_s", "robotnik_waw_ptrs", "robotnik_waw_ari_s", "robotnik_waw_kar_i", "robotnik_waw_mosi", "robotnik_waw_spr_i", "robotnik_waw_ari" }
local WAW_PISTOLS = { "robotnik_waw_1911", "robotnik_waw_p38", "robotnik_waw_tok", "robotnik_waw_nbu" }

-- ── Black Ops (BO1) ─────────────────────────────────────────────────────
local BO1_AR = { "robotnik_bo1_ak47", "robotnik_bo1_aug", "robotnik_bo1_com", "robotnik_bo1_en", "robotnik_bo1_fms", "robotnik_bo1_fal", "robotnik_bo1_g11", "robotnik_bo1_gal", "robotnik_bo1_m14", "robotnik_bo1_16" }
local BO1_SMG = { "robotnik_bo1_74u", "robotnik_bo1_74g", "robotnik_bo1_ki", "robotnik_bo1_m11", "robotnik_bo1_mp5", "robotnik_bo1_mpl", "robotnik_bo1_pm", "robotnik_bo1_skrp", "robotnik_bo1_uzi", "robotnik_bo1_spc" }
local BO1_LMG = { "robotnik_bo1_hk", "robotnik_bo1_m60", "robotnik_bo1_rpk", "robotnik_bo1_stn" }
local BO1_SG = { "robotnik_bo1_h10", "robotnik_bo1_ol", "robotnik_bo1_sps", "robotnik_bo1_so", "robotnik_bo1_sog" }
local BO1_SR = { "robotnik_bo1_drg", "robotnik_bo1_l96", "robotnik_bo1_psg", "robotnik_bo1_wa" }
local BO1_PISTOLS = { "robotnik_bo1_py", "robotnik_bo1_mak", "combine_pk_m1911", "robotnik_bo1_1911", "robotnik_bo1_cz", "robotnik_bo1_asp" }

-- ── Black Ops II (BO2) ──────────────────────────────────────────────────
local BO2_AR = { "mac_bo2_an94", "mac_bo2_falosw", "mac_bo2_hk416", "mac_bo2_m8a1", "mac_bo2_mtar", "mac_bo2_scar", "mac_bo2_smr", "mac_bo2_swat", "mac_bo2_type25" }
local BO2_SMG = { "mac_bo2_chicom", "mac_bo2_mp7", "mac_bo2_msmc", "mac_bo2_pdw", "mac_bo2_peacekpr", "mac_bo2_scorp", "mac_bo2_vector" }
local BO2_LMG = { "mac_bo2_hamr", "mac_bo2_lsat", "mac_bo2_mk48", "mac_bo2_qbblsw" }
local BO2_SG = { "mac_bo2_ksg", "mac_bo2_m1216", "mac_bo2_870", "mac_bo2_s12" }
local BO2_SR = { "mac_bo2_ballista", "mac_bo2_dsr50", "mac_bo2_svu", "mac_bo2_xpr50" }
local BO2_PISTOLS = { "mac_bo2_tac45", "mac_bo2_kard", "mac_bo2_five7", "mac_bo2_exec", "mac_bo2_b23r" }

-- ── Special Weapons ─────────────────────────────────────────────────────
local SPECIAL = { "mac_bo2_deathmach", "mac_bo2_balknife", "mac_bo2_crssbw_f", "robotnik_bo1_dm", "robotnik_bo1_cb", "robotnik_bo1_bk", "robotnik_waw_rg", "robotnik_waw_m2" }

-- ── Merged Secondaries ───────────────────────────────────────────────────
local PISTOLS = {}
table.Add(PISTOLS, IW3_PISTOLS)
table.Add(PISTOLS, { "iw4_anaconda", "iw4_deserteagle", "iw4_beretta", "iw4_usp", "iw4_glock", "iw4_raffica" })
table.Add(PISTOLS, IW5_PISTOLS)
table.Add(PISTOLS, WAW_PISTOLS)
table.Add(PISTOLS, BO1_PISTOLS)
table.Add(PISTOLS, BO2_PISTOLS)

-- ── Launchers — special slot, not given on spawn by default ───────────────
local LAUNCHERS = {}
table.Add(LAUNCHERS, IW3_LAUNCHERS)
table.Add(LAUNCHERS, { "iw4_at4", "iw4_javelin", "iw4_rpg", "iw4_stinger", "iw4_m79" })
table.Add(LAUNCHERS, IW5_LAUNCHERS)
table.Add(LAUNCHERS, { "mac_bo2_usrpg", "mac_bo2_smaw", "mac_bo2_warmach", "robotnik_bo1_cl", "robotnik_bo1_202", "robotnik_bo1_law", "robotnik_bo1_rpg", "robotnik_waw_baz", "robotnik_waw_pzsk" })

-- Categorized Primary weapons for UI display
SND.Config.WeaponGroups = {
	-- COD4
	{ name = "CoD4: Assault Rifles", weapons = IW3_AR, cid = "cod4_ar", icon = "game_icons/cod4.png" },
	{ name = "CoD4: SMGs", weapons = IW3_SMG, cid = "cod4_smg", icon = "game_icons/cod4.png" },
	{ name = "CoD4: Sniper Rifles", weapons = IW3_SR, cid = "cod4_sr", icon = "game_icons/cod4.png" },
	{ name = "CoD4: LMGs & Shotguns", weapons = table.Add(table.Copy(IW3_LMG), IW3_SG), cid = "cod4_lmg", icon = "game_icons/cod4.png" },
	{ name = "CoD4: Pistols", weapons = IW3_PISTOLS, isSecondary = true, cid = "cod4_pistol", icon = "game_icons/cod4.png" },

	-- MW2
	{ name = "MW2: Assault Rifles", weapons = AR, cid = "mw2_ar", icon = "game_icons/mw2.png" },
	{ name = "MW2: SMGs", weapons = SMG, cid = "mw2_smg", icon = "game_icons/mw2.png" },
	{ name = "MW2: Sniper Rifles", weapons = SR, cid = "mw2_sr", icon = "game_icons/mw2.png" },
	{ name = "MW2: LMGs", weapons = LMG, cid = "mw2_lmg", icon = "game_icons/mw2.png" },
	{ name = "MW2: Shotguns", weapons = SG, cid = "mw2_sg", icon = "game_icons/mw2.png" },
	{ name = "MW2: Pistols", weapons = { "iw4_anaconda", "iw4_deserteagle", "iw4_beretta", "iw4_usp", "iw4_glock", "iw4_raffica" }, isSecondary = true, cid = "mw2_pistol", icon = "game_icons/mw2.png" },

	-- MW3
	{ name = "MW3: Assault Rifles", weapons = IW5_AR, cid = "mw3_ar", icon = "game_icons/mw3.png" },
	{ name = "MW3: SMGs", weapons = IW5_SMG, cid = "mw3_smg", icon = "game_icons/mw3.png" },
	{ name = "MW3: Sniper Rifles", weapons = IW5_SR, cid = "mw3_sr", icon = "game_icons/mw3.png" },
	{ name = "MW3: LMGs & Shotguns", weapons = table.Add(table.Copy(IW5_LMG), IW5_SG), cid = "mw3_lmg", icon = "game_icons/mw3.png" },

	-- World at War
	{ name = "WaW: Rifles", weapons = WAW_AR, cid = "waw_ar", icon = "game_icons/waw.png" },
	{ name = "WaW: SMGs", weapons = WAW_SMG, cid = "waw_smg", icon = "game_icons/waw.png" },
	{ name = "WaW: Sniper Rifles", weapons = WAW_SR, cid = "waw_sr", icon = "game_icons/waw.png" },
	{ name = "WaW: LMGs & Shotguns", weapons = table.Add(table.Copy(WAW_LMG), WAW_SG), cid = "waw_lmg", icon = "game_icons/waw.png" },
	{ name = "WaW: Pistols", weapons = WAW_PISTOLS, isSecondary = true, cid = "waw_pistol", icon = "game_icons/waw.png" },

	-- Black Ops
	{ name = "BO1: Assault Rifles", weapons = BO1_AR, cid = "bo1_ar", icon = "game_icons/bo1.png" },
	{ name = "BO1: SMGs", weapons = BO1_SMG, cid = "bo1_smg", icon = "game_icons/bo1.png" },
	{ name = "BO1: Sniper Rifles", weapons = BO1_SR, cid = "bo1_sr", icon = "game_icons/bo1.png" },
	{ name = "BO1: LMGs & Shotguns", weapons = table.Add(table.Copy(BO1_LMG), BO1_SG), cid = "bo1_lmg", icon = "game_icons/bo1.png" },
	{ name = "BO1: Pistols", weapons = BO1_PISTOLS, isSecondary = true, cid = "bo1_pistol", icon = "game_icons/bo1.png" },

	-- Black Ops II
	{ name = "BO2: Assault Rifles", weapons = BO2_AR, cid = "bo2_ar", icon = "game_icons/bo2.png" },
	{ name = "BO2: SMGs", weapons = BO2_SMG, cid = "bo2_smg", icon = "game_icons/bo2.png" },
	{ name = "BO2: Sniper Rifles", weapons = BO2_SR, cid = "bo2_sr", icon = "game_icons/bo2.png" },
	{ name = "BO2: LMGs & Shotguns", weapons = table.Add(table.Copy(BO2_LMG), BO2_SG), cid = "bo2_lmg", icon = "game_icons/bo2.png" },
	{ name = "BO2: Pistols", weapons = BO2_PISTOLS, isSecondary = true, cid = "bo2_pistol", icon = "game_icons/bo2.png" },
	
	{ name = "Special: Weapons", weapons = SPECIAL, cid = "special", icon = "game_icons/special.png" },
	{ name = "Miscellaneous", weapons = MISC, cid = "misc", icon = "game_icons/misc.png" },
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
			CreateConVar("snd_cat_" .. group.cid, "1", { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY })
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
