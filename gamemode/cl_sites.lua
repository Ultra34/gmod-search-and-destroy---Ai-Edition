--[[ Bomb site world markers — 3D floating A / B labels, ground ring, arrow when off-screen
     NEW FILE: gamemode/cl_sites.lua
     Add to init.lua:    AddCSLuaFile("cl_sites.lua")
     Add to cl_init.lua: include("cl_sites.lua")
]]

-- ── Site data sent from server ────────────────────────────────────────────
SND.Client.Sites = {}   -- Global for HUD prompt

-- Server sends site positions when the round state changes
net.Receive("SND_SiteData", function()
	local n = net.ReadUInt(8)
	SND.Client.Sites = {}
	for i = 1, n do
		SND.Client.Sites[i] = {
			id     = net.ReadString(),
			pos    = net.ReadVector(),
			radius = net.ReadFloat(),
		}
	end
end)

-- ── Colours ───────────────────────────────────────────────────────────────
local COL_A       = Color(255, 180,  40, 255)   -- gold for A
local COL_B       = Color( 80, 200, 255, 255)   -- sky-blue for B
local COL_PLANTED = Color(255,  60,  40, 255)   -- red when planted
local COL_RING    = Color(255, 255, 255,  60)   -- faint ground ring
local COL_ARROW   = Color(255, 255, 255, 200)

local function siteColor(site)
	if SND.Bomb and SND.Bomb.PlantedSite == site.id then
		return COL_PLANTED
	end
	return site.id == "A" and COL_A or COL_B
end

-- ── Ground ring (drawn in 3D) ─────────────────────────────────────────────
local function drawRing(pos, radius, col, segments, alphaMult)
	segments = segments or 32
	alphaMult = alphaMult or 1
	local step = (math.pi * 2) / segments
	local pts  = {}
	for i = 0, segments do
		local a = i * step
		pts[i+1] = pos + Vector(math.cos(a) * radius, math.sin(a) * radius, 2)
	end
	for i = 1, segments do
		local c = Color(col.r, col.g, col.b, 80 * alphaMult)
		render.DrawLine(pts[i], pts[i+1], c, true)
	end
end

-- ── Off-screen arrow helper ────────────────────────────────────────────────
local function drawOffscreenArrow(worldPos, col)
	local scrW, scrH = ScrW(), ScrH()
	local cx, cy     = scrW * 0.5, scrH * 0.5
	local sx, sy, vis = worldPos:ToScreen()

	if vis and sx >= 0 and sx <= scrW and sy >= 0 and sy <= scrH then
		return false   -- on screen, no arrow needed
	end

	-- Project world pos to screen edge
	local dx = sx - cx
	local dy = sy - cy
	local scale = math.max(math.abs(dx) / (scrW * 0.44), math.abs(dy) / (scrH * 0.44))
	local ax = cx + dx / scale
	local ay = cy + dy / scale

	-- Clamp
	ax = math.Clamp(ax, 32, scrW - 32)
	ay = math.Clamp(ay, 32, scrH - 32)

	-- Draw a small triangle pointing toward the site
	local ang   = math.atan2(dy, dx)
	local size  = 16
	local tip   = { x = ax + math.cos(ang) * size,     y = ay + math.sin(ang) * size }
	local left  = { x = ax + math.cos(ang + 2.4) * size * 0.6, y = ay + math.sin(ang + 2.4) * size * 0.6 }
	local right = { x = ax + math.cos(ang - 2.4) * size * 0.6, y = ay + math.sin(ang - 2.4) * size * 0.6 }

	surface.SetDrawColor(col.r, col.g, col.b, 200)
	surface.DrawPoly({ tip, left, right })
	return true
end

