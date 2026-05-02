--[[ Gun Picker — shown during freeze time so players can choose their loadout ]]
-- NEW FILE: gamemode/cl_gunpicker.lua
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

local function friendlyName(class)
	return DISPLAY_NAMES[class] or class
end

-- ── State ─────────────────────────────────────────────────────────────────
local pickerFrame = nil

-- ── Open the picker panel ─────────────────────────────────────────────────
function SND.GunPicker.Open()
	-- Close any existing panel first
	if IsValid(pickerFrame) then pickerFrame:Remove() end

	local primaries   = SND.GunPicker.Primaries   or {}
	local secondaries = SND.GunPicker.Secondaries  or {}

	if #primaries == 0 and #secondaries == 0 then
		LocalPlayer():ChatPrint("[SND] No weapon list received yet — try again in a moment.")
		return
	end

	-- ── Frame ─────────────────────────────────────────────────────────────
	local W, H = 560, 520
	local f = vgui.Create("DFrame")
	f:SetTitle("Choose Your Loadout")
	f:SetSize(W, H)
	f:Center()
	f:SetDraggable(true)
	f:SetDeleteOnClose(false)  -- keep until round ends or player chooses
	f:MakePopup()
	pickerFrame = f

	-- Tinted dark background
	f.Paint = function(self, w, h)
		draw.RoundedBox(6, 0, 0, w, h, Color(20, 22, 28, 230))
		draw.RoundedBox(6, 0, 0, w, 28, Color(40, 44, 55, 255))
		draw.SimpleText("Choose Your Loadout", "DermaDefaultBold", w/2, 14, Color(220,220,220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	local sheet = vgui.Create("DPropertySheet", f)
	sheet:Dock(FILL)
	sheet:DockMargin(4, 4, 4, 4)

	-- ── Helper: build a weapon list tab ───────────────────────────────────
	local function makeTab(label, pool, slotKey)
		local scroll = vgui.Create("DScrollPanel")

		local list = vgui.Create("DPanelList", scroll)
		list:Dock(FILL)
		list:EnableVerticalScrollbar(false)

		local selectedPanel = nil  -- track which button is highlighted

		for _, class in ipairs(pool) do
			local row = vgui.Create("DButton", list)
			row:SetTall(38)
			row:SetText("")
			list:AddItem(row)

			-- Store class on the panel for later reference
			row.weaponClass = class

			-- Highlight if already chosen
			local alreadyChosen = (SND.GunPicker.Chosen and SND.GunPicker.Chosen[slotKey] == class)
			row.selected = alreadyChosen
			if alreadyChosen then selectedPanel = row end

			row.Paint = function(self, w, h)
				local bg = self.selected and Color(60, 120, 60, 200)
				            or (self:IsHovered() and Color(55, 60, 75, 200)
				            or Color(35, 38, 48, 200))
				draw.RoundedBox(4, 2, 2, w-4, h-4, bg)
				draw.SimpleText(friendlyName(class), "Trebuchet18", 12, h/2,
				    Color(220,220,220), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				if self.selected then
					draw.SimpleText("✔ Selected", "Trebuchet18", w - 12, h/2,
					    Color(120,220,120), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
				end
			end

			row.DoClick = function(self)
				-- Deselect previous
				if IsValid(selectedPanel) then
					selectedPanel.selected = false
				end
				self.selected = true
				selectedPanel = self

				-- Store choice locally
				SND.GunPicker.Chosen = SND.GunPicker.Chosen or {}
				SND.GunPicker.Chosen[slotKey] = class

				-- Send to server
				net.Start("SND_GunPickerChoose")
					net.WriteString(slotKey)    -- "primary" or "secondary"
					net.WriteString(class)
				net.SendToServer()

				LocalPlayer():ChatPrint("[SND] " .. label .. " set to: " .. friendlyName(class))
			end
		end

		scroll:SetPanelVisible(list, true)
		sheet:AddSheet(label, scroll, "icon16/gun.png")
	end

	makeTab("Primary",   primaries,   "primary")
	makeTab("Secondary", secondaries, "secondary")

	-- ── Close / Done button ───────────────────────────────────────────────
	local done = vgui.Create("DButton", f)
	done:SetText("Done")
	done:SetSize(100, 28)
	done:Dock(BOTTOM)
	done:DockMargin(4, 2, 4, 4)
	done.DoClick = function()
		f:Close()
	end
end

function SND.GunPicker.Close()
	if IsValid(pickerFrame) then
		pickerFrame:Remove()
		pickerFrame = nil
	end
end

-- ── Network: server sends weapon list when round freeze starts ────────────
net.Receive("SND_GunPickerOpen", function()
	local nPri = net.ReadUInt(8)
	local primaries = {}
	for i = 1, nPri do primaries[i] = net.ReadString() end

	local nSec = net.ReadUInt(8)
	local secondaries = {}
	for i = 1, nSec do secondaries[i] = net.ReadString() end

	SND.GunPicker.Primaries   = primaries
	SND.GunPicker.Secondaries = secondaries
	SND.GunPicker.Chosen      = nil  -- reset choices for new round

	SND.GunPicker.Open()
end)

-- Close panel when round goes live (freeze ends)
net.Receive("SND_RoundState", function()
	local phase = net.ReadUInt(3)
	net.ReadUInt(4)   -- winner (unused here)
	SND.Client        = SND.Client or {}
	SND.Client.AttackScore = net.ReadUInt(8)
	SND.Client.DefendScore = net.ReadUInt(8)
	SND.Client.Phase  = phase

	if phase == SND.PHASE_LIVE then
		SND.GunPicker.Close()
	end
end)

-- ── Rebind: open picker manually ─────────────────────────────────────────
concommand.Add("snd_gunpicker", function()
	SND.GunPicker.Open()
end)
