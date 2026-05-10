--[[ COD-style movement: freeze lock, sprint, air accel
     REPLACES: gamemode/snd_movement.lua ]]

AddCSLuaFile()

SND.Movement = SND.Movement or {}

-- Fallback for environments where IN_CONTEXT_MENU is not defined (added in GMod March 2023)
local IN_CONTEXT_MENU = IN_CONTEXT_MENU or 67108864

function SND.Movement.Setup(ply)
	ply.SND_Sprinting = false
end

if CLIENT then
	SND.AutoRunActive = false
	concommand.Add("snd_autorun", function()
		SND.AutoRunActive = not SND.AutoRunActive
		local status = SND.AutoRunActive and "ENABLED" or "DISABLED"
		chat.AddText(Color(255, 120, 0), "[SND] ", Color(255, 255, 255), "Auto-Run: " .. status)
	end)
end

hook.Add("StartCommand", "SND_FreezeInput", function(ply, cmd)
	if not IsValid(ply) or not ply:Alive() then return end

	local phase = SERVER and SND.Round.Phase or SND.Client.Phase
	if (phase == SND.PHASE_WAIT or phase == SND.PHASE_FREEZE or phase == SND.PHASE_POST) and phase ~= SND.PHASE_DEBUG then
		-- Block all action inputs to prevent shooting, reloading, or planting
		-- Intercepting buttons in StartCommand is more reliable for blocking weapon fire
		local blocked = bit.bor(IN_ATTACK, IN_ATTACK2, IN_RELOAD, IN_USE, IN_CONTEXT_MENU)
		cmd:SetButtons(bit.band(cmd:GetButtons(), bit.bnot(blocked)))
		cmd:ClearMovement()
	end

	-- Quick Throw: Force the attack button if the server-side logic requested it
	if ply.SND_ForceAttackGrenade then
		cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_ATTACK))
	end

	-- Auto-Run logic: Inject forward movement when enabled.
	if CLIENT and SND.AutoRunActive and ply == LocalPlayer() then
		if cmd:KeyDown(IN_BACK) then
			SND.AutoRunActive = false -- Cancel autorun if moving backward manually
		elseif phase == SND.PHASE_LIVE or phase == SND.PHASE_DEBUG then
			cmd:SetForwardMove(ply:GetMaxSpeed())
		end
	end

	-- Prevent sprinting if exhausted
	if ply:GetNWBool("SND_Exhausted", false) then
		cmd:RemoveKey(IN_SPEED)
	end
end)

-- ── Aggressive Fire Block (Server & Client) ──────────────────────────────
hook.Add("Think", "SND_FreezeFireLock", function()
	local phase = SERVER and SND.Round.Phase or (SND.Client and SND.Client.Phase) or SND.PHASE_WAIT

	for _, ply in ipairs(player.GetAll()) do
		-- Force stop breathing if dead, phase ended, or no longer exhausted
		local exhausted = ply:GetNWBool("SND_Exhausted", false)
		local stamina = ply:GetNWFloat("SND_Stamina", 1.0)
		if not ply:Alive() or phase == SND.PHASE_POST or (not exhausted and stamina > 0.8) then
			ply:StopSound("player/breathe1.wav")
		end

		if phase ~= SND.PHASE_WAIT and phase ~= SND.PHASE_FREEZE and phase ~= SND.PHASE_POST then continue end
		if not ply:Alive() then continue end

		local wep = ply:GetActiveWeapon()
		if IsValid(wep) then
			wep:SetNextPrimaryFire(CurTime() + 0.1)
			wep:SetNextSecondaryFire(CurTime() + 0.1)
		end
	end
end)

