include("shared.lua")
include("snd_bot_anim.lua")
include("cl_hud.lua")
include("snd_movement.lua")
include("cl_crosshair_menu.lua")
include("cl_settings.lua")
include("cl_levels.lua")

SND = SND or {}
SND.Client = SND.Client or {}
SND.Client.Phase = SND.PHASE_WAIT
SND.Client.AttackScore = 0
SND.Client.DefendScore = 0
SND.Round = SND.Round or {}
SND.Client.KillFeed = SND.Client.KillFeed or {} -- Initialize kill feed table
SND.Bomb = SND.Bomb or {}
SND.Round.RoundTimerEnd = 0
SND.Client.HalftimeTime = -1

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

	-- Force the crosshair toggle state to reset on phase changes
	-- This prevents it being stuck hidden if the round ends while scoped.
	hook.Run("SND_ResetCrosshairState")
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

net.Receive("SND_Halftime", function()
	SND.Client.HalftimeTime = CurTime()
	surface.PlaySound("ambient/levels/citadel/citadel_ambient_loop1.wav")
end)


net.Receive("SND_MapVote", function()
	local n = net.ReadUInt(8)
	local maps = {}
	for i = 1, n do
		maps[i] = net.ReadString()
	end
	chat.AddText(Color(120, 200, 255), "[SND] Map vote — candidates: ", Color(255, 255, 255), table.concat(maps, ", "))
end)

hook.Add("OnPlayerChat", "SND_PersonalizationCommand", function(ply, text)
	if ply ~= LocalPlayer() then return end
	local lower = string.lower(text)
	if lower == "!card" or lower == "!emblem" or lower == "!identity" then
		SND.OpenSettingsMenu()
		return true
	end
end)

hook.Add("PopulateToolMenu", "SND_SettingsMenu", function()
	spawnmenu.AddToolMenuOption("Utilities", "SND", "SND_Settings", "S&D Settings", "", "", function(panel)
		panel:ClearControls()
		panel:Help("SuperAdmin / listen-server host: tune gameplay ConVars (snd_*) in console or open frame.")
		panel:Button("Open settings", "snd_open_settings")
	end)
end)

-- ── MW2 Scoreboard Implementation ────────────────────────────────────────
surface.CreateFont("SND_BO3_Title", { font = "Verdana", size = 26, weight = 1000, italic = true, antialias = true })
surface.CreateFont("SND_BO3_Team", { font = "Verdana", size = 18, weight = 900, antialias = true })
surface.CreateFont("SND_BO3_Score", { font = "Verdana", size = 32, weight = 900, antialias = true })
surface.CreateFont("SND_BO3_Header", { font = "Verdana", size = 13, weight = 700, uppercase = true, antialias = true })
surface.CreateFont("SND_BO3_Player", { font = "Verdana", size = 17, weight = 400, antialias = true })

local scoreboard = nil

