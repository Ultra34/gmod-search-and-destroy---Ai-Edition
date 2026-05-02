--[[ Bot AI — state machine, skill 1-10, weapon reload/switch, bomb objectives
--[[ Bot AI Reworked — Goal-Oriented Action Planning
     Focuses on pathfinding, lead-aiming, and objective priority. ]]

SND.Bots = SND.Bots or {}

-- ── Bot states ────────────────────────────────────────────────────────────
local BS_IDLE   = 0   -- frozen (freeze phase or waiting)
local BS_PATROL = 1   -- no enemies known; wandering
local BS_ENGAGE = 2   -- has line of sight on an enemy; shooting
local BS_CHASE  = 3   -- lost sight; walking to last known position
local BS_PLANT  = 4   -- attacker + bomb carrier; moving to site
local BS_DEFUSE = 5   -- defender; bomb planted; moving to bomb
local BS_RELOAD = 6   -- weapon empty/low; reloading or switching

-- ── Skill 1-10 → internal float helpers ──────────────────────────────────
local function skillT(s)       return (math.Clamp(s, 1, 10) - 1) / 9 end
local function getSkill()      return SND.Settings.GetInt("bot_skill", 5) end
local function aimNoise(s)     return Lerp(skillT(s), 12, 0.5) end
local function reactionSec(s)  return Lerp(skillT(s), 0.8, 0.1) end
local function engageRange(s)  return Lerp(skillT(s), 1500, 5000) end
local function botMoveSpeed(s) return Lerp(skillT(s), 180, 320) end

-- ── AI State ──────────────────────────────────────────────────────────────
local function newAI()
	return {
		state         = BS_IDLE,
		enemy         = nil,     -- current target
		lastKnownPos  = nil,
		lastKnownTime = 0,
		canShoot      = false,   -- reaction time gate
		shootGate     = 0,       -- CurTime() when bot may first fire at this target
		patrolAngle   = math.Rand(0, 360),
		patrolFlip    = 0,
		needsReload   = false,
		reloadEnd     = 0,
		strafeDir     = 1,
		strafeFlip    = 0,
		stuckPos      = Vector(0,0,0),
		stuckCheck    = 0,
		nextShot      = 0,
		path          = nil, -- PathFollower object
		nextPathUpdate = 0,
		lastPathGoal  = Vector(0,0,0)
	}
end

function SND.Bots.CountBots()
	local n = 0
	for _, p in ipairs(player.GetAll()) do if p.SND_IsBot then n = n + 1 end end
	return n
end

local function pickTeam()
	local a = #team.GetPlayers(SND.TEAM_ATTACK)
	local d = #team.GetPlayers(SND.TEAM_DEFEND)
	return (a <= d) and SND.TEAM_ATTACK or SND.TEAM_DEFEND
end

function SND.Bots.EnsureCount()
	local want = SND.Settings.GetInt("bot_count", 0)
	if want <= 0 then return end
	local have = SND.Bots.CountBots()
	if have >= want then return end

	for i = have + 1, want do
		local bot = player.CreateNextBot("SNDBot" .. i)
		if not IsValid(bot) then
			print("[SND Bots] CreateNextBot failed (slot " .. i .. ").")
			timer.Simple(2, function() SND.Bots.EnsureCount() end)
			break
		end
		bot.SND_IsBot = true
		bot.SND_AI    = newAI()
		bot:SetTeam(pickTeam())
		SND.Teams.ApplyFactionModel(bot)
		bot:Spawn()
	end
end

function SND.Bots.OnPlayerSpawn(ply)
	if not ply.SND_IsBot then return end
	SND.Teams.ApplyFactionModel(ply)
	ply.SND_AI = newAI()
end

hook.Add("PlayerDisconnected", "SND_BotRefill", function(ply)
	if not ply.SND_IsBot then return end
	timer.Simple(1, function() SND.Bots.EnsureCount() end)
end)

-- ── Line-of-sight ─────────────────────────────────────────────────────────
local function canSee(bot, target)
	if not IsValid(target) then return false end
	local tr = util.TraceLine({
		start  = bot:GetShootPos(),
		endpos = target:EyePos(),
		filter = { bot, target },
		mask   = MASK_SHOT_HULL,
	})
	return tr.Entity == target or tr.Fraction >= 0.99
end

-- ── Nearest visible / nearest any enemy ──────────────────────────────────
local function nearestEnemy(bot, requireLOS)
	local best, bestDist2
	for _, p in ipairs(player.GetAll()) do
		if p ~= bot and p:Alive() and p:Team() ~= bot:Team() then
			if not requireLOS or canSee(bot, p) then
				local d2 = bot:GetPos():DistToSqr(p:GetPos())
				if not bestDist2 or d2 < bestDist2 then
					best, bestDist2 = p, d2
				end
			end
		end
	end
	return best, bestDist2 and math.sqrt(bestDist2)
end

-- ── Nearest bomb site helper ─────────────────────────────────────────────
local function nearestSite(bot)
	local map = game.GetMap()
	local sites = SND.Config.MapSites[map]
	if not sites or #sites == 0 then return nil, math.huge end
	local best, bestDist
	for _, s in ipairs(sites) do
		local d = bot:GetPos():Distance(s.plantPos)
		if not best or d < bestDist then best, bestDist = s, d end
	end
	return best, bestDist
end

local function weaponCheck(bot, cmd)
	local wep = bot:GetActiveWeapon()
	if not IsValid(wep) then return end

	local max = wep:GetMaxClip1()
	if max > 0 and wep:Clip1() <= 0 then
		cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_RELOAD))
	end

	-- Switch to primary if we have ammo and are currently using a pistol
	local primary = bot:GetWeapon(SND.Config.BotPrimaries[1] or "")
	if IsValid(primary) and primary ~= wep and primary:Clip1() > 0 then
		bot:SelectWeapon(primary:GetClass())
	end
