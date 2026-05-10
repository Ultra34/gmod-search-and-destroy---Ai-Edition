--[[ Map + loadout config — IW4 (MW2) weapon classes
     REPLACES: gamemode/snd_config.lua ]]

SND.Config = SND.Config or {}

-- ── ARC9: Black Ops Classic (arc9_bo1_*) ──────────────────────────────
SND.Config.BO1_AR = { "arc9_bo1_ak47", "arc9_bo1_m16", "arc9_bo1_famas", "arc9_bo1_galil", "arc9_bo1_aug", "arc9_bo1_commando", "arc9_bo1_g11", "arc9_bo1_enfield", "arc9_bo1_fal" }
SND.Config.BO1_SMG = { "arc9_bo1_mp5k", "arc9_bo1_uzi", "arc9_bo1_ak74u", "arc9_bo1_mpl", "arc9_bo1_pm63", "arc9_bo1_skorpion", "arc9_bo1_spectre" }
SND.Config.BO1_LMG = { "arc9_bo1_m60", "arc9_bo1_rpk", "arc9_bo1_hk21", "arc9_bo1_stoner63" }
SND.Config.BO1_SG = { "arc9_bo1_spas12", "arc9_bo1_ithaca", "arc9_bo1_olympia", "arc9_bo1_hs10" }
SND.Config.BO1_SR = { "arc9_bo1_l96a1", "arc9_bo1_dragunov", "arc9_bo1_psg1", "arc9_bo1_wa2000" }
SND.Config.BO1_PISTOLS = { "arc9_bo1_m1911", "arc9_bo1_python", "arc9_bo1_makarov", "arc9_bo1_cz75", "arc9_bo1_asp" }

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

	{ name = "Miscellaneous", weapons = { "arc9_mw3_riotshield" }, cid = "misc", icon = "game_icons/misc.png", default = "0" },
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

SND.Config.Mw2eSpecial     = {} -- Launchers not included in requested packs or handled separately

-- ── Default loadouts ──────────────────────────────────────────────────────
SND.Config.DefaultLoadouts = {
	attack = {
		random_primary   = true, -- Only applies to bots
		random_secondary = true, -- Only applies to bots
		primary          = "arc9_mw3_m4a1",
		secondary        = "arc9_mw3_usp",
		lethal           = "weapon_frag",
		tactical         = "",
	},
	defend = {
		random_primary   = true, -- Only applies to bots
		random_secondary = true, -- Only applies to bots
		primary          = "arc9_bo1_ak47",
		secondary        = "arc9_bo1_m1911",
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
table.RemoveByValue(SND.Config.BotPrimaries, "arc9_mw3_riotshield")

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