local function createScoreboard()
	local f = vgui.Create("EditablePanel")
	local cv = GetConVar("snd_hud_scale")
	local sc = math.Clamp(cv and cv:GetFloat() or 1, 0.75, 1.5)

	f:SetSize(900 * sc, 700 * sc)
	f:Center()
	f:MakePopup()
	f:SetKeyboardInputEnabled(false)

	f.Paint = function(self, w, h)
		-- BO3 Sleek Translucent Background
		surface.SetDrawColor(10, 10, 10, 245)
		surface.DrawRect(0, 0, w, h)
		
		-- Top Accent Bar (BO3 Orange)
		surface.SetDrawColor(255, 120, 0, 255)
		surface.DrawRect(0, 0, w, 2 * sc)

		-- Top Header Area
		surface.SetDrawColor(0, 0, 0, 150)
		surface.DrawRect(0, 2 * sc, w, 50 * sc)
		
		draw.SimpleText("GMOD SEARCH & DESTROY", "SND_BO3_Title", 20 * sc, 27 * sc, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(game.GetMap():upper(), "SND_BO3_Header", w - 20 * sc, 27 * sc, Color(180, 180, 180), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		-- Stats Header Strip
		surface.SetDrawColor(30, 30, 30, 255)
		surface.DrawRect(0, 52 * sc, w, 22 * sc)
		
		local cols = { 
			{n="RANK", x=30*sc, a=1}, {n="PLAYER", x=80*sc, a=0}, 
			{n="SCORE", x=w-280*sc, a=1}, {n="KILLS", x=w-200*sc, a=1}, 
			{n="DEATHS", x=w-120*sc, a=1}, {n="PING", x=w-40*sc, a=1} 
		}

		-- Column Dividers (Subtle)
		surface.SetDrawColor(255, 255, 255, 5)
		for i = 3, #cols do
			local cx = cols[i].x - 40 * sc
			surface.DrawRect(cx, 52 * sc, 1, h - 52 * sc)
		end

		for _, c in ipairs(cols) do
			draw.SimpleText(c.n, "SND_BO3_Header", c.x, (52 + 11) * sc, Color(150, 150, 150), c.a, TEXT_ALIGN_CENTER)
		end
	end

	local scroll = vgui.Create("DScrollPanel", f)
	scroll:Dock(FILL)
	scroll:DockMargin(0, (60 + 25) * sc, 0, 0)

	local function addTeamHeader(name, score, color, list)
		local p = list:Add("DPanel")
		p:Dock(TOP)
		p:SetTall(32 * sc)
		p:DockMargin(0, 10 * sc, 0, 2 * sc)
		p.Paint = function(self, w, h)
			-- BO3 Team Divider
			surface.SetDrawColor(color.r, color.g, color.b, 30)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(color.r, color.g, color.b, 200)
			surface.DrawRect(0, 0, 4 * sc, h) -- Side bar accent
			
			draw.SimpleText(name:upper(), "SND_BO3_Team", 20 * sc, h/2, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(tostring(score), "SND_BO3_Score", w - 40 * sc, h/2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	local function addPlayerRow(ply, list)
		local p = list:Add("DPanel")
		p:Dock(TOP)
		p:SetTall(34 * sc)
		p:DockMargin(0, 0, 0, 1 * sc)

		p.Paint = function(self, w, h)
			if not IsValid(ply) then return end
			
			-- BO3-style Row Background & Hover
			if ply == LocalPlayer() then
				surface.SetDrawColor(255, 120, 0, 30)
			elseif self:IsHovered() then
				surface.SetDrawColor(255, 255, 255, 15)
			else
				surface.SetDrawColor(255, 255, 255, 5)
			end
			surface.DrawRect(0, 0, w, h)

			local txtCol = ply:Alive() and Color(240, 240, 240) or Color(100, 100, 100)

			-- Level Icon / Number
			local lvl = ply:GetNWInt("SND_Level", 1)
			local mat = (SND.Levels and SND.Levels.GetIcon) and SND.Levels.GetIcon(lvl) or nil
			if mat then
				surface.SetMaterial(mat)
				surface.SetDrawColor(255, 255, 255, 255)
				surface.DrawTexturedRect(15 * sc, h/2 - 12 * sc, 24 * sc, 24 * sc)
			else
				draw.SimpleText(tostring(lvl), "SND_BO3_Header", 30 * sc, h/2, Color(255, 180, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			-- Specialist / Team Color Accent
			local isAttacker = ply:Team() == SND.TEAM_ATTACK
			surface.SetDrawColor(isAttacker and 220 or 60, isAttacker and 70 or 140, isAttacker and 50 or 220, 200)
			surface.DrawRect(70 * sc, 8 * sc, 3 * sc, h - 16 * sc)

			draw.SimpleText(ply:Nick():upper(), "SND_BO3_Player", 80 * sc, h/2, txtCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			-- Stats (BO3 justified alignment)
			draw.SimpleText(ply:Frags() * 100, "SND_BO3_Player", w-280 * sc, h/2, txtCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(ply:Frags(), "SND_BO3_Player", w-200 * sc, h/2, txtCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(ply:Deaths(), "SND_BO3_Player", w-120 * sc, h/2, txtCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			
			-- Ping Bars
			local ping = ply:Ping()
			local pingCol = Color(0, 255, 100, 150)
			if ping > 150 then pingCol = Color(255, 50, 50, 150)
			elseif ping > 75 then pingCol = Color(255, 200, 0, 150) end
			
			draw.SimpleText(tostring(ping), "SND_BO3_Player", w-40 * sc, h/2, pingCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
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

			-- Defenders (Rangers/Seals Style - Blue)
			addTeamHeader("Defenders", SND.Client.DefendScore or 0, Color(60, 150, 220), scroll)
			for _, p in ipairs(players) do
				if p:Team() == SND.TEAM_DEFEND then
					addPlayerRow(p, scroll)
				end
			end

			-- Attackers (Opfor Style - Red)
			addTeamHeader("Attackers", SND.Client.AttackScore or 0, Color(200, 40, 40), scroll)
			for _, p in ipairs(players) do
				if p:Team() == SND.TEAM_ATTACK then
					addPlayerRow(p, scroll)
				end
			end

			self.NextRefresh = CurTime() + 1
		end
	end

	return f
end

-- ── Custom Loadout Input Interceptor ─────────────────────────────────────
hook.Add("PlayerBindPress", "SND_WeaponSelection", function(ply, bind, pressed)
	if not pressed then return end

	if bind == "slot1" then
		net.Start("SND_QuickSwitch") net.WriteUInt(1, 2) net.SendToServer()
		return true
	elseif bind == "slot2" then
		net.Start("SND_QuickSwitch") net.WriteUInt(2, 2) net.SendToServer()
		return true
	elseif string.find(bind, "slot") or string.find(bind, "invnext") or string.find(bind, "invprev") then
		return true 
	end
end)

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
