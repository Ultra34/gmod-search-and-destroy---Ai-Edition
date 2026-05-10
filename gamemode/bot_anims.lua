-- ── Bot & Legacy Rig Animation System ─────────────────────────────────────
-- Centrally manages animations for CSS models and Bot specific behaviors.

AddCSLuaFile()

local function isLegacyRig(ply)
	local mdl = string.lower(ply:GetModel() or "")
	return mdl:find("/ct_", 1, true) or mdl:find("/t_", 1, true) or mdl:find("player/ct_", 1, true) or mdl:find("player/t_", 1, true)
end

local HOLD_SUFFIXES = {
	pistol = "PISTOL", revolver = "REVOLVER", smg = "SMG1", smg1 = "SMG1", smg2 = "SMG1",
	ar2 = "AR2", shotgun = "SHOTGUN", rpg = "RPG", rpg7 = "RPG", melee = "MELEE",
	knife = "KNIFE", fist = "FIST", grenade = "GRENADE", slam = "SLAM", passive = ""
}

-- ── Movement Activity Translation (Shared) ─────────────────────────────────
hook.Add("TranslateActivity", "SND_LegacyAnimationFix", function(ply, act)
	if not IsValid(ply) or not ply:Alive() or not isLegacyRig(ply) then return end

	-- Map standard activities to base names for string construction
	local map = {
		[ACT_MP_STAND_IDLE]  = "IDLE",
		[ACT_MP_WALK]        = "WALK",
		[ACT_MP_RUN]         = "RUN",
		[ACT_MP_CROUCH_IDLE] = "IDLE_CROUCH",
		[ACT_MP_CROUCHWALK]  = "WALK_CROUCH",
		[ACT_MP_JUMP]        = "JUMP",
		[ACT_MP_SWIM]        = "SWIM",
		[ACT_MP_ATTACK_STAND_PRIMARYFIRE] = "GESTURE_RANGE_ATTACK"
	}

	local base = map[act]
	if not base then return end

	local wep = ply:GetActiveWeapon()
	local hold = IsValid(wep) and wep:GetHoldType() or "ar2"
	local suffix = HOLD_SUFFIXES[hold] or "AR2"

	local actName = "ACT_HL2MP_" .. base
	if string.find(base, "GESTURE") then
		actName = "ACT_HL2MP_" .. base .. "_" .. suffix
	elseif suffix ~= "" then
		actName = actName .. "_" .. suffix
	end

	-- Resolve activity enum, falling back to AR2 if specific variant is missing
	return _G[actName] or _G["ACT_HL2MP_" .. base .. "_AR2"] or _G["ACT_HL2MP_" .. base] or ACT_HL2MP_IDLE_AR2
end)

-- ── Combat Gesture Handling (Shared) ───────────────────────────────────────
hook.Add("DoAnimationEvent", "SND_LegacyGestureHandler", function(ply, event, data)
	if not isLegacyRig(ply) then return end

	local wep = ply:GetActiveWeapon()
	local hold = IsValid(wep) and wep:GetHoldType() or "ar2"
	local suffix = HOLD_SUFFIXES[hold] or "AR2"

	if event == PLAYERANIMEVENT_ATTACK_PRIMARY then
		local act = _G["ACT_HL2MP_GESTURE_RANGE_ATTACK_" .. suffix] or ACT_HL2MP_GESTURE_RANGE_ATTACK_AR2
		ply:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, act, true)
		return ACT_INVALID
	elseif event == PLAYERANIMEVENT_RELOAD then
		local act = _G["ACT_HL2MP_GESTURE_RELOAD_" .. suffix] or ACT_HL2MP_GESTURE_RELOAD_AR2
		ply:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, act, true)
		return ACT_INVALID
	end
end)

-- ── Orientation & Reactions (Server) ───────────────────────────────────────
if SERVER then
	-- Procedural rotation to prevent "moonwalking" for Bots
	hook.Add("Think", "SND_BotOrientationController", function()
		for _, bot in ipairs(player.GetAll()) do
			if not bot.SND_IsBot or not bot:Alive() then continue end

			local vel = bot:GetVelocity()
			local speed = vel:Length2D()
			local angles = bot:GetAngles()
			local eyeYaw = bot:EyeAngles().y

			if speed > 15 then
				bot:SetAngles(Angle(0, vel:Angle().y, 0))
			else
				local diff = math.NormalizeAngle(eyeYaw - angles.y)
				if math.abs(diff) > 40 then
					angles.y = LerpAngle(FrameTime() * 15, angles, Angle(0, eyeYaw, 0)).y
					bot:SetAngles(angles)
				end
			end
		end
	end)

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