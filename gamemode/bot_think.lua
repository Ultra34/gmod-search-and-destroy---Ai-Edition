function SND.Bots.Think(bot, cmd)
	local ai = bot.SND_AI
	local skill = SND.Bots.GetSkill()
	local now = CurTime()
	local speed = Lerp(SND.Bots.SkillT(skill), 120, 310) * (ai.personality.roamSpeedMult or 1)

	-- Target Selection
	local enemy, dist = nil, math.huge
	for _, p in ipairs(player.GetAll()) do
		if p:Alive() and SND.Bots.AreEnemies(bot, p) and SND.Bots.CanSee(bot, p) then
			local d = bot:GetPos():Distance(p:GetPos())
			if d < dist then enemy, dist = p, d end
		end
	end

	local engageRange = Lerp(SND.Bots.SkillT(skill), 600, 3800)
	local shouldEngage = IsValid(enemy) and dist < engageRange

	if shouldEngage then
		ai.state = 2 -- BS_ENGAGE
		ai.lastKnownPos = enemy:GetPos()
		
		-- Aiming
		local aim = SND.Bots.GetAimVector(bot, enemy, skill)
		local newAng = LerpAngle(0.12 + SND.Bots.SkillT(skill) * 0.2, bot:EyeAngles(), aim)
		bot:SetEyeAngles(newAng)
		cmd:SetViewAngles(newAng)

		-- Firing
		SND.Bots.HandleFiring(bot, cmd, enemy, dist, skill)

		-- Tactical Movement (ADAD)
		if now > ai.strafeFlip then
			ai.strafeDir = -ai.strafeDir
			ai.strafeFlip = now + math.Rand(0.5, 1.5)
		end
		cmd:SetSideMove(ai.strafeDir * speed)
		
		if dist > (ai.personality.holdRange or 600) then
			cmd:SetForwardMove(speed)
		elseif dist < 300 then
			cmd:SetForwardMove(-speed)
		end
	else
		-- Objective Logic
		local goal = nil
		local isCarrier = (bot:Team() == SND.TEAM_ATTACK and SND.Bomb.Carrier == bot)
		local isDefusing = (bot:Team() == SND.TEAM_DEFEND and SND.Bomb.State == SND.BOMB_STATE_PLANTED)

		if isCarrier then
			ai.state = 4 -- BS_PLANT
			local sites = SND.Config.MapSites[game.GetMap()] or {}
			local site = sites[1] -- Simplified: go to A
			if site then goal = site.plantPos end
		elseif isDefusing then
			ai.state = 5 -- BS_DEFUSE
			goal = SND.Bomb.PlantPos
		else
			ai.state = 1 -- BS_PATROL
			local sites = SND.Config.MapSites[game.GetMap()] or {}
			local s = (#sites > 0) and sites[(bot:EntIndex() % #sites) + 1] or nil
			if s then goal = s.plantPos end
		end

		if goal then
			local d = SND.Bots.MoveToward(bot, cmd, goal, speed)
			if d < 100 then
				if isCarrier or isDefusing then
					cmd:ClearMovement()
					cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_USE))
					bot:SetEyeAngles(LerpAngle(0.1, bot:EyeAngles(), Angle(75, bot:EyeAngles().y, 0)))
				end
			end
		end
	end

	SND.Bots.WeaponCheck(bot, cmd)
end