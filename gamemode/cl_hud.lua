--[[ HUD: scores, phase, freeze countdown bar, bomb carrier/planted info
     REPLACES: gamemode/cl_hud.lua ]]

-- Ensure math.EaseOut and math.EaseIn are defined (defensive check)
if not math.EaseOut then
    function math.EaseOut(t, power)
        power = power or 2
        return 1 - (1 - t)^power
    end
end
if not math.EaseIn then
    function math.EaseIn(t, power)
        power = power or 2
        return t^power
    end
end
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

	-- Block right-click interaction during freeze phase
	local phase = SND.Client and SND.Client.Phase or SND.PHASE_WAIT
	if phase == SND.PHASE_FREEZE then return end

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

-- Helper to check if a path is a special format (GIF or Local Data)
local function isSpecialPath(path)
	local p = tostring(path):lower()
	return p:EndsWith(".gif") or p:StartWith("http") or p:find("data/")
end

-- ── GIF & Web Material Support ────────────────────────────────────────────
local gifPanels = {}
function SND.GetIMaterial(path)
    if not path or path == "" or path == "steam" then return nil end

    local needsBridge = path:lower():EndsWith(".gif") or path:lower():StartWith("http") or path:lower():StartWith("data/")
    if needsBridge then
        if gifPanels[path] and IsValid(gifPanels[path]) then 
            return gifPanels[path]:GetHTMLMaterial() 
        end

        local p = vgui.Create("DHTML")
        p:SetSize(512, 512)
        p:SetAlpha(0)
        p:SetMouseInputEnabled(false)
        p:SetKeyboardInputEnabled(false)

        local url = path:lower():StartWith("http") and path or ("asset://garrysmod/data/" .. path:gsub("^data/", ""))
        -- Cleaner wrapper to ensure the image fills the 4:1 or 1:1 area perfectly
        p:SetHTML([[
            <html>
            <body style="margin:0; padding:0; overflow:hidden; background:transparent;">
                <img src="]] .. url .. [[" style="width:100%; height:100%; object-fit:fill;">
            </body>
            </html>
        ]])

		-- Force internal update so the material exists immediately
		p:InvalidateLayout(true)
		
        gifPanels[path] = p
        return p:GetHTMLMaterial()
    end

    return Material(path, "smooth noclamp")
end

local MAT_WHITE = Material("vgui/white")
local MAT_BOMB  = Material("vgui/hud/weapon_c4", "smooth mips")
-- Fallback if CS:S is not mounted
if MAT_BOMB:IsError() then -- If CS:S C4 model is not available
	MAT_BOMB = Material("icon16/bomb.png") -- Use a generic bomb icon
end

-- ── Calling Card State ────────────────────────────────────────────────────
SND.Client.ActiveCallingCard = SND.Client.ActiveCallingCard or nil
local cardSlideIn = 0
local cardAvatar = nil

-- ── Minimap Pings ─────────────────────────────────────────────────────────
SND.Client.MinimapPings = SND.Client.MinimapPings or {}
net.Receive("SND_MinimapPing", function()
	local pos = net.ReadVector()
	local duration = net.ReadFloat()
	table.insert(SND.Client.MinimapPings, { pos = pos, endTime = CurTime() + duration, duration = duration })
end)

