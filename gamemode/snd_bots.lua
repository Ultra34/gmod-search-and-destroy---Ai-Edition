--[[ Bot AI — state machine, skill 1-10, weapon reload/switch, bomb objectives
--[[ Bot AI — state machine, skill 1-10, weapon reload/switch
--[[ Bot AI Reworked — Roam & Kill
     Uses PathFollower for navigation and tactical state management. ]]

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
		lastPathGoal  = Vector(0,0,0),
		nextScan      = 0,
		scanOffset    = 0,
		isScanning    = false,
		suppressedEnd = 0
	}
end

-- ── Custom Bot Naming System ─────────────────────────────────────────────
SND.Bots.CustomNamePool = {
	"radracerdk",
	"Dezener",
	"BOIDBERG",
	"Long Long Maaaaan",
	"TTV_LoopedVibes",
	"Soap",
	"Price",
	"Ghost",
	"Gaz",
	"Roach",
	"Sandman",
	"Grinch",
	"Frost",
	"Yuri",
	"Makarov",
	"Shepherd",
	"Kamarov",
	"Nikolai",
	"Alex",
	"Farah"
}

local currentBotNames = table.Copy(SND.Bots.CustomNamePool)

hook.Add("SND_RoundStart_Freeze", "SND_ResetBotNames", function()
	currentBotNames = table.Copy(SND.Bots.CustomNamePool)
end)

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
		local rawName = "SNDBot" .. i
		if #currentBotNames > 0 then
			local idx = math.random(#currentBotNames)
			rawName = currentBotNames[idx]
			table.remove(currentBotNames, idx)
		end

		local bot = player.CreateNextBot("[BOT] " .. string.sub(rawName, 1, 25))
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

-- ── Objective Helpers ────────────────────────────────────────────────────
local function nearestSite(bot)
	local map = game.GetMap()
	local sites = SND.Config.MapSites[map]
	if not sites or #sites == 0 then return nil, math.huge end
	local best, bestDist
	for _, s in ipairs(sites) do
		local d = bot:GetPos():DistToSqr(s.plantPos or s.pos)
		if not best or d < bestDist then best, bestDist = s, d end
	end
	return best, math.sqrt(bestDist)
end

local function weaponCheck(bot, cmd)
	local wep = bot:GetActiveWeapon()
	if not IsValid(wep) then return end
	local ai = bot.SND_AI

	local max = wep:GetMaxClip1()
	local clip = wep:Clip1()

	-- 1. Mid-fight emergency switch: Primary is empty, pull out secondary
	if ai.state == BS_ENGAGE and max > 0 and clip <= 0 then
		local isPri = false
		for _, pClass in ipairs(SND.Config.BotPrimaries) do
			if wep:GetClass() == pClass then isPri = true break end
		end

		if isPri then
			for _, sClass in ipairs(SND.Config.BotSecondaries) do
				local swep = bot:GetWeapon(sClass)
				if IsValid(swep) and swep:Clip1() > 0 then
					bot:SelectWeapon(sClass)
					return
				end
			end
		end
	end

	-- 2. Reloading: If empty, or safe and needs a top-off (checking reserve ammo)
	local isSafe = (ai.state == BS_PATROL or ai.state == BS_CHASE or ai.state == BS_IDLE)
	local hasReserve = bot:GetAmmoCount(wep:GetPrimaryAmmoType()) > 0
	if max > 0 and hasReserve then
		if clip <= 0 or (isSafe and clip < max) then
			cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_RELOAD))
		end
	end

	-- 3. Recovery: Switch back to primary once the area is clear
	if isSafe and clip >= 0 then
		for _, pClass in ipairs(SND.Config.BotPrimaries) do
			local pwep = bot:GetWeapon(pClass)
			if IsValid(pwep) and pwep ~= wep and pwep:Clip1() > 0 then
				bot:SelectWeapon(pClass)
				break
			end
		end
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
	if not isvector(targetPos) then return 0 end

	local ai = bot.SND_AI
	local myPos = bot:GetPos()
	local moveDest = Vector(targetPos.x, targetPos.y, targetPos.z)

	if navmesh.IsLoaded() then
		if not ai.path then
			ai.path = Path("Follow")
			ai.path:SetMinLookAheadDistance(300)
			ai.path:SetGoalTolerance(20)
		end

		-- Recompute path every 1 second or if goal moves
		if CurTime() > ai.nextPathUpdate or ai.lastPathGoal:DistToSqr(targetPos) > 16384 then
			ai.path:Compute(bot, targetPos)
			ai.nextPathUpdate = CurTime() + 1.0
			ai.lastPathGoal = targetPos
		end

		if ai.path:IsValid() then
			ai.path:Update(bot)
			-- FIX: GetPositionOnPath converts the distance (number) into a Vector (coordinates)
			local cursorDist = ai.path:GetCursorPosition()
			local pathPos = ai.path:GetPositionOnPath(cursorDist)
			if isvector(pathPos) then 
				moveDest = pathPos 
			end
		end
	end

	-- Safety: Ensure moveDest is a vector before subtraction
	if not isvector(moveDest) then moveDest = targetPos end

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

	local distToGoal = moveDest:Distance(myPos)

	-- Only adjust eye angles for movement when not actively engaging an enemy
	if ai.state ~= BS_ENGAGE and distToGoal > 15 then
		local goalAngle = (moveDest - myPos):Angle()
		goalAngle.p = 0

		-- Tactical Roam: Check corners while moving
		if CurTime() > ai.nextScan then
			-- 30% chance to scan a corner, otherwise stay focused forward
			ai.isScanning = math.random() < 0.3
			ai.scanOffset = ai.isScanning and math.random(-45, 45) or 0
			ai.nextScan = CurTime() + math.Rand(0.5, 2.0)
		end

		local targetYaw = goalAngle.y + ai.scanOffset
		local lerpSpeed = ai.isScanning and 0.05 or 0.15 -- Slower look-overs, faster forward focus
		
		-- Normalize Angle for Lerp to prevent spinning at 180 degrees
		local curAng = bot:EyeAngles()
		local diff = math.NormalizeAngle(targetYaw - curAng.y)
		curAng.y = curAng.y + diff * lerpSpeed
		
		bot:SetEyeAngles(curAng)
	end

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

	-- ── Objective & Role Logic ──────────────────────────────────────────
	local targetObj = nil
	local isCarrier = (bot:Team() == SND.TEAM_ATTACK and SND.Bomb.Carrier == bot)
	local isRetaker = (bot:Team() == SND.TEAM_DEFEND and SND.Bomb.State == SND.BOMB_STATE_PLANTED)

	-- Update objective state if not in active combat
	if ai.state ~= BS_ENGAGE then
		if isCarrier then ai.state = BS_PLANT
		elseif isRetaker then ai.state = BS_DEFUSE
		elseif ai.state == BS_IDLE then ai.state = BS_PATROL end
	end

	if ai.state == BS_PATROL or ai.state == BS_PLANT or ai.state == BS_DEFUSE or ai.state == BS_CHASE then
		if ai.state == BS_PLANT then
			local site = nearestSite(bot)
			if site then targetObj = site.plantPos or site.pos end
		elseif ai.state == BS_DEFUSE then
			targetObj = SND.Bomb.PlantPos
		elseif bot:Team() == SND.TEAM_ATTACK then
			-- Support carrier
			if IsValid(SND.Bomb.Carrier) then targetObj = SND.Bomb.Carrier:GetPos() end
		else
			-- Guard sites
			local sites = SND.Config.MapSites[game.GetMap()]
			if sites and #sites > 0 then
				local siteIdx = (bot:EntIndex() % #sites) + 1
				targetObj = sites[siteIdx].plantPos or sites[siteIdx].pos
			end
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
		
		local goal = targetObj or ai.lastKnownPos
		if goal then
			-- If we are already mid-interaction, stop moving entirely to avoid velocity cancellation
			if bot.SND_Planting or bot.SND_Defusing then
				cmd:ClearMovement()
				cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_USE))
				bot:SetEyeAngles(LerpAngle(0.1, bot:EyeAngles(), Angle(45, bot:EyeAngles().y, 0)))
			else
				local d = moveToward(bot, cmd, goal, speed)
			
				-- Start interaction if close enough
				if d < 110 then
					if (ai.state == BS_PLANT or ai.state == BS_DEFUSE) then
						cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_USE))
						-- Look at the ground to prepare the plant/defuse trace
						bot:SetEyeAngles(LerpAngle(0.1, bot:EyeAngles(), Angle(45, bot:EyeAngles().y, 0)))
					elseif bot:Team() == SND.TEAM_DEFEND then
						cmd:ClearMovement() -- Camping
					end
				end
			end
		end
	end

	-- Suppression reaction
	if now < ai.suppressedEnd then
		cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_DUCK))
	end

	
	weaponCheck(bot, cmd)
