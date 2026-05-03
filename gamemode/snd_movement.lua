--[[ COD-style movement: freeze lock, sprint, air accel
     REPLACES: gamemode/snd_movement.lua ]]

SND.Movement = SND.Movement or {}

function SND.Movement.Setup(ply)
	ply.SND_Sprinting = false
end

hook.Add("StartCommand", "SND_FreezeInput", function(ply, cmd)
	if not IsValid(ply) or not ply:Alive() then return end

	local phase = SERVER and SND.Round.Phase or SND.Client.Phase
	if phase == SND.PHASE_FREEZE or phase == SND.PHASE_POST or phase == SND.PHASE_KILLCAM then
		-- Block all action inputs to prevent shooting, reloading, or planting
		-- Intercepting buttons in StartCommand is more reliable for blocking weapon fire
		local blocked = bit.bor(IN_ATTACK, IN_ATTACK2, IN_RELOAD, IN_USE)
		cmd:SetButtons(bit.band(cmd:GetButtons(), bit.bnot(blocked)))
		cmd:ClearMovement()
	end
end)

-- ── Aggressive Fire Block (Server & Client) ──────────────────────────────
hook.Add("Think", "SND_FreezeFireLock", function()
	local phase = SERVER and SND.Round.Phase or (SND.Client and SND.Client.Phase)
	if phase ~= SND.PHASE_FREEZE and phase ~= SND.PHASE_POST and phase ~= SND.PHASE_KILLCAM then end

	for _, ply in ipairs(player.GetAll()) do
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
	if phase == SND.PHASE_FREEZE or phase == SND.PHASE_POST or phase == SND.PHASE_KILLCAM then
		mv:SetForwardSpeed(0)
		mv:SetSideSpeed(0)
		mv:SetUpSpeed(0)
		mv:SetVelocity(Vector(0, 0, 0))
		ply.SND_Sprinting = false
		return
	end

	if phase ~= SND.PHASE_LIVE then return end

	-- ── SPRINT ────────────────────────────────────────────────────────────
    local mult        = SND.Settings.Get("sprint_mult", 1.5)
    local base        = SND.Settings.GetInt("run_speed", 280)
    local onGround    = ply:IsOnGround()
    local wantSprint  = cmd:KeyDown(IN_SPEED)
    local stamina     = ply:GetNWFloat("SND_Stamina", 1.0)
    local isMoving    = mv:GetForwardSpeed() > 0

    -- Sprint Stamina Logic (MW2 had limited sprint duration)
    if onGround and wantSprint and isMoving and stamina > 0 and not ply:Crouching() then
        ply.SND_Sprinting = true
        local sprintSpeed = base * mult
        
        -- Apply Jump Penalty (prevents bunny hopping)
        if ply.SND_JumpPenaltyTimer and CurTime() < ply.SND_JumpPenaltyTimer then
            sprintSpeed = sprintSpeed * 0.7
        end

        mv:SetMaxClientSpeed(sprintSpeed)
        mv:SetMaxSpeed(sprintSpeed)

        if SERVER then
            ply:SetNWFloat("SND_Stamina", math.max(0, stamina - (FrameTime() * 0.25))) -- ~4 seconds of sprint
        end
    else
        ply.SND_Sprinting = false
        mv:SetMaxClientSpeed(base)
        mv:SetMaxSpeed(base)

        if SERVER and stamina < 1.0 then
            ply:SetNWFloat("SND_Stamina", math.min(1.0, stamina + (FrameTime() * 0.4))) -- Recovery
        end
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

-- ── Sprint View Bobbing (Client Only) ─────────────────────────────────────
if CLIENT then
    hook.Add("CalcView", "SND_SprintViewBob", function(ply, pos, ang, fov)
        if not ply:Alive() or ply:GetObserverMode() ~= OBS_MODE_NONE then return end
        
        if ply.SND_Sprinting and ply:IsOnGround() and ply:GetVelocity():Length2D() > 100 then
            local t = CurTime() * 10
            local intensity = 0.5
            
            -- MW2-style camera sway/roll during sprint
            ang.roll = ang.roll + math.sin(t * 0.5) * intensity
            ang.pitch = ang.pitch + math.cos(t) * (intensity * 0.5)
            
            return {
                angles = ang
            }
        end
    end)
end
