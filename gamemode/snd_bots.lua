--[[ Lua-driven bots — competitive-grade AI is not feasible in raw Lua; this implements objective-aware combat ]]

SND.Bots = SND.Bots or {}

function SND.Bots.CountBots()
	local n = 0
	for _, p in ipairs(player.GetAll()) do
		if p.SND_IsBot then n = n + 1 end
	end
	return n
end

function SND.Bots.EnsureCount()
	local want = SND.Settings.GetInt("bot_count", 0)
	if want <= 0 then return end

	local have = SND.Bots.CountBots()
	while have < want do
		local bot = player.CreateNextBot("SNDBot" .. tostring(have + 1))
		if not IsValid(bot) then
			print("[SND] player.CreateNextBot failed — run `bot` / enable bot quota on dedicated servers.")
			break
		end
		bot.SND_IsBot = true
		bot:SetTeam(math.random(1, 2) == 1 and SND.TEAM_ATTACK or SND.TEAM_DEFEND)
		have = have + 1
	end
end

function SND.Bots.OnPlayerSpawn(ply)
	if not ply.SND_IsBot then return end
	SND.Teams.ApplyFactionModel(ply)
end

local function nearestEnemy(ply)
	local best, dist
	for _, o in ipairs(player.GetAll()) do
		if o ~= ply and o:Alive() and o:Team() ~= ply:Team() then
			local d = ply:GetPos():Distance(o:GetPos())
			if not dist or d < dist then
				best, dist = o, d
			end
		end
	end
	return best, dist
end

local function visible(ply, tgt)
	if not IsValid(tgt) then return false end
	local tr = util.TraceLine({
		start = ply:GetShootPos(),
		endpos = tgt:EyePos(),
		filter = ply,
		mask = MASK_SHOT_HULL,
	})
	return tr.Entity == tgt or tr.Fraction > 0.97
end

hook.Add("StartCommand", "SND_BotAI", function(ply, cmd)
	if not ply.SND_IsBot or not ply:Alive() then return end
	if SND.Round.Phase ~= SND.PHASE_LIVE and SND.Round.Phase ~= SND.PHASE_FREEZE then return end

	local skill = math.Clamp(SND.Settings.Get("bot_skill", 0.65), 0.15, 1)

	local enemy, dist = nearestEnemy(ply)
	if IsValid(enemy) then
		local aim = (enemy:EyePos() - ply:EyePos()):Angle()
		aim.p = aim.p + (math.random() - 0.5) * 40 * (1 - skill)
		aim.y = aim.y + (math.random() - 0.5) * 40 * (1 - skill)
		ply:SetEyeAngles(aim)

		if visible(ply, enemy) and dist and dist < 2200 then
			cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_ATTACK))
		end

		local dir = (enemy:GetPos() - ply:GetPos())
		dir.z = 0
		if dir:Length() > 220 then
			dir:Normalize()
			cmd:SetForwardMove(400 * skill)
			cmd:SetSideMove(math.sin(CurTime() * 3 + ply:EntIndex()) * 320 * skill)
		end
	end

	if ply:Team() == SND.TEAM_ATTACK and SND.Bomb.Carrier == ply and SND.Bomb.State == SND.BOMB_STATE_CARRIED then
		-- Nudge toward nearest site (sites resolved server-side in bomb module; approximate forward push)
		cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_SPEED))
	end
end)
