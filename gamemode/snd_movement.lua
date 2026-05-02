--[[ COD-style movement: freeze lock, sprint, air accel
     REPLACES: gamemode/snd_movement.lua ]]

SND.Movement = SND.Movement or {}

function SND.Movement.Setup(ply)
	ply.SND_Sprinting = false
end

hook.Add("StartCommand", "SND_FreezeInput", function(ply, cmd)
	if not IsValid(ply) or not ply:Alive() then return end

	local phase = SERVER and SND.Round.Phase or SND.Client.Phase
	if phase == SND.PHASE_FREEZE then
		-- Block all action inputs to prevent shooting, reloading, or planting
		-- Intercepting buttons in StartCommand is more reliable for blocking weapon fire
		local blocked = bit.bor(IN_ATTACK, IN_ATTACK2, IN_RELOAD, IN_USE)
		cmd:SetButtons(bit.band(cmd:GetButtons(), bit.bnot(blocked)))
		cmd:ClearMovement()
	end
end)

hook.Add("SetupMove", "SND_Movement", function(ply, mv, cmd)
	if not IsValid(ply) or not ply:Alive() then return end

	-- ── FREEZE: nobody moves ───────────────────────────────────────────────
	local phase = SERVER and SND.Round.Phase or SND.Client.Phase
	if phase == SND.PHASE_FREEZE then
		mv:SetForwardSpeed(0)
		mv:SetSideSpeed(0)
		mv:SetUpSpeed(0)
		mv:SetVelocity(Vector(0, 0, 0))
		ply.SND_Sprinting = false
		return
	end

	if phase ~= SND.PHASE_LIVE then return end

	-- ── SPRINT ────────────────────────────────────────────────────────────
	local mult    = SND.Settings.Get("sprint_mult", 1.65)
	local base    = SND.Settings.GetInt("run_speed", 280)
	local onGround = ply:IsOnGround()
	local wantSprint = cmd:KeyDown(IN_SPEED)

	if onGround and wantSprint then
		ply.SND_Sprinting = true
		mv:SetMaxClientSpeed(base * mult)
		mv:SetMaxSpeed(base * mult)
	else
		ply.SND_Sprinting = false
		mv:SetMaxClientSpeed(base)
		mv:SetMaxSpeed(base)
	end
end)

-- ── Air acceleration tweak ────────────────────────────────────────────────
hook.Add("Move", "SND_AirAccel", function(ply, mv)
	if not IsValid(ply) or not ply:Alive() then return end
	if SND.Round.Phase == SND.PHASE_FREEZE then return end
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

-- ── Fall Feedback (Screen Shake / View Punch) ─────────────────────────────
if SERVER then
	hook.Add("OnPlayerHitGround", "SND_FallLandingEffects", function(ply, inWater, onFloater, speed)
		if inWater or speed < 300 then return end

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
