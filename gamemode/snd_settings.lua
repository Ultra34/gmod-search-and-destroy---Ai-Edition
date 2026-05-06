--[[ Replicated settings (server authoritative). Client reads for UI.
     REPLACES: gamemode/snd_settings.lua ]]

SND.Settings = SND.Settings or {}

SND.Settings.Defaults = {
	sprint_mult      = 1.5,
	walk_speed       = 190,
	run_speed        = 280,
	ads_slow         = 0.88,
	air_accel_scale  = 1.35,
	friction_floor   = 0.92,
	plant_time       = 5,
	stamina_drain    = 0.25, -- Exactly 4 seconds of sprint
	stamina_recover  = 0.25, -- ~4 seconds recovery standing still
	defuse_time      = 8,
	freeze_time      = 6,
	round_time       = 120,
	win_limit        = 4,
	bot_count        = 0,
	bot_skill        = 5,    -- 1 (worst) to 10 (best)
	team_balance     = 1,
	mapvote_enabled  = 1,
	mapvote_time     = 20,
	announcer_volume = 1,
	hud_scale        = 1,
}

if SERVER then
	for k, v in pairs(SND.Settings.Defaults) do
		local flags = (type(v) == "string") and { FCVAR_ARCHIVE } or { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY }
		CreateConVar("snd_" .. k, tostring(v), flags)
	end
end

function SND.Settings.Get(name, fallback)
	local cv = GetConVar("snd_" .. name)
	if cv then return cv:GetFloat() end
	return fallback or SND.Settings.Defaults[name]
end

function SND.Settings.GetInt(name, fallback)
	local cv = GetConVar("snd_" .. name)
	if cv then return cv:GetInt() end
	return fallback or SND.Settings.Defaults[name]
end

function SND.Settings.GetString(name, fallback)
	local cv = GetConVar("snd_" .. name)
	if cv then return cv:GetString() end
	return fallback or SND.Settings.Defaults[name]
end