end

local function switchToFilledWeapon(bot)
	local active = bot:GetActiveWeapon()
	for _, wep in ipairs(bot:GetWeapons()) do
		if IsValid(wep) and wep ~= active then
			local max = wep:GetMaxClip1()
			if max <= 0 or wep:Clip1() > 0 then
				bot:SelectWeapon(wep:GetClass())
				return true
			end
		end
	end
	return false
end

-- ── Navigation ────────────────────────────────────────────────────────────
local function moveToward(bot, cmd, targetPos, speed)
	local ai = bot.SND_AI
	local myPos = bot:GetPos()
	local moveDest = targetPos

	-- Use NavMesh pathfinding if available
	if navmesh.IsLoaded() then
		if not ai.path then
			ai.path = Path("Follow")
			ai.path:SetMinLookAheadDistance(300)
			ai.path:SetGoalTolerance(20)
		end

		-- Recompute path if goal changed significantly or every second
		if CurTime() > ai.nextPathUpdate or ai.lastPathGoal:DistToSqr(targetPos) > 4096 then
			ai.path:Compute(bot, targetPos)
			ai.nextPathUpdate = CurTime() + 1.0
			ai.lastPathGoal = targetPos
		end

		-- Standard PathFollower:Update(bot) then verify position
		if ai.path:IsValid() then
			ai.path:Update(bot)
			local pos = ai.path:GetCursorPosition()
			if pos then moveDest = pos end
		end
	end

	local diff = moveDest - myPos
	local dist = (targetPos - myPos):Length()

	if dist < 30 then return dist end

	-- Improved Stuck detection / Obstacle jumping
	if bot:IsOnGround() and CurTime() > ai.stuckCheck then
		if myPos:Distance(ai.stuckPos) < 15 then
			cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_JUMP))
		end
		ai.stuckPos = myPos
		ai.stuckCheck = CurTime() + 0.5
	end

	-- Steering
	local goalAngle = (moveDest - myPos):Angle()
	goalAngle.p = 0
	
	local curAngle = bot:EyeAngles()
	local smoothed = LerpAngle(0.2, curAngle, goalAngle)
	bot:SetEyeAngles(smoothed)

	cmd:SetForwardMove(speed)
	return dist
end

-- Lead aiming: Predict where the player will be based on velocity
local function getAimVector(bot, target, noise)
	local targetPos = target:GetPos() + Vector(0, 0, 55) -- Aim for chest/head
	local dist = bot:GetPos():Distance(targetPos)
	
	-- Prediction: Bullet travel time simulation
	local velocity = target:GetVelocity()
	local prediction = (dist / 15000) * velocity -- Adjust 15000 based on average bullet speed
	targetPos = targetPos + prediction

	local aimAng = (targetPos - bot:EyePos()):Angle()
	aimAng.p = aimAng.p + math.Rand(-noise, noise)
	aimAng.y = aimAng.y + math.Rand(-noise, noise)

	return aimAng
