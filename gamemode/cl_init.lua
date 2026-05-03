include("shared.lua")
include("snd_settings.lua")
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

SND.Killcam = SND.Killcam or {}
SND.Killcam.Active = false
SND.Killcam.Data = nil
SND.Killcam.StartTime = 0
SND.Killcam.PlaybackTime = 0
SND.Killcam.WepModel = nil
SND.Killcam.VictimModel = nil
SND.Killcam.LastShot = 0
local TICK_INTERVAL = 0.033

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

	if phase == SND.PHASE_FREEZE then
		SND.Killcam.Active = false
		SND.Killcam.Data = nil
		if IsValid(SND.Killcam.WepModel) then
			SND.Killcam.WepModel:Remove()
			SND.Killcam.WepModel = nil
		end
		if IsValid(SND.Killcam.VictimModel) then
			SND.Killcam.VictimModel:Remove()
			SND.Killcam.VictimModel = nil
		end
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

net.Receive("SND_KillCam", function()
	local attacker = net.ReadEntity()
	local attHP = net.ReadUInt(7)
	local attLvl = net.ReadUInt(16)
	local weapon = net.ReadString()
	local vicMdl = net.ReadString()
	local attCount = net.ReadUInt(16)
	local attPoints = {}

	for i = 1, attCount do
		attPoints[i] = {
			p = net.ReadVector(),
			a = net.ReadAngle(),
			o = net.ReadVector(),
			b = net.ReadUInt(32),
			w = net.ReadString(),
			ws = net.ReadUInt(16),
			wc = net.ReadFloat(),
			vp = net.ReadAngle(),
			f = net.ReadFloat(),
			h = net.ReadBool()
		}
	end

	local vicCount = net.ReadUInt(16)
	if vicCount == 0 then SND.Killcam.Active = false return end
	local vicPoints = {}
	for i = 1, vicCount do
		vicPoints[i] = {
			p  = net.ReadVector(),
			a  = net.ReadAngle(),
			s  = net.ReadUInt(16),
			cy = net.ReadFloat()
		}
	end

	SND.Killcam.Data = {
		attacker = attacker,
		attHP = attHP,
		attLvl = attLvl,
		weapon = weapon,
		attPoints = attPoints,
		vicPoints = vicPoints,
		vicModelName = vicMdl
	}
	SND.Killcam.Active = true
	SND.Killcam.PlaybackTime = 0
	SND.Killcam.LastShot = 0
	SND.Killcam.SlowMoTriggered = false

	surface.PlaySound("ambient/levels/citadel/citadel_ambient_loop1.wav")
end)

