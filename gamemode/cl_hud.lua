local function col(a, d)
	return Color(220, 230, 240, a or 255)
end

hook.Add("HUDPaint", "SND_HUD", function()
	local lp = LocalPlayer()
	if not IsValid(lp) then return end

	local cv = GetConVar("snd_hud_scale")
	local sc = math.Clamp(cv and cv:GetFloat() or 1, 0.75, 1.5)
	local x, y = 24 * sc, 24 * sc

	draw.SimpleText(
		"A " .. tostring(SND.Client.AttackScore or 0) .. "  —  " .. tostring(SND.Client.DefendScore or 0) .. " D",
		"DermaLarge",
		x,
		y,
		col(255),
		TEXT_ALIGN_LEFT,
		TEXT_ALIGN_TOP
	)

	local phase = SND.Client.Phase or SND.PHASE_WAIT
	local label = "WAIT"
	if phase == SND.PHASE_FREEZE then label = "FREEZE" end
	if phase == SND.PHASE_LIVE then label = "LIVE" end
	if phase == SND.PHASE_POST then label = "ROUND END" end

	draw.SimpleText(label, "Trebuchet24", x, y + 36 * sc, col(220), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	-- Display round timer with flashing red warning at <10 seconds
	if phase == SND.PHASE_FREEZE or phase == SND.PHASE_LIVE then
		local timeRemaining = math.max(0, SND.Round.RoundTimerEnd - CurTime())
		local mins = math.floor(timeRemaining / 60)
		local secs = math.floor(timeRemaining % 60)
		local timeStr = string.format("Time: %02d:%02d", mins, secs)

		-- Flash red when less than 10 seconds remaining
		local timerColor = col(220)
		if timeRemaining < 10 and timeRemaining > 0 then
			local flash = math.sin(CurTime() * 4) > 0 and 1 or 0.3
			timerColor = Color(255, 100 * flash, 100 * flash, 255)
		end

		draw.SimpleText(timeStr, "Trebuchet24", x, y + 60 * sc, timerColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	if IsValid(SND.Client.BombCarrier) then
		local who = SND.Client.BombCarrier == lp and "You have the bomb" or (SND.Client.BombCarrier:Nick() .. " has the bomb")
		draw.SimpleText(who, "Trebuchet24", ScrW() / 2, ScrH() - 120 * sc, Color(255, 200, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	end

	if not lp:Alive() and (SND.Client.Phase == SND.PHASE_LIVE or SND.Client.Phase == SND.PHASE_FREEZE or SND.Client.Phase == SND.PHASE_POST) then
		local tgt = lp:GetObserverTarget()
		local line = "Spectating teammates only — M1: next   M2: prev"
		if IsValid(tgt) and tgt:IsPlayer() then
			line = "Watching: " .. tgt:Nick() .. "  (M1 next / M2 prev)"
		elseif not IsValid(tgt) then
			line = line .. "  |  No living teammates — free look"
		end
		draw.SimpleText(line, "Trebuchet18", ScrW() / 2, ScrH() - 88 * sc, Color(160, 200, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	end
end)