end

-- ── Main Logic ────────────────────────────────────────────────────────────
hook.Add("StartCommand", "SND_BotAI", function(bot, cmd)
	if not bot.SND_IsBot or not bot:Alive() then return end

	if SND.Round.Phase == SND.PHASE_FREEZE then
		cmd:ClearButtons()
		cmd:ClearMovement()
		return
	end

	local ai = bot.SND_AI
	if not ai then bot.SND_AI = newAI() ai = bot.SND_AI end

	local skill = getSkill()
	local speed = botMoveSpeed(skill)
	local now = CurTime()

	-- Objective: Bomb Site / Bomb
	local targetObj = nil
	if bot:Team() == SND.TEAM_ATTACK then
		if SND.Bomb.Carrier == bot then
			local site = nearestSite(bot)
			if site then targetObj = site.plantPos end
		end
	elseif bot:Team() == SND.TEAM_DEFEND then
		if SND.Bomb.State == SND.BOMB_STATE_PLANTED then
			targetObj = SND.Bomb.PlantPos
		end
	end

	-- Combat Scanning
	local enemy, dist = nearestEnemy(bot, true)
	if IsValid(enemy) and dist < engageRange(skill) then
		ai.state = BS_ENGAGE
		ai.lastKnownPos = enemy:GetPos()
		ai.lastKnownTime = now

		-- Aiming
		local aim = getAimVector(bot, enemy, aimNoise(skill))
		bot:SetEyeAngles(LerpAngle(0.1 + (skill * 0.05), bot:EyeAngles(), aim))

		-- Shooting with burst logic
		if now > ai.nextShot then
			if now > ai.shootGate then
				cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_ATTACK))
				
				-- Real trigger control: High skill bots tap at range
				local burst = (dist > 1000) and math.Rand(0.1, 0.3) or 0.05
				ai.nextShot = now + burst
			else
				-- Reaction time simulation
				if ai.shootGate == 0 or ai.enemy ~= enemy then
					ai.shootGate = now + reactionSec(skill)
					ai.enemy = enemy
				end
			end
		end

		-- Combat movement (Strafe)
		if now > ai.strafeFlip then
			ai.strafeDir = -ai.strafeDir
			ai.strafeFlip = now + math.Rand(1, 3)
		end
		cmd:SetSideMove(ai.strafeDir * speed)

		-- Close distance or maintain gap
		if dist > 600 then
			cmd:SetForwardMove(speed)
		elseif dist < 300 then
			cmd:SetForwardMove(-speed)
		end

		-- Smart crouching
		if skill > 7 and dist > 800 then
			cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_DUCK))
		end
	else
		-- No enemy visible, focus on objectives or patrol
		ai.enemy = nil
		ai.shootGate = 0
		
		if targetObj then
			local d = moveToward(bot, cmd, targetObj, speed)
			if skill > 4 then cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_SPEED)) end
			
			-- Interaction (Plant/Defuse)
			if d < 100 then
				cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_USE))
				-- Look down while planting
				local ang = bot:EyeAngles()
				ang.p = 45
				bot:SetEyeAngles(LerpAngle(0.1, bot:EyeAngles(), ang))
			end
		elseif ai.lastKnownPos and (now - ai.lastKnownTime) < 8 then
			-- Chase last known
			moveToward(bot, cmd, ai.lastKnownPos, speed)
		else
			-- Patrol
			if now > ai.patrolFlip then
				ai.patrolAngle = math.Rand(0, 360)
				ai.patrolFlip = now + math.Rand(4, 10)
			end
			local targetAng = Angle(0, ai.patrolAngle, 0)
			bot:SetEyeAngles(LerpAngle(0.05, bot:EyeAngles(), targetAng))
			cmd:SetForwardMove(speed * 0.6)
		end
	end

	
	weaponCheck(bot, cmd)
end)

hook.Add("Think", "SND_BotFreezeVelocity", function()
	if SND.Round.Phase ~= SND.PHASE_FREEZE then return end
	for _, bot in ipairs(player.GetAll()) do
		if bot.SND_IsBot and IsValid(bot) and bot:Alive() then
			bot:SetVelocity(-bot:GetVelocity())  -- cancel any residual velocity
		end
	end
end)
