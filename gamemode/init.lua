-- Mark all client-side and shared files for download
AddCSLuaFile("shared.lua")           -- Shared constants
AddCSLuaFile("cl_init.lua")           -- Client entry
AddCSLuaFile("cl_hud.lua")            -- HUD & Visuals
AddCSLuaFile("cl_settings.lua")       -- SuperAdmin UI
AddCSLuaFile("cl_levels.lua")         -- XP/Rank Client
AddCSLuaFile("cl_gunpicker.lua")      -- Loadout UI
AddCSLuaFile("cl_crosshair_menu.lua") -- Crosshair UI
AddCSLuaFile("cl_debug_menu.lua")     -- Debug UI
AddCSLuaFile("cl_sites.lua")          -- 3D Objective Markers
AddCSLuaFile("cl_mapvote.lua")        -- Map Vote UI
AddCSLuaFile("snd_settings.lua")      -- Replicated ConVars
AddCSLuaFile("snd_movement.lua")      -- Movement & Stamina logic
AddCSLuaFile("snd_teams.lua")         -- Faction logic
AddCSLuaFile("snd_bomb.lua")          -- Bomb logic
AddCSLuaFile("snd_round.lua")         -- Round manager

include("shared.lua")
include("snd_settings.lua")
include("snd_teams.lua")
include("snd_bomb.lua")
include("snd_round.lua")
include("snd_movement.lua")
include("snd_loadout.lua")
include("snd_mapvote.lua")
include("snd_announcer.lua")
include("bot_core.lua")
include("snd_spawns.lua")
include("snd_rust.lua")
include("snd_spectate.lua")
include("snd_sites_sv.lua")
include("snd_rules.lua")
include("snd_levels.lua")

-- Ensure the directory structure exists in garrysmod/data/
local DATA_FOLDERS = {"players", "banners", "emblems", "titles", "game_icons", "maps"}
local function initFilesystem()
    for _, folder in ipairs(DATA_FOLDERS) do
        if not file.IsDir("snd_mwclassic/" .. folder, "DATA") then
            file.CreateDir("snd_mwclassic/" .. folder)
        end
    end
end
initFilesystem()

-- Perform a write-access test to alert the user if the folder is read-only
local testPath = "snd_mwclassic/write_test.txt"
file.Write(testPath, "ok")
if file.Exists(testPath, "DATA") then
	file.Delete(testPath)
	print("[SND] Filesystem Check: Write access confirmed.")
else
	ErrorNoHalt("[SND] CRITICAL: Filesystem is READ-ONLY. Progress will not save!\n")
end

print("[SND] Core Match Engine Initialized.")

-- ── Network Registry ─────────────────────────────────────────────────────
util.AddNetworkString("SND_ShowCallingCard")
util.AddNetworkString("SND_KillFeed")
util.AddNetworkString("SND_SetEmblem")
util.AddNetworkString("SND_SetTitle")
util.AddNetworkString("SND_SetCallingCard")
util.AddNetworkString("SND_SetShowTitle")
util.AddNetworkString("SND_SetTitleMat")
util.AddNetworkString("SND_SetUseTitleMat")
util.AddNetworkString("SND_PlayerReady")
util.AddNetworkString("SND_SyncReadyState")
util.AddNetworkString("SND_QuickThrow")
util.AddNetworkString("SND_SelectLoadoutSlot")
util.AddNetworkString("SND_SaveLoadoutName")
util.AddNetworkString("SND_ClearLoadoutSlot")
util.AddNetworkString("SND_MinimapPing")
util.AddNetworkString("SND_NavData")
util.AddNetworkString("SND_SubmitMapVote")
util.AddNetworkString("SND_MapVoteSync")
util.AddNetworkString("SND_Halftime")
util.AddNetworkString("SND_QuickSwitch")

DEFINE_BASECLASS("gamemode_base")

function GM:Initialize()
	self.BaseClass.Initialize(self)
	SND.Config.LoadDataFile()
	team.SetUp(SND.TEAM_ATTACK, SND.Config.Factions.attack.name or "Attackers", Color(180, 90, 60))
	team.SetUp(SND.TEAM_DEFEND, SND.Config.Factions.defend.name or "Defenders", Color(70, 120, 200))
