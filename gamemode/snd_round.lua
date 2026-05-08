--[[ Round state, win conditions, spectate rules, team balance hooks ]]

AddCSLuaFile()

SND.Round = SND.Round or {}

SND.Round.Phase = SND.PHASE_WAIT
SND.Round.AttackScore = 0
SND.Round.DefendScore = 0
SND.Round.RoundNumber = 0
SND.Round.MatchStarted = false
SND.Round.Winner = SND.WIN_NONE
SND.Round.RoundTimerEnd = 0
SND.Round.HalftimeReached = false

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
	local bombPlanted = (SND.Bomb.State == SND.BOMB_STATE_PLANTED)

	if a == 0 and d == 0 then
		SND.Round.EndRound(SND.WIN_DRAW)
	elseif a == 0 then
		-- If bomb is planted, Defenders must still defuse even if Attackers are dead
		if not bombPlanted then
			SND.Round.EndRound(SND.WIN_DEFEND_ELIM)
		end
	elseif d == 0 then
		SND.Round.EndRound(SND.WIN_ATTACK_ELIM)
	end
end

function SND.Round.CheckTime()
	if SND.Round.Phase ~= SND.PHASE_LIVE then return end
	if SND.Bomb.State == SND.BOMB_STATE_PLANTED then return end

	if CurTime() >= SND.Round.RoundTimerEnd then
		SND.Round.EndRound(SND.WIN_TIME) -- Defenders win on timeout if bomb not planted
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
	hook.Run("SND_RoundEnd", reason)
	SND.Bomb.ResetForRound()

	-- Sync phase to clients immediately
	SND.Round.Sync()

	local lim = SND.Settings.GetInt("win_limit", 4)
	local totalRounds = SND.Round.AttackScore + SND.Round.DefendScore
	local isHalftime = not SND.Round.HalftimeReached and totalRounds > 0 and totalRounds == (lim - 1)

	if SND.Round.AttackScore >= lim or SND.Round.DefendScore >= lim then
		timer.Simple(8, function()
			SND.MapVote.StartMatchEnd()
		end)
	elseif isHalftime then
		-- Wait until Victory Phase is over, then trigger Halftime
		timer.Simple(8, function()
			SND.Round.HalftimeReached = true
			net.Start("SND_Halftime") net.Broadcast()
			SND.Round.SwitchTeams()

			-- Show Halftime banner for 5 seconds before starting the Freeze Phase
			timer.Simple(5, function()
				SND.Round.StartNewRound()
			end)
		end)
	else
		timer.Simple(8, function()
			SND.Round.StartNewRound()
		end)
	end
end

function SND.Round.SwitchTeams()
	print("[SND] Halftime: Switching sides...")

	SND.Bomb.ResetForRound() -- Clear all bomb data and timers before switching

	-- Swap scores so teams keep their points after roles change
	local oldAttack = SND.Round.AttackScore
	SND.Round.AttackScore = SND.Round.DefendScore
	SND.Round.DefendScore = oldAttack

	for _, ply in ipairs(player.GetAll()) do
		local oldTeam = ply:Team()
		if oldTeam == SND.TEAM_ATTACK then
			ply:SetTeam(SND.TEAM_DEFEND)
		elseif oldTeam == SND.TEAM_DEFEND then
			ply:SetTeam(SND.TEAM_ATTACK)
		end
		SND.Teams.ApplyFactionModel(ply)
	end

	SND.Announcer.OnRoundEnd(SND.WIN_DRAW) -- Play a neutral sound
	SND.Round.Sync() -- Update HUD with swapped scores immediately
end

function SND.Round.StartNewRound()
	SND.Round.RoundNumber = SND.Round.RoundNumber + 1
	SND.Round.Phase = SND.PHASE_FREEZE
	SND.Round.Winner = SND.WIN_NONE

	-- Cleanup world: remove dropped weapons and clear blood decals for all clients
	for _, ent in ipairs(ents.GetAll()) do
		-- Explicitly remove weapons and any dropped bomb props left in the world
		if (ent:IsWeapon() and ent.SND_Dropped) or ent:GetNWBool("SND_IsDroppedBomb") then
			ent:Remove()
		end
	end
	BroadcastLua("LocalPlayer():ConCommand('r_cleardecals')")

	-- 1. Balance teams first
	SND.TeamBalance.MaybeShuffle()

	-- 2. Assign carrier after the teams are settled
	SND.Bomb.AssignCarrier()

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
		net.WriteDouble(SND.Round.RoundTimerEnd)
		net.Broadcast()
	end)

	net.Start("SND_RoundState")
	net.WriteUInt(SND.Round.Phase, 3)
	net.WriteUInt(0, 4)
	net.WriteUInt(SND.Round.AttackScore, 8)
	net.WriteUInt(SND.Round.DefendScore, 8)
	net.WriteDouble(SND.Round.RoundTimerEnd)
	net.Broadcast()

	SND.Announcer.RoundFreeze()
	hook.Run("SND_RoundStart_Freeze")

	for _, ply in ipairs(player.GetAll()) do
		ply:Spawn()
	end
