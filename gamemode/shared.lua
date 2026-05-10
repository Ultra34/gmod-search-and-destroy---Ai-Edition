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

function SND.ResolveCSSActivity(ply, velocity)
	local speed = velocity:Length2D()

	-- Use standard activities; TranslateActivity will handle the weapon mapping.
	if not ply:IsOnGround() then return ACT_MP_JUMP end
	if ply:Crouching() then
		return (speed < 15) and ACT_MP_CROUCH_IDLE or ACT_MP_CROUCHWALK
	end

	if speed < 10 then
		return ACT_MP_STAND_IDLE
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

	local wep = ply:GetActiveWeapon()
	local hold = IsValid(wep) and wep:GetHoldType() or "ar2"
	
	-- Map standard acts to the holdtype versions that CSS models support.
	local actMap = {
		[ACT_MP_STAND_IDLE] = "IDLE",
		[ACT_MP_WALK] = "WALK",
		[ACT_MP_RUN] = "RUN",
		[ACT_MP_CROUCH_IDLE] = "IDLE_CROUCH",
		[ACT_MP_CROUCHWALK] = "WALK_CROUCH",
		[ACT_MP_JUMP] = "JUMP",
	}

	local suffix = actMap[act]
	if suffix then
		-- CSS models typically don't have 'normal', 'passive', or 'rpg' specific sets, so we map to AR2.
		if hold == "normal" or hold == "passive" or hold == "rpg" or hold == "physgun" or hold == "grenade" or hold == "slam" then 
			hold = "ar2" 
		end
		if hold == "smg1" or hold == "smg" then hold = "smg1" end
		if hold == "revolver" then hold = "pistol" end
		
		local holdUpper = string.upper(hold)
		local mapped = _G["ACT_HL2MP_" .. suffix .. "_" .. holdUpper]
		
		-- Special construction for jump as it doesn't always follow the suffix_holdtype pattern
		if suffix == "JUMP" and not mapped then
			mapped = _G["ACT_HL2MP_JUMP_" .. holdUpper] or ACT_HL2MP_JUMP_AR2
		end

		if mapped then return mapped end

		-- Ultimate fallback to AR2 activities for CSS models to prevent T-posing
		local fallback = _G["ACT_HL2MP_" .. suffix .. "_AR2"]
		if fallback then return fallback end
	end

	if IsValid(wep) and wep.TranslateActivity then
		local translated = wep:TranslateActivity(act)
		if translated and translated ~= -1 then return translated end
	end
end)
