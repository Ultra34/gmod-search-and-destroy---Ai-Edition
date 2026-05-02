--[[ Lua-driven bots — FIXED: missing bot:Spawn() call, CSS models, bomb-objective AI ]]
-- REPLACES: gamemode/snd_bots.lua

SND.Bots = SND.Bots or {}

function SND.Bots.CountBots()
	local n = 0
	for _, p in ipairs(player.GetAll()) do
		if p.SND_IsBot then n = n + 1 end
	end
	return n
end

-- Pick the team with fewer players to keep sides even
local function pickBalancedTeam()
	local attack = #team.GetPlayers(SND.TEAM_ATTACK)
	local defend = #team.GetPlayers(SND.TEAM_DEFEND)
	return (attack <= defend) and SND.TEAM_ATTACK or SND.TEAM_DEFEND
end

function SND.Bots.EnsureCount()
	local want = SND.Settings.GetInt("bot_count", 0)
	if want <= 0 then return end

	local have = SND.Bots.CountBots()
	if have >= want then return end

	for i = have + 1, want do
		local bot = player.CreateNextBot("SNDBot" .. tostring(i))

		if not IsValid(bot) then
			print("[SND] player.CreateNextBot failed (slot " .. i .. ").")
			print("[SND] On a dedicated server: ensure sv_cheats 1 OR a bot-management plugin is loaded.")
			-- Retry the remaining slots after a short delay
			timer.Simple(2, function() SND.Bots.EnsureCount() end)
			break
		end

		bot.SND_IsBot = true
		bot:SetTeam(pickBalancedTeam())

		-- Apply CSS faction model before Spawn() so the engine uses it
		SND.Teams.ApplyFactionModel(bot)

		-- *** THE MAIN FIX ***
		-- player.CreateNextBot creates the player object but does NOT call GM:PlayerSpawn.
		-- Without bot:Spawn() the bot floats at 0,0,0 with no weapons and never appears.
		bot:Spawn()
	end
end

function SND.Bots.OnPlayerSpawn(ply)
	if not ply.SND_IsBot then return end
	-- Re-enforce CSS model in case the engine reset it during spawn
	SND.Teams.ApplyFactionModel(ply)
end

-- If a bot somehow disconnects / gets removed, refill the slot
hook.Add("PlayerDisconnected", "SND_BotRefill", function(ply)
	if not ply.SND_IsBot then return end
	timer.Simple(1, function() SND.Bots.EnsureCount() end)
end)

-- ──────────────────────────────────────────────────────────────────
-- AI Think (runs via StartCommand hook every tick)
-- ──────────────────────────────────────────────────────────────────
local function nearestEnemy(ply)
	local best, bestDist
	for _, o in ipairs(player.GetAll()) do
		if o ~= ply and o:Alive() and o:Team() ~= ply:Team() then
			local d = ply:GetPos():Distance(o:GetPos())
			if not bestDist or d < bestDist then
				best, bestDist = o, d
			end
		end
	end
	return best, bestDist
end

local function canSee(ply, tgt)
	if not IsValid(tgt) then return false end
	local tr = util.TraceLine({
		start  = ply:GetShootPos(),
		endpos = tgt:EyePos(),
		filter = ply,
		mask   = MASK_SHOT_HULL,
	})
	return tr.Entity == tgt or tr.Fraction > 0.97
end

hook.Add("StartCommand", "SND_BotAI", function(ply, cmd)
	if not ply.SND_IsBot or not ply:Alive() then return end
	if SND.Round.Phase ~= SND.PHASE_LIVE and SND.Round.Phase ~= SND.PHASE_FREEZE then return end

	local skill = math.Clamp(SND.Settings.Get("bot_skill", 0.65), 0.15, 1)

	-- Combat: aim and shoot nearest visible enemy
	local enemy, dist = nearestEnemy(ply)
	if IsValid(enemy) then
		local aimAngle = (enemy:EyePos() - ply:EyePos()):Angle()
		local noise    = (1 - skill) * 40
		aimAngle.p = aimAngle.p + (math.random() - 0.5) * noise
		aimAngle.y = aimAngle.y + (math.random() - 0.5) * noise
		ply:SetEyeAngles(aimAngle)

		if canSee(ply, enemy) and dist and dist < 2200 then
			cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_ATTACK))
		end

		-- Chase if far
		if dist and dist > 220 then
			cmd:SetForwardMove(400 * skill)
			cmd:SetSideMove(math.sin(CurTime() * 3 + ply:EntIndex()) * 320 * skill)
		end
	end

	-- Attacker bomb-carrier sprints toward bomb site and tries to plant
	if ply:Team() == SND.TEAM_ATTACK
	   and SND.Bomb.State == SND.BOMB_STATE_CARRIED
	   and SND.Bomb.Carrier == ply then
		cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_SPEED)) -- sprint
		if SND.Round.Phase == SND.PHASE_LIVE then
			-- Holding USE will trigger TryPlant once in site radius
			cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_USE))
		end
	end

	-- Defender tries to defuse planted bomb when nearby
	if ply:Team() == SND.TEAM_DEFEND
	   and SND.Bomb.State == SND.BOMB_STATE_PLANTED
	   and SND.Bomb.PlantPos
	   and ply:GetPos():Distance(SND.Bomb.PlantPos) < 128 then
		cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_USE))
	end
end)
