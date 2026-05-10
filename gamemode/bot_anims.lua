-- ── Bot & Legacy Rig Animation System ─────────────────────────────────────
-- Moved to lua/autorun/sh_snd_bot_anims.lua

-- ── Orientation & Reactions (Server) ───────────────────────────────────────
if SERVER then

	-- Shared reaction/flinch animations
	hook.Add("EntityTakeDamage", "SND_BotReactionHandler", function(target, dmg)
		if not IsValid(target) or not target.SND_IsBot or not target:Alive() then return end
		target:AnimRestartGesture(GESTURE_SLOT_FLINCH, ACT_FLINCH_PHYSICS, true)
		target:SetLayerWeight(GESTURE_SLOT_FLINCH, math.Clamp(dmg:GetDamage() / 45, 0.2, 1.0))
	end)

	-- Force synchronization on spawn to prevent T-posing
	hook.Add("PlayerSpawn", "SND_BotAnimationInitializer", function(ply)
		if not ply.SND_IsBot then return end
		timer.Simple(0.1, function()
			if not IsValid(ply) then return end
			local wep = ply:GetActiveWeapon()
			if IsValid(wep) then wep:SetHoldType(wep:GetHoldType()) end
		end)
	end)
end