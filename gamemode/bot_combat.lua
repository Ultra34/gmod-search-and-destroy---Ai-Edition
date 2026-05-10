function SND.Bots.GetAimVector(bot, target, skill)
	local targetPos = target:GetPos() + Vector(0, 0, 55)
	local dist = bot:EyePos():Distance(targetPos)
	local prediction = (dist / 16000) * target:GetVelocity()
	targetPos = targetPos + prediction

	local aimAng = (targetPos - bot:EyePos()):Angle()
	
	-- Recoil & Noise
	local noise = Lerp(SND.Bots.SkillT(skill), 70, 2)
	local spread = noise * (dist / 1200)
	if bot:KeyDown(IN_ATTACK) then
		aimAng.p = aimAng.p + Lerp(SND.Bots.SkillT(skill), 0, 2.0)
	end
	aimAng.p = aimAng.p + math.Rand(-spread, spread)
	aimAng.y = aimAng.y + math.Rand(-spread, spread)

	return aimAng
end

function SND.Bots.WeaponCheck(bot, cmd)
	local wep = bot:GetActiveWeapon()
	if not IsValid(wep) then return end
	local ai = bot.SND_AI

	local max = wep:GetMaxClip1()
	local clip = wep:Clip1() or 0
	local isSafe = (ai.state == 1 or ai.state == 8 or ai.state == 0) -- BS_PATROL, BS_SEARCH, BS_IDLE

	-- Emergency Switch
	if ai.state == 2 and max > 0 and clip <= 0 then
		for _, sClass in ipairs(SND.Config.Mw2eSecondaries) do
			local swep = bot:GetWeapon(sClass)
			if IsValid(swep) and swep:Clip1() > 0 then
				bot:SelectWeapon(sClass)
				return
			end
		end
	end

	-- Reloading
	if max > 0 and bot:GetAmmoCount(wep:GetPrimaryAmmoType()) > 0 then
		if clip <= 0 or (isSafe and clip < max) then
			cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_RELOAD))
			if not ai.needsReload then
				ai.needsReload = true
				local h = wep:GetHoldType() or "ar2"
				local act = _G["ACT_HL2MP_GESTURE_RELOAD_" .. h:upper()] or ACT_HL2MP_GESTURE_RELOAD_AR2
				bot:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, act, true)
			end
		end
	else
		ai.needsReload = false
	end
end

function SND.Bots.HandleFiring(bot, cmd, enemy, dist, skill)
	local ai = bot.SND_AI
	local now = CurTime()
	
	local wantShoot = (now > ai.shootGate) and (now > ai.nextShot)
	if wantShoot and now > (ai.nextFireGesture or 0) then
		local h = bot:GetActiveWeapon():GetHoldType() or "ar2"
		local act = _G["ACT_HL2MP_GESTURE_RANGE_ATTACK_" .. h:upper()] or ACT_HL2MP_GESTURE_RANGE_ATTACK_AR2
		bot:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, act, true)
		ai.nextFireGesture = now + 0.15
	end

	if now > ai.nextShot then
		if now > ai.shootGate then
			cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_ATTACK))
			ai.nextShot = now + ((dist > 1200) and math.Rand(0.08, 0.25) or 0.05)
		else
			if ai.shootGate == 0 or ai.enemy ~= enemy then
				ai.shootGate = now + Lerp(SND.Bots.SkillT(skill), 1.3, 0.04)
				ai.enemy = enemy
			end
		end
	end
end