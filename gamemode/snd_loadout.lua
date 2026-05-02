--[[ ARC9 MW2 Extended loadouts — ConVars or data/snd_mwclassic/loadouts.lua ]]

SND.Loadout = SND.Loadout or {}

local function cvarPrimary(teamId)
	return GetConVar("snd_loadout_" .. (teamId == SND.TEAM_ATTACK and "attack_pri" or "defend_pri"))
end

local function cvarSecondary(teamId)
	return GetConVar("snd_loadout_" .. (teamId == SND.TEAM_ATTACK and "attack_sec" or "defend_sec"))
end

function SND.Loadout.Apply(ply)
	if not IsValid(ply) then return end

	ply:StripWeapons()

	local t = ply:Team()
	local defaults = (t == SND.TEAM_ATTACK) and SND.Config.DefaultLoadouts.attack or SND.Config.DefaultLoadouts.defend

	local pri = cvarPrimary(t) and cvarPrimary(t):GetString() or ""
	local sec = cvarSecondary(t) and cvarSecondary(t):GetString() or ""

	if pri == "" then
		if defaults.random_primary and SND.Config.Mw2ePrimaries and #SND.Config.Mw2ePrimaries > 0 then
			pri = table.Random(SND.Config.Mw2ePrimaries)
		else
			pri = defaults.primary
		end
	end
	if sec == "" then
		if defaults.random_secondary and SND.Config.Mw2eSecondaries and #SND.Config.Mw2eSecondaries > 0 then
			sec = table.Random(SND.Config.Mw2eSecondaries)
		else
			sec = defaults.secondary
		end
	end

	local function giveSafe(class)
		if not class or class == "" then return end
		local w = ply:Give(class)
		if not IsValid(w) then
			ply:ChatPrint("[SND] Missing weapon class: " .. tostring(class))
		end
	end

	giveSafe(pri)
	giveSafe(sec)
	giveSafe(defaults.lethal)
	if defaults.tactical and defaults.tactical ~= "" then
		giveSafe(defaults.tactical)
	end

	local weps = ply:GetWeapons()
	if #weps > 0 then
		ply:SelectWeapon(weps[1]:GetClass())
	end
end

if SERVER then
	CreateConVar("snd_loadout_attack_pri", "", FCVAR_ARCHIVE)
	CreateConVar("snd_loadout_attack_sec", "", FCVAR_ARCHIVE)
	CreateConVar("snd_loadout_defend_pri", "", FCVAR_ARCHIVE)
	CreateConVar("snd_loadout_defend_sec", "", FCVAR_ARCHIVE)
end
