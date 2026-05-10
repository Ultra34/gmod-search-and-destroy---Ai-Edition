--[[
	Search & Destroy — shared definitions
	Requires: ARC9 + MW2 Extended (arc9_mw2e_*) or override in data/snd_mwclassic/loadouts.lua / ConVars
]]

GM.Name = "GMod Search & Destroy"
GM.Author = "snd_mwclassic"
GM.Email = ""
GM.Website = ""

SND = SND or {}

SND.VERSION = 1
SND.Config   = SND.Config or {}
SND.Settings = SND.Settings or {}
SND.Round    = SND.Round or {}
SND.Bomb = SND.Bomb or {}
SND.Levels   = SND.Levels or {}
SND.Teams    = SND.Teams or {}
SND.Bots     = SND.Bots or {}
if CLIENT then SND.Client = SND.Client or {} end

SND.TEAM_ATTACK = 1
SND.TEAM_DEFEND = 2

SND.PHASE_WAIT = 0
SND.PHASE_FREEZE = 1
SND.PHASE_LIVE = 2
SND.PHASE_POST = 3
SND.PHASE_DEBUG = 4

SND.WIN_NONE = 0
SND.WIN_ATTACK_ELIM = 1
SND.WIN_ATTACK_PLANT = 2
SND.WIN_DEFEND_ELIM = 3
SND.WIN_DEFEND_DEFUSE = 4
SND.WIN_TIME = 5
SND.WIN_DRAW = 6
SND.BOMB_STATE_NONE = 0
SND.BOMB_STATE_CARRIED = 1
SND.BOMB_STATE_PLANTED = 2

if SERVER then
	AddCSLuaFile("snd_config.lua")
	AddCSLuaFile("snd_settings.lua")
	AddCSLuaFile("cl_init.lua")
	AddCSLuaFile("cl_hud.lua")
	AddCSLuaFile("cl_settings.lua")
	AddCSLuaFile("snd_movement.lua")
end

include("snd_config.lua")

if CLIENT then
	include("snd_settings.lua")
end

-- ── Shared Animation Activity Resolution (CSS Models) ──────────────────────
function SND.IsCSSModel(ply)
	local model = string.lower(ply:GetModel() or "")
	-- Catch standard CSS paths and common variations
	return string.find(model, "/ct_") or string.find(model, "/t_") or string.find(model, "player/ct_") or string.find(model, "player/t_")
end

local holdTypeToSuffix = {
	["pistol"] = "PISTOL", ["revolver"] = "REVOLVER", ["smg"] = "SMG1", ["smg1"] = "SMG1",
	["ar2"] = "AR2", ["rpg"] = "RPG", ["physgun"] = "AR2", ["shotgun"] = "SHOTGUN",
	["melee"] = "MELEE", ["melee2"] = "MELEE", ["fist"] = "FIST", ["knife"] = "KNIFE",
	["grenade"] = "GRENADE", ["slam"] = "SLAM", ["passive"] = "PASSIVE", ["normal"] = "PASSIVE"
}

function SND.ResolveCSSActivity(ply, velocity)
	local speed = velocity:Length2D()

	-- Use standard activities as the base; SND_BotAnimTranslate will map to HL2MP versions for CSS models.
	if not ply:IsOnGround() then return ACT_MP_JUMP end

	if ply:Crouching() then
		return (speed < 15) and ACT_MP_CROUCH_IDLE or ACT_MP_CROUCHWALK
	end

	if speed < 10 then
		return ACT_MP_STAND_IDLE
	elseif ply:IsSprinting() then
		return ACT_MP_RUN
	elseif speed < 150 then
		return ACT_MP_WALK
	else
		return ACT_MP_RUN
	end
end

hook.Add("CalcMainActivity", "SND_SharedCalcActivity", function(ply, velocity)
	if not IsValid(ply) or not ply:Alive() or not SND.IsCSSModel(ply) then return end
	return SND.ResolveCSSActivity(ply, velocity), -1
end)

hook.Add("TranslateActivity", "SND_BotAnimTranslate", function(ply, act)
	if not IsValid(ply) or not ply:Alive() or not SND.IsCSSModel(ply) then return end

	-- Map generic player activities to the base HL2MP strings
	local moveMap = {
		[ACT_MP_STAND_IDLE]  = "IDLE",
		[ACT_MP_WALK]        = "WALK",
		[ACT_MP_RUN]         = "RUN",
		[ACT_MP_CROUCH_IDLE] = "IDLE_CROUCH",
		[ACT_MP_CROUCHWALK]  = "WALK_CROUCH",
		[ACT_MP_JUMP]        = "JUMP",
		[ACT_MP_SWIM]        = "SWIM",
		[ACT_MP_ATTACK_STAND_PRIMARYFIRE] = "GESTURE_RANGE_ATTACK"
	}
	
	local base = moveMap[act]
	if not base then
		-- If not a movement activity, let the weapon handle it (Firing/Reloading)
		local wep = ply:GetActiveWeapon()
		if IsValid(wep) and wep.TranslateActivity then
			local translated = wep:TranslateActivity(act)
			if translated and translated ~= -1 then return translated end
		end
		return
	end

	local wep = ply:GetActiveWeapon()
	local hold = IsValid(wep) and wep:GetHoldType() or "ar2"
	
	-- Comprehensive holdtype to Suffix mapping for legacy CSS rigs
	local holdToSuffix = {
		["pistol"] = "PISTOL", ["revolver"] = "REVOLVER", ["smg"] = "SMG1", ["smg1"] = "SMG1", ["smg2"] = "SMG1",
		["ar2"] = "AR2", ["rpg"] = "RPG", ["physgun"] = "AR2", ["shotgun"] = "SHOTGUN",
		["melee"] = "MELEE", ["melee2"] = "MELEE", ["fist"] = "FIST", ["knife"] = "KNIFE",
		["grenade"] = "GRENADE", ["slam"] = "SLAM", ["duel"] = "PISTOL", ["revolver"] = "REVOLVER",
		["rpg7"] = "RPG", ["crossbow"] = "AR2", ["magic"] = "",
		["passive"] = "", ["normal"] = "", ["camera"] = "", ["magic"] = ""
	}

	local suffix = holdToSuffix[hold] or "AR2"
	local actName = "ACT_HL2MP_" .. base
	
	-- Specific handling for gestures vs movement
	if string.find(base, "GESTURE") then
		actName = "ACT_HL2MP_" .. base .. "_" .. suffix
	elseif suffix ~= "" then
		actName = actName .. "_" .. suffix
	end

	-- Resolve from global table, with strict fallbacks to avoid T-posing
	local resolved = _G[actName]
	if resolved then return resolved end

	-- Fallback chain to ensure the bot NEVER T-poses
	return _G["ACT_HL2MP_" .. base .. "_AR2"] or _G["ACT_HL2MP_" .. base] or ACT_HL2MP_IDLE_AR2
end)
