--[[ Bot AI — state machine, skill 1-10, weapon reload/switch, bomb objectives
     REPLACES: gamemode/snd_bots.lua ]]

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
local function skillT(s)       return (math.Clamp(s, 1, 10) - 1) / 9     end
local function getSkill()      return SND.Settings.GetInt("bot_skill", 5) end
local function aimNoise(s)     return math.Lerp(skillT(s), 70,   2)       end  -- degrees
local function reactionSec(s)  return math.Lerp(skillT(s),  1.3, 0.04)   end  -- seconds
local function engageRange(s)  return math.Lerp(skillT(s),  600, 3800)   end  -- units
local function botMoveSpeed(s) return math.Lerp(skillT(s),  120, 310)    end  -- units/s
local function reloadThresh(s) return math.Lerp(skillT(s),  0.6, 0.12)   end  -- clip% to reload at

-- ── Fresh AI state for a bot ──────────────────────────────────────────────
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
	}
end

-- ── Spawn / count helpers ─────────────────────────────────────────────────
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

-- ── Nearest bomb site (returns site table and distance) ───────────────────
local function nearestSite(bot)
	local map   = game.GetMap()
	local sites = SND.Config.MapSites[map]
	if not sites or #sites == 0 then return nil, math.huge end
	local best, bestDist
	for _, s in ipairs(sites) do
		local d = bot:GetPos():Distance(s.plantPos)
		if not best or d < bestDist then best, bestDist = s, d end
	end
	return best, bestDist
end

-- ── Weapon helpers ────────────────────────────────────────────────────────
local function activeClipRatio(bot)
	local wep = bot:GetActiveWeapon()
	if not IsValid(wep) then return 1 end
	local max = wep:GetMaxClip1()
	if max <= 0 then return 1 end
	return wep:Clip1() / max
end

-- Try to switch to a weapon that has ammo; returns true if switched
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

-- ── Weapon management timer (runs every 0.4 s) ────────────────────────────
timer.Create("SND_BotWeaponManage", 0.4, 0, function()
	for _, bot in ipairs(player.GetAll()) do
		if not bot.SND_IsBot or not bot:Alive() then continue end

		local ai    = bot.SND_AI
		if not ai then continue end
		local skill = getSkill()
		local wep   = bot:GetActiveWeapon()
		if not IsValid(wep) then continue end

		local ratio = activeClipRatio(bot)

		-- Completely empty: switch to another weapon first
		if ratio <= 0 then
			if not switchToFilledWeapon(bot) then
				-- No weapon has ammo; flag for reload
				ai.needsReload = true
				ai.reloadEnd   = CurTime() + 2.4
			end
		-- Low ammo and not currently engaging: reload proactively
		elseif ratio < reloadThresh(skill) and ai.state ~= BS_ENGAGE then
			ai.needsReload = true
			ai.reloadEnd   = CurTime() + 2.4
		end

		-- After reload timer expires, clear the flag
		if ai.needsReload and CurTime() >= ai.reloadEnd then
			ai.needsReload = false
		end

		-- Force a weapon switch back to primary if holding secondary and primary has ammo
		-- (give bots a slight preference for the primary slot)
		if ai.state ~= BS_ENGAGE and not ai.needsReload then
			local weps = bot:GetWeapons()
			if #weps >= 2 then
				local best, bestAmmo = nil, -1
				for _, w in ipairs(weps) do
					if IsValid(w) and w:Clip1() > bestAmmo then
						bestAmmo = w:Clip1()
						best = w
					end
				end
				if IsValid(best) and best ~= wep then
					bot:SelectWeapon(best:GetClass())
				end
			end
		end
	end
end)

-- ── Move bot toward a world position ──────────────────────────────────────
local function moveToward(bot, cmd, targetPos, speed)
	local diff = targetPos - bot:GetPos()
	diff.z = 0
	local dist = diff:Length()
	if dist < 20 then return dist end

	local ang = diff:Angle()
	ang.p = 0
	bot:SetEyeAngles(ang)
	cmd:SetForwardMove(speed)
	return dist
end

