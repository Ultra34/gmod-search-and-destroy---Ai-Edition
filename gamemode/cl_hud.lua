--[[ HUD: scores, phase, freeze countdown bar, bomb carrier/planted info
     REPLACES: gamemode/cl_hud.lua ]]

-- ── Freeze end time (set by SND_FreezeInfo net message) ──────────────────
local freezeEndTime  = 0
local freezeDuration = 6

net.Receive("SND_FreezeInfo", function()
	freezeEndTime  = net.ReadFloat()   -- absolute CurTime() when freeze ends
	freezeDuration = net.ReadFloat()   -- total freeze seconds (for bar width)
end)

-- ── Crosshair Settings (CS:GO Style) ─────────────────────────────────────
local cv_enabled = CreateClientConVar("snd_crosshair_enabled", "1", true, false)
local cv_gap     = CreateClientConVar("snd_crosshair_gap", "4", true, false)
local cv_length  = CreateClientConVar("snd_crosshair_length", "8", true, false)
local cv_thick   = CreateClientConVar("snd_crosshair_thickness", "2", true, false)
local cv_dot     = CreateClientConVar("snd_crosshair_dot", "1", true, false)
local cv_r       = CreateClientConVar("snd_crosshair_r", "255", true, false)
local cv_g       = CreateClientConVar("snd_crosshair_g", "255", true, false)
local cv_b       = CreateClientConVar("snd_crosshair_b", "255", true, false)

SND.Client.XPPopups = SND.Client.XPPopups or {}
local levelUpTime = -1
local levelUpAlpha = 0
local lastLevelReceived = 0

-- ── Crosshair Toggle Logic (Right-Click) ─────────────────────────────────
local crosshairVisible = true
hook.Add("PlayerButtonDown", "SND_CrosshairToggle", function(ply, btn)
	-- Prevent toggling while in menus, console, or if the cursor is visible
	if gui.IsGameUIVisible() or gui.IsConsoleVisible() or vgui.CursorVisible() then return end

	if btn == MOUSE_RIGHT then
		crosshairVisible = not crosshairVisible
	end
end)

hook.Add("SND_ResetCrosshairState", "SND_ResetCrosshair", function()
	crosshairVisible = true
end)

hook.Add("PlayerSpawn", "SND_ResetCrosshairOnSpawn", function(ply)
	if ply == LocalPlayer() then crosshairVisible = true end
end)

-- ── Red Damage Vignette Materials ────────────────────────────────────────
local MAT_GRAD_D = Material("vgui/gradient-d")
local MAT_GRAD_U = Material("vgui/gradient-u")
local MAT_GRAD_L = Material("vgui/gradient-l")
local MAT_GRAD_R = Material("vgui/gradient-r")

-- ── Colours ───────────────────────────────────────────────────────────────
local function col(r, g, b, a) return Color(r, g, b, a or 255) end

local C_WHITE  = col(230, 235, 245)
local C_DIM    = col(160, 170, 190)
local C_ATTACK = col(220,  70,  50)
local C_DEFEND = col( 60, 140, 220)
local C_BOMB   = col(255, 200,  60)
local C_DANGER = col(255,  60,  40) -- Used for "OUT OF AMMO" and match defeat
local C_GREEN  = col( 80, 220, 100)
local C_BG     = col(  0,   0,   0, 160)
local C_PILL   = col( 35,  38,  48, 210) -- Slightly lighter for score background

-- ── Rounded pill helper ───────────────────────────────────────────────────
local function pill(x, y, w, h, c)
	draw.RoundedBox(6, x, y, w, h, c)
end

-- ── Crosshair ────────────────────────────────────────────────────────────
local function drawCrosshair(sw, sh, sc)
	if not cv_enabled:GetBool() then return end

	local gap       = cv_gap:GetFloat() * sc
	local length    = cv_length:GetFloat() * sc
	local thickness = cv_thick:GetFloat() * sc
	
	surface.SetDrawColor(cv_r:GetInt(), cv_g:GetInt(), cv_b:GetInt(), 220)

	-- Left
	surface.DrawRect(sw * 0.5 - gap - length, sh * 0.5 - thickness * 0.5, length, thickness)
	-- Right
	surface.DrawRect(sw * 0.5 + gap, sh * 0.5 - thickness * 0.5, length, thickness)
	-- Top
	surface.DrawRect(sw * 0.5 - thickness * 0.5, sh * 0.5 - gap - length, thickness, length)
	-- Bottom
	surface.DrawRect(sw * 0.5 - thickness * 0.5, sh * 0.5 + gap, thickness, length)

	-- Center dot
	if cv_dot:GetBool() then
		surface.DrawRect(sw * 0.5 - thickness * 0.5, sh * 0.5 - thickness * 0.5, thickness, thickness)
	end
