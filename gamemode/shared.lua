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

	-- Fallback to standard activities if we aren't handling a specific movement act
	local suffix = actMap[act] or actMap[ACT_MP_STAND_IDLE]
	if not actMap[act] then return end

	if suffix then
		-- Fallback holdtypes to prevent T-posing on older CSS model rigs
		if hold == "rpg" or hold == "physgun" or hold == "grenade" or hold == "slam" then hold = "ar2" end
		if hold == "smg1" then hold = "smg" end
		
		local mapped = _G["ACT_HL2MP_" .. suffix .. "_" .. string.upper(hold)]
		if mapped then return mapped end
	end

	if IsValid(wep) and wep.TranslateActivity then
		local translated = wep:TranslateActivity(act)
		if translated and translated ~= -1 then return translated end
	end
end)
