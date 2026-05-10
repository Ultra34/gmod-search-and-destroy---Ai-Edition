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