end)

-- ── Acoustic Awareness: Reacting to footsteps and gunshots ───────────────
hook.Add("EntityEmitSound", "SND_BotHearing", function(t)
	local src = t.Entity
	if not IsValid(src) or not src:IsPlayer() or not src:Alive() then return end

	local soundPos = t.Pos or src:GetPos()
	local isGunshot = string.find(t.SoundName:lower(), "fire") or string.find(t.SoundName:lower(), "shoot")
	local isFootstep = string.find(t.SoundName:lower(), "step")

	-- Define hearing ranges
	local range = 0
	if isGunshot then range = 2500 end
	if isFootstep then range = 500 end
	if range == 0 then return end

	for _, bot in ipairs(player.GetAll()) do
		if not bot.SND_IsBot or not bot:Alive() or bot:Team() == src:Team() then continue end
		
		local ai = bot.SND_AI
		if not ai or ai.state == BS_ENGAGE then continue end

		local dist = bot:GetPos():Distance(soundPos)
		local skill = getSkill()
		
		-- High skill bots hear better and from further away
		local modifiedRange = range * (0.5 + (skill / 10))

		if dist < modifiedRange then
			-- If the bot can't see the target, they investigate the sound
			if not canSee(bot, src) then
				ai.lastKnownPos = soundPos
				ai.lastKnownTime = CurTime()
				
				-- Only switch to chase if currently idling or patrolling
				if ai.state == BS_IDLE or ai.state == BS_PATROL then
					ai.state = BS_CHASE
				end
			end
		end
	end
end)

