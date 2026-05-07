--[[ Gun Picker — shown during freeze time so players can choose their loadout ]]
--[[ Loadout Manager — 10-slot persistent system with Ready Up logic ]]
-- Add to init.lua:   AddCSLuaFile("cl_gunpicker.lua")
-- Add to cl_init.lua: include("cl_gunpicker.lua")

SND = SND or {}
SND.GunPicker = SND.GunPicker or {}

-- ── Friendly display names ────────────────────────────────────────────────
-- If a weapon class has no entry here the raw class name is shown instead.
local DISPLAY_NAMES = {
	-- CoD4 IW3
	["iw3_ak47"] = "AK-47 (Classic)",
	["iw3_g3"] = "G3",
	["iw3_g36c"] = "G36C (Classic)",
	["iw3_m14"] = "M14",
	["iw3_m16a4"] = "M16A4 (Classic)",
	["iw3_m4a1"] = "M4A1 (Classic)",
	["iw3_mp44"] = "MP44",
	["iw3_usp"] = "USP .45 (Classic)",
	["iw3_beretta"] = "M9 Beretta (Classic)",
	["iw3_colt45"] = "M1911 Colt",
	["iw3_deserteagle"] = "Desert Eagle (Classic)",
	["iw3_m249"] = "M249 SAW",
	["iw3_m60e4"] = "M60E4",
	["iw3_rpd"] = "RPD (Classic)",
	["iw3_m1014"] = "M1014 (Classic)",
	["iw3_w1200"] = "W1200",
	["iw3_barrett"] = "M82 Barrett (Classic)",
	["iw3_dragunov"] = "SVD Dragunov (Classic)",
	["iw3_m21"] = "M21 Sniper",
	["iw3_m40a3"] = "M40A3",
	["iw3_r700"] = "R700",
	["iw3_skorpion"] = "Skorpion",
	["iw3_p90"] = "P90 (Classic)",
	["iw3_mp5"] = "MP5 (Classic)",
	["iw3_miniuzi"] = "Mini-Uzi (Classic)",
	["iw3_ak74u"] = "AK-74u",
	["iw3_at4"] = "AT4 (Classic)",
	["iw3_rpg"] = "RPG-7 (Classic)",

	-- MW2 primaries (TFA)
	["iw4_acr"]         = "ACR 6.8",
	["iw4_ak47"]        = "AK-47",
	["iw4_f2000"]       = "F2000",
	["iw4_fal"]         = "FN FAL",
	["iw4_famas"]       = "FAMAS",
	["iw4_m16a4"]       = "M16A4",
	["iw4_m4a1"]        = "M4A1",
	["iw4_scar"]        = "SCAR-H",
	["iw4_tavor"]       = "TAVOR",
	["iw4_aug"]         = "AUG",
	["iw4_rpd"]         = "RPD",
	["iw4_m240"]        = "M240",
	["iw4_mg4"]         = "MG4",
	["iw4_sa80"]        = "L86 LSW",
	["iw4_miniuzi"]     = "Mini-Uzi",
	["iw4_ump45"]       = "UMP45",
	["iw4_tmp"]         = "TMP",
	["iw4_m1014"]       = "M1014",
	["iw4_1887"]        = "Model 1887",
	["iw4_akimbo_1887"] = "Akimbo 1887",
	["iw4_ranger"]      = "W1200 Ranger",
	["iw4_spas12"]      = "SPAS-12",
	["iw4_striker"]     = "Striker",
	["iw4_cheytac"]     = "CheyTac M200",
	["iw4_dragunov"]    = "SVD Dragunov",
	["iw4_m14ebr"]      = "M14 EBR",
	["iw4_barrett"]     = "Barrett .50cal",
	["iw4_wa2000"]      = "WA2000",
	["iw4_mp5"]         = "MP5K",
	["iw4_pp2000"]      = "PP-2000",
	["iw4_vector"]      = "KRISS Vector",
	["iw4_riotshield"]  = "Riot Shield",

	-- MW3 IW5
	["iw5_acr"] = "ACR 6.8 (MW3)",
	["iw5_ak47"] = "AK-47 (MW3)",
	["iw5_cm901"] = "CM901",
	["iw5_fad"] = "FAD",
	["iw5_g36c"] = "G36C (MW3)",
	["iw5_m16a4"] = "M16A4 (MW3)",
	["iw5_m4a1"] = "M4A1 (MW3)",
	["iw5_mk14"] = "MK14 EBR",
	["iw5_type95"] = "Type 95",
	["iw5_scar"] = "SCAR-L",
	["iw5_anaconda"] = ".44 Magnum (MW3)",
	["iw5_deserteagle"] = "Desert Eagle (MW3)",
	["iw5_fiveseven"] = "Five-SeveN",
	["iw5_mp412"] = "MP412",
	["iw5_p99"] = "P99",
	["iw5_usp"] = "USP .45 (MW3)",
	["iw5_sa80"] = "L86 LSW",
	["iw5_m60e4"] = "M60E4 (MW3)",
	["iw5_mg36"] = "MG36",
	["iw5_mk46"] = "MK46",
	["iw5_pecheneg"] = "PKP Pecheneg",
	["iw5_skorpion"] = "Skorpion (MW3)",
	["iw5_tmp"] = "MP9",
	["iw5_glock"] = "G18",
	["iw5_fmg"] = "FMG9",
	["iw5_aa12"] = "AA-12 (MW3)",
	["iw5_ksg"] = "KSG 12",
	["iw5_1887"] = "Model 1887 (MW3)",
	["iw5_spas12"] = "SPAS-12 (MW3)",
	["iw5_striker"] = "Striker (MW3)",
	["iw5_usas12"] = "USAS-12",
	["iw5_rsass"] = "RSASS",
	["iw5_msr"] = "MSR",
	["iw5_mk12spr"] = "MK12 SPR",
	["iw5_l96a1"] = "L118A",
	["iw5_dragunov"] = "Dragunov (MW3)",
	["iw5_barrett"] = "Barrett .50cal (MW3)",
	["iw5_as50"] = "AS50",
	["iw5_ak74u"] = "AK-74u (MW3)",
	["iw5_mp5"] = "MP5 (MW3)",
	["iw5_mp7"] = "MP7",
	["iw5_p90"] = "P90 (MW3)",
	["iw5_pm9"] = "PM-9",
	["iw5_ump45"] = "UMP45 (MW3)",
	["iw5_pp90m1"] = "PP90M1",
	["iw5_riotshield"] = "Riot Shield (MW3)",

	-- MW2 Secondaries & Special
	["iw4_glock"]         = "Glock 17",
	["iw4_usp"]           = "USP .45",
	["iw4_raffica"]       = "Beretta 93R",
	["iw4_anaconda"]      = ".44 Magnum",
	["iw4_deserteagle"]   = "Desert Eagle",
	["iw4_beretta"]       = "M9 Beretta",
	["iw4_at4"]           = "AT4",
	["iw4_javelin"]       = "Javelin",
	["iw4_rpg"]           = "RPG-7",
	["iw4_stinger"]       = "Stinger",
	["iw4_m79"]           = "M79 Thumper",
}

