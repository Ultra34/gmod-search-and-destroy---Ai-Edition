include("shared.lua")
include("snd_settings.lua")
include("snd_bot_anim.lua")
include("cl_hud.lua")
include("snd_movement.lua")
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
		SND.Client.BombCarrierIdx = net.ReadInt(16)
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

-- ── MW2 Scoreboard Implementation ────────────────────────────────────────
surface.CreateFont("SND_MW2_Title", { font = "Verdana", size = 24, weight = 800, italic = true })
surface.CreateFont("SND_MW2_Team", { font = "Verdana", size = 22, weight = 700 })
surface.CreateFont("SND_MW2_Score", { font = "Verdana", size = 32, weight = 800 })
surface.CreateFont("SND_MW2_Header", { font = "Verdana", size = 14, weight = 600, uppercase = true })
surface.CreateFont("SND_MW2_Player", { font = "Verdana", size = 16, weight = 500 })

local scoreboard = nil

local function createScoreboard()
	local f = vgui.Create("EditablePanel")
	f:SetSize(math.min(ScrW() * 0.8, 800), ScrH() * 0.7)
	f:Center()
	f:MakePopup()
	f:SetKeyboardInputEnabled(false)

	f.Paint = function(self, w, h)
		-- Main Dark Background
		draw.RoundedBox(0, 0, 0, w, h, Color(10, 10, 10, 230))
		surface.SetDrawColor(60, 60, 60, 100)
		surface.DrawOutlinedRect(0, 0, w, h)

		-- Top Bar (Match Info)
		surface.SetDrawColor(0, 0, 0, 200)
		surface.DrawRect(0, 0, w, 60)
		draw.SimpleText("SEARCH & DESTROY", "SND_MW2_Title", 20, 30, Color(220, 220, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(game.GetMap():upper(), "SND_MW2_Header", w - 20, 30, Color(150, 150, 150), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		-- Team Scores
		local scoreA = SND.Client.AttackScore or 0
		local scoreD = SND.Client.DefendScore or 0

		-- Attackers (Red)
		surface.SetDrawColor(220, 70, 50, 40)
		surface.DrawRect(0, 60, w * 0.5, 60)
		draw.SimpleText("ATTACKERS", "SND_MW2_Team", 20, 90, Color(220, 70, 50), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(tostring(scoreA), "SND_MW2_Score", w * 0.5 - 20, 90, Color(255, 255, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		-- Defenders (Blue)
		surface.SetDrawColor(60, 140, 220, 40)
		surface.DrawRect(w * 0.5, 60, w * 0.5, 60)
		draw.SimpleText("DEFENDERS", "SND_MW2_Team", w * 0.5 + 20, 90, Color(60, 140, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(tostring(scoreD), "SND_MW2_Score", w - 20, 90, Color(255, 255, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		-- Column Headers
		surface.SetDrawColor(30, 30, 30, 255)
		surface.DrawRect(0, 120, w, 25)
		local cols = { {n="NAME", x=20, a=0}, {n="SCORE", x=w-230, a=1}, {n="K", x=w-160, a=1}, {n="D", x=w-100, a=1}, {n="PING", x=w-30, a=1} }
		for _, c in ipairs(cols) do
			draw.SimpleText(c.n, "SND_MW2_Header", c.x, 132, Color(180, 180, 180), c.a, TEXT_ALIGN_CENTER)
		end
	end

	local scroll = vgui.Create("DScrollPanel", f)
	scroll:Dock(FILL)
	scroll:DockMargin(0, 120 + 25, 0, 0)

	local function addPlayerRow(ply, list)
		local p = list:Add("DPanel")
		p:Dock(TOP)
		p:SetTall(32)
		p:DockMargin(0, 0, 0, 1)

		p.Paint = function(self, w, h)
			if not IsValid(ply) then return end
			
			-- Local Player Highlight
			if ply == LocalPlayer() then
				surface.SetDrawColor(255, 255, 255, 15)
				surface.DrawRect(0, 0, w, h)
			end

			local isAttacker = ply:Team() == SND.TEAM_ATTACK
			local teamCol = isAttacker and Color(220, 70, 50) or Color(60, 140, 220)
			local txtCol = ply:Alive() and Color(230, 230, 230) or Color(100, 100, 100)

			-- Name with Team Color Bullet
			surface.SetDrawColor(teamCol.r, teamCol.g, teamCol.b, 200)
			surface.DrawRect(5, 10, 4, 12)
			draw.SimpleText(ply:Nick(), "SND_MW2_Player", 20, h/2, txtCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			-- Stats
			draw.SimpleText(ply:Frags() * 100, "SND_MW2_Player", w-230, h/2, txtCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(ply:Frags(), "SND_MW2_Player", w-160, h/2, txtCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(ply:Deaths(), "SND_MW2_Player", w-100, h/2, txtCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			
			-- Ping Bars
			local ping = ply:Ping()
			local pingCol = Color(0, 255, 0, 200)
			if ping > 150 then pingCol = Color(255, 0, 0, 200)
			elseif ping > 75 then pingCol = Color(255, 200, 0, 200) end
			
			draw.SimpleText(tostring(ping), "SND_MW2_Player", w-30, h/2, pingCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	f.Think = function(self)
		if not self:IsVisible() then return end
		
		-- Refresh player list occasionally
		if not self.NextRefresh or CurTime() > self.NextRefresh then
			scroll:Clear()
			
			local players = player.GetAll()
			table.sort(players, function(a, b)
				if a:Team() ~= b:Team() then return a:Team() < b:Team() end
				return a:Frags() > b:Frags()
			end)

			-- Add Attackers
			local hasAtt = false
			for _, p in ipairs(players) do
				if p:Team() == SND.TEAM_ATTACK then
					addPlayerRow(p, scroll)
					hasAtt = true
				end
			end

			-- Spacer
			local spacer = scroll:Add("DPanel")
			spacer:Dock(TOP)
			spacer:SetTall(10)
			spacer.Paint = nil

			-- Add Defenders
			for _, p in ipairs(players) do
				if p:Team() == SND.TEAM_DEFEND then
					addPlayerRow(p, scroll)
				end
			end

			self.NextRefresh = CurTime() + 1
		end
	end

	return f
end

hook.Add("ScoreboardShow", "SND_ScoreboardShow", function()
	if not IsValid(scoreboard) then
		scoreboard = createScoreboard()
	end
	scoreboard:SetVisible(true)
	return true
end)

hook.Add("ScoreboardHide", "SND_ScoreboardHide", function()
	if IsValid(scoreboard) then
		scoreboard:SetVisible(false)
	end
end)

concommand.Add("snd_open_settings", function()
	SND.OpenSettingsMenu()
end)
