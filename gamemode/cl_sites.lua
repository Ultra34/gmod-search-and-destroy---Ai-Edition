--[[ Bomb site world markers — 3D floating A / B labels, ground ring, arrow when off-screen
--[[ Bomb site world markers — 3D floating A / B labels, ground ring, arrow when off-screen ]]

-- ── Site Data Handling ───────────────────────────────────────────────────
SND.Client.Sites = SND.Client.Sites or {}
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

-- ── Diamond Drawing Helper ────────────────────────────────────────────────
function SND.DrawSiteDiamond(x, y, size, col)
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

-- ── Off-screen arrow helper ────────────────────────────────────────────────
function SND.DrawSiteOffscreenArrow(worldPos, col, alphaMult)
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

local COL_A       = Color(255, 180,  40, 255)
local COL_B       = Color( 80, 200, 255, 255)
local COL_PLANTED = Color(255,  60,  40, 255)

function SND.GetSiteColor(siteId)
	if SND.Bomb and SND.Bomb.PlantedSite == siteId then
		return COL_PLANTED
	end
	return siteId == "A" and COL_A or COL_B
end
