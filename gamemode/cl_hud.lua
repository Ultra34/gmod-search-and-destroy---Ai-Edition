--[[ HUD: scores, phase, freeze countdown bar, bomb carrier/planted info
     REPLACES: gamemode/cl_hud.lua ]]

-- ── Freeze end time (set by SND_FreezeInfo net message) ──────────────────
local freezeEndTime  = 0
local freezeDuration = 6

net.Receive("SND_FreezeInfo", function()
	freezeEndTime  = net.ReadFloat()   -- absolute CurTime() when freeze ends
	freezeDuration = net.ReadFloat()   -- total freeze seconds (for bar width)
end)

SND.Client.XPPopups = SND.Client.XPPopups or {}

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
	local gap = 4 * sc
	local length = 8 * sc
	local thickness = 2 * sc
	
	surface.SetDrawColor(255, 255, 255, 200)
	-- Left
	surface.DrawRect(sw * 0.5 - gap - length, sh * 0.5 - thickness * 0.5, length, thickness)
	-- Right
	surface.DrawRect(sw * 0.5 + gap, sh * 0.5 - thickness * 0.5, length, thickness)
	-- Top
	surface.DrawRect(sw * 0.5 - thickness * 0.5, sh * 0.5 - gap - length, thickness, length)
	-- Bottom
	surface.DrawRect(sw * 0.5 - thickness * 0.5, sh * 0.5 + gap, thickness, length)

	-- Center dot
	surface.DrawRect(sw * 0.5 - 1, sh * 0.5 - 1, 2, 2)
end

-- ── Main HUD ─────────────────────────────────────────────────────────────
hook.Add("HUDPaint", "SND_HUD", function()
	local lp = LocalPlayer()
	if not IsValid(lp) then return end

	local cv = GetConVar("snd_hud_scale")
	local sc = math.Clamp(cv and cv:GetFloat() or 1, 0.75, 1.5)
	local sw, sh = ScrW(), ScrH()

	if lp:Alive() and lp:GetObserverMode() == OBS_MODE_NONE then drawCrosshair(sw, sh, sc) end

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
		local teamStr = (lp:Team() == SND.TEAM_ATTACK) and "ATTACKER" or "DEFENDER"
		local teamCol = (lp:Team() == SND.TEAM_ATTACK) and C_ATTACK or C_DEFEND
		draw.SimpleText(teamStr, "DermaLarge", sw * 0.5, sh * 0.5, teamCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
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
		local matchOver = (SND.Client.AttackScore or 0) >= winLimit or (SND.Client.DefendScore or 0) >= winLimit

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

		draw.SimpleText(winStr, "DermaLarge", sw * 0.5, sh * 0.3, winCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		if subStr ~= "" then
			draw.SimpleText(subStr, "Trebuchet24", sw * 0.5, sh * 0.3 + 40 * sc, C_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
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
	if name == "CHudDeathNotice" then
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

hook.Add("RenderScreenspaceEffects", "SND_FreezePostProcess", function()
	if SND.Client and SND.Client.Phase == SND.PHASE_FREEZE then
		DrawColorModify(freezePP)
	end
end)
