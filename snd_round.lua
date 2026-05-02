--[[ Round state, win conditions, spectate rules, team balance hooks ]]

SND.Round = SND.Round or {}

SND.Round.Phase = SND.PHASE_WAIT
SND.Round.AttackScore = 0
SND.Round.DefendScore = 0
SND.Round.RoundNumber = 0
SND.Round.MatchStarted = false
SND.Round.Winner = SND.WIN_NONE
SND.Round.RoundTimerEnd = 0

local nextBalanceCheck = 0

function SND.Round.WaitingForSpawn(ply)
	if ply:Alive() then return false end
	return true
end

local function aliveOnTeamReal(t)
	local n = 0
	for _, p in ipairs(team.GetPlayers(t)) do
		if p:Alive() then n = n + 1 end
	end
	return n
end

function SND.Round.CheckElimination()
	if SND.Round.Phase ~= SND.PHASE_LIVE then return end

	local a = aliveOnTeamReal(SND.TEAM_ATTACK)
	local d = aliveOnTeamReal(SND.TEAM_DEFEND)

	if a == 0 and d > 0 then
		SND.Round.EndRound(SND.WIN_DEFEND_ELIM)
	elseif d == 0 and a > 0 then
		SND.Round.EndRound(SND.WIN_ATTACK_ELIM)
	end
end

function SND.Round.CheckTime()
	if SND.Round.Phase ~= SND.PHASE_LIVE then return end
	if CurTime() >= SND.Round.RoundTimerEnd then
		SND.Round.EndRound(SND.WIN_TIME)
	end
end

function SND.Round.EndRound(reason)
	SND.Round.Phase = SND.PHASE_POST
	SND.Round.Winner = reason

	if reason == SND.WIN_ATTACK_ELIM or reason == SND.WIN_ATTACK_PLANT then
		SND.Round.AttackScore = SND.Round.AttackScore + 1
	elseif reason == SND.WIN_DEFEND_ELIM or reason == SND.WIN_DEFEND_DEFUSE or reason == SND.WIN_TIME then
		SND.Round.DefendScore = SND.Round.DefendScore + 1
	end

	SND.Announcer.OnRoundEnd(reason)
	SND.Bomb.ResetForRound()

	local lim = SND.Settings.GetInt("win_limit", 4)
	if SND.Round.AttackScore >= lim or SND.Round.DefendScore >= lim then
		timer.Simple(4, function()
			SND.MapVote.StartMatchEnd()
		end)
	else
		timer.Simple(5, function()
			SND.Round.StartNewRound()
		end)
	end

	net.Start("SND_RoundState")
	net.WriteUInt(SND.Round.Phase, 3)
	net.WriteUInt(reason, 4)
	net.WriteUInt(SND.Round.AttackScore, 8)
	net.WriteUInt(SND.Round.DefendScore, 8)
	net.Broadcast()
end

function SND.Round.StartNewRound()
	SND.Round.RoundNumber = SND.Round.RoundNumber + 1
	SND.Round.Phase = SND.PHASE_FREEZE
	SND.Round.Winner = SND.WIN_NONE

	SND.Bomb.AssignCarrier()
	SND.TeamBalance.MaybeShuffle()

	local freeze = SND.Settings.Get("freeze_time", 6)
	SND.Round.RoundTimerEnd = CurTime() + freeze + SND.Settings.Get("round_time", 120)

	timer.Simple(freeze, function()
		if SND.Round.Phase ~= SND.PHASE_FREEZE then return end
		SND.Round.Phase = SND.PHASE_LIVE
		SND.Round.RoundTimerEnd = CurTime() + SND.Settings.Get("round_time", 120)
		SND.Announcer.RoundLive()

		net.Start("SND_RoundState")
		net.WriteUInt(SND.Round.Phase, 3)
		net.WriteUInt(0, 4)
		net.WriteUInt(SND.Round.AttackScore, 8)
		net.WriteUInt(SND.Round.DefendScore, 8)
		net.Broadcast()
	end)

	net.Start("SND_RoundState")
	net.WriteUInt(SND.Round.Phase, 3)
	net.WriteUInt(0, 4)
	net.WriteUInt(SND.Round.AttackScore, 8)
	net.WriteUInt(SND.Round.DefendScore, 8)
	net.Broadcast()

	SND.Announcer.RoundFreeze()

	for _, ply in ipairs(player.GetAll()) do
		ply:Spawn()
	end
end

function SND.Round.OnPlayerDeath(victim, attacker)
	if not IsValid(victim) then return end
	timer.Simple(0, function()
		SND.Round.CheckElimination()
		local teamAlive = aliveOnTeamReal(victim:Team())
		if teamAlive == 1 then
			SND.Announcer.LastMan()
		end
	end)
end

function SND.Round.FirstSpawn()
	if SND.Round.MatchStarted then return end
	SND.Round.MatchStarted = true
	timer.Simple(1, function()
		SND.Round.StartNewRound()
	end)
end

hook.Add("PlayerInitialSpawn", "SND_RoundTrack", function(ply)
	timer.Simple(0.5, function()
		local humans = 0
		for _, p in ipairs(player.GetAll()) do
			if not p.SND_IsBot then humans = humans + 1 end
		end
		SND.Bots.EnsureCount()
		if humans + SND.Bots.CountBots() > 0 then
			SND.Round.FirstSpawn()
		end
	end)
end)

timer.Create("SND_RoundTick", 0.25, 0, function()
	SND.Round.CheckTime()
	nextBalanceCheck = nextBalanceCheck + 0.25
	if nextBalanceCheck >= 30 then
		nextBalanceCheck = 0
		SND.TeamBalance.Tick()
	end
end)

util.AddNetworkString("SND_RoundState")

function SND.Round.Sync(ply)
	if not IsValid(ply) then return end
	net.Start("SND_RoundState")
	net.WriteUInt(SND.Round.Phase, 3)
	net.WriteUInt(SND.Round.Winner or 0, 4)
	net.WriteUInt(SND.Round.AttackScore, 8)
	net.WriteUInt(SND.Round.DefendScore, 8)
	net.Send(ply)
end

hook.Add("PlayerInitialSpawn", "SND_SyncState", function(ply)
	timer.Simple(0, function()
		if not IsValid(ply) then return end
		SND.Round.Sync(ply)
	end)
end)

-- Team balance module (same file for cohesion)
SND.TeamBalance = SND.TeamBalance or {}

function SND.TeamBalance.Enabled()
	return SND.Settings.GetInt("team_balance", 1) >= 1
end

function SND.TeamBalance.MaybeShuffle()
	if not SND.TeamBalance.Enabled() then return end
	local function n(tid)
		return #team.GetPlayers(tid)
	end
	local attack = n(SND.TEAM_ATTACK)
	local defend = n(SND.TEAM_DEFEND)
	if math.abs(attack - defend) <= 1 then return end

	local bigger = attack > defend and SND.TEAM_ATTACK or SND.TEAM_DEFEND
	local smaller = attack > defend and SND.TEAM_DEFEND or SND.TEAM_ATTACK
	local need = math.floor((attack + defend) / 2) - n(smaller)

	for i = 1, need do
		local candidates = team.GetPlayers(bigger)
		if #candidates == 0 then break end
		local ply = table.Random(candidates)
		ply:SetTeam(smaller)
		SND.Teams.ApplyFactionModel(ply)
	end
end

function SND.TeamBalance.Tick()
	if not SND.TeamBalance.Enabled() then return end
	SND.TeamBalance.MaybeShuffle()
end
