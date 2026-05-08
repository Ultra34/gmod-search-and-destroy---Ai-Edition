--[[ CSS player model animation fix for bots AND human players
     Fixes: T-pose on bots, broken weapon hold animations, missing move_yaw/body_yaw
     IMPROVED: Better animation blending, reduced jitter, stable pose parameters
     NEW FILE: gamemode/snd_bot_anim.lua  (SHARED — runs on both server and client)

     Add to init.lua:    include("snd_bot_anim.lua")
     Add to cl_init.lua: include("snd_bot_anim.lua")
     Add to shared.lua (inside SERVER block):  AddCSLuaFile("snd_bot_anim.lua")
]]

-- ── Activity translation for CSS model skeleton ───────────────────────────
-- CSS player models ship with the standard HL2/GMod ACT_ sequences, so the
-- default GMod animation system works — but CreateNextBot bots don't run the
-- same animation state machine as human players.  TranslateActivity ensures
-- activities resolve to sequences that exist in the CSS model.
hook.Add("TranslateActivity", "SND_CSSAnimTranslate", function(ply, act)
	if act == nil then return end

	local model = ply:GetModel() or ""
	local isCSS = string.find(model, "models/player/ct_") ~= nil or string.find(model, "models/player/t_") ~= nil
	if not isCSS then return end

	local wep = ply:GetActiveWeapon()
	local hold = IsValid(wep) and wep:GetHoldType() or "normal"

	local t = {}

	-- PISTOL / REVOLVER animations for CSS models
	if hold == "pistol" or hold == "revolver" then
		local p = (hold == "pistol")
		if ACT_MP_STAND_IDLE then t[ACT_MP_STAND_IDLE] = p and ACT_HL2MP_IDLE_PISTOL or ACT_HL2MP_IDLE_REVOLVER end
		if ACT_MP_WALK then t[ACT_MP_WALK] = p and ACT_HL2MP_WALK_PISTOL or ACT_HL2MP_WALK_REVOLVER end
		if ACT_MP_RUN then t[ACT_MP_RUN] = p and ACT_HL2MP_RUN_PISTOL or ACT_HL2MP_RUN_REVOLVER end
		if ACT_MP_CROUCH_IDLE then t[ACT_MP_CROUCH_IDLE] = p and ACT_HL2MP_IDLE_CROUCH_PISTOL or ACT_HL2MP_IDLE_CROUCH_REVOLVER end
		if ACT_MP_CROUCHWALK then t[ACT_MP_CROUCHWALK] = p and ACT_HL2MP_WALK_CROUCH_PISTOL or ACT_HL2MP_WALK_CROUCH_REVOLVER end
		if ACT_MP_ATTACK_STAND_PRIMARYFIRE then t[ACT_MP_ATTACK_STAND_PRIMARYFIRE] = p and ACT_HL2MP_GESTURE_RANGE_ATTACK_PISTOL or ACT_HL2MP_GESTURE_RANGE_ATTACK_REVOLVER end
	else
		if ACT_MP_STAND_IDLE then t[ACT_MP_STAND_IDLE] = ACT_IDLE end
		if ACT_MP_WALK then t[ACT_MP_WALK] = ACT_WALK end
		if ACT_MP_RUN then t[ACT_MP_RUN] = ACT_RUN end
		if ACT_MP_CROUCHWALK then t[ACT_MP_CROUCHWALK] = ACT_WALK end
		if ACT_MP_CROUCH_IDLE then t[ACT_MP_CROUCH_IDLE] = ACT_CROUCHIDLE end
	end

	if ACT_MP_JUMP then t[ACT_MP_JUMP] = ACT_HOP end -- CS:S models use ACT_HOP for jumping
	if ACT_MP_JUMP_START then t[ACT_MP_JUMP_START] = ACT_HOP end
	if ACT_MP_JUMP_FLOAT then t[ACT_MP_JUMP_FLOAT] = ACT_HOP end
	if ACT_MP_JUMP_LAND then t[ACT_MP_JUMP_LAND] = ACT_IDLE end -- Map landing to idle to prevent T-pose

	-- Fallback for HL2MP holdtypes if the model supports standard activities
	if not t[act] and act >= 1600 and act <= 2000 then
		if string.find(tostring(act), "WALK") then return ACT_WALK end
		if string.find(tostring(act), "RUN") then return ACT_RUN end
		return ACT_IDLE
	end

	return t[act]
end)

