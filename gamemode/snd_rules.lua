--[[ Server rules — noclip disabled via every available hook
     REPLACES: gamemode/snd_rules.lua ]]

-- ── Noclip: three layers of prevention ───────────────────────────────────

-- Layer 1: the canonical GMod hook — returning false denies the toggle
hook.Add("PlayerNoClip", "SND_NoNoclip", function(ply, desiredState)
	if SND.Settings.GetInt("debug_mode", 0) == 1 or (SND.Round and SND.Round.Phase == SND.PHASE_DEBUG) then
		return true
	end
	return false
end)

-- Layer 2: override the gamemode method itself so the base class can't re-enable it
function GM:PlayerNoClip(ply, desiredState)
	if SND.Settings.GetInt("debug_mode", 0) == 1 or (SND.Round and SND.Round.Phase == SND.PHASE_DEBUG) then
		return true
	end
	return false
end

-- Layer 3: poll every 0.5 s and forcibly walk anyone who somehow got noclip
timer.Create("SND_NoclipEnforce", 0.5, 0, function()
	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) and ply:GetMoveType() == MOVETYPE_NOCLIP then
			if SND.Settings.GetInt("debug_mode", 0) == 1 or (SND.Round and SND.Round.Phase == SND.PHASE_DEBUG) then continue end
			ply:SetMoveType(MOVETYPE_WALK)
		end
	end
end)

-- Layer 4: strip it on every spawn as a safety net
hook.Add("PlayerSpawn", "SND_StripNoclip", function(ply)
	if ply:GetMoveType() == MOVETYPE_NOCLIP then
		if SND.Settings.GetInt("debug_mode", 0) == 1 or (SND.Round and SND.Round.Phase == SND.PHASE_DEBUG) then return end
		ply:SetMoveType(MOVETYPE_WALK)
	end
end)
