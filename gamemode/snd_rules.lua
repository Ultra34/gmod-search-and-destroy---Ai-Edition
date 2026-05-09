--[[ Server rules — noclip disabled via every available hook
     REPLACES: gamemode/snd_rules.lua ]]

-- ── Noclip: three layers of prevention ───────────────────────────────────

-- Layer 1: the canonical GMod hook — returning false denies the toggle
hook.Add("PlayerNoClip", "SND_NoNoclip", function(ply, desiredState)
	if desiredState == false then return true end -- Always allow turning noclip OFF
	if (SND.Round and SND.Round.Phase == SND.PHASE_DEBUG) and ply:IsAdmin() then
		return true -- Allow toggle if in debug mode and is an admin
	end
	return false
end)

-- Layer 3: poll every 0.5 s and forcibly walk anyone who somehow got noclip without permission
timer.Create("SND_NoclipEnforce", 0.5, 0, function()
	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) and ply:GetMoveType() == MOVETYPE_NOCLIP then
			if (SND.Round and SND.Round.Phase == SND.PHASE_DEBUG) and ply:IsAdmin() then continue end
			ply:SetMoveType(MOVETYPE_WALK)
		end
	end
end)

-- Layer 4: strip it on every spawn as a safety net
hook.Add("PlayerSpawn", "SND_StripNoclip", function(ply)
	if ply:GetMoveType() == MOVETYPE_NOCLIP then
		if (SND.Round and SND.Round.Phase == SND.PHASE_DEBUG) and ply:IsAdmin() then return end
		ply:SetMoveType(MOVETYPE_WALK)
	end
end)
