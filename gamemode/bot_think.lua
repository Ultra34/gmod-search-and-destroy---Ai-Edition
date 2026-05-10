function SND.Bots.Think(bot, cmd)
	local ai = bot.SND_AI
	local skill = SND.Bots.GetSkill()
	local now = CurTime()
	local speed = Lerp(SND.Bots.SkillT(skill), 120, 310) * (ai.personality.roamSpeedMult or 1)

	-- Combat Logic (Internalizes Firing, Aiming, Recoil, and FSMs)
	SND.Bots.CombatThink(bot, cmd)

	local target = ai.target
	local canSee = SND.Bots.CanSee(bot, target)
	local shouldEngage = IsValid(target) and canSee

	if shouldEngage then
		local dist = bot:GetPos():Distance(target:GetPos())
		ai.state = 2 -- BS_ENGAGE

		-- Tactical Movement (ADAD)
		if now > ai.strafeFlip then
			ai.strafeDir = -ai.strafeDir
			ai.strafeFlip = now + math.Rand(0.5, 1.5)
		end
		
		-- Force attack bits from CombatThink
		if ai.wantAttack or (ai.tapUntil and now < ai.tapUntil) then
			cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_ATTACK))
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