--[[ Server rules enforced by the gamemode
     NEW FILE: gamemode/snd_rules.lua
     Add to init.lua:  include("snd_rules.lua")
]]

-- ── Noclip: completely disabled for everyone ──────────────────────────────
hook.Add("PlayerNoClip", "SND_NoNoclip", function(ply, wantsNoclip)
	-- Return false to deny the toggle regardless of who asks
	return false
end)

-- Belt-and-suspenders: strip noclip if somehow already active on spawn
hook.Add("PlayerSpawn", "SND_StripNoclip", function(ply)
	if ply:GetMoveType() == MOVETYPE_NOCLIP then
		ply:SetMoveType(MOVETYPE_WALK)
	end
end)

-- ── Prevent weapon drop (keeps CSS world models tidy) ────────────────────
hook.Add("PlayerDroppedWeapon", "SND_NoWeaponDrop", function(ply, wep)
	-- Remove the dropped entity immediately so weapons don't litter the map
	if IsValid(wep) then
		wep:Remove()
	end
end)

-- Block +drop command
hook.Add("PlayerSwitchWeapon", "SND_DropBlock", function(ply, old, new)
	-- allow normal switching
end)

concommand.Add("drop", function() end, nil, nil, FCVAR_CLIENTCMD_CAN_EXECUTE)
