--[[ Gun Picker — shown during freeze time so players can choose their loadout ]]
--[[ Loadout Manager — 10-slot persistent system with Ready Up logic ]]
-- Add to init.lua:   AddCSLuaFile("cl_gunpicker.lua")
-- Add to cl_init.lua: include("cl_gunpicker.lua")

SND = SND or {}
SND.GunPicker = SND.GunPicker or {}

-- ── Friendly display names ────────────────────────────────────────────────
-- If a weapon class has no entry here the raw class name is shown instead.
local DISPLAY_NAMES = {
	-- ARC9 MW2 primaries
	["arc9_mw2e_acr"]         = "ACR 6.8",
	["arc9_mw2e_ak47"]        = "AK-47",
	["arc9_mw2e_f2000"]       = "F2000",
	["arc9_mw2e_fnfal"]       = "FN FAL",
	["arc9_mw2e_famas"]       = "FAMAS",
	["arc9_mw2e_m16a4"]       = "M16A4",
	["arc9_mw2e_m4a1"]        = "M4A1",
	["arc9_mw2e_scarh"]       = "SCAR-H",
	["arc9_mw2e_tavor"]       = "TAVOR",
	["arc9_mw2e_aug"]         = "AUG",
	["arc9_mw2e_m240"]        = "M240",
	["arc9_mw2e_mg4"]         = "MG4",
	["arc9_mw2e_m1014"]       = "M1014",
	["arc9_mw3e_m1887"]       = "Model 1887",
	["arc9_mw2e_akimbo_1887"] = "Akimbo 1887",
	["arc9_mw2e_ranger"]      = "W1200 Ranger",
	["arc9_mw2e_spas12"]      = "SPAS-12",
	["arc9_mw2e_cheytac"]     = "CheyTac M200",
	["arc9_mw2e_mp5k"]        = "MP5K",
	["arc9_mw2e_pp2000"]      = "PP-2000",
	["arc9_mw2e_vector"]      = "KRISS Vector",
	-- ARC9 MW2 secondaries
	["arc9_mw2e_g17"]         = "Glock 17",
	["arc9_mw2e_mk23"]        = "MK23 SOCOM",
	["arc9_mw2e_m93r"]        = "Beretta 93R",
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

	local primaries = SND.GunPicker.Primaries or {}
	local secondaries = SND.GunPicker.Secondaries or {}

	if #primaries == 0 and #secondaries == 0 then
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

	local content = vgui.Create("DPanel", f)
	content:Dock(FILL)
	content:DockMargin(5, 60, 10, 10) -- Adjusted margin for title and bottom buttons
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

		local activeSlot = LocalPlayer():GetNWInt("SND_ActiveLoadoutSlot", 1)
		local data = SND.GunPicker.Slots[activeSlot] or { primary = "", secondary = "", loadoutName = "LOADOUT " .. activeSlot }
		loadoutNameEntry:SetText(data.loadoutName)

		local function createGrid(title, pool, slotKey)
			local lbl = vgui.Create("DLabel", content)
			lbl:SetText(title:upper())
			lbl:SetFont("SND_BO3_Header")
			lbl:Dock(TOP)
			lbl:DockMargin(0, 10, 0, 5)

			local grid = vgui.Create("DIconLayout", content)
			grid:Dock(TOP)
			grid:SetSpaceX(5)
			grid:SetSpaceY(5)
			grid:SetTall(200)

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
		end

		createGrid("Primary Weapons", primaries, "primary")
		createGrid("Secondary Weapons", secondaries, "secondary")
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
	local nPri = net.ReadUInt(8)
	local primaries = {}
	for i = 1, nPri do primaries[i] = net.ReadString() end

	local nSec = net.ReadUInt(8)
	local secondaries = {}
	for i = 1, nSec do secondaries[i] = net.ReadString() end

	SND.GunPicker.Primaries = primaries
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