hook.Add("CalcView", "SND_KillcamView", function(ply, pos, ang, fov)
	if not SND.Killcam.Active or not SND.Killcam.Data then return end

	local dt = FrameTime()
	local data = SND.Killcam.Data
	local attPoints = data.attPoints
	
	-- Slow motion logic: slow down near the end of the clip (impact)
	local progress = SND.Killcam.PlaybackTime / (#attPoints * TICK_INTERVAL)
	local timescale = (progress > 0.85) and 0.25 or 1.0

	-- Play slow-mo sound once
	if progress > 0.85 and not SND.Killcam.SlowMoTriggered then
		SND.Killcam.SlowMoTriggered = true
		surface.PlaySound("weapons/fx/nearmiss/bullet_hit_flesh_7.wav") -- Cinematic impact sound
	end
	
	SND.Killcam.PlaybackTime = SND.Killcam.PlaybackTime + dt * timescale
	
	local totalTime = SND.Killcam.PlaybackTime / TICK_INTERVAL
	local i1 = math.floor(totalTime) + 1
	local i2 = i1 + 1
	local frac = totalTime - math.floor(totalTime)

	local p1 = attPoints[i1] or attPoints[#attPoints]
	local p2 = attPoints[i2] or p1

	-- Interpolate for smooth playback
	local viewPos = LerpVector(frac, p1.p, p2.p) + LerpVector(frac, p1.o, p2.o)
	local viewAng = LerpAngle(frac, p1.a, p2.a)
	local viewPunch = LerpAngle(frac, p1.vp, p2.vp)
	local fovVal = Lerp(frac, p1.f, p2.f)

	-- Reconstruct exact client view angles by combining recorded eye angles and recoil
	local finalAng = viewAng + viewPunch

	SND.Killcam.CurrentPos = viewPos
	SND.Killcam.CurrentAng = finalAng
	SND.Killcam.CurrentPoint = p1
	SND.Killcam.CurrentFrac = frac
	SND.Killcam.CurrentIndex = i1

	if i1 >= #attPoints then
		SND.Killcam.Active = false
	end

	return {
		origin = viewPos,
		angles = finalAng,
		fov = fovVal,
		drawviewmodel = false
	}
end)

hook.Add("PrePlayerDraw", "SND_KillcamHideAttacker", function(ply)
	if SND.Killcam.Active and SND.Killcam.Data and ply == SND.Killcam.Data.attacker then
		return true -- Hide attacker body to prevent camera clipping
	end
	if SND.Killcam.Active and SND.Killcam.Data then
		-- Hide the "real" victim if they are still in the world as a ragdoll/player
		-- We will draw our own ghost version at the recorded position
		return true 
	end
end)

hook.Add("PostDrawTranslucentRenderables", "SND_KillcamWeaponRender", function()
	if not SND.Killcam.Active or not SND.Killcam.Data then return end

	local data = SND.Killcam.Data
	local pt = SND.Killcam.CurrentPoint
	local idx = SND.Killcam.CurrentIndex
	local frac = SND.Killcam.CurrentFrac
	if not pt or not idx or not frac then return end

	-- ── Render Victim Ghost ──────────────────────────────────────────────
	if data.vicPoints and data.vicPoints[idx] then
		if not IsValid(SND.Killcam.VictimModel) then
			SND.Killcam.VictimModel = ClientsideModel(data.vicModelName, RENDERGROUP_OPAQUE)
			SND.Killcam.VictimModel:SetNoDraw(true)
		end
		local vp1 = data.vicPoints[idx]
		local vp2 = data.vicPoints[idx + 1] or vp1
		
		local vPos = LerpVector(frac, vp1.p, vp2.p)
		local vAng = LerpAngle(frac, vp1.a, vp2.a)
		vAng.p = 0 -- Keep feet on ground

		SND.Killcam.VictimModel:SetPos(vPos)
		SND.Killcam.VictimModel:SetAngles(vAng)
		SND.Killcam.VictimModel:SetSequence(vp1.s)
		SND.Killcam.VictimModel:SetCycle(vp1.cy)
		SND.Killcam.VictimModel:DrawModel()
	end

	-- ── Render Attacker Weapon ───────────────────────────────────────────
	local class = pt.w
	if class == "" then return end

	local wepData = weapons.Get(class)
	local mdl = wepData and (wepData.ViewModel or wepData.WorldModel) or "models/weapons/w_rif_m4a1.mdl"

	if not IsValid(SND.Killcam.WepModel) or SND.Killcam.WepModel:GetModel() ~= mdl then
		if IsValid(SND.Killcam.WepModel) then SND.Killcam.WepModel:Remove() end
		SND.Killcam.WepModel = ClientsideModel(mdl, RENDERGROUP_VIEWMODEL)
		SND.Killcam.WepModel:SetNoDraw(true)
	end

	if IsValid(SND.Killcam.WepModel) then
		local pos = SND.Killcam.CurrentPos
		local ang = SND.Killcam.CurrentAng

		-- Tethered offset: Refined for "First Person" accuracy
		local isADS = bit.band(pt.b, IN_ATTACK2) ~= 0
		local forwardOffset = isADS and 10 or 14
		local rightOffset = isADS and 0 or 8.5
		local upOffset = isADS and -8 or -11

		local offset = ang:Forward() * forwardOffset + ang:Right() * rightOffset + ang:Up() * upOffset
		local drawPos = pos + offset

		if bit.band(pt.b, IN_ATTACK) ~= 0 then
			-- Effects and Sounds
			local light = DynamicLight(0)
			if light then
				light.pos = pos + ang:Forward() * 40
				light.r = 255; light.g = 180; light.b = 50; light.brightness = 2
				light.Size = 256; light.DieTime = CurTime() + 0.1
			end
			if CurTime() > (SND.Killcam.LastShot or 0) + 0.08 then
				SND.Killcam.LastShot = CurTime()
				local shootSound = (wepData and wepData.Primary and wepData.Primary.Sound) or "weapons/m4a1/m4a1_unsil-1.wav"
				LocalPlayer():EmitSound(shootSound, 80, 100, 1, CHAN_WEAPON)
				local effect = EffectData()
				effect:SetOrigin(pos + ang:Forward() * 30 + ang:Up() * -2)
				effect:SetAngles(ang)
				util.Effect("MuzzleFlash", effect)
			end
			drawPos = drawPos + ang:Forward() * -1.5 + ang:Up() * 0.5 -- Kick back and up
		end

		SND.Killcam.WepModel:SetPos(drawPos)
		local renderAng = Angle(ang.p, ang.y, ang.r)
		SND.Killcam.WepModel:SetAngles(renderAng)

		-- Apply weapon animations
		SND.Killcam.WepModel:SetSequence(pt.ws or 0)
		SND.Killcam.WepModel:SetCycle(pt.wc or 0)

		SND.Killcam.WepModel:SetupBones()
		SND.Killcam.WepModel:DrawModel()
	end
end)

hook.Add("RenderScreenspaceEffects", "SND_KillcamFX", function()
	if not SND.Killcam.Active then return end
	
	local attPoints = SND.Killcam.Data.attPoints
	local progress = SND.Killcam.PlaybackTime / (#attPoints * TICK_INTERVAL)

	-- Cinematic desaturation and flashback filter for the first 2 seconds
	local desat = (progress < 0.3) and 0.1 or 0.5

	local modify = {
		[ "$pp_colour_addr" ] = 0,
		[ "$pp_colour_addg" ] = 0,
		[ "$pp_colour_addb" ] = 0,
		[ "$pp_colour_brightness" ] = -0.02,
		[ "$pp_colour_contrast" ] = 1.1,
		[ "$pp_colour_colour" ] = desat,
		[ "$pp_colour_mulr" ] = 0,
		[ "$pp_colour_mulg" ] = 0,
		[ "$pp_colour_mulb" ] = 0
	}
	DrawColorModify(modify)
	DrawMotionBlur(0.1, 0.4, 0.05)
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