end

-- ── XP Progress Bar ──────────────────────────────────────────────────────
local function drawXPBar(sw, sh, sc, lp)
	local currentXP = lp.SND_XP or 0
	local level = lp:GetNWInt("SND_Level", 1)
	local xpInLevel = currentXP % 2000 -- Matches XP_PER_LEVEL in snd_levels.lua
	local progress = xpInLevel / 2000

	local w, h = 400 * sc, 10 * sc
	local x, y = sw * 0.5 - w * 0.5, sh - 20 * sc

	-- Background
	surface.SetDrawColor(0, 0, 0, 200)
	surface.DrawRect(x, y, w, h)

	-- Fill
	surface.SetDrawColor(255, 210, 50, 255)
	surface.DrawRect(x, y, w * progress, h)

	-- Label
	draw.SimpleText("RANK " .. level .. " PROGRESS", "Trebuchet18", x, y - 15 * sc, Color(255, 210, 50, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end

-- ── Level Up Popup ───────────────────────────────────────────────────────
local function drawLevelUpPopup(sw, sh, sc)
	if levelUpTime < 0 or CurTime() > levelUpTime + 4 then return end
	
	local age = CurTime() - levelUpTime
	local alpha = age < 3 and 255 or math.max(0, 255 - (age - 3) * 255)
	
	local yPos = sh * 0.4 - (math.sin(age * 2) * 10) -- Subtle bounce
	
	draw.SimpleText("LEVEL UP", "DermaLarge", sw * 0.5, yPos, Color(255, 210, 50, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText("YOU HAVE REACHED RANK " .. LocalPlayer():GetNWInt("SND_Level", 1), "Trebuchet24", sw * 0.5, yPos + 40 * sc, Color(255, 255, 255, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

-- ── Red Damage Vignette ──────────────────────────────────────────────────
local function drawDamageVignette(sw, sh, sc, hp)
	if hp >= 100 then return end
	local alpha = math.Clamp((100 - hp) / 75, 0, 1) * 200
	local size = 180 * sc
	
	surface.SetDrawColor(180, 0, 0, alpha)
	surface.SetMaterial(MAT_GRAD_D)
	surface.DrawTexturedRect(0, 0, sw, size)
	surface.SetMaterial(MAT_GRAD_U)
	surface.DrawTexturedRect(0, sh - size, sw, size)
	surface.SetMaterial(MAT_GRAD_L)
	surface.DrawTexturedRect(0, 0, size, sh)
	surface.SetMaterial(MAT_GRAD_R)
	surface.DrawTexturedRect(sw - size, 0, size, sh)
end

-- ── Weapon Inventory HUD ─────────────────────────────────────────────────
local function drawWeaponInventory(sw, sh, sc, lp)
	local pri = lp:GetNWString("SND_Primary", "")
	local sec = lp:GetNWString("SND_Secondary", "")
	local activeWep = lp:GetActiveWeapon()
	local activeClass = IsValid(activeWep) and activeWep:GetClass() or ""

	local x, y = sw - 20 * sc, sh - 80 * sc

	local function cleanName(class)
		if class == "" then return "---" end
		local name = class:gsub("arc9_mw2e_", ""):gsub("iw4_", ""):upper()
		return name
	end

	-- Helper to draw weapon icon
	local function drawIcon(class, label, iconX, iconY, alpha)
		local wep = lp:GetWeapon(class)
		if IsValid(wep) and wep.WepIcon then
			surface.SetFont("Trebuchet24")
			local tw, _ = surface.GetTextSize(label)
			surface.SetMaterial(wep.WepIcon)
			surface.SetDrawColor(255, 255, 255, alpha)
			surface.DrawTexturedRect(iconX - tw - 110 * sc, iconY - 35 * sc, 100 * sc, 50 * sc)
		end
	end

	-- Secondary
	local sName = "2: " .. cleanName(sec)
	local secCol = (activeClass == sec) and C_WHITE or C_DIM
	local secAlpha = (activeClass == sec) and 255 or 80
	draw.SimpleText(sName, "Trebuchet24", x, y, col(secCol.r, secCol.g, secCol.b, 200), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
	drawIcon(sec, sName, x, y, secAlpha)

	-- Primary
	local pName = "1: " .. cleanName(pri)
	local priCol = (activeClass == pri) and C_WHITE or C_DIM
	local priAlpha = (activeClass == pri) and 255 or 80
	draw.SimpleText(pName, "Trebuchet24", x, y - 40 * sc, col(priCol.r, priCol.g, priCol.b, 200), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
	drawIcon(pri, pName, x, y - 40 * sc, priAlpha)
end

-- ── Ammo Counter HUD ─────────────────────────────────────────────────────
local function drawAmmoCounter(sw, sh, sc, lp)
	local wep = lp:GetActiveWeapon()
	if not IsValid(wep) then return end

	local clip = wep:Clip1()
	local reserve = lp:GetAmmoCount(wep:GetPrimaryAmmoType())
	if clip < 0 then return end -- Don't draw for melee

	local x, y = sw - 20 * sc, sh - 20 * sc

	-- Ammo counts
	draw.SimpleText(tostring(reserve), "Trebuchet24", x, y, C_DIM, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
	surface.SetFont("Trebuchet24")
	local tw, _ = surface.GetTextSize(tostring(reserve))
	
	draw.SimpleText(tostring(clip), "DermaLarge", x - tw - 10 * sc, y + 5 * sc, C_WHITE, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
end

-- ── Bomb Plant Prompt ─────────────────────────────────────────────────────
local function drawPlantPrompt(sw, sh, sc, lp)
	if lp:Team() ~= SND.TEAM_ATTACK then return end
	if lp:EntIndex() ~= (SND.Client.BombCarrierIdx or -1) then return end
	if SND.Client.Phase ~= SND.PHASE_LIVE then return end

	-- Check if looking at a site
	local tr = lp:GetEyeTrace()
	if not tr.Hit or tr.StartPos:Distance(tr.HitPos) > 120 then return end

	-- Verify if the hit position is within a site radius
	local inSite = false
	local siteName = ""
	if SND.Client.Sites then
		for _, s in ipairs(SND.Client.Sites) do
			if tr.HitPos:Distance(s.pos) < s.radius then
				inSite = true
				siteName = s.id
				break
			end
		end
	end

	if inSite then
		-- Verify surface angle (mostly flat ground)
		if tr.HitNormal:Dot(Vector(0, 0, 1)) > 0.65 then
			local alpha = 180 + math.sin(CurTime() * 10) * 75
			draw.SimpleText("HOLD [E] TO PLANT AT SITE " .. siteName, "Trebuchet24", sw * 0.5, sh * 0.6, Color(255, 200, 50, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end
end

-- ── Main HUD ─────────────────────────────────────────────────────────────
hook.Add("HUDPaint", "SND_HUD", function()
	local lp = LocalPlayer()
	if not IsValid(lp) then return end

	local cv = GetConVar("snd_hud_scale")
	local sc = math.Clamp(cv and cv:GetFloat() or 1, 0.75, 1.5)
	local sw, sh = ScrW(), ScrH()

	if lp:Alive() and lp:GetObserverMode() == OBS_MODE_NONE and crosshairVisible then drawCrosshair(sw, sh, sc) end

	if lp:Alive() then drawDamageVignette(sw, sh, sc, lp:Health()) end

	-- ── XP & Leveling UI ──────────────────────────────────────────────────
	if lp:Alive() then
		drawXPBar(sw, sh, sc, lp)
		
		-- Detect Level Up for Popup (Ignoring the initial sync from 0)
		local curLvl = lp:GetNWInt("SND_Level", 0)
		if curLvl > 0 then
			if lastLevelReceived ~= 0 and curLvl > lastLevelReceived then
				levelUpTime = CurTime()
				surface.PlaySound("garrysmod/content_downloaded.wav")
				print("[SND] Level Up detected on HUD: Rank " .. curLvl)
			end
			lastLevelReceived = curLvl
		end
		drawLevelUpPopup(sw, sh, sc)
	end

	if lp:Alive() then
		drawWeaponInventory(sw, sh, sc, lp)
		drawAmmoCounter(sw, sh, sc, lp)
		drawPlantPrompt(sw, sh, sc, lp)
	end

	-- ── Visual Freeze Effect ──────────────────────────────────────────────
	local phase = SND.Client.Phase or SND.PHASE_WAIT
	if phase == SND.PHASE_FREEZE then
		-- Subtle dark grey overlay for better text legibility
		surface.SetDrawColor(0, 0, 0, 40)
		surface.DrawRect(0, 0, sw, sh)
	end

	-- ── Score bar (top-left) ───────────────────────────────────────────────
	local scoreW, scoreH = 220 * sc, 44 * sc
	local sx, sy = 16 * sc, 16 * sc

	pill(sx, sy, scoreW, scoreH, C_PILL)

	draw.SimpleText(
		tostring(SND.Client.AttackScore or 0),
		"DermaLarge", sx + 18 * sc, sy + scoreH * 0.5,
		C_ATTACK, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
	)
	draw.SimpleText(
		"—",
		"DermaLarge", sx + scoreW * 0.5, sy + scoreH * 0.5,
		C_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
	)
	draw.SimpleText(
		tostring(SND.Client.DefendScore or 0),
		"DermaLarge", sx + scoreW - 18 * sc, sy + scoreH * 0.5,
		C_DEFEND, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER
	)

	-- ── Phase label ───────────────────────────────────────────────────────
	local phaseStr = "WAITING"
	if phase == SND.PHASE_FREEZE then phaseStr = "GET READY"
	elseif phase == SND.PHASE_LIVE  then phaseStr = "LIVE"
	elseif phase == SND.PHASE_POST  then phaseStr = "ROUND END"
	end

	draw.SimpleText(
		phaseStr, "Trebuchet18",
		sx + scoreW * 0.5, sy + scoreH + 6 * sc,
		C_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP
	)

	-- ── Central Timer (Match & Bomb) ─────────────────────────────────────
	if phase == SND.PHASE_LIVE or phase == SND.PHASE_FREEZE then
		local timerVal = math.max(0, (SND.Round.RoundTimerEnd or 0) - CurTime())
		local timerCol = C_WHITE
		local isBomb = false

		-- Bomb timer takes priority over the round timer once planted
		if SND.Bomb and SND.Bomb.State == SND.BOMB_STATE_PLANTED and SND.Bomb.PlantTime then
			local fuse = 45 -- Matches FUSE_TIME in snd_bomb.lua
			timerVal = math.max(0, fuse - (CurTime() - SND.Bomb.PlantTime))
			timerCol = C_BOMB
			isBomb = true
			
			-- Pulse red when detonation is imminent (under 10s)
			if timerVal < 10 then
				local p = math.abs(math.sin(CurTime() * 10))
				timerCol = col(255, 60 + 195 * p, 40 + 215 * p)
			end
		end

		local m = math.floor(timerVal / 60)
		local s = math.floor(timerVal % 60)
		local timerText = (isBomb and timerVal < 10) and string.format("%.1f", timerVal) or string.format("%02d:%02d", m, s)

		surface.SetFont("DermaLarge")
		local tw, th = surface.GetTextSize(timerText)
		local boxW = tw + 30 * sc
		local boxH = th + 4 * sc
		
		pill(sw * 0.5 - boxW * 0.5, 12 * sc, boxW, boxH, C_PILL)
		draw.SimpleText(timerText, "DermaLarge", sw * 0.5, 12 * sc + boxH * 0.5, timerCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	-- ── Central Team Indicator (Freeze Only) ──────────────────────────────
	if phase == SND.PHASE_FREEZE then
		local isAttack = (lp:Team() == SND.TEAM_ATTACK)
		local teamStr  = isAttack and "ATTACK" or "DEFEND"
		local subStr   = isAttack and "ELIMINATE ENEMIES OR PLANT THE BOMB" or "ELIMINATE ENEMIES OR DEFUSE THE BOMB"
		local teamCol  = isAttack and C_ATTACK or C_DEFEND

		-- Match Point Logic
		local winLimit = SND.Settings.GetInt("win_limit", 4)
		local attMatchPoint = (SND.Client.AttackScore == winLimit - 1)
		local defMatchPoint = (SND.Client.DefendScore == winLimit - 1)
		local isMatchPoint = attMatchPoint or defMatchPoint

		-- Valorant-style banner background
		local barH = isMatchPoint and 125 * sc or 100 * sc
		local barY = sh * 0.45 - barH * 0.5
		
		surface.SetDrawColor(0, 0, 0, 180)
		surface.DrawRect(0, barY, sw, barH)
		
		-- Side accent lines
		surface.SetDrawColor(teamCol.r, teamCol.g, teamCol.b, 255)
		surface.DrawRect(0, barY, 4 * sc, barH)
		surface.DrawRect(sw - 4 * sc, barY, 4 * sc, barH)

		local offset = isMatchPoint and 25 * sc or 0
		if isMatchPoint then
			local mpCol = Color(255, 210, 50, 255)
			draw.SimpleText("MATCH POINT", "Trebuchet24", sw * 0.5, barY + 20 * sc, mpCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		draw.SimpleText(teamStr, "DermaLarge", sw * 0.5, barY + 35 * sc + offset, teamCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(subStr, "Trebuchet18", sw * 0.5, barY + 70 * sc + offset, C_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	-- ── FREEZE COUNTDOWN BAR (bottom-center) ──────────────────────────────
	if phase == SND.PHASE_FREEZE and freezeEndTime > 0 then
		local remaining = math.max(0, freezeEndTime - CurTime())
		local frac      = math.Clamp(remaining / math.max(freezeDuration, 0.01), 0, 1)

		local bw = 360 * sc
		local bh = 26 * sc
		local bx = sw * 0.5 - bw * 0.5
		local by = sh - 140 * sc

		-- Background
		pill(bx - 2, by - 2, bw + 4, bh + 4, C_BG)
		pill(bx, by, bw, bh, col(30, 32, 40, 220))

		-- Fill (green → yellow → red as time runs out)
		local r = math.floor(Lerp(frac, 220, 60))
		local g = math.floor(Lerp(frac, 80, 200))
		local fillCol = col(r, g, 60, 220)
		if bw * frac > 4 then
			pill(bx, by, bw * frac, bh, fillCol)
		end

		-- Text
		draw.SimpleText(
			string.format("STARTING IN  %.1f", remaining),
			"Trebuchet18",
			sw * 0.5, by + bh * 0.5,
			C_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
		)
	end

	-- ── Bomb info (bottom-center, hide from defenders) ────────────────────
	local lpTeam = lp:Team()
	if phase == SND.PHASE_LIVE and lpTeam == SND.TEAM_ATTACK then
		local bombLine = nil
		local carrierIdx = SND.Client.BombCarrierIdx or -1
		local carrier = Entity(carrierIdx)

		if IsValid(carrier) and carrierIdx ~= -1 then
			if carrier == lp then
				bombLine = "YOU HAVE THE BOMB — PLANT AT A OR B"
			else
				bombLine = carrier:Nick():upper() .. " HAS THE BOMB"
			end
		end

		if bombLine then
			draw.SimpleText(bombLine, "Trebuchet24", sw * 0.5, sh - 104 * sc,
				C_BOMB, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
			)
		end
	end

	-- ── Low Ammo Warning ──────────────────────────────────────────────────
	if phase == SND.PHASE_LIVE and lp:Alive() then
		local wep = lp:GetActiveWeapon()
		if IsValid(wep) then
			local clip = wep:Clip1()
			local max  = wep:GetMaxClip1()

			-- Show warning if clip is 25% or less (and weapon uses clips)
			if max > 0 and clip >= 0 and clip <= math.floor(max * 0.25) then
				local isOut = clip == 0
				local ammoStr = isOut and "OUT OF AMMO" or "LOW AMMO"
				local ammoCol = isOut and C_DANGER or C_BOMB

				-- Pulsing alpha for urgency
				local pulse = math.abs(math.sin(CurTime() * 7))
				local alpha = 140 + (pulse * 115)
				
				draw.SimpleText(ammoStr, "Trebuchet24", sw * 0.5, sh * 0.65,
					col(ammoCol.r, ammoCol.g, ammoCol.b, alpha),
					TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
				)
			end
		end
	end

	-- ── Kill Feed (top-right) ─────────────────────────────────────────────────
	local kfX, kfY = sw - 16 * sc, 16 * sc
	local kfLineHeight = 36 * sc -- Increased height for larger text
	local kfMaxLines = 5
	local kfFadeTime = 7 -- seconds

	-- Iterate backwards to remove old entries and draw from bottom up
	for i = #SND.Client.KillFeed, 1, -1 do
		local entry = SND.Client.KillFeed[i]
		local age = CurTime() - entry.timestamp
		if age > kfFadeTime then
			table.remove(SND.Client.KillFeed, i)
			continue
		end

		local alpha = math.Clamp(1 - (age / kfFadeTime), 0, 1) * 255
		local currentY = kfY + (#SND.Client.KillFeed - i) * kfLineHeight

		-- Ensure we don't draw too many lines
		if (#SND.Client.KillFeed - i) >= kfMaxLines then continue end

		local attackerCol = (entry.attackerTeam == SND.TEAM_ATTACK) and C_ATTACK or C_DEFEND
		local victimCol = (entry.victimTeam == SND.TEAM_ATTACK) and C_ATTACK or C_DEFEND

		local currentDrawX = kfX

		-- Draw Victim Nick
		local vNick = entry.victimNick
		surface.SetFont("Trebuchet24")
		local twV, _ = surface.GetTextSize(vNick)
		draw.SimpleText(vNick, "Trebuchet24", currentDrawX, currentY, col(victimCol.r, victimCol.g, victimCol.b, alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		currentDrawX = currentDrawX - twV - 10 * sc

		-- Draw Weapon Name (or icon placeholder)
		local weaponText = " (" .. entry.weaponName .. ") "
		local twW, _ = surface.GetTextSize(weaponText)
		draw.SimpleText(weaponText, "Trebuchet24", currentDrawX, currentY, col(C_DIM.r, C_DIM.g, C_DIM.b, alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		currentDrawX = currentDrawX - twW - 10 * sc

		-- Draw Attacker Nick
		local aNick = entry.attackerNick
		if aNick ~= "" then
			draw.SimpleText(aNick, "Trebuchet24", currentDrawX, currentY, col(attackerCol.r, attackerCol.g, attackerCol.b, alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		end
	end

	-- ── Bot Tag ──────────────────────────────────────────────────────────
	local botCount = SND.Settings.GetInt("bot_count", 0)
	if botCount > 0 then
		draw.SimpleText("BOTS (EXPERIMENTAL)", "Trebuchet18", 
			sx + scoreW * 0.5, sy + scoreH + 26 * sc, 
			Color(255, 150, 50, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	end

	-- ── Player Nameplates (Teammates & Visible Enemies) ───────────────────
	for _, target in ipairs(player.GetAll()) do
		if not IsValid(target) or not target:Alive() or target == lp then continue end

		local isTeammate = target:Team() == lpTeam
		local dist = lp:GetPos():Distance(target:GetPos())

		-- Enemy Visibility Check
		if not isTeammate then
			local tr = util.TraceLine({
				start = lp:EyePos(),
				endpos = target:EyePos(),
				filter = {lp, target},
				mask = MASK_SHOT
			})
			if tr.Fraction < 1 then continue end
		end

		local headPos = target:GetPos() + Vector(0, 0, 78)
		local scr = headPos:ToScreen()
		if not scr.visible then continue end

		-- Teammates visible from far away; enemies fade out within 10m (~525 units)
		local startFade = isTeammate and 800 or 350
		local endFade = isTeammate and 1200 or 525

		local alpha = math.Clamp(255 * (1 - (dist - startFade) / (endFade - startFade)), isTeammate and 40 or 0, 220)
		if alpha <= 0 then continue end

		local teamColor = (target:Team() == SND.TEAM_ATTACK) and C_ATTACK or C_DEFEND
		draw.SimpleText(target:Nick(), "Trebuchet24", scr.x, scr.y, Color(teamColor.r, teamColor.g, teamColor.b, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	-- ── XP Popups ────────────────────────────────────────────────────────
	for i = #SND.Client.XPPopups, 1, -1 do
		local p = SND.Client.XPPopups[i]
		local age = CurTime() - p.time
		if age > 2 then table.remove(SND.Client.XPPopups, i) continue end

		local alpha = math.Clamp(1 - (age / 2), 0, 1) * 255
		local yOffset = age * 40 * sc
		
		draw.SimpleText(
			"+" .. p.amount,
			"Trebuchet24",
			sw * 0.5 + 40 * sc,
			sh * 0.5 - 20 * sc - yOffset,
			Color(255, 255, 255, alpha),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
		)
	end

	-- ── Victory Messages (Round End) ──────────────────────────────────────
	if phase == SND.PHASE_POST then
		local winLimit = SND.Settings.GetInt("win_limit", 4)
		local matchOver = (SND.Client.Winner ~= SND.WIN_DRAW and SND.Client.Winner ~= SND.WIN_NONE) and ((SND.Client.AttackScore or 0) >= winLimit or (SND.Client.DefendScore or 0) >= winLimit)

		if matchOver then
			draw.RoundedBox(0, 0, 0, sw, sh, col(0, 0, 0, 200))
		end

		local winStr = "ROUND DRAW"
		local winCol = C_WHITE
		local subStr = ""
		local winner = SND.Client.Winner or SND.WIN_NONE
		local lpTeam = lp:Team()

		if winner == SND.WIN_ATTACK_ELIM or winner == SND.WIN_ATTACK_PLANT then
			subStr = "ATTACKERS WIN"
			if lpTeam == SND.TEAM_ATTACK then
				winStr = matchOver and "MATCH VICTORY" or "VICTORY"
				winCol = C_GREEN
			else
				winStr = matchOver and "MATCH DEFEAT" or "DEFEAT"
				winCol = C_DANGER
			end
		elseif winner == SND.WIN_DEFEND_ELIM or winner == SND.WIN_DEFEND_DEFUSE or winner == SND.WIN_TIME then
			subStr = "DEFENDERS WIN"
			if lpTeam == SND.TEAM_DEFEND then
				winStr = matchOver and "MATCH VICTORY" or "VICTORY"
				winCol = C_GREEN
			else
				winStr = matchOver and "MATCH DEFEAT" or "DEFEAT"
				winCol = C_DANGER
			end
		end

		if matchOver and winner ~= SND.WIN_DRAW then
			subStr = subStr .. " — FINAL SCORE " .. (SND.Client.AttackScore or 0) .. ":" .. (SND.Client.DefendScore or 0)
		end

		-- Flashy CoD Style Victory Banner
		local bannerH = 140 * sc
		local bannerY = sh * 0.3 - bannerH * 0.5
		
		surface.SetDrawColor(0, 0, 0, 220)
		surface.DrawRect(0, bannerY, sw, bannerH)
		
		-- Accent lines
		surface.SetDrawColor(winCol.r, winCol.g, winCol.b, 255)
		surface.DrawRect(0, bannerY, sw, 2 * sc)
		surface.DrawRect(0, bannerY + bannerH - 2 * sc, sw, 2 * sc)

		draw.SimpleText(winStr, "DermaLarge", sw * 0.5, bannerY + 45 * sc, winCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		
		if subStr ~= "" then
			draw.SimpleText(subStr, "Trebuchet24", sw * 0.5, bannerY + 95 * sc, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			
			-- Show Scoreboard-style score below
			draw.SimpleText(SND.Client.AttackScore .. "  -  " .. SND.Client.DefendScore, "SND_BO3_Score", sw * 0.5, bannerY + 160 * sc, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	-- ── Killcam Overlay ──────────────────────────────────────────────────
	if SND.Killcam and SND.Killcam.Active and SND.Killcam.Data then
		local data = SND.Killcam.Data
		surface.SetDrawColor(0, 0, 0, 150)
		surface.DrawRect(0, 0, sw, 80 * sc)
		surface.DrawRect(0, sh - 80 * sc, sw, 80 * sc)

		surface.SetDrawColor(255, 120, 0, 255)
		surface.DrawRect(0, 78 * sc, sw, 2 * sc)
		surface.DrawRect(0, sh - 80 * sc, sw, 2 * sc)

		draw.SimpleText("FINAL KILLCAM", "SND_BO3_Title", sw * 0.5, 40 * sc, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		
		local attackerName = IsValid(data.attacker) and data.attacker:Nick():upper() or "PLAYER"
		local weaponName = data.weapon:upper()
		draw.SimpleText(attackerName .. "  //  " .. weaponName, "Trebuchet24", 40 * sc, sh - 40 * sc, Color(255, 120, 0), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	-- ── Spectator label ───────────────────────────────────────────────────
	if not lp:Alive() and (phase == SND.PHASE_LIVE or phase == SND.PHASE_FREEZE) then
		local tgt  = lp:GetObserverTarget()
		local line = IsValid(tgt) and tgt:IsPlayer()
		            and ("Watching: " .. tgt:Nick() .. "  (M1 next / M2 prev)")
		            or "Spectating — no living teammates — free look"
		draw.SimpleText(line, "Trebuchet18", sw * 0.5, sh - 72 * sc,
			col(160, 200, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end)

-- ── Plant/defuse progress bar (driven by SND_BombProgress) ───────────────
local BombProg = { kind = 0, who = nil, total = 0, started = 0 }

net.Receive("SND_BombProgress", function()
	BombProg.kind    = net.ReadUInt(2)
	BombProg.who     = net.ReadEntity()
	BombProg.total   = net.ReadFloat()
	BombProg.started = CurTime()
end)

hook.Add("HUDPaint", "SND_BombProgressBar", function()
	if BombProg.kind == 0 then return end
	if not IsValid(BombProg.who) then BombProg.kind = 0 return end

	local elapsed  = CurTime() - BombProg.started
	local frac     = math.Clamp(elapsed / math.max(BombProg.total, 0.01), 0, 1)
	if frac >= 1 then BombProg.kind = 0 return end

	local sw, sh = ScrW(), ScrH()
	local bw, bh = 320, 24
	local bx = sw * 0.5 - bw * 0.5
	local by = sh - 170

	local lbl    = BombProg.kind == 1 and "PLANTING…" or "DEFUSING…"
	local fillC  = BombProg.kind == 1 and col(220, 80, 40) or col(40, 160, 220)

	draw.RoundedBox(5, bx, by, bw, bh, col(25, 27, 35, 220))
	if bw * frac > 4 then
		draw.RoundedBox(5, bx, by, bw * frac, bh, fillC)
	end

	draw.SimpleText(lbl, "Trebuchet18", sw * 0.5, by + bh * 0.5,
		col(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	-- Who is doing it
	local nick = BombProg.who:Nick() or "?"
	draw.SimpleText(nick, "Trebuchet18", sw * 0.5, by + bh + 4,
		col(210, 210, 210), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
end)

-- ── Disable default GMod Death Notice ─────────────────────────────────────
hook.Add("HUDShouldDraw", "SND_DisableDefaultKillFeed", function(name)
	if name == "CHudDeathNotice" or name == "CHudWeaponSelection" or name == "CHudHistoryResource" or name == "CHudHealth" or name == "CHudBattery" or name == "CHudAmmo" or name == "CHudTargetID" then
		return false
	end
end)

-- ── Post-Processing Freeze Effect ────────────────────────────────────────
local freezePP = {
	[ "$pp_colour_addr" ] = 0,
	[ "$pp_colour_addg" ] = 0,
	[ "$pp_colour_addb" ] = 0,
	[ "$pp_colour_brightness" ] = -0.05,
	[ "$pp_colour_contrast" ] = 1.1,
	[ "$pp_colour_colour" ] = 0, -- Full greyscale desaturation
	[ "$pp_colour_mulr" ] = 0,
	[ "$pp_colour_mulg" ] = 0,
	[ "$pp_colour_mulb" ] = 0
}

-- ── Damage Post-Processing ──────────────────────────────────────────────
local damagePP = {
	[ "$pp_colour_addr" ] = 0,
	[ "$pp_colour_addg" ] = 0,
	[ "$pp_colour_addb" ] = 0,
	[ "$pp_colour_brightness" ] = 0,
	[ "$pp_colour_contrast" ] = 1,
	[ "$pp_colour_colour" ] = 1,
	[ "$pp_colour_mulr" ] = 0,
	[ "$pp_colour_mulg" ] = 0,
	[ "$pp_colour_mulb" ] = 0
}

hook.Add("RenderScreenspaceEffects", "SND_FreezePostProcess", function()
	if SND.Client and SND.Client.Phase == SND.PHASE_FREEZE then
		DrawColorModify(freezePP)
	end
end)

hook.Add("RenderScreenspaceEffects", "SND_DamagePostProcess", function()
	local lp = LocalPlayer()
	if not IsValid(lp) or not lp:Alive() then return end
	
	local hp = lp:Health()
	if hp < 100 then
		local intensity = math.Clamp((100 - hp) / 100, 0, 1)
		damagePP["$pp_colour_addr"] = 0.15 * intensity
		damagePP["$pp_colour_mulr"] = 0.1 * intensity
		damagePP["$pp_colour_brightness"] = -0.05 * intensity
		DrawColorModify(damagePP)
	end
end)
