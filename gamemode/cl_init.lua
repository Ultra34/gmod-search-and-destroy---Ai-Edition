include("shared.lua")
include("snd_settings.lua")
include("snd_bot_anim.lua")
include("cl_hud.lua")
include("cl_settings.lua")

SND = SND or {}
SND.Client = SND.Client or {}
SND.Client.Phase = SND.PHASE_WAIT
SND.Client.AttackScore = 0
SND.Client.DefendScore = 0
SND.Round = SND.Round or {}
SND.Client.KillFeed = SND.Client.KillFeed or {} -- Initialize kill feed table
SND.Bomb = SND.Bomb or {}
SND.Round.RoundTimerEnd = 0

net.Receive("SND_RoundState", function()
	local phase = net.ReadUInt(3)
	SND.Client.Phase = phase
	SND.Client.Winner = net.ReadUInt(4)
	SND.Client.AttackScore = net.ReadUInt(8)
	SND.Client.DefendScore = net.ReadUInt(8)
	SND.Round.RoundTimerEnd = net.ReadDouble()

	-- Clear bomb carrier whenever a round resets or moves to freeze
	if phase == SND.PHASE_FREEZE then
		SND.Client.BombCarrier = nil
	end
end)

net.Receive("SND_Bomb", function()
	SND.Client = SND.Client or {}
	SND.Bomb = SND.Bomb or {}

	local t = net.ReadUInt(3)
	if t == 1 then -- Carrier assigned
		SND.Client.BombCarrier   = net.ReadEntity()
		SND.Bomb.State           = SND.BOMB_STATE_CARRIED
		SND.Bomb.PlantedSite     = nil
		SND.Bomb.PlantTime       = nil
	elseif t == 2 then -- Bomb planted
		SND.Client.BombCarrier   = nil
		SND.Bomb.State           = SND.BOMB_STATE_PLANTED
		SND.Bomb.PlantPos        = net.ReadVector()
		SND.Bomb.PlantedSite     = net.ReadString()
		SND.Bomb.PlantTime       = CurTime()
	end
end)

net.Receive("SND_KillFeed", function()
    local attackerNick = net.ReadString()
    local attackerTeam = net.ReadUInt(2)
    local victimNick = net.ReadString()
    local victimTeam = net.ReadUInt(2)
    local weaponName = net.ReadString()

    table.insert(SND.Client.KillFeed, {
        attackerNick = attackerNick,
        attackerTeam = attackerTeam,
        victimNick = victimNick,
        victimTeam = victimTeam,
        weaponName = weaponName,
        timestamp = CurTime()
    })
end)

net.Receive("SND_MapVote", function()
	local n = net.ReadUInt(8)
	local maps = {}
	for i = 1, n do
		maps[i] = net.ReadString()
	end
	chat.AddText(Color(120, 200, 255), "[SND] Map vote — candidates: ", Color(255, 255, 255), table.concat(maps, ", "))
end)

hook.Add("PopulateToolMenu", "SND_SettingsMenu", function()
	spawnmenu.AddToolMenuOption("Utilities", "SND", "SND_Settings", "S&D Settings", "", "", function(panel)
		panel:ClearControls()
		panel:Help("SuperAdmin / listen-server host: tune gameplay ConVars (snd_*) in console or open frame.")
		panel:Button("Open settings", "snd_open_settings")
	end)
end)

concommand.Add("snd_open_settings", function()
	SND.OpenSettingsMenu()
end)

-- ── Sync Steam Friends for Bot Names ────────────────────────────────────
hook.Add("InitPostEntity", "SND_SyncFriendsForBots", function()
	local friends = player.GetFriends()
	if not friends or #friends == 0 then return end
	local names = {}
	for _, f in ipairs(friends) do table.insert(names, f:Nick()) end

	net.Start("SND_SyncBotNames")
	net.WriteTable(names)
	net.SendToServer()
end)