-- ── Main AI think (StartCommand runs every tick) ──────────────────────────
hook.Add("StartCommand", "SND_BotAI", function(bot, cmd)
	if not bot.SND_IsBot or not bot:Alive() then return end

	-- During freeze: stand still
	if SND.Round.Phase == SND.PHASE_FREEZE then
		cmd:SetForwardMove(0)
		cmd:SetSideMove(0)
		cmd:SetUpMove(0)
		return
	end

	if SND.Round.Phase ~= SND.PHASE_LIVE then return end

	local ai    = bot.SND_AI
	if not ai then ai = newAI() bot.SND_AI = ai end

	local skill = getSkill()
	local now   = CurTime()

	-- ── RELOAD state ──────────────────────────────────────────────────────
	if ai.needsReload then
		ai.state = BS_RELOAD
		cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_RELOAD))
		cmd:SetForwardMove(0)
		cmd:SetSideMove(0)
		return
	end

	-- ── BOMB OBJECTIVES (override most other states) ──────────────────────

	-- Attacker carrier: plant
	local isCarrier = (bot:Team() == SND.TEAM_ATTACK)
	                  and (SND.Bomb.State == SND.BOMB_STATE_CARRIED)
	                  and (SND.Bomb.Carrier == bot)

	local bombPlanted = SND.Bomb.State == SND.BOMB_STATE_PLANTED

	if isCarrier and SND.Round.Phase == SND.PHASE_LIVE then
		ai.state = BS_PLANT
		local site, siteDist = nearestSite(bot)

		if site then
			local radius = (site.defuseRadius or 96) + 32
			if siteDist > radius then
				-- Move to the site
				local sp = botMoveSpeed(skill)
				cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_SPEED))
				moveToward(bot, cmd, site.plantPos, sp)
			else
				-- In range: look down at ground and hold USE to plant
				local downAngle = Angle(60, bot:EyeAngles().y, 0)
				bot:SetEyeAngles(downAngle)
				cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_USE))
				cmd:SetForwardMove(0)
				cmd:SetSideMove(0)
			end
		end
		return
	end

	-- Defender: defuse planted bomb
	if bot:Team() == SND.TEAM_DEFEND and bombPlanted and SND.Bomb.PlantPos then
		local bombDist = bot:GetPos():Distance(SND.Bomb.PlantPos)
		if bombDist > 128 then
			ai.state = BS_DEFUSE
			moveToward(bot, cmd, SND.Bomb.PlantPos, botMoveSpeed(skill))
		else
			-- At bomb: look at it and defuse
			ai.state = BS_DEFUSE
			local towardBomb = (SND.Bomb.PlantPos - bot:GetPos()):Angle()
			towardBomb.p = 30  -- look slightly down at the bomb
			bot:SetEyeAngles(towardBomb)
			cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_USE))
			cmd:SetForwardMove(0)
			cmd:SetSideMove(0)
		end
		-- Still scan for enemies while travelling to bomb
		local visEnemy, visDist = nearestEnemy(bot, true)
		if IsValid(visEnemy) and visDist and visDist < engageRange(skill) then
			-- Shoot if we can see someone; movement already set above
			local ang   = (visEnemy:EyePos() - bot:EyePos()):Angle()
			local noise = aimNoise(skill)
			ang.p = ang.p + (math.random() - 0.5) * noise
			ang.y = ang.y + (math.random() - 0.5) * noise
			bot:SetEyeAngles(ang)
			cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_ATTACK))
		end
		return
	end

	-- ── COMBAT / PATROL logic ─────────────────────────────────────────────
	local visEnemy, visDist = nearestEnemy(bot, true)

	if IsValid(visEnemy) and visDist and visDist < engageRange(skill) then
		-- ── ENGAGE ────────────────────────────────────────────────────────
		ai.state        = BS_ENGAGE
		ai.lastKnownPos  = visEnemy:GetPos()
		ai.lastKnownTime = now

		-- Reaction gate: don't fire instantly on first sight
		if ai.enemy ~= visEnemy then
			ai.enemy     = visEnemy
			ai.canShoot  = false
			ai.shootGate = now + reactionSec(skill)
		end
		if not ai.canShoot and now >= ai.shootGate then
			ai.canShoot = true
		end

		-- Aim with noise proportional to (1-skill)
		local targetPos = visEnemy:EyePos()
		local aimAng    = (targetPos - bot:EyePos()):Angle()
		local noise     = aimNoise(skill)
		aimAng.p = aimAng.p + (math.random() - 0.5) * noise
		aimAng.y = aimAng.y + (math.random() - 0.5) * noise
		bot:SetEyeAngles(aimAng)

		if ai.canShoot then
			cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_ATTACK))
		end

		-- Strafe while shooting (flip direction periodically)
		if now > ai.strafeFlip then
			ai.strafeDir  = -ai.strafeDir
			ai.strafeFlip = now + math.Rand(0.8, 2.0)
		end
		local sp = botMoveSpeed(skill)
		cmd:SetSideMove(ai.strafeDir * sp * 0.7)

		-- Close distance if far; hold ground if close
		if visDist > 350 then
			cmd:SetForwardMove(sp * 0.6)
		elseif visDist < 120 then
			cmd:SetForwardMove(-sp * 0.4)  -- back up at point-blank
		end

	elseif ai.lastKnownPos and (now - ai.lastKnownTime) < 5 then
		-- ── CHASE ─────────────────────────────────────────────────────────
		ai.state    = BS_CHASE
		ai.enemy    = nil
		ai.canShoot = false

		local dist = moveToward(bot, cmd, ai.lastKnownPos, botMoveSpeed(skill) * 0.85)
		if dist < 60 then
			ai.lastKnownPos  = nil
			ai.lastKnownTime = 0
		end

	else
		-- ── PATROL ────────────────────────────────────────────────────────
		ai.state         = BS_PATROL
		ai.enemy         = nil
		ai.canShoot      = false
		ai.lastKnownPos  = nil
		ai.lastKnownTime = 0

		-- Change patrol direction periodically
		if now > ai.patrolFlip then
			ai.patrolAngle = ai.patrolAngle + math.Rand(-80, 80)
			ai.patrolFlip  = now + math.Rand(2, 4)
		end
		bot:SetEyeAngles(Angle(0, ai.patrolAngle, 0))
		cmd:SetForwardMove(botMoveSpeed(skill) * 0.5)
	end
end)

-- ── Keep bots frozen in place during freeze phase ────────────────────────
hook.Add("Think", "SND_BotFreezeVelocity", function()
	if SND.Round.Phase ~= SND.PHASE_FREEZE then return end
	for _, bot in ipairs(player.GetAll()) do
		if bot.SND_IsBot and IsValid(bot) and bot:Alive() then
			bot:SetVelocity(-bot:GetVelocity())  -- cancel any residual velocity
		end
	end
end)