hook.Add("SetupMove", "SND_Movement", function(ply, mv, cmd)
	if not IsValid(ply) or not ply:Alive() then return end

	-- ── FREEZE: nobody moves ───────────────────────────────────────────────
	local phase = SERVER and SND.Round.Phase or SND.Client.Phase
	if (phase == SND.PHASE_WAIT or phase == SND.PHASE_FREEZE or phase == SND.PHASE_POST) and phase ~= SND.PHASE_DEBUG then
		mv:SetForwardSpeed(0)
		mv:SetSideSpeed(0)
		mv:SetUpSpeed(0)
		ply.SND_Sprinting = false
		return
	end

	if phase ~= SND.PHASE_LIVE then return end

	-- ── SPRINT ────────────────────────────────────────────────────────────
	local mult        = SND.Settings.Get("sprint_mult", 1.5)
	local walkSpeed   = SND.Settings.GetInt("walk_speed", 190)
	local runSpeed    = SND.Settings.GetInt("run_speed", 280)
	local onGround    = ply:IsOnGround()
	local wantSprint  = cmd:KeyDown(IN_SPEED)
	local isADS       = cmd:KeyDown(IN_ATTACK2)
	local stamina     = ply:GetNWFloat("SND_Stamina", 1.0)
	local isExhausted = ply:GetNWBool("SND_Exhausted", false)
	local isMoving    = mv:GetForwardSpeed() > 0 or math.abs(mv:GetSideSpeed()) > 0

	-- ADS Speed Reduction (applied to baseline speeds)
	if isADS then
		local adsMult = SND.Settings.Get("ads_slow", 0.88)
		runSpeed = runSpeed * adsMult
		walkSpeed = walkSpeed * adsMult
	end

	-- Jump Stamina Cost
	if onGround and cmd:KeyDown(IN_JUMP) and not ply.SND_JumpDown then
		ply.SND_JumpDown = true
		if SERVER then
			local jumpCost = SND.Settings.Get("stamina_jump_cost", 0.15)
			stamina = math.max(0, stamina - jumpCost)
			ply:SetNWFloat("SND_Stamina", stamina)
		end
	elseif not cmd:KeyDown(IN_JUMP) then
		ply.SND_JumpDown = false
	end

	local targetSpeed = runSpeed

	-- Sprint Logic
	if onGround and wantSprint and isMoving and stamina > 0 and not isExhausted and not ply:Crouching() and not isADS then
		ply.SND_Sprinting = true
		targetSpeed = runSpeed * mult

		if SERVER then
			local drain = SND.Settings.Get("stamina_drain", 0.25)
			local nextStam = math.max(0, stamina - (FrameTime() * drain))
			ply:SetNWFloat("SND_Stamina", nextStam)
			if nextStam <= 0 then
				ply:SetNWBool("SND_Exhausted", true)
				ply:EmitSound("player/breathe1.wav", 50, 100, 0.4)
			end
		end
	else
		ply.SND_Sprinting = false
		if isExhausted then targetSpeed = walkSpeed end

		if SERVER and stamina < 1.0 then
			local recoverBase = SND.Settings.Get("stamina_recover", 0.15)
			local bonus = (not isMoving) and 2.0 or (ply:Crouching() and 1.2 or 0.6)
			local nextStam = math.min(1.0, stamina + (FrameTime() * recoverBase * bonus))
			ply:SetNWFloat("SND_Stamina", nextStam)
			if nextStam > 0.25 then ply:SetNWBool("SND_Exhausted", false) end
		end
	end

	-- Apply Jump Penalty (prevents bunny hopping)
	if ply.SND_JumpPenaltyTimer and CurTime() < ply.SND_JumpPenaltyTimer then
		targetSpeed = targetSpeed * 0.7
	end

	mv:SetMaxClientSpeed(targetSpeed)
	mv:SetMaxSpeed(targetSpeed)
end)

-- ── Fall Feedback (Screen Shake / View Punch) ─────────────────────────────
if SERVER then
	hook.Add("OnPlayerHitGround", "SND_FallLandingEffects", function(ply, inWater, onFloater, speed)
		if inWater or speed < 300 then return end

        -- Jump/Fall Fatigue: Slow player down briefly upon landing
        ply.SND_JumpPenaltyTimer = CurTime() + 0.5
        ply:SetVelocity(ply:GetVelocity() * 0.8)

		-- Always apply a slight view dip on landing
		local punchIntensity = math.Clamp(speed * 0.02, 2, 15)
		ply:ViewPunch(Angle(punchIntensity, 0, math.random(-2, 2)))

		-- If it was a hard landing (took damage threshold)
		if speed > 580 then
			-- Intense screen shake
			util.ScreenShake(ply:GetPos(), 12, 5, 0.6, 500)
			
			-- Play "thud" and grunt sounds
			ply:EmitSound("player/damage_fall" .. math.random(1, 3) .. ".wav", 75, 100, 0.8)
			ply:EmitSound("physics/flesh/flesh_bloody_break.wav", 70, 110, 0.4)
		end
	end)
end

-- ── Air acceleration tweak ────────────────────────────────────────────────
hook.Add("Move", "SND_AirAccel", function(ply, mv)
	if not IsValid(ply) or not ply:Alive() then return end
	if (SERVER and SND.Round.Phase == SND.PHASE_FREEZE) or (CLIENT and SND.Client.Phase == SND.PHASE_FREEZE) then return end
	if ply:IsOnGround() then return end

	local scale   = SND.Settings.Get("air_accel_scale", 1.35)
	local forward = mv:GetForwardSpeed()
	local side    = mv:GetSideSpeed()
	if forward == 0 and side == 0 then return end

	local wish = (ply:GetForward() * forward + ply:GetRight() * side)
	wish.z = 0
	if wish:Length() > 0 then
		wish:Normalize()
		local vel = mv:GetVelocity() + wish * (FrameTime() * 45 * scale)
		mv:SetVelocity(vel)
	end
end)