-- ── Minimap State ─────────────────────────────────────────────────────────
local navData = nil
local minimapScale = 0.15
net.Receive("SND_NavData", function()
	local len = net.ReadUInt(32)
	local compressed = net.ReadData(len)
	local json = util.Decompress(compressed)
	navData = util.JSONToTable(json or "[]")
	print("[SND] Minimap: Received floorplan data (" .. (#navData/5) .. " areas)")
end)

local function rotatePoint(x, y, ang)
	local rad = math.rad(ang)
	local cos = math.cos(rad)
	local sin = math.sin(rad)
	return x * cos - y * sin, x * sin + y * cos
end

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

-- Smooth Lerp Targets
local lerpStamina = 1
local lerpHP = 100

-- ── Rounded pill helper ───────────────────────────────────────────────────
local function pill(x, y, w, h, c)
	draw.RoundedBox(6, x, y, w, h, c)
end

local function drawMinimap(sw, sh, sc, lp)
	local size = 150 * sc
	local mx, my = 16 * sc + size/2, 16 * sc + size/2
	local radius = size / 2
	local pPos = lp:GetPos()
	local pAng = lp:EyeAngles().y

	-- 1. Background
	pill(mx - radius, my - radius, size, size, col(0, 0, 0, 180))
	
	-- 2. Nav Mesh Geometry (Floorplan)
	if navData then
		render.SetScissorRect(mx - radius, my - radius, mx + radius, my + radius, true)
		surface.SetDrawColor(150, 155, 160, 150) -- Brighter grey for geometry

		for i = 1, #navData, 5 do
			local xMin, yMin, xMax, yMax, zVal = navData[i], navData[i+1], navData[i+2], navData[i+3], navData[i+4]
			
			-- ── Filters ──
			-- 1. Only show areas on the current "floor" (within 200 units height)
			if math.abs(zVal - pPos.z) > 200 then continue end

			-- 2. Distance check to save performance
			local cx, cy = (xMin + xMax) / 2, (yMin + yMax) / 2
			local distSq = (cx - pPos.x)^2 + (cy - pPos.y)^2
			if distSq > 16000000 then continue end 

			-- Calculate relative screen positions
			local x1, y1 = (xMin - pPos.x) * minimapScale, (yMin - pPos.y) * minimapScale
			local x2, y2 = (xMax - pPos.x) * minimapScale, (yMax - pPos.y) * minimapScale
			
			local rot = -pAng + 90
			local rx1, ry1 = rotatePoint(x1, y1, rot)
			local rx2, ry2 = rotatePoint(x2, y2, rot)
			local rx3, ry3 = rotatePoint(x2, y1, rot)
			local rx4, ry4 = rotatePoint(x1, y2, rot)

			-- Draw Outlines (Modern CoD style) for better visibility
			surface.DrawLine(mx + rx1, my - ry1, mx + rx3, my - ry3)
			surface.DrawLine(mx + rx3, my - ry3, mx + rx2, my - ry2)
			surface.DrawLine(mx + rx2, my - ry2, mx + rx4, my - ry4)
			surface.DrawLine(mx + rx4, my - ry4, mx + rx1, my - ry1)
			
			-- Draw very faint fill for volume
			surface.SetDrawColor(150, 155, 160, 20)
			draw.NoTexture()
			surface.DrawPoly({
				{x = mx + rx1, y = my - ry1},
				{x = mx + rx3, y = my - ry3},
				{x = mx + rx2, y = my - ry2},
				{x = mx + rx4, y = my - ry4}
			})
			surface.SetDrawColor(150, 155, 160, 150) -- Reset for next line
		end
		
		render.SetScissorRect(0, 0, 0, 0, false)

		-- 3. Bomb Sites
		for _, site in ipairs(SND.Client.Sites or {}) do
			local dx, dy = (site.pos.x - pPos.x) * minimapScale, (site.pos.y - pPos.y) * minimapScale
			local rx, ry = rotatePoint(dx, dy, -pAng + 90)
			
			-- Clamp to map edge
			local d = math.sqrt(rx*rx + ry*ry)
			if d > radius - 10 then
				rx, ry = (rx/d)*(radius-10), (ry/d)*(radius-10)
			end

			local siteCol = SND.GetSiteColor(site.id)
			draw.SimpleText(site.id, "SND_BO3_Header", mx + rx, my - ry, siteCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		-- 4. Teammates
		local lpTeam = lp:Team()
		surface.SetDrawColor(C_DEFEND.r, C_DEFEND.g, C_DEFEND.b, 255)
		for _, p in ipairs(player.GetAll()) do
			if not IsValid(p) or not p:Alive() or p == lp or p:Team() ~= lpTeam then continue end
			local dx, dy = (p:GetPos().x - pPos.x) * minimapScale, (p:GetPos().y - pPos.y) * minimapScale
			local rx, ry = rotatePoint(dx, dy, -pAng + 90)
			
			local d = math.sqrt(rx*rx + ry*ry)
			if d < radius then
				surface.DrawRect(mx + rx - 3, my - ry - 3, 6, 6) -- Slightly larger teammate icons for closer zoom
			end
		end

		-- 4.5. Enemy Pings
		for i = #SND.Client.MinimapPings, 1, -1 do
			local ping = SND.Client.MinimapPings[i]
			if CurTime() > ping.endTime then
				table.remove(SND.Client.MinimapPings, i)
				continue
			end

			local dx, dy = (ping.pos.x - pPos.x) * minimapScale, (ping.pos.y - pPos.y) * minimapScale
			local rx, ry = rotatePoint(dx, dy, -pAng + 90)
			
			-- Clamp to map edge
			local d = math.sqrt(rx*rx + ry*ry)
			if d > radius - 10 then
				rx, ry = (rx/d)*(radius-10), (ry/d)*(radius-10)
			end

			-- Fade out effect
			local alpha = math.Clamp((ping.endTime - CurTime()) / ping.duration, 0, 1) * 255
			surface.SetDrawColor(C_DANGER.r, C_DANGER.g, C_DANGER.b, alpha)
			surface.DrawRect(mx + rx - 3, my - ry - 3, 6, 6) -- Draw a small red square
		end
	end

	-- 5. Compass Letters
	local compass = { {90, "N"}, {0, "E"}, {-90, "S"}, {180, "W"} }
	for _, c in ipairs(compass) do
		local rx, ry = rotatePoint(0, radius - 8, c[1] - pAng + 90)
		draw.SimpleText(c[2], "DermaDefault", mx + rx, my - ry, C_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	-- 6. Player Arrow (Center)
	surface.SetDrawColor(255, 255, 255, 255)
	draw.NoTexture()
	surface.DrawPoly({
		{x = mx, y = my - 6},
		{x = mx + 4, y = my + 4},
		{x = mx - 4, y = my + 4}
	})

	-- 7. Outer Border
	surface.SetDrawColor(255, 120, 0, 150)
	surface.DrawOutlinedRect(mx - radius, my - radius, size, size, 2)
	
	return size
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
	local targetProgress = xpInLevel / 2000

	SND.HUD.LerpXP = Lerp(FrameTime() * 4, SND.HUD.LerpXP, targetProgress)

	local w, h = 400 * sc, 10 * sc
	local x, y = sw * 0.5 - w * 0.5, sh - 20 * sc

	-- Background
	surface.SetDrawColor(0, 0, 0, 200)
	surface.DrawRect(x, y, w, h)

	-- Fill
	surface.SetDrawColor(255, 210, 50, 255)
	surface.DrawRect(x, y, w * SND.HUD.LerpXP, h)

	-- Label
	draw.SimpleText("RANK " .. level .. " PROGRESS", "Trebuchet18", x, y - 15 * sc, Color(255, 210, 50, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end

-- ── Stamina Bar ──────────────────────────────────────────────────────────
local function drawStaminaBar(sw, sh, sc, lp)
	local targetStam = lp:GetNWFloat("SND_Stamina", 1.0)
	SND.HUD.LerpStamina = Lerp(FrameTime() * 8, SND.HUD.LerpStamina, targetStam)
	
	if SND.HUD.LerpStamina >= 0.99 and not lp.SND_Sprinting then return end

	local w, h = 180 * sc, 4 * sc
	local x, y = sw * 0.5 - w * 0.5, sh * 0.75
	local isExhausted = lp:GetNWBool("SND_Exhausted", false)

	-- Background
	surface.SetDrawColor(0, 0, 0, 150)
	surface.DrawRect(x, y, w, h)

	-- Fill
	local barCol = isExhausted and Color(255, 60, 40, 200) or Color(255, 255, 255, 180)
	surface.SetDrawColor(barCol)
	surface.DrawRect(x, y, w * SND.HUD.LerpStamina, h)
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
	SND.HUD.LerpHP = Lerp(FrameTime() * 6, SND.HUD.LerpHP, hp)
	if SND.HUD.LerpHP >= 98 then return end
	
	local alpha = math.Clamp((100 - SND.HUD.LerpHP) / 80, 0, 1) * 210
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
		if SND.GunPicker and SND.GunPicker.GetFriendlyName then
			return SND.GunPicker.GetFriendlyName(class):upper()
		end
		return class:gsub("iw[345]_", ""):upper()
	end

	-- Update Weapon Alphas (Smooth highlighting)
	SND.HUD.WepAlphas.pri = Lerp(FrameTime() * 10, SND.HUD.WepAlphas.pri, (activeClass == pri) and 255 or 80)
	SND.HUD.WepAlphas.sec = Lerp(FrameTime() * 10, SND.HUD.WepAlphas.sec, (activeClass == sec) and 255 or 80)

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
	draw.SimpleText(sName, "Trebuchet24", x, y, col(secCol.r, secCol.g, secCol.b, SND.HUD.WepAlphas.sec * 0.8), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
	drawIcon(sec, sName, x, y, SND.HUD.WepAlphas.sec)

	-- Primary
	local pName = "1: " .. cleanName(pri)
	local priCol = (activeClass == pri) and C_WHITE or C_DIM
	draw.SimpleText(pName, "Trebuchet24", x, y - 40 * sc, col(priCol.r, priCol.g, priCol.b, SND.HUD.WepAlphas.pri * 0.8), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
	drawIcon(pri, pName, x, y - 40 * sc, SND.HUD.WepAlphas.pri)
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

-- ── Weapon Pickup Prompt ──────────────────────────────────────────────────
local function drawWeaponPickupPrompt(sw, sh, sc, lp)
	local tr = lp:GetEyeTrace()
	local ent = tr.Entity
	-- Only show prompt for weapons on the ground (no owner) within reach
	if IsValid(ent) and ent:IsWeapon() and not IsValid(ent:GetOwner()) and tr.StartPos:DistToSqr(tr.HitPos) < 14400 then
		local name = ent.GetPrintName and ent:GetPrintName() or ent:GetClass()
		local alpha = 180 + math.sin(CurTime() * 10) * 75
		draw.SimpleText("PRESS [E] TO SWAP FOR " .. name:upper(), "Trebuchet24", sw * 0.5, sh * 0.55, Color(255, 255, 255, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

-- ── Calling Card HUD (MW2 Style) ─────────────────────────────────────────
local function drawCallingCardPopup(sw, sh, sc)
	local card = SND.Client.ActiveCallingCard
	if not card or CurTime() > card.endTime then return end

	local age = CurTime() - card.startTime
	local duration = card.endTime - card.startTime
	
	-- Cleanup Avatar Panel if card expired
	if CurTime() > card.endTime then
		if IsValid(cardAvatar) then cardAvatar:SetVisible(false) end
		return
	end

	-- Slide and Alpha Logic (Classic MW2 Speed)
	local alpha = 255
	if age < 0.5 then alpha = (age / 0.5) * 255 
	elseif age > duration - 0.5 then alpha = ((duration - age) / 0.5) * 255 end

	-- Balanced Banner: 512x128
	local w, h = 512 * sc, 128 * sc
	local x = sw * 0.5 - w * 0.5
	
	-- MW2 Style: Slide up from the absolute bottom center
	local animSpeed = 0.4
	local slide = math.EaseOut(math.Clamp(age / animSpeed, 0, 1), 4)
	if age > duration - animSpeed then
		slide = math.EaseIn(math.Clamp((duration - age) / animSpeed, 0, 1), 4)
	end
	
	local y = sh - (h + 50 * sc) * slide -- Positioned comfortably above the XP bar

	-- Status Label (Killed By / You Killed)
	local isKiller = card.wasKiller
	local statusText = isKiller and ("YOU KILLED " .. (card.name or "ENEMY"):upper()) or "KILLED BY"
	draw.SimpleText(statusText, "SND_BO3_Header", sw * 0.5, y - 5 * sc, col(255, 255, 255, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)

    -- Transparent hint-of-grey background (MW2 Default)
    surface.SetDrawColor(30, 30, 30, alpha * 0.7)
    surface.DrawRect(x, y, w, h)

	-- Borders
	surface.SetDrawColor(0, 0, 0, alpha * 0.8)
	surface.DrawOutlinedRect(x, y, w, h, 2 * sc)

	-- Positioning Anchors
	local embSize = 100 * sc
	local embX, embY = x + 12 * sc, y + (h - embSize) * 0.5
	local textX = x + 125 * sc

	-- ── MW2 Title Graphic (Top Strip) ────────────────────────────────────
	if card.showTitle and card.useTitleMat then 
		surface.SetMaterial(MAT_WHITE) -- Reset material state
		surface.SetDrawColor(255, 255, 255, alpha)
		local tMat = card.titleMat
		if tMat and not (tMat:IsError() and not tostring(card.titleMatPath):match("[.gif|data/]")) then
			local tW, tH = w - (embSize + 20 * sc), h * 0.45 
			surface.SetMaterial(tMat)

			if not tostring(card.titleMatPath):match("[.gif|data/]") then
				local frames = tMat:GetInt("$numframes") or 1
				if frames > 1 then tMat:SetInt("$frame", math.floor(CurTime() * 12) % frames) end
			end

			surface.DrawTexturedRect(textX - 10 * sc, y + 5 * sc, tW, tH) -- Offset to not block emblem
		end
	end

	-- Custom Title Text (Overlayed on Banner)
	if card.showTitle and not card.useTitleMat then
		draw.SimpleText(card.title:upper(), "SND_BO3_Team", textX + 1, y + 36 * sc, Color(0, 0, 0, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(card.title:upper(), "SND_BO3_Team", textX, y + 35 * sc, Color(255, 210, 50, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
	
	-- Player Name (Team Colored)
    local tCol = team.GetColor(card.team or 0)
	draw.SimpleText(card.name:upper(), "SND_BO3_Player", textX + 1, y + 93 * sc, Color(0, 0, 0, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(card.name:upper(), "SND_BO3_Player", textX, y + 92 * sc, Color(tCol.r, tCol.g, tCol.b, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	-- Rank Icon (Far Right of banner)
	local lvl = card.level or 1
	local icon = (SND.Levels and SND.Levels.GetIcon) and SND.Levels.GetIcon(lvl)
	if icon and not icon:IsError() then -- Check if icon is a valid material
		surface.SetMaterial(icon) -- Reset material state
		surface.SetDrawColor(255, 255, 255, alpha)
		surface.DrawTexturedRect(x + w - 55 * sc, y + h * 0.5 - 20 * sc, 40 * sc, 40 * sc)
	end

	if card.emblemMatPath == "steam" and not card.isBot and card.sid64 ~= "0" then
		surface.SetMaterial(MAT_WHITE) -- Reset material state
		if IsValid(cardAvatar) then
			cardAvatar:SetVisible(true)
			cardAvatar:SetPos(embX, embY)
			cardAvatar:SetSize(embSize, embSize)
			cardAvatar:SetAlpha(alpha)
		end
	else
        if IsValid(cardAvatar) then cardAvatar:SetVisible(false) end
        local embMat = card.emblemMat
		surface.SetMaterial(MAT_WHITE) -- Reset material state
        if embMat and (isSpecialPath(card.emblemMatPath) or not embMat:IsError()) then
            surface.SetMaterial(embMat)

            -- Support for animated emblem frames (Standard VTF only)
            if not isSpecialPath(card.emblemMatPath) then
                local frames = embMat:GetInt("$numframes") or 1
                if frames > 1 then
                    embMat:SetInt("$frame", math.floor(CurTime() * 12) % frames)
                end
            end

            surface.SetDrawColor(255, 255, 255, alpha)
            surface.DrawTexturedRect(embX, embY, embSize, embSize)
        end
	end
end

net.Receive("SND_ShowCallingCard", function()
	local card = {
		name = net.ReadString(),
		title = net.ReadString(),
		matPath = net.ReadString(),
		emblemMatPath = net.ReadString(),
		sid64 = net.ReadString(),
		victimName = net.ReadString(),
		level = net.ReadUInt(16),
		isBot = net.ReadBool(),
        team = net.ReadUInt(4),
        showTitle = net.ReadBool(),
		useTitleMat = net.ReadBool(),
		titleMatPath = net.ReadString(),
        wasKiller = net.ReadBool(),
		startTime = CurTime(),
		endTime = CurTime() + 4
	}

	-- Pre-cache materials to prevent frame-lag and allow animation properties to be read
	card.bannerMat = SND.GetIMaterial(card.matPath)
	if card.emblemMatPath ~= "steam" then
		card.emblemMat = SND.GetIMaterial(card.emblemMatPath)
	end
	if card.useTitleMat then
		card.titleMat = SND.GetIMaterial(card.titleMatPath)
	end

	SND.Client.ActiveCallingCard = card

	if not IsValid(cardAvatar) then
		cardAvatar = vgui.Create("AvatarImage")
		cardAvatar:SetPaintedManually(false)
	end
	cardAvatar:SetSteamID(card.sid64, 128) -- Higher resolution for 96px emblem
end)

-- ── Main HUD ─────────────────────────────────────────────────────────────
hook.Add("HUDPaint", "SND_HUD", function()
	local lp = LocalPlayer()
	if not IsValid(lp) then return end

	-- Professional Defensive Check: Ensure animation buffers are always ready
	SND.HUD = SND.HUD or {}
	SND.HUD.LerpStamina = SND.HUD.LerpStamina or 1
	SND.HUD.LerpHP      = SND.HUD.LerpHP or 100
	SND.HUD.LerpScores  = SND.HUD.LerpScores or { [1] = 0, [2] = 0 }
	SND.HUD.LerpBomb    = SND.HUD.LerpBomb or 0
	SND.HUD.LerpXP      = SND.HUD.LerpXP or 0
	SND.HUD.LerpFreeze  = SND.HUD.LerpFreeze or 0
	SND.HUD.WepAlphas   = SND.HUD.WepAlphas or { pri = 80, sec = 80 }

	local cv = GetConVar("snd_hud_scale")
	local sc = math.Clamp(cv and cv:GetFloat() or 1, 0.75, 1.5)
	local sw, sh = ScrW(), ScrH()
	local phase = SND.Client.Phase or SND.PHASE_WAIT

	if lp:Alive() and lp:GetObserverMode() == OBS_MODE_NONE and crosshairVisible then drawCrosshair(sw, sh, sc) end

	drawCallingCardPopup(sw, sh, sc)

	if lp:Alive() then drawDamageVignette(sw, sh, sc, lp:Health()) end

	-- ── XP & Leveling UI ──────────────────────────────────────────────────
	if lp:Alive() then
		drawXPBar(sw, sh, sc, lp)
		drawStaminaBar(sw, sh, sc, lp)
		
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
		drawWeaponPickupPrompt(sw, sh, sc, lp)
		drawPlantPrompt(sw, sh, sc, lp)
	end

	-- ── Bomb Site Markers (Attacker Only) ─────────────────────────────────
	local debugMode = GetConVar("snd_debug_mode"):GetBool()
	local isPlanted = SND.Bomb and SND.Bomb.State == SND.BOMB_STATE_PLANTED
	
	local isADS = lp:Alive() and not debugMode and lp:KeyDown(IN_ATTACK2)

	-- Show markers regardless of team or convar if in the dedicated Debug Phase
	local showMarkers = debugMode or isPlanted or (lp:Team() == SND.TEAM_ATTACK) or (phase == SND.PHASE_DEBUG)
	if not isADS and showMarkers and (phase == SND.PHASE_LIVE or phase == SND.PHASE_FREEZE or phase == SND.PHASE_DEBUG) then
		for _, site in ipairs(SND.Client.Sites or {}) do
			-- Defenders only see the site where the bomb is actually planted
			if lp:Team() == SND.TEAM_DEFEND and not debugMode and (not isPlanted or SND.Bomb.PlantedSite ~= site.id) then continue end

			local col = SND.GetSiteColor(site.id)
			local labelPos = site.pos + Vector(0, 0, 95)
			
			-- Draw off-screen arrows (purely 2D logic to point to the 3D objective)
			if not SND.DrawSiteOffscreenArrow(labelPos, col, 1) then
				SND.DrawSiteHUDMarker(labelPos, site.id, col, 1)
			end
		end
	end

	-- ── WAITING FOR PLAYERS COUNTER ───────────────────────────────────────
	if phase == SND.PHASE_WAIT then
		local humans = 0
		local ready = 0
		for _, p in ipairs(player.GetAll()) do
			if not p:IsBot() and not p.SND_IsBot then
				humans = humans + 1
				if p:GetNWBool("SND_IsReady", false) then ready = ready + 1 end
			end
		end

		local waitW, waitH = 300 * sc, 80 * sc
		local wx, wy = sw * 0.5 - waitW * 0.5, sh * 0.2
		
		pill(wx, wy, waitW, waitH, col(0, 0, 0, 180))
		surface.SetDrawColor(255, 120, 0, 255)
		surface.DrawRect(wx, wy, waitW, 2 * sc)

		draw.SimpleText("WAITING FOR PLAYERS", "SND_BO3_Header", sw * 0.5, wy + 25 * sc, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		local readyCol = (ready >= humans and humans > 0) and C_GREEN or Color(255, 210, 50)
		draw.SimpleText(ready .. " / " .. humans .. " READY", "SND_BO3_Score", sw * 0.5, wy + 55 * sc, readyCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		return -- Block regular HUD scores during waiting
	end

	if phase == SND.PHASE_FREEZE then
		-- Subtle dark grey overlay for better text legibility
		surface.SetDrawColor(0, 0, 0, 40)
		surface.DrawRect(0, 0, sw, sh)
	end

	-- ── Minimap ──
	local mSize = drawMinimap(sw, sh, sc, lp)

	-- ── Score bar (top-left) ───────────────────────────────────────────────
	local scoreW, scoreH = 220 * sc, 44 * sc
	local sx, sy = 32 * sc + mSize, 16 * sc

	-- Update Score Buffers
	local attKey, defKey = 1, 2

	SND.HUD.LerpScores[attKey] = SND.HUD.LerpScores[attKey] or 0
	SND.HUD.LerpScores[defKey] = SND.HUD.LerpScores[defKey] or 0

	SND.HUD.LerpScores[attKey] = Lerp(FrameTime() * 5, SND.HUD.LerpScores[attKey], SND.Client.AttackScore or 0)
	SND.HUD.LerpScores[defKey] = Lerp(FrameTime() * 5, SND.HUD.LerpScores[defKey], SND.Client.DefendScore or 0)

	pill(sx, sy, scoreW, scoreH, C_PILL)

	draw.SimpleText(
		tostring(math.Round(SND.HUD.LerpScores[attKey])),
		"DermaLarge", sx + 18 * sc, sy + scoreH * 0.5,
		C_ATTACK, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
	)
	draw.SimpleText(
		"—",
		"DermaLarge", sx + scoreW * 0.5, sy + scoreH * 0.5,
		C_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
	)
	draw.SimpleText(
		tostring(math.Round(SND.HUD.LerpScores[defKey])),
		"DermaLarge", sx + scoreW - 18 * sc, sy + scoreH * 0.5,
		C_DEFEND, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER
	)

	-- ── Phase label ───────────────────────────────────────────────────────
	local phaseStr = "WAITING"
	local phaseCol = C_DIM
	if phase == SND.PHASE_FREEZE then phaseStr = "GET READY"
	elseif phase == SND.PHASE_LIVE  then phaseStr = "LIVE"
	elseif phase == SND.PHASE_POST  then phaseStr = "ROUND END"
	elseif phase == SND.PHASE_DEBUG then 
		phaseStr = "DEBUG MODE"
		phaseCol = Color(180, 50, 255) -- Purple
	end

	draw.SimpleText(
		phaseStr, "Trebuchet18",
		sx + scoreW * 0.5, sy + scoreH + 6 * sc,
		phaseCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP
	)

	-- ── Central Timer (Match & Bomb) ─────────────────────────────────────
	if phase == SND.PHASE_LIVE or phase == SND.PHASE_FREEZE or phase == SND.PHASE_DEBUG then
		local timerVal = math.max(0, (SND.Round.RoundTimerEnd or 0) - CurTime())
		local timerCol = C_WHITE
		local isBomb = false
		local timerText = ""

		if phase == SND.PHASE_DEBUG then
			timerText = "PAUSED"
			timerCol = Color(180, 50, 255)
		else
			-- Bomb timer takes priority over the round timer once planted
			if SND.Bomb and SND.Bomb.State == SND.BOMB_STATE_PLANTED and SND.Bomb.PlantTime then
				local fuse = SND.Settings.Get("bomb_fuse_time", 45)
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
			timerText = (isBomb and timerVal < 10) and string.format("%.1f", timerVal) or string.format("%02d:%02d", m, s)
		end

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
		local targetFrac = math.Clamp(remaining / math.max(freezeDuration, 0.01), 0, 1)
		
		SND.HUD.LerpFreeze = Lerp(FrameTime() * 15, SND.HUD.LerpFreeze, targetFrac)

		local bw = 360 * sc
		local bh = 26 * sc
		local bx = sw * 0.5 - bw * 0.5
		local by = sh - 140 * sc

		-- Background
		pill(bx - 2, by - 2, bw + 4, bh + 4, C_BG)
		pill(bx, by, bw, bh, col(30, 32, 40, 220))

		-- Fill (green → yellow → red as time runs out)
		local r = math.floor(Lerp(SND.HUD.LerpFreeze, 220, 60))
		local g = math.floor(Lerp(SND.HUD.LerpFreeze, 80, 200))
		local fillCol = col(r, g, 60, 220)
		if bw * SND.HUD.LerpFreeze > 4 then
			pill(bx, by, bw * SND.HUD.LerpFreeze, bh, fillCol)
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
	if (phase == SND.PHASE_LIVE or phase == SND.PHASE_FREEZE) and lpTeam == SND.TEAM_ATTACK then
		local carrierIdx = SND.Client.BombCarrierIdx or -1
		local carrier = Entity(carrierIdx)

		if IsValid(carrier) and carrierIdx ~= -1 then
			if carrier == lp then
				local pulse = 180 + math.sin(CurTime() * 6) * 75
				draw.SimpleText("YOU HAVE THE BOMB", "SND_BO3_Team", sw * 0.5, sh - 130 * sc, col(C_BOMB.r, C_BOMB.g, C_BOMB.b, pulse), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			else
				draw.SimpleText("CARRIER: " .. carrier:Nick():upper(), "SND_BO3_Header", sw * 0.5, sh - 120 * sc, col(C_BOMB.r, C_BOMB.g, C_BOMB.b, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
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

		-- Draw Weapon Name (or icon placeholder)
		local weaponText = " (" .. entry.weaponName .. ") "
		local twW, _ = surface.GetTextSize(weaponText)

		-- Draw Attacker Nick
		local aNick = entry.attackerNick
		local twA = 0
		if aNick ~= "" then twA, _ = surface.GetTextSize(aNick) end

		-- Background box for visibility on bright maps
		local rowW = twV + twW + (aNick ~= "" and (twA + 10 * sc) or 0) + 10 * sc
		surface.SetDrawColor(0, 0, 0, alpha * 0.45)
		surface.DrawRect(kfX - rowW, currentY, rowW + 5 * sc, kfLineHeight - 4 * sc)

		draw.SimpleText(vNick, "Trebuchet24", currentDrawX + 1, currentY + 1, col(0, 0, 0, alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		draw.SimpleText(vNick, "Trebuchet24", currentDrawX, currentY, col(victimCol.r, victimCol.g, victimCol.b, alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		currentDrawX = currentDrawX - twV - 10 * sc

		draw.SimpleText(weaponText, "Trebuchet24", currentDrawX + 1, currentY + 1, col(0, 0, 0, alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		draw.SimpleText(weaponText, "Trebuchet24", currentDrawX, currentY, col(C_DIM.r, C_DIM.g, C_DIM.b, alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		currentDrawX = currentDrawX - twW - 10 * sc

		if aNick ~= "" then
			draw.SimpleText(aNick, "Trebuchet24", currentDrawX + 1, currentY + 1, col(0, 0, 0, alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
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

		-- 3D Overhead Bomb Carrier Indicator
		if SND.Client.BombCarrierIdx == target:EntIndex() then
			local pulse = 200 + math.sin(CurTime() * 8) * 55
			surface.SetMaterial(MAT_BOMB)
			surface.SetDrawColor(255, 200, 60, alpha)
			surface.DrawTexturedRect(scr.x - 12 * sc, scr.y - 45 * sc, 24 * sc, 24 * sc)
			draw.SimpleText("BOMB", "SND_BO3_Header", scr.x, scr.y - 55 * sc, Color(255, 200, 60, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
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
	local isHalftimeActive = SND.Client.HalftimeTime and SND.Client.HalftimeTime > 0 and CurTime() < SND.Client.HalftimeTime + 5

	if phase == SND.PHASE_POST and not isHalftimeActive then
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

		local bannerH = 140 * sc
		local bannerY = sh * 0.3 - bannerH * 0.5
		
		surface.SetDrawColor(0, 0, 0, 220)
		surface.DrawRect(0, bannerY, sw, bannerH)
		surface.SetDrawColor(winCol.r, winCol.g, winCol.b, 255)
		surface.DrawRect(0, bannerY, sw, 2 * sc)
		surface.DrawRect(0, bannerY + bannerH - 2 * sc, sw, 2 * sc)
		draw.SimpleText(winStr, "DermaLarge", sw * 0.5, bannerY + 45 * sc, winCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		if subStr ~= "" then
			draw.SimpleText(subStr, "Trebuchet24", sw * 0.5, bannerY + 95 * sc, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(SND.Client.AttackScore .. "  -  " .. SND.Client.DefendScore, "SND_BO3_Score", sw * 0.5, bannerY + 160 * sc, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	-- ── Halftime Message ─────────────────────────────────────────────────
	if SND.Client.HalftimeTime and SND.Client.HalftimeTime > 0 and CurTime() < SND.Client.HalftimeTime + 5 then
		local age = CurTime() - SND.Client.HalftimeTime
		local alpha = (age < 4) and 255 or math.max(0, 255 - (age - 4) * 255)
		
		local bannerH = 140 * sc
		local bannerY = sh * 0.5 - bannerH * 0.5
		
		surface.SetDrawColor(0, 0, 0, 220 * (alpha / 255))
		surface.DrawRect(0, bannerY, sw, bannerH)
		surface.SetDrawColor(255, 120, 0, alpha) -- BO3 Orange Accent
		surface.DrawRect(0, bannerY, sw, 3 * sc)
		surface.DrawRect(0, bannerY + bannerH - 3 * sc, sw, 3 * sc)

		draw.SimpleText("HALFTIME", "SND_BO3_Title", sw * 0.5, bannerY + 45 * sc, Color(255, 210, 50, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("SWITCHING SIDES", "Trebuchet24", sw * 0.5, bannerY + 95 * sc, Color(255, 255, 255, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
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

	-- ── Debug Mode Control Legend ────────────────────────────────────────
	if phase == SND.PHASE_DEBUG then
		local dy = sh * 0.15
		draw.SimpleText("DEBUG MODE - OPEN MENU: snd_open_debug_menu", "Trebuchet24", sw * 0.5, dy, Color(180, 50, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("F5: Set Site A | F6: Set Site B", "Trebuchet18", sw * 0.5, dy + 25 * sc, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("F7: Add Attack Spawn | F8: Add Defend Spawn", "Trebuchet18", sw * 0.5, dy + 45 * sc, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end)

-- ── Dropped Bomb Halo (Attacker Only) ────────────────────────────────────
hook.Add("PreDrawHalos", "SND_DroppedBombHalo", function()
	local lp = LocalPlayer()
	if not IsValid(lp) or lp:Team() ~= SND.TEAM_ATTACK then return end

	local droppedBombs = {}
	for _, ent in ipairs(ents.FindByClass("prop_physics")) do
		if ent:GetNWBool("SND_IsDroppedBomb") then
			table.insert(droppedBombs, ent)
		end
	end

	if #droppedBombs > 0 then
		local pulse = math.abs(math.sin(CurTime() * 4))
		local color = Color(255, 200, 60, 150 + (pulse * 105))
		-- Pulse the width and color; visible through walls for attackers
		halo.Add(droppedBombs, color, 2 + (pulse * 2), 2 + (pulse * 2), 1, true, true)
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

	-- Defensive Check for Bomb Bar
	SND.HUD = SND.HUD or {}
	SND.HUD.LerpBomb = SND.HUD.LerpBomb or 0

	local elapsed  = CurTime() - BombProg.started
	local targetFrac = math.Clamp(elapsed / math.max(BombProg.total, 0.01), 0, 1)
	SND.HUD.LerpBomb = Lerp(FrameTime() * 15, SND.HUD.LerpBomb, targetFrac)
	
	if SND.HUD.LerpBomb >= 0.999 and targetFrac >= 1 then BombProg.kind = 0 SND.HUD.LerpBomb = 0 return end

	local sw, sh = ScrW(), ScrH()
	local bw, bh = 320, 24
	local bx = sw * 0.5 - bw * 0.5
	local by = sh - 170

	local lbl    = BombProg.kind == 1 and "PLANTING…" or "DEFUSING…"
	local fillC  = BombProg.kind == 1 and col(220, 80, 40) or col(40, 160, 220)

	draw.RoundedBox(5, bx, by, bw, bh, col(25, 27, 35, 220))
	if bw * SND.HUD.LerpBomb > 4 then
		draw.RoundedBox(5, bx, by, bw * SND.HUD.LerpBomb, bh, fillC)
	end

	draw.SimpleText(lbl, "Trebuchet18", sw * 0.5, by + bh * 0.5,
		col(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	-- Who is doing it
	local nick = BombProg.who:Nick() or "?"
	draw.SimpleText(nick, "Trebuchet18", sw * 0.5, by + bh + 4,
		col(210, 210, 210), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
end)

-- ── Disable default GMod Death Notice ─────────────────────────────────────
hook.Add("HUDDrawTargetID", "SND_ForceRemoveHoverText", function()
	-- Returning false here removes the "Target: Name" text used by Sandbox
	return false
end)

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