-- ── Suppression: Reacting to bullets whizzing past ──────────────────────
hook.Add("EntityFireBullets", "SND_BotSuppression", function(ent, data)
	if not IsValid(ent) or not ent:IsPlayer() then return end

	local src = data.Src
	local dir = data.Dir
	local dist = data.Distance or 4096

	for _, bot in ipairs(player.GetAll()) do
		if not bot.SND_IsBot or not bot:Alive() or bot:Team() == ent:Team() then continue end

		local ai = bot.SND_AI
		if not ai then continue end

		local botPos = bot:WorldSpaceCenter()
		local lineVec = botPos - src
		local dot = lineVec:Dot(dir)

		-- If bullet is flying towards or past the bot
		if dot > 0 and dot < dist then
			local closestPoint = src + dir * dot
			local distToBullet = closestPoint:Distance(botPos)

			if distToBullet < 80 then -- Bullet whizzed within 80 units
				ai.suppressedEnd = CurTime() + math.Rand(0.8, 2.0)
				
				-- Clue for investigation if not already fighting
				if ai.state ~= BS_ENGAGE then
					ai.lastKnownPos = ent:GetPos()
					ai.lastKnownTime = CurTime()
				end
			end
		end
	end
end)
hook.Add("Think", "SND_BotFreezeVelocity", function()
	if SND.Round.Phase ~= SND.PHASE_FREEZE then return end
	for _, bot in ipairs(player.GetAll()) do
		if bot.SND_IsBot and IsValid(bot) and bot:Alive() then
			bot:SetVelocity(-bot:GetVelocity())  -- cancel any residual velocity
		end
	end
end)
