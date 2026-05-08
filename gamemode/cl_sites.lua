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

SND.Client.Spawns = SND.Client.Spawns or { attack = {}, defend = {} }
net.Receive("SND_SpawnData", function()
    SND.Client.Spawns.attack = {}
    local nAttack = net.ReadUInt(8)
    for i = 1, nAttack do
        table.insert(SND.Client.Spawns.attack, {
            pos = net.ReadVector(),
            ang = net.ReadAngle()
        })
    end

    SND.Client.Spawns.defend = {}
    local nDefend = net.ReadUInt(8)
    for i = 1, nDefend do
        table.insert(SND.Client.Spawns.defend, {
            pos = net.ReadVector(),
            ang = net.ReadAngle()
        })
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
	local scr = worldPos:ToScreen()
	local sx, sy, vis = scr.x, scr.y, scr.visible

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

-- ── Ground Ring Helper ───────────────────────────────────────────────────
local function drawGroundRing(pos, radius, col)
	render.SetColorMaterial()
	local segments = 32
	local step = (math.pi * 2) / segments
	local lastPos = nil
	
	for i = 0, segments do
		local ang = i * step
		local offset = Vector(math.cos(ang) * radius, math.sin(ang) * radius, 10)
		local worldP = pos + offset
		
		-- Trace down to stick to ground
		local tr = util.TraceLine({
			start = worldP,
			endpos = worldP - Vector(0, 0, 100),
			mask = MASK_SOLID_BRUSHONLY
		})
		local drawP = tr.Hit and (tr.HitPos + tr.HitNormal) or worldP
		
		if lastPos then render.DrawLine(lastPos, drawP, col, true) end
		lastPos = drawP
	end
end

-- ── 3D2D World Markers ───────────────────────────────────────────────────
hook.Add("PostDrawTranslucentRenderables", "SND_Site3D2D", function()
	local lp = LocalPlayer()
	if not IsValid(lp) then return end

	local phase = SND.Client and SND.Client.Phase or SND.PHASE_WAIT
	local debugMode = GetConVar("snd_debug_mode"):GetBool()

	local isPlanted = SND.Bomb and SND.Bomb.State == SND.BOMB_STATE_PLANTED

	-- Show for Attackers normally, everyone in Debug Mode, or if the bomb is planted
	if lp:Team() ~= SND.TEAM_ATTACK and not debugMode and not isPlanted then return end
	if phase ~= SND.PHASE_LIVE and phase ~= SND.PHASE_FREEZE and phase ~= SND.PHASE_DEBUG then return end

	local sites = SND.Client.Sites or {}
	if #sites == 0 then return end

	local isADS = lp:Alive() and not debugMode and lp:KeyDown(IN_ATTACK2)
	local eyePos = lp:EyePos()
	local eyeAng = lp:EyeAngles()

	for _, site in ipairs(sites) do
		if isADS then continue end

		-- Defenders only see markers for the site where the bomb is actually active
		local isThisPlanted = SND.Bomb and SND.Bomb.PlantedSite == site.id
		if lp:Team() == SND.TEAM_DEFEND and not debugMode and not isThisPlanted then continue end

		local col = SND.GetSiteColor(site.id)
		local pos = site.pos + Vector(0, 0, 85) -- Slightly lower anchor for better visibility
		local dist = eyePos:Distance(pos)
		local meters = math.floor(dist / 52.49)

		-- ── Billboarding & Constant Scaling ──
		-- Keep the icon facing the player but locked vertically (upright)
		local drawAng = Angle(0, eyeAng.y - 90, 90)
		
		-- Formula to keep the icon roughly the same size on screen regardless of distance
		local scale = math.Clamp(dist * 0.00015, 0.04, 0.18)

		-- cam.Start3D2D handles the transformation into world-space
		cam.Start3D2D(pos, drawAng, scale)
			-- Objective markers are typically visible through walls for attackers
			render.OverrideDepthEnable(true, false)
			
			local diamondSize = 100
			local diamondPulse = isThisPlanted and (math.abs(math.sin(CurTime() * 8)) * 0.5 + 0.5) or 1
			
			-- Draw stylized "COD" container (Shadow -> Background -> Border)
			SND.DrawSiteDiamond(0, 0, diamondSize + 10, Color(0, 0, 0, 180 * diamondPulse))
			SND.DrawSiteDiamond(0, 0, diamondSize, Color(col.r, col.g, col.b, 230 * diamondPulse))

			draw.SimpleText(site.id, "SND_MW2_3D2D", 0, 0, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			
			-- Render Distance using cam-space coordinates
			draw.SimpleText(meters .. "M", "SND_BO3_Score", 0, diamondSize + 20, Color(255, 255, 255, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

			-- Render bomb timer in world-space
			if isPlanted and SND.Bomb.PlantTime then
				local remaining = math.max(0, 45 - (CurTime() - SND.Bomb.PlantTime))
				local timeStr   = string.format("%.1f", remaining)
				local urgency   = remaining < 10 and Color(255, 60, 40) or Color(255, 210, 40)
				
				draw.SimpleText(timeStr, "SND_MW2_3D2D", 0, diamondSize + 120, urgency, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			end
			
			render.OverrideDepthEnable(false, false)
		cam.End3D2D()

		-- ── Reworked Ground Zone Visuals ──
		local ringPulseSpeed = isThisPlanted and 4 or 2
		local pulse = 0.6 + math.abs(math.sin(CurTime() * ringPulseSpeed)) * 0.4
		
		-- Outer glowing ring
		drawGroundRing(site.pos, (site.radius or 120) + 2, Color(col.r, col.g, col.b, 50 * pulse))
		-- Main inner ring
		drawGroundRing(site.pos, site.radius or 120, Color(col.r, col.g, col.b, 150 * pulse))

		-- Vertical Beacon Effect for active objectives
		if isThisPlanted or debugMode then
			render.SetColorMaterial()
			local beamAlpha = isThisPlanted and (80 * pulse) or 30
			local beamHeight = isThisPlanted and (600 + math.sin(CurTime() * 5) * 50) or 200
			render.DrawBeam(site.pos, site.pos + Vector(0,0,beamHeight), 12, 0, 1, Color(col.r, col.g, col.b, beamAlpha))
		end

		-- Draw the defuse radius ring in world-space during Debug Mode
		if debugMode or phase == SND.PHASE_DEBUG then
			debugoverlay.Sphere(site.pos, site.radius or 120, 0.1, Color(255, 255, 0, 255), true)
			debugoverlay.EntityText(0, site.pos + Vector(0,0,20), "SITE " .. (site.id or "?"), 0.1, Color(255, 255, 0), true)
		end
	end

    -- Draw Spawn Debug Visuals
    if debugMode or phase == SND.PHASE_DEBUG then
        local spawns = SND.Client.Spawns
        if spawns then
            -- Draw Attack Spawns (Red)
            for _, s in ipairs(spawns.attack or {}) do
                debugoverlay.Box(s.pos, Vector(-16,-16,0), Vector(16,16,72), 0.1, Color(255, 0, 0, 255), true) -- Box already draws through walls
                debugoverlay.EntityText(0, s.pos + Vector(0,0,75), "ATTACKER SPAWN", 0.1, Color(255, 50, 50), true)
            end
            -- Draw Defend Spawns (Blue)
            for _, s in ipairs(spawns.defend or {}) do
                debugoverlay.Box(s.pos, Vector(-16,-16,0), Vector(16,16,72), 0.1, Color(0, 0, 255, 255), true) -- Box already draws through walls
                debugoverlay.EntityText(0, s.pos + Vector(0,0,75), "DEFENDER SPAWN", 0.1, Color(50, 50, 255), true)
            end
        end
    end
end)