end

-- ── CoD Style Fall Damage ────────────────────────────────────────────────
function GM:GetFallDamage(ply, speed)
	-- Call of Duty typically allows falling from ~15-20ft safely.
	-- Lowered threshold to 500 to make it feel more "CoD-like" and dangerous.
	if speed < 500 then return 0 end

	-- If falling from an extreme height, it's an instant splat (1000+ velocity)
	if speed > 1000 then return 200 end

	-- Linear scaling between minimal pain and near-death
	return math.Remap(speed, 500, 1000, 30, 110)
end

local function sendNavToPlayer(ply)
	if not navmesh.IsLoaded() then 
		print("[SND] Minimap Warning: No nav mesh found. Use 'nav_generate' in console.")
		return 
	end

	local areas = navmesh.GetAllNavAreas()
	print("[SND] Minimap: Sending " .. #areas .. " nav areas to " .. ply:Nick())
	
	local data = {}
	for _, a in ipairs(areas) do
		local c1, c2 = a:GetCorner(0), a:GetCorner(2)
		-- Flattened data: x1, y1, x2, y2, z
		table.insert(data, math.Round(c1.x)) table.insert(data, math.Round(c1.y))
		table.insert(data, math.Round(c2.x)) table.insert(data, math.Round(c2.y))
		table.insert(data, math.Round(c1.z))
	end
	
	local compressed = util.Compress(util.TableToJSON(data))
	if compressed then
		net.Start("SND_NavData")
			net.WriteUInt(#compressed, 32)
			net.WriteData(compressed, #compressed)
		net.Send(ply)
	end
end

function GM:PlayerInitialSpawn(ply)
	self.BaseClass.PlayerInitialSpawn(self, ply)
	if not ply.SND_Joined then
		ply.SND_Joined = true
		ply:SetTeam(math.random(1, 2) == 1 and SND.TEAM_ATTACK or SND.TEAM_DEFEND)
		ply.SND_IsReady = false
	end
	
	-- Load Calling Card
	ply:SetNWString("SND_CardTitle", ply:GetPData("snd_card_title", "New Recruit"))
	local isBot = (ply:IsBot() or ply.SND_IsBot) -- Check if it's a bot
	ply:SetNWString("SND_CardMat", ply:GetPData("snd_card_mat", isBot and (SND.Config.DefaultBotBanner or "") or "")) -- Default to transparent for players/bots
	ply:SetNWBool("SND_ShowTitle", ply:GetPData("snd_show_title", "1") == "1")
	ply:SetNWBool("SND_UseTitleMat", ply:GetPData("snd_use_title_mat", "0") == "1")
	ply:SetNWString("SND_TitleMat", ply:GetPData("snd_title_mat", "vgui/white"))
	ply:SetNWString("SND_EmblemMat", ply:GetPData("snd_emblem_mat", isBot and (SND.Config.DefaultBotEmblem or "vgui/icon_skull") or "steam"))

	-- Load Active Loadout Slot choice
	local savedSlot = tonumber(ply:GetPData("snd_active_slot", "1")) or 1
	ply:SetNWInt("SND_ActiveLoadoutSlot", savedSlot)
    SND.Teams.ApplyFactionModel(ply)
    
    -- Delayed Data Sync for Client Readiness
    timer.Simple(1.5, function()
        if not IsValid(ply) then return end
        sendNavToPlayer(ply)
        SND.Round.Sync(ply)
        SND.Loadout.SendLoadoutData(ply)
    end)
end

function GM:PlayerSpawn(ply)
	self.BaseClass.PlayerSpawn(self, ply)
	if ply.UnSpectate then ply:UnSpectate() end
	ply.SND_SpecIdx = nil
	ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
	ply:SetAvoidPlayers(false)

	local walk = SND.Settings.GetInt("walk_speed", 190)
	local run = SND.Settings.GetInt("run_speed", 280)
	ply:SetWalkSpeed(walk)
	ply:SetRunSpeed(run)
	ply:SetJumpPower(160)
	ply:SetNWFloat("SND_Stamina", 1.0)

	SND.Teams.ApplyFactionModel(ply)
	SND.Movement.Setup(ply)
	SND.Loadout.Apply(ply)
	SND.Spawns.Apply(ply)
	SND.Bots.OnPlayerSpawn(ply)
end

local function sendSelfCallingCardUpdate(ply)
    if not IsValid(ply) then return end

    net.Start("SND_ShowCallingCard")
        net.WriteString(ply:Nick()) -- Killer's name (self)
        net.WriteString(ply:GetNWString("SND_CardTitle", "New Recruit"))
        net.WriteString(ply:GetNWString("SND_CardMat", "vgui/white"))
        net.WriteString(ply:GetNWString("SND_EmblemMat", "vgui/white"))
        net.WriteString(ply:SteamID64())
        net.WriteString(ply:Nick()) -- Victim's name (self)
        net.WriteUInt(ply:GetNWInt("SND_Level", 1), 16)
        net.WriteBool(ply:IsBot() or ply.SND_IsBot)
        net.WriteUInt(ply:Team(), 4)
        net.WriteBool(ply:GetNWBool("SND_ShowTitle", true))
        net.WriteBool(ply:GetNWBool("SND_UseTitleMat", false))
        net.WriteString(ply:GetNWString("SND_TitleMat", "vgui/white"))
        net.WriteBool(false) -- wasKiller: false, as it's not a kill event
    net.Send(ply)
end

net.Receive("SND_SetCallingCard", function(_, ply)
	local title = net.ReadString()
	local mat = net.ReadString()
	
	ply:SetNWString("SND_CardTitle", title)
	ply:SetNWString("SND_CardMat", mat)
	ply:SetPData("snd_card_title", title)
	ply:SetPData("snd_card_mat", mat)
	sendSelfCallingCardUpdate(ply)
end)

net.Receive("SND_SetEmblem", function(_, ply)
	local mat = net.ReadString()
	
	ply:SetNWString("SND_EmblemMat", mat)
	ply:SetPData("snd_emblem_mat", mat)
	sendSelfCallingCardUpdate(ply)
end)

net.Receive("SND_SetShowTitle", function(_, ply)
	local show = net.ReadBool()
	ply:SetNWBool("SND_ShowTitle", show)
	ply:SetPData("snd_show_title", show and "1" or "0")
	sendSelfCallingCardUpdate(ply)
end)

net.Receive("SND_SetUseTitleMat", function(_, ply)
	local useMat = net.ReadBool()
	ply:SetNWBool("SND_UseTitleMat", useMat)
	ply:SetPData("snd_use_title_mat", useMat and "1" or "0")
	sendSelfCallingCardUpdate(ply)
end)

net.Receive("SND_SetTitleMat", function(_, ply)
	local mat = net.ReadString()
	ply:SetNWString("SND_TitleMat", mat)
	ply:SetPData("snd_title_mat", mat)
	sendSelfCallingCardUpdate(ply)
end)




function GM:PlayerDeath(victim, inflictor, attacker)
	-- Drop weapons on death BEFORE they are stripped by the base gamemode
	for _, wep in ipairs(victim:GetWeapons()) do
		if IsValid(wep) then
			wep.SND_Dropped = true -- Mark for manual interaction
			victim:DropWeapon(wep)
		end
	end

	self.BaseClass.PlayerDeath(self, victim, inflictor, attacker)
	SND.Round.OnPlayerDeath(victim, attacker)
	SND.Announcer.OnDeathContext(victim, attacker)

	if IsValid(attacker) and attacker:IsPlayer() and attacker ~= victim then
		timer.Simple(0, function()
			if not IsValid(attacker) or not IsValid(victim) then return end
			-- 1. Send Attacker's Identity to Victim (The person who killed you)
			net.Start("SND_ShowCallingCard")
				net.WriteString(attacker:Nick())
				net.WriteString(attacker:GetNWString("SND_CardTitle", "New Recruit"))
				net.WriteString(attacker:GetNWString("SND_CardMat", "vgui/white"))
				net.WriteString(attacker:GetNWString("SND_EmblemMat", "vgui/white"))
				net.WriteString(attacker:SteamID64())
				net.WriteString(victim:Nick())
				net.WriteUInt(attacker:GetNWInt("SND_Level", 1), 16)
				net.WriteBool(attacker:IsBot() or attacker.SND_IsBot)
				net.WriteUInt(attacker:Team(), 4)
				net.WriteBool(attacker:GetNWBool("SND_ShowTitle", true))
				net.WriteBool(attacker:GetNWBool("SND_UseTitleMat", false))
				net.WriteString(attacker:GetNWString("SND_TitleMat", "vgui/white"))
				net.WriteBool(false) -- You were NOT the killer
			net.Send(victim)

			-- 2. Send Victim's Identity to Attacker (The person you just killed)
			net.Start("SND_ShowCallingCard")
				net.WriteString(victim:Nick())
				net.WriteString(victim:GetNWString("SND_CardTitle", "New Recruit"))
				net.WriteString(victim:GetNWString("SND_CardMat", "vgui/white"))
				net.WriteString(victim:GetNWString("SND_EmblemMat", "vgui/white"))
				net.WriteString(victim:SteamID64())
				net.WriteString(victim:Nick())
				net.WriteUInt(victim:GetNWInt("SND_Level", 1), 16)
				net.WriteBool(victim:IsBot() or victim.SND_IsBot)
				net.WriteUInt(victim:Team(), 4)
				net.WriteBool(victim:GetNWBool("SND_ShowTitle", true))
				net.WriteBool(victim:GetNWBool("SND_UseTitleMat", false))
				net.WriteString(victim:GetNWString("SND_TitleMat", "vgui/white"))
				net.WriteBool(true) -- You WERE the killer
			net.Send(attacker)

			-- Award XP for the kill (Team Check)
			if attacker:Team() ~= victim:Team() then
				local amount = 100
				if victim:LastHitGroup() == HITGROUP_HEAD then
					amount = amount + 50
				end
				SND.Levels.AddXP(attacker, amount)
			end
		end)
	end
end

-- ── Health Regeneration (CoD Style) ──────────────────────────────────────
hook.Add("Think", "SND_HealthRegen", function()
	local now = CurTime()
	for _, ply in ipairs(player.GetAll()) do
		if not ply:Alive() or ply:Health() >= 100 then continue end
		
		local lastDmg = ply.SND_LastDamageTime or 0
		local delay = SND.Settings.Get("health_regen_delay", 5)
		if now > lastDmg + delay then
			if not ply.SND_NextRegen or now > ply.SND_NextRegen then
				local rate = SND.Settings.Get("health_regen_rate", 5)
				ply:SetHealth(math.min(100, ply:Health() + rate))
				ply.SND_NextRegen = now + 0.1
			end
		end
	end
end)

-- ── Minimap Ping on Enemy Fire ───────────────────────────────────────────
hook.Add("EntityFireBullets", "SND_MinimapEnemyPing", function(ent, data)
    -- Only ping for valid, alive players firing damaging shots
    if not IsValid(ent) or not ent:IsPlayer() or not ent:Alive() then return end
    if data.Damage <= 0 then return end

    -- Debounce pings from the same player to prevent spamming
    local pingCooldown = 0.5 -- seconds between pings from one player
    if ent.SND_LastMinimapPing and CurTime() < ent.SND_LastMinimapPing + pingCooldown then return end
    ent.SND_LastMinimapPing = CurTime()

    local pingPos = ent:GetPos()
    local pingDuration = 1.5 -- seconds the ping remains visible

    for _, ply in ipairs(player.GetAll()) do
        -- Send ping only to enemies
        if IsValid(ply) and ply:Alive() and ply:Team() ~= ent:Team() then
            net.Start("SND_MinimapPing")
                net.WriteVector(pingPos)
                net.WriteFloat(pingDuration)
            net.Send(ply)
        end
    end
end)

hook.Add("EntityTakeDamage", "SND_RegenTracker", function(target, dmg)
	if IsValid(target) and target:IsPlayer() then
		target.SND_LastDamageTime = CurTime()
	end
end)

function GM:PlayerDeathThink(ply)
	if SND.Round.WaitingForSpawn(ply) then
		SND.Spectate.Ensure(ply)
		return true
	end
	return self.BaseClass.PlayerDeathThink(self, ply)
end

function GM:PlayerCanPickupWeapon(ply, wep)
	if SND.Round.Phase ~= SND.PHASE_LIVE and SND.Round.Phase ~= SND.PHASE_FREEZE then
		return false
	end
	-- Block automatic pickup for dropped weapons unless explicitly forced via swap logic
	if wep.SND_Dropped and not ply.SND_ForcedPickup then
		return false
	end
	return true
end

function GM:ShowTeamSpawns()
	return false
end

hook.Add("PlayerSay", "SND_AdminSettings", function(ply, text)
	if string.lower(text) == "!snd_settings" and ply:IsSuperAdmin() then
		ply:SendLua([[SND.OpenSettingsMenu()]])
		return ""
	end
end)

concommand.Add("snd_start_mapvote", function(ply)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	SND.MapVote.Start()
end)

util.AddNetworkString("SND_SetCvar")
net.Receive("SND_SetCvar", function(_, ply)
	if not IsValid(ply) or not ply:IsSuperAdmin() then return end
	local key = net.ReadString()
	local val = net.ReadString()
	if string.sub(key, 1, 4) ~= "snd_" then return end
	local cv = GetConVar(key)
	if not cv then return end
	local num = tonumber(val)
	if num then
		cv:SetFloat(num)
	else
		cv:SetString(val)
	end
end)

concommand.Add("snd_open_debug_menu", function(ply)
	if IsValid(ply) and ply:IsSuperAdmin() then
		ply:SendLua([[SND.OpenDebugMenu()]])
	end
end)

hook.Add("InitPostEntity", "SND_MapInitialization", function()
	if SERVER then
		-- Delay slightly to ensure filesystem readiness
		timer.Simple(1, function()
			local map = string.lower(game.GetMap())
			
			-- 1. Load existing data or initialize empty tables
			SND.Config.LoadMapOverrides(map)

			-- 2. Run fallbacks (like Rust auto-logic)
			SND.Rust.InitPostEntity()

			-- 3. Auto-create the .json file if it's missing
			local path = "snd_mwclassic/maps/" .. map .. ".json"
			file.CreateDir("snd_mwclassic/maps") -- Double check directory existence
			if not file.Exists(path, "DATA") then
				print("[SND] No map JSON config found. Auto-generating template for: " .. map)
				SND.Config.SaveMapData(map)
				
				-- Notify SuperAdmins in chat
				for _, p in ipairs(player.GetAll()) do
					if p:IsSuperAdmin() then p:ChatPrint("[SND] Created new map config: data/" .. path) end
				end
			end
			
			-- 5. Always ensure the map is in the voting rotation
			SND.Config.RegisterMapForVoting(map)
		end)
	end
end)

-- ── Disable Friendly Fire ────────────────────────────────────────────────
hook.Add("PlayerShouldTakeDamage", "SND_NoFriendlyFire", function(ply, attacker)
	if IsValid(attacker) and attacker:IsPlayer() and attacker:Team() == ply:Team() and attacker ~= ply then
		return false
	end
end)

-- ── Weapon Pickup/Swap Logic ──────────────────────────────────────────────
hook.Add("PlayerButtonDown", "SND_WeaponPickup", function(ply, btn)
	if btn ~= KEY_E then return end
	if not IsValid(ply) or not ply:Alive() then return end
	if SND.Round.Phase ~= SND.PHASE_LIVE and SND.Round.Phase ~= SND.PHASE_FREEZE then return end

	local tr = ply:GetEyeTrace()
	local ent = tr.Entity
	-- Allow interaction within 120 units
	if IsValid(ent) and ent:IsWeapon() and ent.SND_Dropped and tr.StartPos:DistToSqr(tr.HitPos) < 14400 then
		local class = ent:GetClass()
		local isPri = table.HasValue(SND.Config.Mw2ePrimaries or {}, class)
		local isSec = table.HasValue(SND.Config.Mw2eSecondaries or {}, class)
		
		if not isPri and not isSec then return end -- Ignore non-loadout weapons

		-- Identify current weapon in the corresponding slot to drop it
		local slotKey = isPri and "SND_Primary" or "SND_Secondary"
		local currentClass = ply:GetNWString(slotKey, "")
		local currentWep = ply:GetWeapon(currentClass)

		if IsValid(currentWep) then
			currentWep.SND_Dropped = true
			ply:DropWeapon(currentWep)
		end

		-- Enable forced pickup to bypass the CanPickup block
		ply.SND_ForcedPickup = true
		ply:PickupWeapon(ent)
		ply.SND_ForcedPickup = false

		-- Update network state so HUD and logic stay in sync
		ply:SetNWString(slotKey, class)
		
		-- Switch to the new weapon immediately
		ply:SelectWeapon(class)
		ply:EmitSound("items/ammo_pickup.wav", 65, 100)
	end
end)

-- ── Custom Loadout & Quick-Throw System (Server) ─────────────────────────
local function performQuickThrow(ply)
	if ply.SND_IsQuickThrowing then return end
	local lethal = ply:GetNWString("SND_Lethal", "")
	if lethal == "" or not ply:HasWeapon(lethal) then return end

	local current = ply:GetActiveWeapon()
	if not IsValid(current) or current:GetClass() == lethal then return end

	local oldWepClass = current:GetClass()
	ply.SND_IsQuickThrowing = true
	ply:SelectWeapon(lethal)

	-- Allow time for the grenade to deploy, then force the attack bit
	timer.Simple(0.45, function()
		if IsValid(ply) and ply:Alive() then
			local wep = ply:GetActiveWeapon()
			if IsValid(wep) and wep:GetClass() == lethal then
				ply.SND_ForceAttackGrenade = true
				-- Hold attack for 0.4s to ensure the weapon base registers the throw
				timer.Simple(0.4, function()
					if IsValid(ply) then ply.SND_ForceAttackGrenade = false end
				end)
			end
		end
	end)

	-- Switch back to previous weapon after the throw is guaranteed to be finished
	timer.Simple(1.6, function()
		if IsValid(ply) and ply:Alive() then
			if ply:HasWeapon(oldWepClass) then ply:SelectWeapon(oldWepClass) end
		end
		ply.SND_IsQuickThrowing = false
	end)
end

net.Receive("SND_QuickThrow", function(_, ply)
	if not IsValid(ply) or not ply:Alive() then return end
	performQuickThrow(ply)
end)

net.Receive("SND_QuickSwitch", function(_, ply)
	if not IsValid(ply) or not ply:Alive() then return end
	local slot = net.ReadUInt(2)
	if slot == 1 then
		local pri = ply:GetNWString("SND_Primary", "")
		if pri ~= "" then ply:SelectWeapon(pri) end
	elseif slot == 2 then
		local sec = ply:GetNWString("SND_Secondary", "")
		if sec ~= "" then ply:SelectWeapon(sec) end
	end

-- ── Admin Notification for Disabled Weapon Categories ───────────────────
hook.Add("PlayerInitialSpawn", "SND_AdminWeaponNotify", function(ply)
	timer.Simple(5, function()
		if not IsValid(ply) or not ply:IsSuperAdmin() then return end
		
		local disabled = {}
		for _, group in ipairs(SND.Config.WeaponGroups or {}) do
			if group.cid then
				local cv = GetConVar("snd_cat_" .. group.cid)
				if cv and not cv:GetBool() then
					table.insert(disabled, group.name)
				end
			end
		end
		
		if #disabled > 0 then
			ply:ChatPrint("[SND] ADMIN NOTICE: The following weapon pools are currently DISABLED:")
			for _, name in ipairs(disabled) do
				ply:ChatPrint(" - " .. name)
			end
			ply:ChatPrint("[SND] Use the Debug Menu (F4 -> Weapon Pools) to re-enable them.")
		end
	end)
end)
end)
