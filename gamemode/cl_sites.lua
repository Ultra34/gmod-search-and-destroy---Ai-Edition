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

-- ── Diamond Drawing Helper ────────────────────────────────────────────────
local function drawDiamond(x, y, size, col)
	local pts = {
		{ x = x, y = y - size },         -- Top
		{ x = x + size, y = y },         -- Right
		{ x = x, y = y + size },         -- Bottom
		{ x = x - size, y = y }          -- Left
	}
	surface.SetDrawColor(col.r, col.g, col.b, col.a)
	draw.NoTexture()
	surface.DrawPoly(pts)
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
local function drawOffscreenArrow(worldPos, col, alphaMult)
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

	surface.SetDrawColor(col.r, col.g, col.b, 200 * alphaMult)
	surface.DrawPoly({ tip, left, right })
	return true
end

-- ── Main render hook ──────────────────────────────────────────────────────
hook.Add("PostDrawTranslucentRenderables", "SND_SiteMarkers", function()
    -- 3D render logic disabled in favor of full HUD markers for better through-wall visibility
end)

-- ── 2D overlay: floating letters + countdown ──────────────────────────────
hook.Add("HUDPaint", "SND_SiteHUD", function()
	if not SND.Client.Sites or #SND.Client.Sites == 0 then return end
	local lp = LocalPlayer()
	if not IsValid(lp) then return end

    -- ONLY ATTACKERS SEE BOMB SITES THROUGH WALLS/HUD
    if lp:Team() ~= SND.TEAM_ATTACK then return end

	local phase = SND.Client and SND.Client.Phase
	if phase ~= SND.PHASE_LIVE and phase ~= SND.PHASE_FREEZE then return end

	local bombPlanted = SND.Bomb and SND.Bomb.State == SND.BOMB_STATE_PLANTED
	local plantedId   = SND.Bomb and SND.Bomb.PlantedSite
	local plantTime   = SND.Bomb and SND.Bomb.PlantTime

	for _, site in ipairs(SND.Client.Sites) do
		local col         = siteColor(site)
		local isPlanted   = bombPlanted and plantedId == site.id
		local labelPos    = site.pos + Vector(0, 0, 90)
		local dist        = lp:GetPos():Distance(site.pos)
		local meters      = math.floor(dist / 52.49) -- Source units to meters

        -- For Attackers, we keep visibility at 1 (always on) so they can find the objective
		local visibility = 1 

		local sx, sy, vis = labelPos:ToScreen()

		-- Off-screen arrow
		local isOffscreen = drawOffscreenArrow(labelPos, col, visibility)

		if not isOffscreen then
			-- Distance fade: fully visible up to 2000 units, fades to 30% at 5000
			local alpha  = math.Clamp(1 - (dist - 2000) / 3000, 0.30, 1) * 255 * visibility

			-- 1. Diamond Background (BO3/Modern Warfare style)
			local diamondSize = 28
			-- Pulsing effect for the diamond when the bomb is planted
			local pulse = isPlanted and (math.abs(math.sin(CurTime() * 5)) * 0.3 + 0.7) or 1
			
			-- Black shadow diamond
			drawDiamond(sx + 2, sy + 2, diamondSize, Color(0, 0, 0, alpha * 0.5))
			-- Team-colored diamond
			drawDiamond(sx, sy, diamondSize, Color(col.r, col.g, col.b, alpha * 0.8 * pulse))

			-- 2. Site Letter (A or B)
			draw.SimpleText(
				site.id,
				"SND_BO3_Score",
				sx, sy,
				Color(255, 255, 255, alpha),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
			)

			-- 3. Distance Counter
			local distText = meters .. "m"
			draw.SimpleText(distText, "SND_BO3_Header", sx, sy + diamondSize + 5, Color(255, 255, 255, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

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
