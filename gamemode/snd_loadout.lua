--[[ ARC9 MW Classic loadouts — set real SWEP class names in ConVars or data file ]]

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

	if pri == "" then pri = defaults.primary end
	if sec == "" then sec = defaults.secondary end

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
	giveSafe(defaults.tactical)

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