end

function SND.Round.OnPlayerDeath(victim, attacker)
	if not IsValid(victim) or not victim:IsPlayer() then return end
	victim.SND_DeathTime = CurTime()

	-- Send kill feed data to clients
	if IsValid(attacker) and attacker:IsPlayer() and attacker ~= victim then
		local wep = attacker:GetActiveWeapon()
		local weaponName = IsValid(wep) and wep:GetPrintName() or "Fists" -- Fallback for melee/no weapon
		
		net.Start("SND_KillFeed")
			net.WriteString(attacker:Nick())
			net.WriteUInt(attacker:Team(), 2)
			net.WriteString(victim:Nick())
			net.WriteUInt(victim:Team(), 2)
			net.WriteString(weaponName)
		net.Broadcast()
	else
		-- Handle suicides or environmental deaths
		net.Start("SND_KillFeed")
			net.WriteString("") -- No attacker
			net.WriteUInt(0, 2) -- No attacker team
			net.WriteString(victim:Nick())
			net.WriteUInt(victim:Team(), 2)
			net.WriteString("died") -- Generic death message
		net.Broadcast()
	end

	SND.Round.CheckElimination()
	local teamAlive = aliveOnTeamReal(victim:Team())
	if teamAlive == 1 then
		SND.Announcer.LastMan()
	end
end

concommand.Add("snd_debug_toggle", function(ply)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	
	if SND.Round.Phase ~= SND.PHASE_DEBUG then
		SND.Round.Phase = SND.PHASE_DEBUG
		SND.Round.RoundTimerEnd = 0
		game.ConsoleCommand("snd_debug_mode 1\n")
		game.ConsoleCommand("sv_cheats 1\n")
		ply:SetMoveType(MOVETYPE_NOCLIP)
		ply:ChatPrint("[SND] DEBUG PHASE ENABLED. Match logic paused. Noclip ENABLED.")
	else
		SND.Round.Phase = SND.PHASE_FREEZE
		game.ConsoleCommand("snd_debug_mode 0\n")
		game.ConsoleCommand("sv_cheats 0\n")
		ply:SetMoveType(MOVETYPE_WALK)
		ply:ChatPrint("[SND] DEBUG PHASE DISABLED. Restarting round...")
		SND.Round.StartNewRound()
	end
	SND.Round.Sync()
end)

concommand.Add("snd_noclip", function(ply)
	if not IsValid(ply) or not ply:IsAdmin() then return end
	local isDebug = (SND.Settings.GetInt("debug_mode", 0) == 1 or SND.Round.Phase == SND.PHASE_DEBUG)
	if not isDebug then 
		ply:ChatPrint("[SND] Noclip is restricted to Debug Mode.")
		return 
	end

	if ply:GetMoveType() == MOVETYPE_NOCLIP then
		ply:SetMoveType(MOVETYPE_WALK)
	else
		ply:SetMoveType(MOVETYPE_NOCLIP)
	end
end)

function SND.Round.FirstSpawn()
	if SND.Round.MatchStarted then return end
	
	-- Verify everyone is ready before starting the very first round
	local ready = true
	for _, ply in ipairs(player.GetAll()) do
		if not ply:IsBot() and not ply.SND_IsBot and not ply.SND_IsReady then
			ready = false break
		end
	end
	if not ready then return end

	SND.Round.MatchStarted = true
	SND.Round.StartNewRound()
end

hook.Add("PlayerInitialSpawn", "SND_RoundTrack", function(ply)
	timer.Simple(0.5, function()
		local humans = 0
		for _, p in ipairs(player.GetAll()) do
			if not p.SND_IsBot then humans = humans + 1 end
		end
		SND.Bots.EnsureCount()
		
		-- Open the loadout menu for the player immediately on join
		if not ply:IsBot() then
			timer.Simple(1, function()
				if IsValid(ply) then SND.Loadout.SendLoadoutData(ply) end
			end)
		end
	end)
end)

timer.Create("SND_RoundTick", 0.25, 0, function()
	SND.Round.CheckTime()
	SND.Round.CheckElimination()
	nextBalanceCheck = nextBalanceCheck + 0.25
	if nextBalanceCheck >= 30 then
		nextBalanceCheck = 0
		SND.TeamBalance.Tick()
	end
end)

util.AddNetworkString("SND_RoundState")
util.AddNetworkString("SND_Halftime")

function SND.Round.Sync(target)
    net.Start("SND_RoundState")
    net.WriteUInt(tonumber(SND.Round.Phase) or 0, 3)
    net.WriteUInt(SND.Round.Winner or 0, 4)
    net.WriteUInt(tonumber(SND.Round.AttackScore) or 0, 8)
    net.WriteUInt(tonumber(SND.Round.DefendScore) or 0, 8)
    net.WriteDouble(tonumber(SND.Round.RoundTimerEnd) or 0)
    if target then net.Send(target) else net.Broadcast() end
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
