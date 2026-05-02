--[[ Lua-driven bots
     Fixes: wall-vision (last-known-pos system), bot:Spawn(), CSS models, bomb objectives ]]
-- REPLACES: gamemode/snd_bots.lua

SND.Bots = SND.Bots or {}

-- ── Count helpers ─────────────────────────────────────────────────────────
function SND.Bots.CountBots()
	local n = 0
	for _, p in ipairs(player.GetAll()) do
		if p.SND_IsBot then n = n + 1 end
	end
	return n
end

local function pickBalancedTeam()
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
			print("[SND] player.CreateNextBot failed (slot " .. i .. "). On a dedicated server ensure sv_cheats 1 or a bot plugin.")
			timer.Simple(2, function() SND.Bots.EnsureCount() end)
			break
		end
		bot.SND_IsBot = true
		bot.SND_AI    = {}
		bot:SetTeam(pickBalancedTeam())
		SND.Teams.ApplyFactionModel(bot)
		bot:Spawn()   -- ← THE MAIN SPAWN FIX: triggers GM:PlayerSpawn → weapons + position
	end
end

function SND.Bots.OnPlayerSpawn(ply)
	if not ply.SND_IsBot then return end
	SND.Teams.ApplyFactionModel(ply)
	ply.SND_AI = { lastKnownPos = nil, lastKnownTime = 0, patrolAngle = math.Rand(0,360), patrolTimer = 0 }
end

hook.Add("PlayerDisconnected", "SND_BotRefill", function(ply)
	if not ply.SND_IsBot then return end
	timer.Simple(1, function() SND.Bots.EnsureCount() end)
end)

-- ── Line-of-sight (NO wall vision) ────────────────────────────────────────
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

local function nearestEnemy(bot)
	local best, bestDist2
	for _, p in ipairs(player.GetAll()) do
		if p ~= bot and p:Alive() and p:Team() ~= bot:Team() then
			local d2 = bot:GetPos():DistToSqr(p:GetPos())
			if not bestDist2 or d2 < bestDist2 then
				best, bestDist2 = p, d2
			end
		end
	end
	return best, bestDist2 and math.sqrt(bestDist2)
end

-- ── AI Think ──────────────────────────────────────────────────────────────
hook.Add("StartCommand", "SND_BotAI", function(bot, cmd)
	if not bot.SND_IsBot or not bot:Alive() then return end
	if SND.Round.Phase ~= SND.PHASE_LIVE and SND.Round.Phase ~= SND.PHASE_FREEZE then return end

	local ai    = bot.SND_AI or {}
	local skill = math.Clamp(SND.Settings.Get("bot_skill", 0.65), 0.15, 1)
	local now   = CurTime()

	local enemy, dist = nearestEnemy(bot)

	if IsValid(enemy) and canSee(bot, enemy) then
		-- ── VISIBLE ENEMY: aim + shoot ─────────────────────────────────────
		ai.lastKnownPos  = enemy:GetPos()
		ai.lastKnownTime = now

		local ang   = (enemy:EyePos() - bot:EyePos()):Angle()
		local noise = (1 - skill) * 35
		ang.p = ang.p + (math.random() - 0.5) * noise
		ang.y = ang.y + (math.random() - 0.5) * noise
		bot:SetEyeAngles(ang)

		if dist and dist < 2400 then
			cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_ATTACK))
		end
		-- Strafe while shooting so bots don't stand still
		cmd:SetForwardMove(dist and dist > 200 and 300 * skill or 0)
		cmd:SetSideMove(math.sin(now * 4 + bot:EntIndex()) * 220 * skill)

	elseif ai.lastKnownPos and (now - (ai.lastKnownTime or 0)) < 5 then
		-- ── MEMORY: move toward last known position, do NOT shoot ──────────
		local diff = ai.lastKnownPos - bot:GetPos()
		diff.z = 0
		local memDist = diff:Length()
		if memDist > 80 then
			local ang = diff:Angle()
			ang.p = 0
			bot:SetEyeAngles(ang)
			cmd:SetForwardMove(260 * skill)
		else
			ai.lastKnownPos  = nil  -- arrived, forget
			ai.lastKnownTime = 0
		end
	else
		-- ── NO SIGHTING: patrol randomly ──────────────────────────────────
		ai.lastKnownPos  = nil
		ai.lastKnownTime = 0
		if now > (ai.patrolTimer or 0) then
			ai.patrolAngle = (ai.patrolAngle or 0) + math.Rand(-70, 70)
			ai.patrolTimer = now + math.Rand(1.5, 3)
		end
		bot:SetEyeAngles(Angle(0, ai.patrolAngle, 0))
		cmd:SetForwardMove(160)
	end

	-- ── BOMB OBJECTIVES ────────────────────────────────────────────────────
	if bot:Team() == SND.TEAM_ATTACK
	   and SND.Bomb.State == SND.BOMB_STATE_CARRIED
	   and SND.Bomb.Carrier == bot
	   and SND.Round.Phase == SND.PHASE_LIVE then
		cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_SPEED, IN_USE))
	end

	if bot:Team() == SND.TEAM_DEFEND
	   and SND.Bomb.State == SND.BOMB_STATE_PLANTED
	   and SND.Bomb.PlantPos then
		local bd = bot:GetPos():Distance(SND.Bomb.PlantPos)
		if bd < 128 then
			cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_USE))
		else
			local dir = (SND.Bomb.PlantPos - bot:GetPos())
			dir.z = 0
			if dir:Length() > 0 then
				local ang = dir:Angle() ang.p = 0
				bot:SetEyeAngles(ang)
				cmd:SetForwardMove(260)
			end
		end
	end

	bot.SND_AI = ai
end)
