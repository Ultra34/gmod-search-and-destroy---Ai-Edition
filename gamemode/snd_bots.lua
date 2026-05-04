--[[ Bot AI — state machine, skill 1-10, weapon reload/switch, bomb objectives
--[[ Bot AI Reworked — Roam, Investigate, & Objective Play ]]

SND.Bots = SND.Bots or {}

-- ── Debugging ─────────────────────────────────────────────────────────────
if SERVER then
	CreateConVar("snd_bot_debug_paths", "0", FCVAR_CHEAT, "Visualize bot pathfinding segments in real-time.")

	hook.Add("Think", "SND_BotDebugPaths", function()
		if not GetConVar("snd_bot_debug_paths"):GetBool() then return end

		for _, bot in ipairs(player.GetAll()) do
			if not bot.SND_IsBot or not bot:Alive() then continue end
			local ai = bot.SND_AI
			if not ai or not ai.path or not ai.path:IsValid() then continue end

			local segments = ai.path:GetAllSegments()
			if not segments then continue end

			for i = 1, #segments - 1 do
				debugoverlay.Line(segments[i].pos, segments[i+1].pos, 0.1, Color(0, 255, 0), true)
				debugoverlay.Cross(segments[i+1].pos, 3, 0.1, Color(255, 255, 0), true)
			end
		end
	end)
end

-- ── Bot states ────────────────────────────────────────────────────────────
local BS_IDLE      = 0   -- Frozen (Freeze phase)
local BS_PATROL    = 1   -- Moving toward objective/site
local BS_ENGAGE    = 2   -- Active combat
local BS_INVESTIGATE = 3 -- Heading toward a sound/last seen point
local BS_SEARCH    = 4   -- Clearing corners at a location
local BS_PLANT     = 5   -- Moving to plant
local BS_DEFUSE    = 6   -- Moving to defuse
local BS_FOLLOW    = 7   -- Escorting the carrier

-- ── Skill 1-10 → internal float helpers ──────────────────────────────────
local function skillT(s)       return (math.Clamp(s, 1, 10) - 1) / 9 end
local function getSkill()      return SND.Settings.GetInt("bot_skill", 5) end
local function aimNoise(s)     return Lerp(skillT(s), 15, 0.2) end
local function reactionSec(s)  return Lerp(skillT(s), 0.8, 0.1) end
local function engageRange(s)  return Lerp(skillT(s), 2000, 6000) end
local function botMoveSpeed(s) return Lerp(skillT(s), 180, 320) end

-- ── AI State ──────────────────────────────────────────────────────────────
local function newAI()
	return {
		state         = BS_IDLE,
		enemy         = nil,
		lastKnownPos  = nil,
		lastKnownTime = 0,
		searchPoints  = {},      -- Points to check when "investigating"
		currentSearchIdx = 1,
		nextSearchSwitch = 0,
		
		shootGate     = 0,
		nextJump      = 0,
		patrolFlip    = 0,
		needsReload   = false,
		reloadEnd     = 0,
		strafeDir     = 1,
		strafeFlip    = 0,
		stuckPos      = Vector(0,0,0),
		stuckCheck    = 0,
		stuckStartTime = 0,
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

local function getEnemyCarrier()
	if SND.Bomb.State ~= SND.BOMB_STATE_CARRIED then return nil end
	local carrier = SND.Bomb.Carrier
	if IsValid(carrier) and carrier:Alive() then return carrier end
	return nil
end

local function getAllyCarrier(bot)
	local carrier = SND.Bomb.Carrier
	if IsValid(carrier) and carrier:Alive() and carrier:Team() == bot:Team() then return carrier end
	return nil
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
		
		-- Automatic Banner Selection from Data Folders
		local botTitles = {"Lone Wolf", "Shadow", "Elite", "Hunter", "Stalker"}
		local botMats = {"vgui/gradient-d", "vgui/gradient-u", "vgui/white"}
		
		local customBanners = file.Find("snd_mwclassic/banners/*", "DATA")
		if #customBanners > 0 then
			for _, f in ipairs(customBanners) do 
				table.insert(botMats, "data/snd_mwclassic/banners/" .. f)
			end
		end

		bot:SetNWString("SND_CardTitle", table.Random(botTitles))
		bot:SetNWString("SND_CardMat", table.Random(botMats))

		-- Automatic Emblem Selection from Data Folders
		local botEmblems = {SND.Config.DefaultBotEmblem, "vgui/icon_star", "vgui/icon_target", "vgui/icon_crosshair"}
		local customEmblems = file.Find("snd_mwclassic/emblems/*", "DATA")
		if #customEmblems > 0 then
			for _, f in ipairs(customEmblems) do 
				table.insert(botEmblems, "data/snd_mwclassic/emblems/" .. f)
			end
		end
		bot:SetNWString("SND_EmblemMat", table.Random(botEmblems))

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
	local myPos = bot:GetPos()

	for _, s in ipairs(sites) do
		local d = myPos:Distance2D(s.plantPos or s.pos)
		if not best or d < bestDist then best, bestDist = s, d end
	end
	return best, bestDist
end

local function weaponCheck(bot, cmd)
	local wep = bot:GetActiveWeapon()
	if not IsValid(wep) then return end
	local ai = bot.SND_AI

	local max = wep:GetMaxClip1()
	local clip = wep:Clip1() or 0

	-- 1. Mid-fight emergency switch: Primary is empty, pull out secondary
	if ai.state == BS_ENGAGE and max > 0 and (clip <= 0) then
		local isPri = false
		for _, pClass in ipairs(SND.Config.BotPrimaries) do
			if wep:GetClass() == pClass then isPri = true break end
		end

		if isPri then
			for _, sClass in ipairs(SND.Config.Mw2eSecondaries) do
				local swep = bot:GetWeapon(sClass)
				if IsValid(swep) and swep:Clip1() > 0 then
					bot:SelectWeapon(sClass)
					return
				end
			end
		end
	end

	-- 2. Reloading: If empty, or safe and needs a top-off (checking reserve ammo)
	local isSafe = (ai.state == BS_PATROL or ai.state == BS_SEARCH or ai.state == BS_IDLE)
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
				timer.Simple(0.5, function() if IsValid(bot) then bot:SelectWeapon(pClass) end end)
				break
			end
		end
	end
end

local function switchToFilledWeapon(bot)
	-- Implementation already handled in weaponCheck
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
			ai.path:SetMinLookAheadDistance(200)
			ai.path:SetGoalTolerance(20)
		end

		-- Recompute path if goal moves significantly or path is stale
		if not ai.path:IsValid() or CurTime() > ai.nextPathUpdate or ai.lastPathGoal:DistToSqr(targetPos) > 4096 then
			ai.path:Compute(bot, targetPos)
			ai.nextPathUpdate = CurTime() + 2.0
			ai.lastPathGoal = targetPos
		end

		if ai.path:IsValid() then
			ai.path:Update(bot)

			-- Get the point slightly ahead on the path for smoother movement
			local segments = ai.path:GetAllSegments()
			if segments and #segments > 1 then
				moveDest = segments[2].pos
			end
		end
	end

	if not isvector(moveDest) then moveDest = targetPos end

	local dist = (targetPos - myPos):Length()
	if dist < 40 then return dist end

	local isStuck = false
	-- Stuck Detection & Resolution
	if bot:IsOnGround() and speed > 0 then
		-- If we haven't moved more than 16 units in the check interval
		if myPos:DistToSqr(ai.stuckPos) < 256 then
			if CurTime() > ai.stuckCheck then
				if ai.stuckStartTime == 0 then ai.stuckStartTime = CurTime() end
				isStuck = true

				-- We are likely stuck in a corner or on geometry
				if CurTime() > ai.nextJump then
					cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_JUMP))
					ai.nextJump = CurTime() + 0.8
				end

				ai.nextPathUpdate = 0 -- Force re-pathfinding next tick
				cmd:SetSideMove(math.Rand(-speed, speed)) -- Wiggle laterally to get unstuck
				cmd:SetForwardMove(math.Rand(-speed, speed)) -- Wiggle forward/back to break friction

				-- If stuck for too long, reset the path object to force a total re-evaluation
				if CurTime() - ai.stuckStartTime > 4 then
					ai.path = nil
					ai.stuckStartTime = CurTime()
				end
			end
		else
			-- We have moved, update tracking
			ai.stuckPos = myPos
			ai.stuckCheck = CurTime() + 0.5 
			ai.stuckStartTime = 0
		end
	end

	local distToGoal = moveDest:Distance(myPos)
	if ai.state ~= BS_ENGAGE and distToGoal > 15 then
		local goalAngle = (moveDest - myPos):Angle()
		goalAngle.p = 0

		-- Tactical Scanning
		if CurTime() > ai.nextScan then
			-- Scan corners randomly while moving
			ai.isScanning = math.random() < 0.4
			ai.scanOffset = ai.isScanning and math.random(-60, 60) or 0
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

	-- If we are currently trying to wiggle out of a stuck spot, don't overwrite the move buttons
	if not isStuck then
		cmd:SetForwardMove(speed * math.Clamp(distToGoal / 100, 0.5, 1))
	end
	return dist
end

-- Lead aiming: Predict where the player will be based on velocity
local function getAimVector(bot, target, noise)
	local targetPos = target:GetPos() + Vector(0, 0, 55) -- Aim for chest/head
	local dist = bot:EyePos():Distance(targetPos)
	
	-- Prediction: Bullet travel time simulation
	local velocity = target:GetVelocity()
	local prediction = (dist / 15000) * velocity -- Adjust 15000 based on average bullet speed
	targetPos = targetPos + prediction

	local aimAng = (targetPos - bot:EyePos()):Angle()
	aimAng.p = aimAng.p + math.Rand(-noise, noise) * (dist / 1000)
	aimAng.y = aimAng.y + math.Rand(-noise, noise) * (dist / 1000)

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
	local allyCarrier = getAllyCarrier(bot)

	-- Determine if we have a mission-critical objective
	local hasMissionCritical = isCarrier or isRetaker

	-- Objective selection logic when not in active combat
	if ai.state ~= BS_ENGAGE and ai.state ~= BS_INVESTIGATE and ai.state ~= BS_SEARCH then
		if isCarrier then ai.state = BS_PLANT
		elseif isRetaker then ai.state = BS_DEFUSE
		elseif allyCarrier and allyCarrier ~= bot then ai.state = BS_FOLLOW
		elseif ai.state == BS_IDLE then ai.state = BS_PATROL end
	end

	if ai.state == BS_PATROL or ai.state == BS_PLANT or ai.state == BS_DEFUSE or ai.state == BS_FOLLOW then
		if ai.state == BS_PLANT then
			local site = nearestSite(bot)
			if site then targetObj = site.plantPos or site.pos end
		elseif ai.state == BS_DEFUSE then
			targetObj = SND.Bomb.PlantPos
		elseif ai.state == BS_FOLLOW and IsValid(allyCarrier) then
			-- Stay behind the carrier
			targetObj = allyCarrier:GetPos() - allyCarrier:GetForward() * 150
		else
			-- Defenders/Patrollers: Anchor sites
			local sites = SND.Config.MapSites[game.GetMap()]
			if sites and #sites > 0 then
				-- Use EntIndex to determine which site to anchor
				local siteIdx = (bot:EntIndex() % #sites) + 1
				targetObj = sites[siteIdx].plantPos or sites[siteIdx].pos
			end
		end
	end

	-- Combat Scanning
	local enemy, dist = nearestEnemy(bot, true)
	
	-- Mission Focus: Carriers only engage if the enemy is a direct, close-range threat
	local shouldEngage = IsValid(enemy) and dist < engageRange(skill)
	if isCarrier and shouldEngage and dist > 800 then shouldEngage = false end

	if shouldEngage then
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
		-- No enemy visible
		ai.enemy = nil
		ai.shootGate = 0
		
		-- FORCED: Mission-critical objective takes absolute priority over investigation.
		-- If we just finished a fight (BS_ENGAGE) or were looking for someone, 
		-- but the bomb needs attention, go straight to it.
		if hasMissionCritical then
			if isCarrier then ai.state = BS_PLANT 
			else ai.state = BS_DEFUSE end
		elseif ai.state == BS_ENGAGE and ai.lastKnownPos then
			-- We lost sight of an enemy but have no bomb objective?
			-- Head to last known pos to investigate.
			ai.state = BS_INVESTIGATE
		end

		-- Resolve Investigation vs Patrolling
		local goal = nil
		if ai.state == BS_INVESTIGATE and ai.lastKnownPos then
			goal = ai.lastKnownPos
		elseif ai.state == BS_SEARCH then
			goal = ai.searchPoints[ai.currentSearchIdx]
		else
			goal = targetObj
		end

		if goal then
			local distToGoal2D = bot:GetPos():Distance2D(goal)
			local site = nearestSite(bot)
			local siteRad = site and (site.defuseRadius or site.radius or 96) or 96

			-- Use a 2D check with a generous buffer (90% of radius) to prevent jittering
			local inObjectiveRadius = (ai.state == BS_PLANT or ai.state == BS_DEFUSE) and distToGoal2D < (siteRad * 0.9)

			if (bot.SND_Planting and isCarrier) or (bot.SND_Defusing and isRetaker) or inObjectiveRadius then
				cmd:ClearMovement()
				cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_USE))
				bot:SetEyeAngles(LerpAngle(0.1, bot:EyeAngles(), Angle(75, bot:EyeAngles().y, 0)))
			else
				local d = moveToward(bot, cmd, goal, speed)

				if d < (siteRad * 0.7) then
					-- Reached investigation point?
					if ai.state == BS_INVESTIGATE then
						ai.state = BS_SEARCH
						ai.searchPoints = {
							goal + Vector(200, 200, 0),
							goal + Vector(-200, 200, 0),
							goal + Vector(0, -200, 0)
						}
						ai.currentSearchIdx = 1
					elseif ai.state == BS_SEARCH then
						ai.currentSearchIdx = ai.currentSearchIdx + 1
						if ai.currentSearchIdx > #ai.searchPoints then
							ai.state = BS_PATROL -- Finished searching
						end
					end

					if bot:Team() == SND.TEAM_DEFEND and ai.state == BS_PATROL then
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
			if not canSee(bot, src) then
				ai.lastKnownPos = soundPos
				ai.lastKnownTime = CurTime()
				ai.state = BS_INVESTIGATE
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
