-- ── Bot & Legacy Rig Animation System (Autorun) ───────────────────────────
-- Centrally manages animations for CSS models and Bot specific behaviors.

local function isLegacyRig(ply)
	local mdl = string.lower(ply:GetModel() or "")
	return mdl:find("/ct_", 1, true) or mdl:find("/t_", 1, true) or mdl:find("player/ct_", 1, true) or mdl:find("player/t_", 1, true)
end

local HOLD_SUFFIXES = {
	pistol = "PISTOL", revolver = "REVOLVER", smg = "SMG1", smg1 = "SMG1", smg2 = "SMG1",
	ar2 = "AR2", shotgun = "SHOTGUN", rpg = "RPG", rpg7 = "RPG", melee = "MELEE",
	knife = "KNIFE", fist = "FIST", grenade = "GRENADE", slam = "SLAM", passive = ""
}

-- ── Shared Pose Update (Essential for legacy rigs) ─────────────────────────
local function updatePoseParams(ply)
	local vel = ply:GetVelocity()
	local speed = vel:Length2D()
	local maxSpd = math.max(ply:GetMaxSpeed(), 1)
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

	if CLIENT then ply:InvalidateBoneCache() end
end

-- ── Movement Activity Translation (Shared) ─────────────────────────────────
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

-- ── Shared Playback & Pose Hook ────────────────────────────────────────────
hook.Add("UpdateAnimation", "SND_SharedAnimLogic", function(ply, vel, maxSeqGroundSpeed)
	if not IsValid(ply) or not ply:Alive() then return end
	if not ply.SND_IsBot and not ply:IsBot() then return end

	local speed = vel:Length2D()
	if speed > 10 and maxSeqGroundSpeed > 0 then
		ply:SetPlaybackRate(math.Clamp(speed / maxSeqGroundSpeed, 0.2, 2.0))
	else
		ply:SetPlaybackRate(1.0)
	end

	updatePoseParams(ply)
end)