-- Helper to get the world model for a weapon class
local function getWeaponModel(class)
	local swep = weapons.Get(class)
	return swep and swep.WorldModel or "models/weapons/w_pist_usp.mdl"
end

local function friendlyName(class)
	return DISPLAY_NAMES[class] or class
end

-- ── State ─────────────────────────────────────────────────────────────────
local pickerFrame = nil
SND.GunPicker.Slots = SND.GunPicker.Slots or {}
local isReady = false

local loadoutNameEntry = nil
local saveNameButton = nil

-- ── Open the picker panel ─────────────────────────────────────────────────
function SND.GunPicker.Open()
	if IsValid(pickerFrame) then pickerFrame:Remove() end -- Close any existing panel

	local groups = SND.GunPicker.PrimaryGroups or {}
	local secondaries = SND.GunPicker.Secondaries or {}

	if #groups == 0 and #secondaries == 0 then
		LocalPlayer():ChatPrint("[SND] No weapon list received yet — try again in a moment.")
		return
	end

	-- ── Frame ─────────────────────────────────────────────────────────────
	local W, H = 800, 600
	local f = vgui.Create("DFrame")
	f:SetTitle("") -- Custom title drawing
	f:SetSize(W, H)
	f:Center()
	f:MakePopup()
	f:SetBackgroundBlur(true)
	f.btnMaxim:SetVisible(false) -- Hide default minimize/maximize buttons
	f.btnMinim:SetVisible(false)
	pickerFrame = f

	f.Paint = function(self, w, h)
		draw.RoundedBox(0, 0, 0, w, h, Color(15, 15, 15, 250)) -- Dark background
		surface.SetDrawColor(255, 120, 0, 255) -- Orange accent line at top
		surface.DrawRect(0, 0, w, 3)
		draw.SimpleText("LOADOUT SELECTION", "SND_BO3_Title", 20, 28, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	-- ── 10 Slots Sidebar ──────────────────────────────────────────────────
	local sidebar = vgui.Create("DPanel", f)
	sidebar:SetWide(180)
	sidebar:Dock(LEFT)
	sidebar:DockMargin(10, 60, 5, 10) -- Adjusted margin for title and bottom buttons
	sidebar.Paint = nil

	local scrollSidebar = vgui.Create("DScrollPanel", sidebar)
	scrollSidebar:Dock(FILL)

	local content = vgui.Create("DScrollPanel", f)
	content:Dock(FILL)
	content:DockMargin(5, 60, 10, 70) -- Bottom margin increased to clear buttons
	content.Paint = nil

	local function rebuildContent()
		content:Clear() -- Clear existing content to rebuild
		
		-- Create Loadout Name Editor
		local nameEditorPanel = vgui.Create("DPanel", content)
		nameEditorPanel:SetTall(60)
		nameEditorPanel:Dock(TOP)
		nameEditorPanel:DockMargin(0, 0, 0, 10)
		nameEditorPanel.Paint = nil

		local nameLabel = vgui.Create("DLabel", nameEditorPanel)
		nameLabel:SetText("LOADOUT NAME:")
		nameLabel:SetFont("SND_BO3_Header")
		nameLabel:SetTextColor(Color(200, 200, 200))
		nameLabel:SetPos(0, 0)
		nameLabel:SetSize(120, 20)

		loadoutNameEntry = vgui.Create("DTextEntry", nameEditorPanel)
		loadoutNameEntry:SetPos(0, 25)
		loadoutNameEntry:SetWide(200)
		loadoutNameEntry:SetTall(25)
		loadoutNameEntry:SetPlaceholderText("Enter loadout name...")
		loadoutNameEntry:SetFont("DermaDefault")

		saveNameButton = vgui.Create("DButton", nameEditorPanel)
		saveNameButton:SetText("SAVE NAME")
		saveNameButton:SetFont("SND_BO3_Header")
		saveNameButton:SetTextColor(Color(255, 255, 255))
		saveNameButton:SetPos(210, 25)
		saveNameButton:SetSize(100, 25)
		saveNameButton.Paint = function(self, w, h)
			draw.RoundedBox(0, 0, 0, w, h, self:IsHovered() and Color(255, 120, 0, 150) or Color(255, 120, 0, 100))
		end
		saveNameButton.DoClick = function()
			local slot = LocalPlayer():GetNWInt("SND_ActiveLoadoutSlot", 1)
			net.Start("SND_SaveLoadoutName")
				net.WriteUInt(slot, 4)
				net.WriteString(loadoutNameEntry:GetText())
			net.SendToServer()
			surface.PlaySound("buttons/button14.wav")
			
			-- Ensure the cache table exists before updating
			SND.GunPicker.Slots[slot] = SND.GunPicker.Slots[slot] or {}
			SND.GunPicker.Slots[slot].loadoutName = loadoutNameEntry:GetText()
			
			rebuildContent() -- Refresh sidebar buttons to show new name
		end

		-- Clear Slot Button
		local clearSlotButton = vgui.Create("DButton", nameEditorPanel)
		clearSlotButton:SetText("CLEAR SLOT")
		clearSlotButton:SetFont("SND_BO3_Header")
		clearSlotButton:SetTextColor(Color(255, 255, 255))
		clearSlotButton:SetPos(320, 25)
		clearSlotButton:SetSize(100, 25)
		clearSlotButton.Paint = function(self, w, h)
			draw.RoundedBox(0, 0, 0, w, h, self:IsHovered() and Color(150, 50, 50, 150) or Color(120, 40, 40, 100))
		end
		clearSlotButton.DoClick = function()
			local slot = LocalPlayer():GetNWInt("SND_ActiveLoadoutSlot", 1)
			net.Start("SND_ClearLoadoutSlot")
				net.WriteUInt(slot, 4)
			net.SendToServer()
			surface.PlaySound("buttons/button19.wav") -- Error/cancel sound
		end

		local activeSlot = LocalPlayer():GetNWInt("SND_ActiveLoadoutSlot", 1)
		local data = SND.GunPicker.Slots[activeSlot] or { primary = "", secondary = "", loadoutName = "LOADOUT " .. activeSlot }
		loadoutNameEntry:SetText(data.loadoutName)

		local function createGrid(title, pool, slotKey, headerFont, headerCol, leftMargin)
			local lbl = vgui.Create("DLabel", content)
			lbl:SetText(title:upper())
			lbl:SetFont(headerFont or "SND_BO3_Header")
			if headerCol then lbl:SetTextColor(headerCol) end
			lbl:Dock(TOP)
			lbl:DockMargin(leftMargin or 0, 10, 0, 5)

			local grid = vgui.Create("DIconLayout", content)
			grid:Dock(TOP)
			grid:SetSpaceX(5)
			grid:SetSpaceY(5)

			for _, class in ipairs(pool) do
				local wrapper = grid:Add("DPanel") -- Add a DPanel wrapper to the layout
				wrapper:SetSize(64, 64) -- Match the size of the SpawnIcon
				wrapper.Paint = function(self, w, h)
					if data[slotKey] == class then
						draw.RoundedBox(0, 0, 0, w, h, Color(255, 120, 0, 150)) -- Draw background on the wrapper
					end
				end

				local icon = vgui.Create("SpawnIcon", wrapper) -- Create SpawnIcon inside the wrapper
				icon:SetModel(getWeaponModel(class))
				icon:SetTooltip(friendlyName(class))
				icon:SetSize(64, 64)
				icon:Dock(FILL) -- Make SpawnIcon fill the wrapper

				-- SpawnIcons handle their own mouse events, so we must use icon.DoClick
				icon.DoClick = function()
					net.Start("SND_GunPickerChoose")
						net.WriteString(slotKey)
						net.WriteString(class)
					net.SendToServer()
					
					SND.GunPicker.Slots[activeSlot] = SND.GunPicker.Slots[activeSlot] or {}
					SND.GunPicker.Slots[activeSlot][slotKey] = class
					surface.PlaySound("buttons/button14.wav")
					rebuildContent()
				end
			end

			-- Force the grid to calculate its height based on children so the ScrollPanel knows how far to scroll
			grid:InvalidateLayout(true)
			grid:SizeToChildren(false, true)
		end

		if #groups > 0 then
			local lastGame = ""
			for _, g in ipairs(groups) do
				local gameName = g.name:match("^(.-):") or "MISCELLANEOUS"
				if gameName ~= lastGame then
					local gameHeader = vgui.Create("DPanel", content)
					gameHeader:SetTall(32)
					gameHeader:Dock(TOP)
					gameHeader:DockMargin(0, 20, 0, 5)
					gameHeader.Paint = function(self, w, h)
						local iconName = gameName:upper()
						local iconPath = "data/snd_mwclassic/game_icons/" .. iconName .. ".png"
						local iconMat = SND.GetIMaterial(iconPath)
						local textX = 0
						
						if iconMat and not iconMat:IsError() then
							local tex = iconMat:GetTexture("$basetexture")
							local ratio = 1
							if tex then
								ratio = tex:Width() / tex:Height()
							end

							local drawW = h * ratio

							surface.SetMaterial(iconMat)
							surface.SetDrawColor(255, 255, 255, 255)
							surface.DrawTexturedRect(0, 0, drawW, h)
							textX = drawW + 15
						end
						
						draw.SimpleText(gameName:upper(), "SND_BO3_Title", textX, h/2, Color(255, 120, 0), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
					end
					lastGame = gameName
				end
				
				local subHeader = g.name:match("^.-:%s*(.*)$") or g.name
				local slotKey = g.isSecondary and "secondary" or "primary"
				createGrid(subHeader, g.weapons, slotKey, "DermaDefaultBold", Color(180, 180, 180), 15)

				-- ── Separator Line ──
				local sep = vgui.Create("DPanel", content)
				sep:SetTall(20)
				sep:Dock(TOP)
				sep:DockMargin(15, 5, 10, 10)
				sep.Paint = function(self, w, h)
					surface.SetDrawColor(255, 255, 255, 15)
					surface.DrawRect(0, h/2, w, 1)
				end
			end
		end
	end

	local playerLevel = LocalPlayer():GetNWInt("SND_Level", 1)

	for i = 1, 10 do
		local req = SND.Config.SlotLevels[i] or 1
		local isLocked = playerLevel < req

		local btn = scrollSidebar:Add("DButton")
		btn:SetText("") -- Text will be drawn in Paint function
		btn:SetTall(40)
		btn:Dock(TOP)
		btn:DockMargin(0, 0, 0, 5)

		btn.Paint = function(self, w, h)
			local active = LocalPlayer():GetNWInt("SND_ActiveLoadoutSlot", 1) == i
			local bg = active and Color(255, 120, 0, 100) or Color(255, 255, 255, 5)
			if isLocked then bg = Color(50, 50, 50, 100) end

			draw.RoundedBox(0, 0, 0, w, h, bg)
			
			local customName = SND.GunPicker.Slots[i].loadoutName or "LOADOUT " .. i
			local mainText = customName
			local subText = isLocked and ("LOCKED (LVL " .. req .. ")") or ""
			
			draw.SimpleText(mainText, "SND_BO3_Header", 10, isLocked and 12 or h/2, isLocked and Color(150, 150, 150) or Color(220, 220, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			if isLocked then
				draw.SimpleText(subText, "DermaDefault", 10, 26, Color(255, 80, 80), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end

			if active then 
				surface.SetDrawColor(255, 120, 0) 
				surface.DrawRect(0, 0, 4, h) 
			end
		end

		btn.DoClick = function()
			if isLocked then
				surface.PlaySound("buttons/button11.wav")
				return 
			end
			net.Start("SND_SelectLoadoutSlot")
				net.WriteUInt(i, 4)
			net.SendToServer()
			surface.PlaySound("buttons/lightbutton.wav")
			timer.Simple(0.1, rebuildContent) -- Rebuild content to update name entry and weapon grids
		end
	end

	rebuildContent() -- Initial build of the content panel

	-- ── Identity Button ───────────────────────────────────────────────────
	local identity = vgui.Create("DButton", f)
	identity:SetSize(180, 40)
	identity:SetPos(W - 400, H - 55)
	identity:SetText("PLAYER IDENTITY")
	identity:SetFont("SND_BO3_Header")
	identity:SetTextColor(Color(255, 255, 255))
	identity.Paint = function(self, w, h)
		draw.RoundedBox(0, 0, 0, w, h, self:IsHovered() and Color(60, 60, 60) or Color(40, 40, 40))
		surface.SetDrawColor(255, 255, 255, 20)
		surface.DrawOutlinedRect(0, 0, w, h)
	end
	identity.DoClick = function()
		SND.OpenPersonalizationMenu()
	end

	-- ── Ready Button ──────────────────────────────────────────────────────
	local ready = vgui.Create("DButton", f)
	ready:SetSize(200, 50)
	ready:SetPos(W - 210, H - 60)
	ready:SetText(isReady and "READY!" or "READY UP")
	ready:SetFont("SND_BO3_Title")
	ready:SetTextColor(Color(255, 255, 255))

	ready.Paint = function(self, w, h)
		local col = isReady and Color(80, 220, 100) or Color(255, 120, 0)
		if self:IsHovered() then col = Color(col.r + 30, col.g + 30, col.b + 30) end
		draw.RoundedBox(0, 0, 0, w, h, col)
	end

	ready.DoClick = function()
		isReady = not isReady
		net.Start("SND_PlayerReady")
			net.WriteBool(isReady)
		net.SendToServer()
		ready:SetText(isReady and "READY!" or "READY UP")
		surface.PlaySound(isReady and "buttons/button3.wav" or "buttons/button19.wav")
		
		-- Close menu if ready during live game, otherwise stay open for waiting
		if isReady and SND.Client.Phase ~= SND.PHASE_WAIT then
			f:Close()
		end
	end
end

net.Receive("SND_GunPickerOpen", function()
	local nGroups = net.ReadUInt(8)
	local groups = {}
	for i = 1, nGroups do
		local name = net.ReadString()
		local isSec = net.ReadBool()
		local count = net.ReadUInt(8)
		local weapons = {}
		for j = 1, count do weapons[j] = net.ReadString() end
		groups[i] = { name = name, isSecondary = isSec, weapons = weapons }
	end

	local nSec = net.ReadUInt(8)
	local secondaries = {}
	for i = 1, nSec do secondaries[i] = net.ReadString() end

	SND.GunPicker.PrimaryGroups = groups
	SND.GunPicker.Secondaries = secondaries
	
	SND.GunPicker.Slots = {}
	for i = 1, 10 do
		SND.GunPicker.Slots[i] = {
			primary = net.ReadString(),
			secondary = net.ReadString(),
			loadoutName = net.ReadString()
		}
	end

	SND.GunPicker.Open()
end)

function SND.GunPicker.Close()
	if IsValid(pickerFrame) then
		pickerFrame:Remove()
		pickerFrame = nil
	end
end

concommand.Add("snd_gunpicker", function()
	SND.GunPicker.Open()
end)