-- ── SERVER: drive pose parameters for bots each tick ─────────────────────
-- Human players have their pose params set by the engine; bots do not.
if SERVER then
	hook.Add("Think", "SND_BotPoseParams", function()
		for _, bot in ipairs(player.GetAll()) do
			if not bot.SND_IsBot or not bot:Alive() then continue end

			local vel   = bot:GetVelocity()
			local speed = vel:Length2D()

			-- move_yaw: direction of movement relative to where the bot is facing
			local moveYaw = 0
			if speed > 10 then
				local moveDir = vel:Angle()
				local faceDir = bot:EyeAngles()
				moveYaw = math.NormalizeAngle(moveDir.y - faceDir.y)
				-- Smooth out yaw changes to reduce jitter
				local prevYaw = bot:GetPoseParameter("move_yaw") or 0
				moveYaw = Lerp(0.15, prevYaw, moveYaw)
			end
			bot:SetPoseParameter("move_yaw",   moveYaw)

			-- body_yaw: keep at 0 — bots turn their whole body
			bot:SetPoseParameter("body_yaw",   0)

			-- body_pitch: match eye pitch (so they appear to aim up/down)
			local pitch = math.NormalizeAngle(bot:EyeAngles().p)
			bot:SetPoseParameter("body_pitch", math.Clamp(pitch, -60, 60))
		end
	end)
end

-- ── CLIENT: UpdateAnimation — drive bot animation sequences ───────────────
-- This hook fires once per frame per player on the CLIENT and lets us
-- override which animation sequence plays.  Critical for NextBot bots.
if CLIENT then
	hook.Add("UpdateAnimation", "SND_BotAnimUpdate", function(ply, velocity, maxSeqGroundSpeed)
		if not ply:Alive() then return end

		-- Apply to both bots AND human players using CSS models so they look identical
		local isCSSModel = string.find(ply:GetModel(), "models/player/ct_") ~= nil
		                or string.find(ply:GetModel(), "models/player/t_")  ~= nil
		if not isCSSModel then return end

		local speed  = velocity:Length2D()
		
		-- Update the move_x and move_y pose parameters for animations
		if speed > 1 then
			ply:SetPoseParameter("move_x", (velocity:Dot(ply:GetForward()) / speed))
			ply:SetPoseParameter("move_y", (velocity:Dot(ply:GetRight()) / speed) * -1)
		end

		-- Resolve the hold type from the active weapon so the arms look right
		local wep     = ply:GetActiveWeapon()
		local hold    = IsValid(wep) and wep:GetHoldType() or "normal"

		-- Map hold type to a gesture layer sequence name that CSS models have.
		-- CSS models have: "idle_all_aim", "walk_all", "run_all", "crouch_all_aim"
		-- The standard GMod animation system handles hold-type overlays via
		-- ACT_ activities, but we also reinforce move_yaw here.

		local moveYaw = 0
		if speed > 10 then
			local moveDir = velocity:Angle()
			local faceDir = ply:EyeAngles()
			moveYaw = math.NormalizeAngle(moveDir.y - faceDir.y)
			-- Smooth out yaw to prevent erratic animation snapping
			local prevYaw = ply:GetPoseParameter("move_yaw") or 0
			moveYaw = Lerp(0.15, prevYaw, moveYaw)
		end
		ply:SetPoseParameter("move_yaw",   moveYaw)

		local pitch = math.NormalizeAngle(ply:EyeAngles().p)
		ply:SetPoseParameter("body_pitch", math.Clamp(pitch, -60, 60))
		ply:SetPoseParameter("body_yaw",   0)
	end)

	-- ── CalcMainActivity: tell the engine which activity to use ───────────
	-- This is the hook that controls whether the player plays IDLE, WALK, or RUN.
	-- Without this, bots may get stuck on IDLE regardless of their velocity.
	hook.Add("CalcMainActivity", "SND_BotCalcActivity", function(ply, velocity)
		if not ply:Alive() then return end

		local isCSSModel = string.find(ply:GetModel(), "models/player/ct_") ~= nil
		                or string.find(ply:GetModel(), "models/player/t_")  ~= nil
		if not isCSSModel then return end

		local speed = velocity:Length2D()
		local onGround = ply:IsOnGround()

		if not onGround then
			return ACT_MP_JUMP, -1
		end

		if ply:Crouching() then
			return speed < 10 and ACT_CROUCHIDLE or ACT_WALK, -1
		end

		if speed < 10 then
			return ACT_IDLE, -1
		elseif speed < 140 then
			return ACT_WALK, -1
		else
			return ACT_RUN, -1
		end
	end)
end

-- ── SERVER: force correct weapon world-model hold type on bots ────────────
-- When a bot spawns with an ARC9 weapon the worldmodel (3rd-person visible gun)
-- sometimes doesn't update.  Switching weapon twice forces a refresh.
if SERVER then
	hook.Add("PlayerSpawn", "SND_BotWeaponHoldFix", function(ply)
		if not ply.SND_IsBot then return end
		-- Small delay so Give() in Loadout.Apply has finished
		timer.Simple(0.2, function()
			if not IsValid(ply) or not ply:Alive() then return end
			local weps = ply:GetWeapons()
			if #weps < 1 then return end

			-- Select secondary, then primary — forces the hold-type VM/WM refresh
			if #weps >= 2 then
				ply:SelectWeapon(weps[2]:GetClass())
			end
			timer.Simple(0.05, function()
				if IsValid(ply) and ply:Alive() then
					ply:SelectWeapon(weps[1]:GetClass())
				end
			end)
		end)
	end)
-- When a bot spawns with a TFA weapon the worldmodel (3rd-person visible gun)
end
