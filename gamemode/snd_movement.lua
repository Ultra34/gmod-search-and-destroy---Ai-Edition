--[[ COD-ish movement: sprint multiplier, air accel tweak — not a full engine replacement ]]

SND.Movement = SND.Movement or {}

function SND.Movement.Setup(ply)
	ply.SND_Sprinting = false
end

hook.Add("SetupMove", "SND_Sprint", function(ply, mv, cmd)
	if not IsValid(ply) or not ply:Alive() then return end
	if SND.Round.Phase ~= SND.PHASE_LIVE and SND.Round.Phase ~= SND.PHASE_FREEZE then return end

	local mult = SND.Settings.Get("sprint_mult", 1.65)
	local onground = ply:IsOnGround()
	local wantspeed = cmd:KeyDown(IN_SPEED)

	local base = SND.Settings.GetInt("run_speed", 280)
	if onground and wantspeed then
		ply.SND_Sprinting = true
		mv:SetMaxClientSpeed(base * mult)
		mv:SetMaxSpeed(base * mult)
	else
		ply.SND_Sprinting = false
		mv:SetMaxClientSpeed(base)
		mv:SetMaxSpeed(base)
	end
end)

hook.Add("Move", "SND_AirAccel", function(ply, mv)
	if not IsValid(ply) or not ply:Alive() then return end
	if ply:IsOnGround() then return end

	local scale = SND.Settings.Get("air_accel_scale", 1.35)
	local vel = mv:GetVelocity()
	local aim = ply:GetAimVector()
	aim.z = 0
	aim:Normalize()

	local forward = mv:GetForwardSpeed()
	local side = mv:GetSideSpeed()
	if forward == 0 and side == 0 then return end

	local wish = (ply:GetForward() * forward + ply:GetRight() * side)
	wish.z = 0
	if wish:Length() > 0 then
		wish:Normalize()
		vel = vel + wish * (FrameTime() * 45 * scale)
		mv:SetVelocity(vel)
	end
end)
