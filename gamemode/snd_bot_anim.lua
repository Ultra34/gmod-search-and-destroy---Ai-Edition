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
    local isBot = ply:IsBot() or ply:GetNWBool("SND_IsBot", false)

    -- 1. TFA/ARC9 Weapon Translation
    if IsValid(wep) and wep.TranslateActivity then
        local translated = wep:TranslateActivity(act)
        if translated and translated ~= -1 then return translated end
    end

    -- 2. BOT-SPECIFIC CSS SEQUENCE MAPPING
    -- NextBots fail to translate generic activities. We must return the "base" 
    -- CSS activities (ACT_IDLE_RIFLE, etc.) which have arm poses baked in.
    if isBot then
        local h = IsValid(wep) and wep:GetHoldType() or "normal"
        local isRifle = (h == "ar2" or h == "smg" or h == "rpg" or h == "shotgun" or h == "crossbow")
        local isPistol = (h == "pistol" or h == "revolver")

        if act == ACT_MP_STAND_IDLE then
            if isRifle then return ACT_IDLE_RIFLE
            elseif isPistol then return ACT_IDLE_PISTOL
            else return ACT_IDLE end
        elseif act == ACT_MP_WALK then
            if isRifle then return ACT_WALK_RIFLE
            elseif isPistol then return ACT_WALK_PISTOL
            else return ACT_WALK end
        elseif act == ACT_MP_RUN then
            if isRifle then return ACT_RUN_RIFLE
            elseif isPistol then return ACT_RUN_PISTOL
            else return ACT_RUN end
        elseif act == ACT_MP_CROUCH_IDLE then
            return ACT_CROUCHIDLE
        elseif act == ACT_MP_CROUCHWALK then
            return ACT_WALK -- CSS models use move_x/y pose params for crouchwalk
        end
    end

    -- 3. HUMAN PLAYER FALLBACK
    local h = IsValid(wep) and wep:GetHoldType() or "normal"
    local map = { ["pistol"]="PISTOL", ["revolver"]="REVOLVER", ["smg"]="SMG1", ["ar2"]="AR2", ["shotgun"]="SHOTGUN", ["rpg"]="RPG" }
    local sfx = map[h] or "AR2"

    if act == ACT_MP_STAND_IDLE then return _G["ACT_HL2MP_IDLE_" .. sfx] or ACT_HL2MP_IDLE_AR2
    elseif act == ACT_MP_WALK then return _G["ACT_HL2MP_WALK_" .. sfx] or ACT_HL2MP_WALK_AR2
    elseif act == ACT_MP_RUN then return _G["ACT_HL2MP_RUN_" .. sfx] or ACT_HL2MP_RUN_AR2
    elseif act == ACT_MP_CROUCH_IDLE then return _G["ACT_HL2MP_IDLE_CROUCH_" .. sfx] or ACT_HL2MP_IDLE_CROUCH_AR2
    elseif act == ACT_MP_CROUCHWALK then return _G["ACT_HL2MP_WALK_CROUCH_" .. sfx] or ACT_HL2MP_WALK_CROUCH_AR2
    elseif act == ACT_MP_JUMP or act == ACT_MP_JUMP_START or act == ACT_MP_JUMP_FLOAT then return ACT_HL2MP_JUMP_AR2
    elseif act == ACT_MP_JUMP_LAND then return ACT_HL2MP_IDLE_AR2 end

	return act
end)

-- ── Damage Flinching (Gestures) ──────────────────────────────────────────
if SERVER then
	hook.Add("EntityTakeDamage", "SND_BotFlinchAnim", function(target, dmg)
		if not IsValid(target) or not target:IsPlayer() or not target.SND_IsBot then return end
		if not target:Alive() then return end

		-- Don't flinch too often (every 0.7s max)
		if target.SND_NextFlinch and CurTime() < target.SND_NextFlinch then return end
		target.SND_NextFlinch = CurTime() + 0.7

		-- Play flinch gesture based on physics impact
		local act = ACT_FLINCH_PHYSICS
		target:AnimRestartGesture(GESTURE_SLOT_FLINCH, act, true)
	end)
end