-- ── Main render hook ──────────────────────────────────────────────────────
hook.Add("PostDrawTranslucentRenderables", "SND_SiteMarkers", function()
	if not SND.Client.Sites or #SND.Client.Sites == 0 then return end
	local lp = LocalPlayer()
	if not IsValid(lp) then return end

	-- Only show markers during live / freeze phases
	local phase = SND.Client and SND.Client.Phase
	if phase ~= SND.PHASE_LIVE and phase ~= SND.PHASE_FREEZE then return end

	local bombPlanted = SND.Bomb and SND.Bomb.State == SND.BOMB_STATE_PLANTED
	local plantedId   = SND.Bomb and SND.Bomb.PlantedSite

	local startTime = SND.Client and SND.Client.PhaseStartTime or 0
	local showDuration = 7   -- Seconds to show sites at full opacity
	local fadeDuration = 1.5 -- Seconds to fade out

	local proximityRadius = 800 -- Distance to make site show up again
	local proximityFade   = 200 -- Distance to fade in when approaching

	for _, site in ipairs(SND.Client.Sites) do
		local col     = siteColor(site)
		local isThisBombSite = bombPlanted and plantedId == site.id
		local dist = lp:GetPos():Distance(site.pos)

		-- Smooth time-based fade
		local timeAlpha = 1 - math.Clamp((CurTime() - (startTime + showDuration)) / fadeDuration, 0, 1)
		
		-- Proximity-based visibility
		local proximityAlpha = 1 - math.Clamp((dist - proximityRadius) / proximityFade, 0, 1)

		local visibility = isThisBombSite and 1 or math.max(timeAlpha, proximityAlpha)

		-- If invisible, skip
		if visibility <= 0 then continue end

		-- Ground ring (always visible, faint)
		drawRing(site.pos, site.radius, col, 40, visibility)

		-- Pulsing planted ring
		if isThisBombSite then
			local pulse = math.abs(math.sin(CurTime() * 4)) * 0.7 + 0.3
			local pc    = Color(col.r, col.g, col.b, math.floor(pulse * 180))
			drawRing(site.pos, site.radius * 0.5, pc, 32)
		end

		-- 3D floating label
		local labelPos = site.pos + Vector(0, 0, 80)

		-- Background billboard (drawn via 2D overlay below)
	end
end)

-- ── 2D overlay: floating letters + countdown ──────────────────────────────
hook.Add("HUDPaint", "SND_SiteHUD", function()
	if not SND.Client.Sites or #SND.Client.Sites == 0 then return end
	local lp = LocalPlayer()
	if not IsValid(lp) then return end

	local phase = SND.Client and SND.Client.Phase
	if phase ~= SND.PHASE_LIVE and phase ~= SND.PHASE_FREEZE then return end

	local bombPlanted = SND.Bomb and SND.Bomb.State == SND.BOMB_STATE_PLANTED
	local plantedId   = SND.Bomb and SND.Bomb.PlantedSite
	local plantTime   = SND.Bomb and SND.Bomb.PlantTime

	local startTime = SND.Client and SND.Client.PhaseStartTime or 0
	local showDuration = 7   -- Seconds to show sites at full opacity
	local fadeDuration = 1.5 -- Seconds to fade out

	local proximityRadius = 800 -- Distance to make site show up again
	local proximityFade   = 200 -- Distance to fade in when approaching

	for _, site in ipairs(SND.Client.Sites) do
		local col         = siteColor(site)
		local isPlanted   = bombPlanted and plantedId == site.id
		local labelPos    = site.pos + Vector(0, 0, 90)
		local dist        = lp:GetPos():Distance(site.pos)

		-- Smooth time-based fade
		local timeAlpha = 1 - math.Clamp((CurTime() - (startTime + showDuration)) / fadeDuration, 0, 1)
		
		-- Proximity-based visibility
		local proximityAlpha = 1 - math.Clamp((dist - proximityRadius) / proximityFade, 0, 1)

		local visibility = isPlanted and 1 or math.max(timeAlpha, proximityAlpha)

		-- If invisible, skip
		if visibility <= 0 then continue end

		local sx, sy, vis = labelPos:ToScreen()

		-- Off-screen arrow
		local offscreen = drawOffscreenArrow(labelPos, col)

		if not offscreen then
			-- Distance fade: fully visible up to 2000 units, fades to 30% at 5000
			local alpha  = math.Clamp(1 - (dist - 2000) / 3000, 0.30, 1) * 255 * visibility

			-- Outer dark pill background
			local txtW, txtH = 52, 36
			local bx, by = sx - txtW * 0.5, sy - txtH * 0.5

			draw.RoundedBox(8, bx - 2, by - 2, txtW + 4, txtH + 4, Color(0, 0, 0, alpha * 0.6))

			-- Coloured site letter, big and bold
			local pulse = isPlanted and (math.abs(math.sin(CurTime() * 5)) * 0.5 + 0.5) or 1
			draw.SimpleText(
				site.id,
				"DermaLarge",
				sx, sy,
				Color(col.r, col.g, col.b, alpha * pulse),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
			)

			-- "SITE" sub-label
			draw.SimpleText(
				"SITE",
				"Trebuchet18",
				sx, sy + 20,
				Color(220, 220, 220, alpha * 0.7),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
			)

			-- If planted here: countdown timer below the label
			if isPlanted and plantTime then
				local remaining = math.max(0, 45 - (CurTime() - plantTime))
				local timeStr   = string.format("%.1f", remaining)
				local urgency   = remaining < 10 and Color(255, 60, 40, alpha) or Color(255, 210, 40, alpha)
				draw.SimpleText(
					timeStr,
					"Trebuchet18",
					sx, sy + 36,
					urgency,
					TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
				)
			end
		end
	end
end)
