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
	return string.find(model, "/ct_") or string.find(model, "/t_")
end

local holdTypeToSuffix = {
	["pistol"] = "PISTOL", ["revolver"] = "REVOLVER", ["smg"] = "SMG1", ["smg1"] = "SMG1",
	["ar2"] = "AR2", ["rpg"] = "RPG", ["physgun"] = "AR2", ["shotgun"] = "SHOTGUN",
	["melee"] = "MELEE", ["melee2"] = "MELEE", ["fist"] = "FIST", ["knife"] = "KNIFE",
	["grenade"] = "GRENADE", ["slam"] = "SLAM", ["passive"] = "PASSIVE", ["normal"] = "PASSIVE"
}

function SND.ResolveCSSActivity(ply, velocity)
	local speed = velocity:Length2D()
	local wep = ply:GetActiveWeapon()
	local hold = IsValid(wep) and wep:GetHoldType() or "ar2"
	local suffix = holdTypeToSuffix[hold] or "AR2"

	-- 1. Jumping
	if not ply:IsOnGround() then
		if suffix == "PASSIVE" then return ACT_HL2MP_JUMP_PASSIVE end
		return _G["ACT_HL2MP_JUMP_" .. suffix] or ACT_HL2MP_JUMP_AR2
	end

	-- 2. Crouching
	if ply:Crouching() then
		if speed < 15 then
			if suffix == "PASSIVE" then return ACT_HL2MP_IDLE_CROUCH end
			return _G["ACT_HL2MP_IDLE_CROUCH_" .. suffix] or ACT_HL2MP_IDLE_CROUCH_AR2
		else
			return ACT_HL2MP_WALK_CROUCH
		end
	end

	-- 3. Standing/Moving
	if speed < 10 then
		if suffix == "PASSIVE" then return ACT_HL2MP_IDLE end
		return _G["ACT_HL2MP_IDLE_" .. suffix] or ACT_HL2MP_IDLE_AR2
	elseif speed < 150 then
		if suffix == "PASSIVE" then return ACT_HL2MP_WALK_PASSIVE end
		return _G["ACT_HL2MP_WALK_" .. suffix] or ACT_HL2MP_WALK_AR2
	else
		if suffix == "PASSIVE" then return ACT_HL2MP_RUN_PASSIVE end
		return _G["ACT_HL2MP_RUN_" .. suffix] or ACT_HL2MP_RUN_AR2
	end
end

hook.Add("CalcMainActivity", "SND_SharedCalcActivity", function(ply, velocity)
	if not IsValid(ply) or not ply:Alive() or not SND.IsCSSModel(ply) then return end
	return SND.ResolveCSSActivity(ply, velocity), -1
end)

hook.Add("TranslateActivity", "SND_BotAnimTranslate", function(ply, act)
	if not IsValid(ply) or not ply:Alive() or not SND.IsCSSModel(ply) then return end

	-- Movement is now handled directly via HL2MP activities in CalcMainActivity.
	-- This hook now primarily handles action-based remapping (e.g. Firing/Reloading).
	
	local wep = ply:GetActiveWeapon()
	if IsValid(wep) and wep.TranslateActivity then
		local translated = wep:TranslateActivity(act)
		if translated and translated ~= -1 then return translated end
	end
end)
