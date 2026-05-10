function SND.Bots.MoveToward(bot, cmd, targetPos, speed)
	if not isvector(targetPos) then return 0 end
	local ai = bot.SND_AI
	local myPos = bot:GetPos()

	if not navmesh.IsLoaded() then
		cmd:ClearMovement()
		return myPos:Distance(targetPos)
	end

	if not ai.path then
		ai.path = Path("Follow")
		ai.path:SetMinLookAheadDistance(200)
		ai.path:SetGoalTolerance(20)
	end

	local goalShift = ai.lastPathGoal:DistToSqr(targetPos)
	if not ai.path:IsValid() or CurTime() > ai.nextPathUpdate or goalShift > 4096 then
		local jitter = Vector(math.Rand(-40, 40), math.Rand(-40, 40), 0)
		ai.path:Compute(bot, targetPos + jitter)
		ai.nextPathUpdate = CurTime() + math.Rand(1.0, 2.0)
		ai.lastPathGoal = targetPos
	end

	local moveDest = targetPos
	if ai.path:IsValid() then
		ai.path:Update(bot)
		local segments = ai.path:GetAllSegments()
		moveDest = (segments and #segments > 1) and segments[2].pos or targetPos
	end

	-- Obstacle Avoidance
	local eyePos = bot:EyePos()
	local wallTrace = util.TraceHull({
		start = eyePos,
		endpos = eyePos + bot:GetForward() * 48,
		filter = bot,
		mins = Vector(-16, -16, -16),
		maxs = Vector(16, 16, 16),
		mask = MASK_PLAYERSOLID
	})

	if wallTrace.Hit and wallTrace.HitWorld then
		if CurTime() > ai.nextJump then
			cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_JUMP))
			ai.nextJump = CurTime() + 1.2
		end
		local dot = wallTrace.HitNormal:Dot(bot:GetRight())
		cmd:SetSideMove(speed * ((dot > 0) and 1 or -1))
	end

	-- Stuck Resolution
	if bot:IsOnGround() and speed > 0 then
		if myPos:DistToSqr(ai.stuckPos) < 256 then
			if CurTime() > ai.stuckCheck then
				if ai.stuckStartTime == 0 then ai.stuckStartTime = CurTime() end
				if CurTime() > ai.nextJump then
					cmd:SetButtons(bit.bor(cmd:SetButtons(), IN_JUMP))
					ai.nextJump = CurTime() + 0.8
				end
				cmd:SetSideMove(math.Rand(-speed, speed))
				cmd:SetForwardMove(math.Rand(-speed, speed))
				if CurTime() - ai.stuckStartTime > 4 then
					ai.path = nil
					ai.stuckStartTime = 0
				end
			end
		else
			ai.stuckPos = myPos
			ai.stuckCheck = CurTime() + 0.5
			ai.stuckStartTime = 0
		end
	end

	-- View Angles & Scanning
	local distToGoal = moveDest:Distance(myPos)
	if bot.SND_AI.state ~= 2 and distToGoal > 15 then -- Not BS_ENGAGE
		local goalAngle = (moveDest - myPos):Angle()
		if CurTime() > ai.nextScan then
			ai.isScanning = math.random() < 0.4
			ai.scanOffset = ai.isScanning and math.random(-60, 60) or 0
			ai.nextScan = CurTime() + math.Rand(0.5, 2.0)
		end

		local targetYaw = goalAngle.y + ai.scanOffset
		local curAng = bot:EyeAngles()
		local diff = math.NormalizeAngle(targetYaw - curAng.y)
		curAng.y = curAng.y + diff * (ai.isScanning and 0.05 or 0.15)
		bot:SetEyeAngles(curAng)
		cmd:SetViewAngles(curAng)
	end

	cmd:SetForwardMove(speed)
	return myPos:Distance(targetPos)
end