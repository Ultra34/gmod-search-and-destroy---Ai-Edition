-- ── Bot & Legacy Rig Animation System (Autorun) ───────────────────────────
-- Centrally manages animations for CSS models and Bot specific behaviors.

AddCSLuaFile()

-- ── Shared utility function (available to both client and server) ──────────
local function isLegacyRig(ply)
	local mdl = string.lower(ply:GetModel() or "")
	local result = mdl:find("/ct_", 1, true) or mdl:find("/t_", 1, true) or mdl:find("player/ct_", 1, true) or mdl:find("player/t_", 1, true)

	-- Debug check: Enable via 'snd_debug_mode 1' in console
	local cv = GetConVar("snd_debug_mode")
	if cv and cv:GetBool() and IsValid(ply) then
		if ply._snd_anim_lastmdl ~= mdl then
			ply._snd_anim_lastmdl = mdl
			print(string.format("[SND_ANIM] Model Check: %s | Legacy: %s", mdl, result and "YES" or "NO"))
		end
	end

	return result
end

local HOLD_SUFFIXES = {
	pistol = "PISTOL", revolver = "REVOLVER", smg = "SMG1", smg1 = "SMG1", smg2 = "SMG1",
	ar2 = "RIFLE", shotgun = "SHOTGUN", rpg = "RPG", rpg7 = "RPG", melee = "MELEE",
	knife = "KNIFE", fist = "FIST", grenade = "GRENADE", slam = "SLAM", passive = ""
}

-- ── Shared Pose Update (Essential for legacy rigs) ─────────────────────────
local function updatePoseParams(ply)
	local vel = ply:GetVelocity()
	local speed = vel:Length()
	local maxSpd = math.max(ply:GetMaxSpeed(), 250)
	local angles = ply:GetAngles()
	local eye = ply:EyeAngles()

	-- 1. Aiming (Arms/Head)
	local pitch = math.NormalizeAngle(eye.p)
	local yaw = math.NormalizeAngle(eye.y - angles.y)
	ply:SetPoseParameter("aim_pitch", math.Clamp(pitch, -90, 90))
	ply:SetPoseParameter("aim_yaw", math.Clamp(yaw, -60, 60))
	ply:SetPoseParameter("head_pitch", math.Clamp(pitch, -45, 45))
	ply:SetPoseParameter("head_yaw", math.Clamp(yaw, -60, 60))

	-- 2. Directional blending (Legs)
	if speed > 10 then
		local moveYaw = math.NormalizeAngle(vel:Angle().y - angles.y)
		ply:SetPoseParameter("move_yaw", moveYaw)
		
		local fwd = ply:GetForward()
		local rt = ply:GetRight()
		ply:SetPoseParameter("move_x", vel:Dot(fwd) / maxSpd)
		ply:SetPoseParameter("move_y", -vel:Dot(rt) / maxSpd)
	else
		ply:SetPoseParameter("move_yaw", 0)
		ply:SetPoseParameter("move_x", 0)
		ply:SetPoseParameter("move_y", 0)
	end

	-- Throttled bone invalidation to prevent jitter
	if (ply._snd_next_bone_clear or 0) < CurTime() then
		ply:InvalidateBoneCache()
		ply._snd_next_bone_clear = CurTime() + 0.1
	end
end

-- ── Movement Activity Translation (Client & Server) ────────────────────────
-- This hook needs to run on both client and server for proper prediction
hook.Add("TranslateActivity", "SND_LegacyAnimationFix", function(ply, act)
	if not IsValid(ply) or not ply:Alive() or not isLegacyRig(ply) then return end

	local map = {
		[ACT_MP_STAND_IDLE]  = "IDLE",
		[ACT_MP_WALK]        = "WALK",
		[ACT_MP_RUN]         = "RUN",
		[ACT_MP_CROUCH_IDLE] = "IDLE_CROUCH",
		[ACT_MP_CROUCHWALK]  = "WALK_CROUCH",
		[ACT_MP_JUMP]        = "JUMP",
		[ACT_MP_SWIM]        = "SWIM"
	}

	local base = map[act]
	if not base then return end

	local wep = ply:GetActiveWeapon()
	local hold = IsValid(wep) and wep:GetHoldType() or "ar2"
	local suffix = HOLD_SUFFIXES[hold] or "AR2"

	local actName = "ACT_HL2MP_" .. base .. "_" .. suffix
	return _G[actName] or _G["ACT_HL2MP_" .. base .. "_AR2"] or _G["ACT_HL2MP_" .. base] or ACT_HL2MP_IDLE_AR2
end)

-- ── Client-side animation hooks ────────────────────────────────────────────
if CLIENT then
	-- ── Combat Gesture Handling (Client only) ──────────────────────────────
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

	-- ── Bot Playback & Pose Hook (Client only) ─────────────────────────────
	hook.Add("UpdateAnimation", "SND_SharedAnimLogic", function(ply, vel, maxSeqGroundSpeed)
		if not IsValid(ply) or not ply:Alive() then return end

		-- Use networked check to ensure client-side aiming logic runs for bots
		local isBot = ply:IsBot() or ply:GetNWBool("SND_IsBot")
		if not isBot then return end

		-- Debug: Verify that the animation loop is actually running for this entity
		if not ply._snd_anim_active then
			local cv = GetConVar("snd_debug_mode")
			if cv and cv:GetBool() then
				print(string.format("[SND_ANIM] Animation Logic Active for Bot: %s", ply:Nick()))
				ply._snd_anim_active = true
			end
		end

		local speed = vel:Length2D()
		if speed > 10 and maxSeqGroundSpeed > 0 then
			ply:SetPlaybackRate(math.Clamp(speed / maxSeqGroundSpeed, 0.2, 2.0))
		else
			ply:SetPlaybackRate(1.0)
		end

		updatePoseParams(ply)
	end)
end

-- ── Server-side animation hooks ────────────────────────────────────────────
if SERVER then
	-- Reaction/flinch animations for bots
	hook.Add("EntityTakeDamage", "SND_BotReactionHandler", function(target, dmg)
		if not IsValid(target) or not target.SND_IsBot or not target:Alive() then return end
		local act = target:Crouching() and ACT_FLINCH_CROUCH or ACT_FLINCH_PHYSICS
		target:AnimRestartGesture(GESTURE_SLOT_FLINCH, act, true)
		target:SetLayerWeight(GESTURE_SLOT_FLINCH, math.Clamp(dmg:GetDamage() / 30, 0.4, 1.0))
	end)

	-- Force synchronization on spawn to prevent T-posing
	hook.Add("PlayerSpawn", "SND_BotAnimationInitializer", function(ply)
		if not ply.SND_IsBot then return end
		timer.Simple(0.1, function()
			if not IsValid(ply) then return end
			-- Refresh weapon hold type to ensure correct animations
			local wep = ply:GetActiveWeapon()
			if IsValid(wep) then
				wep:SetHoldType(wep:GetHoldType())
			end
		end)
	end)
end
