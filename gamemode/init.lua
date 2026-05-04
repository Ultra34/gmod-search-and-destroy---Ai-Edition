-- Mark all client-side and shared files for download
AddCSLuaFile("shared.lua")           -- Shared constants
AddCSLuaFile("cl_init.lua")           -- Client entry
AddCSLuaFile("cl_hud.lua")            -- HUD & Visuals
AddCSLuaFile("cl_settings.lua")       -- SuperAdmin UI
AddCSLuaFile("cl_levels.lua")         -- XP/Rank Client
AddCSLuaFile("cl_crosshair_menu.lua") -- Crosshair UI
AddCSLuaFile("snd_settings.lua")      -- Replicated ConVars
AddCSLuaFile("snd_bot_anim.lua")      -- Animation Fixes
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
include("snd_bots.lua")
include("snd_spawns.lua")
include("snd_rust.lua")
include("snd_spectate.lua")
include("snd_bot_anim.lua")
include("snd_levels.lua")

-- Ensure the directory structure exists in garrysmod/data/
file.CreateDir("snd_mwclassic/players")
file.CreateDir("snd_mwclassic/banners")
file.CreateDir("snd_mwclassic/emblems")
file.CreateDir("snd_mwclassic/titles")

print("[SND] Calling Card & Emblem System initialized successfully.")

util.AddNetworkString("SND_ShowCallingCard")
util.AddNetworkString("SND_SetEmblem")
util.AddNetworkString("SND_SetCallingCard")
util.AddNetworkString("SND_SetShowTitle")
util.AddNetworkString("SND_SetTitleMat")
util.AddNetworkString("SND_SetUseTitleMat")

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

function GM:PlayerInitialSpawn(ply)
	self.BaseClass.PlayerInitialSpawn(self, ply)
	if not ply.SND_Joined then
		ply.SND_Joined = true
		ply:SetTeam(math.random(1, 2) == 1 and SND.TEAM_ATTACK or SND.TEAM_DEFEND)
	end
	
	-- Load Calling Card
	ply:SetNWString("SND_CardTitle", ply:GetPData("snd_card_title", "New Recruit"))
	ply:SetNWString("SND_CardMat", ply:GetPData("snd_card_mat", "vgui/white"))
	ply:SetNWBool("SND_ShowTitle", ply:GetPData("snd_show_title", "1") == "1")
	ply:SetNWBool("SND_UseTitleMat", ply:GetPData("snd_use_title_mat", "0") == "1")
	ply:SetNWString("SND_TitleMat", ply:GetPData("snd_title_mat", "vgui/white"))
	local isBot = (ply:IsBot() or ply.SND_IsBot)
	ply:SetNWString("SND_EmblemMat", ply:GetPData("snd_emblem_mat", isBot and SND.Config.DefaultBotEmblem or "steam"))

	SND.Teams.ApplyFactionModel(ply)
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

net.Receive("SND_SetCallingCard", function(_, ply)
	local title = net.ReadString()
	local mat = net.ReadString()
	
	ply:SetNWString("SND_CardTitle", title)
	ply:SetNWString("SND_CardMat", mat)
	ply:SetPData("snd_card_title", title)
	ply:SetPData("snd_card_mat", mat)
end)

net.Receive("SND_SetEmblem", function(_, ply)
	local mat = net.ReadString()
	
	ply:SetNWString("SND_EmblemMat", mat)
	ply:SetPData("snd_emblem_mat", mat)
end)




function GM:PlayerDeath(victim, inflictor, attacker)
	self.BaseClass.PlayerDeath(self, victim, inflictor, attacker)
	SND.Round.OnPlayerDeath(victim, attacker)
	SND.Announcer.OnDeathContext(victim, attacker)

	if IsValid(attacker) and attacker:IsPlayer() and attacker ~= victim then
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
	end
end

-- ── Health Regeneration (CoD Style) ──────────────────────────────────────
hook.Add("Think", "SND_HealthRegen", function()
	local now = CurTime()
	for _, ply in ipairs(player.GetAll()) do
		if not ply:Alive() or ply:Health() >= 100 then continue end
		
		local lastDmg = ply.SND_LastDamageTime or 0
		if now > lastDmg + 5 then -- 5 second delay before regen starts
			if not ply.SND_NextRegen or now > ply.SND_NextRegen then
				ply:SetHealth(math.min(100, ply:Health() + 5)) -- Faster heal rate (50 HP/sec)
				ply.SND_NextRegen = now + 0.1
			end
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

hook.Add("InitPostEntity", "SND_RustMapSetup", function()
	if SERVER then
		SND.Rust.InitPostEntity()
	end
end)

-- ── Disable Friendly Fire ────────────────────────────────────────────────
hook.Add("PlayerShouldTakeDamage", "SND_NoFriendlyFire", function(ply, attacker)
	if IsValid(attacker) and attacker:IsPlayer() and attacker:Team() == ply:Team() and attacker ~= ply then
		return false
	end
end)

-- ── Custom Loadout & Quick-Throw System (Server) ─────────────────────────
local function performQuickThrow(ply)
	if ply.SND_IsQuickThrowing then return end
	local lethal = ply:GetNWString("SND_Lethal", "")
	if lethal == "" then return end

	local current = ply:GetActiveWeapon()
	if not IsValid(current) or current:GetClass() == lethal then return end

	ply.SND_IsQuickThrowing = true
	local oldWep = current:GetClass()

	ply:SelectWeapon(lethal)

	-- Force the attack sequence
	timer.Simple(0.1, function()
		if IsValid(ply) and ply:Alive() then
			ply:ConCommand("+attack")
			timer.Simple(0.1, function() if IsValid(ply) then ply:ConCommand("-attack") end end)
		end
	end)

	-- Switch back to previous weapon after throw animation
	timer.Simple(1.1, function()
		if IsValid(ply) and ply:Alive() then
			ply:SelectWeapon(oldWep)
		end
		ply.SND_IsQuickThrowing = false
	end)
end

hook.Add("PlayerButtonDown", "SND_GrenadeKey_SV", function(ply, btn)
	if btn == KEY_G then
		performQuickThrow(ply)
	end
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
end)
util.AddNetworkString("SND_KillFeed") -- Add network string for kill feed