-- ── SERVER: drive pose parameters for bots each tick ─────────────────────
-- Human players have their pose params set by the engine; bots do not.
if SERVER then
	hook.Add("Think", "SND_BotPoseParams", function()
		for _, bot in ipairs(player.GetAll()) do
			if not bot.SND_IsBot or not bot:Alive() then continue end

			local vel   = bot:GetVelocity()
			local speed = vel:Length2D()

			-- move_yaw: direction of movement relative to feet
			local moveYaw = 0
			local eyeAng  = bot:EyeAngles()
			local bodyAng = bot:GetAngles() -- Direction feet are facing

            -- Force the bot's physics body to align with their aim when moving
            if speed > 5 then
                bot:SetAngles(Angle(0, eyeAng.y, 0))
            end

			if speed > 10 then
				local moveDir = vel:Angle()
				moveYaw = math.NormalizeAngle(moveDir.y - bodyAng.y)
				-- Smooth out yaw changes to reduce jitter
				local prevYaw = bot:GetPoseParameter("move_yaw") or 0
				moveYaw = Lerp(0.15, prevYaw, moveYaw)
			end
			bot:SetPoseParameter("move_yaw",   moveYaw)

			-- Procedural Leaning: Tilt torso based on horizontal velocity
			local localVel = bot:WorldToLocal(bot:GetPos() + vel)
			local targetLean = (localVel.y / 320) * 15
			local curLean = bot:GetPoseParameter("body_yaw") or 0
			bot:SetPoseParameter("body_yaw", Lerp(0.1, curLean, targetLean))

			-- body_pitch: match eye pitch (so they appear to aim up/down)
			local pitch = math.NormalizeAngle(eyeAng.p)
			bot:SetPoseParameter("body_pitch", math.Clamp(pitch, -60, 60))
            
            -- These are the two most important pose params for TFA weapon alignment
            bot:SetPoseParameter("aim_pitch", pitch)
            bot:SetPoseParameter("aim_yaw", math.NormalizeAngle(eyeAng.y - bodyAng.y))
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

		local speed = velocity:Length()
		local isBot = ply:IsBot() or ply:GetNWBool("SND_IsBot", false)
        local eyeAng = ply:EyeAngles()
        local bodyAng = ply:GetAngles()

        -- NextBots need manual frame advance and playback rate on client
        if isBot then
            ply:FrameAdvance(FrameTime())
            local rate = (speed > 10) and math.Clamp(speed / maxSeqGroundSpeed, 0.1, 2) or 1
            ply:SetPlaybackRate(rate)
        end
		
		-- Update 8-way movement pose parameters
		if speed > 10 then
			ply:SetPoseParameter("move_x", (velocity:Dot(ply:GetForward()) / speed))
			ply:SetPoseParameter("move_y", (velocity:Dot(ply:GetRight()) / speed) * -1)
		end

		-- Torso and Aim rotation (Fixes floating guns and stiff neck)
		ply:SetPoseParameter("aim_yaw", math.NormalizeAngle(eyeAng.y - bodyAng.y))
        ply:SetPoseParameter("aim_pitch", math.NormalizeAngle(eyeAng.p))

        local pitch = math.NormalizeAngle(eyeAng.p)
        ply:SetPoseParameter("body_pitch", math.Clamp(pitch, -60, 60))
        ply:SetPoseParameter("head_pitch", math.Clamp(pitch, -45, 45))
	end)
end

-- ── CalcMainActivity: tell the engine which activity to use ───────────
-- SHARED: This MUST run on both server and client for bots to animate.
-- This is the hook that controls whether the player plays IDLE, WALK, or RUN.
hook.Add("CalcMainActivity", "SND_BotCalcActivity", function(ply, velocity)
	if not ply:Alive() then return end

	local model = ply:GetModel() or ""
	local isCSSModel = string.find(model, "models/player/ct_") ~= nil
					or string.find(model, "models/player/t_")  ~= nil
	if not isCSSModel then return end

	local speed = velocity:Length2D()
	local onGround = ply:IsOnGround()

	if not onGround then
		return ACT_MP_JUMP, -1
	end

	if ply:Crouching() or ply:GetNWBool("SND_BotCrouching", false) then
		return speed < 10 and ACT_MP_CROUCH_IDLE or ACT_MP_CROUCHWALK, -1
	end

	if speed < 10 then
		return ACT_MP_STAND_IDLE, -1
	elseif speed < 140 then
		return ACT_MP_WALK, -1
	else
		return ACT_MP_RUN, -1
	end
end)

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
