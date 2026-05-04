--[[ In-game Derma settings panel (SuperAdmin)
     REPLACES: gamemode/cl_settings.lua ]]

function SND.OpenSettingsMenu()
	if not IsValid(LocalPlayer()) then return end
	if not LocalPlayer():IsSuperAdmin() then
		LocalPlayer():ChatPrint("[SND] SuperAdmin only.")
		return
	end

	local f = vgui.Create("DFrame")
	f:SetTitle("Search & Destroy — Settings")
	f:SetSize(440, 540)
	f:Center()
	f:MakePopup()

	-- High-tech background
	f.Paint = function(self, w, h)
		draw.RoundedBox(0, 0, 0, w, h, Color(20, 20, 20, 250))
		surface.SetDrawColor(255, 120, 0, 255)
		surface.DrawRect(0, 0, w, 2)
	end

	local sheet = vgui.Create("DPropertySheet", f)
	sheet:Dock(FILL)
	sheet:DockMargin(5, 5, 5, 5)

	local categories = {
		["Match Rules"] = {
			{ key = "snd_round_time",       lbl = "Round duration (sec)", min = 60,   max = 300,  dec = 0 },
			{ key = "snd_freeze_time",      lbl = "Freeze duration (sec)",min = 0,    max = 20,   dec = 0 },
			{ key = "snd_win_limit",        lbl = "Rounds to win match",  min = 1,    max = 16,   dec = 0 },
			{ key = "snd_mapvote_enabled",  lbl = "Enable Map Vote",      min = 0,    max = 1,    dec = 0 },
			{ key = "snd_team_balance",     lbl = "Auto Team Balance",    min = 0,    max = 1,    dec = 0 },
		},
		["Combat & Movement"] = {
			{ key = "snd_walk_speed",       lbl = "Walk Speed",           min = 120,  max = 320,  dec = 0 },
			{ key = "snd_run_speed",        lbl = "Base Run Speed",       min = 160,  max = 400,  dec = 0 },
			{ key = "snd_sprint_mult",      lbl = "Sprint Multiplier",    min = 1,    max = 2.2,  dec = 2 },
			{ key = "snd_plant_time",       lbl = "Bomb Plant Time",      min = 2,    max = 10,   dec = 1 },
			{ key = "snd_defuse_time",      lbl = "Bomb Defuse Time",     min = 3,    max = 12,   dec = 1 },
		},
		["Bots & AI"] = {
			{ key = "snd_bot_count",        lbl = "Target Bot Count",     min = 0,    max = 24,   dec = 0 },
			{ key = "snd_bot_skill",        lbl = "Global Bot Skill",     min = 1,    max = 10,   dec = 0 },
		},
		["Interface"] = {
			{ key = "snd_announcer_volume", lbl = "Announcer Volume",     min = 0,    max = 1,    dec = 2 },
			{ key = "snd_hud_scale",        lbl = "HUD Global Scale",     min = 0.75, max = 1.5,  dec = 2 },
		}
	}

	-- ── Calling Card Customization ──────────────────────────────────────
	local cardPnl = vgui.Create("DPanelList")
	cardPnl:SetPadding(15)
	cardPnl:SetSpacing(10)

	local lbl = vgui.Create("DLabel")
	lbl:SetText("Personalize your Calling Card shown to enemies on kill.")
	lbl:SetDark(true)
	cardPnl:AddItem(lbl)

	local titleEntry = vgui.Create("DTextEntry")
	titleEntry:SetPlaceholderText("Custom Title (e.g., Tactical Expert)")
	titleEntry:SetText(LocalPlayer():GetNWString("SND_CardTitle", "New Recruit"))
	cardPnl:AddItem(titleEntry)

	local pathEntry = vgui.Create("DTextEntry")
	pathEntry:SetPlaceholderText("Material Path (e.g., vgui/gradient-d)")
	pathEntry:SetText(LocalPlayer():GetNWString("SND_CardMat", "vgui/white"))
	cardPnl:AddItem(pathEntry)

	local saveBtn = vgui.Create("DButton")
	saveBtn:SetText("Save Calling Card")
	saveBtn:SetTall(30)
	saveBtn.DoClick = function()
		local path = pathEntry:GetText()
		local mat = Material(path)
		
		-- Size Validation Logic
		if not mat:IsError() then
			local w, h = mat:Width(), mat:Height()
			if w != 480 or h != 120 then
				chat.AddText(Color(255, 50, 50), "[SND] WARNING: ", Color(255, 255, 255), "Banner must be exactly 480x120 pixels! Yours is " .. w .. "x" .. h)
			end
		end

		net.Start("SND_SetCallingCard")
			net.WriteString(titleEntry:GetText())
			net.WriteString(path)
		net.SendToServer()
		surface.PlaySound("buttons/button14.wav")
	end
	cardPnl:AddItem(saveBtn)

	local previewLabel = vgui.Create("DLabel")
	previewLabel:SetText("\nPreview:")
	cardPnl:AddItem(previewLabel)

	local preview = vgui.Create("DPanel")
	preview:SetTall(100) -- Enforce 4:1 Ratio in preview
	preview.Paint = function(self, w, h)
		local cardH = w / 4
		self:SetTall(cardH)
		surface.SetDrawColor(255, 255, 255)
		surface.SetMaterial(Material(pathEntry:GetText()))
		surface.DrawTexturedRect(0, 0, w, cardH)
	end
	cardPnl:AddItem(preview)

	sheet:AddSheet("Calling Card", cardPnl, "icon16/vcard.png")

	-- ── Emblem Customization ────────────────────────────────────────────
	local emblemPnl = vgui.Create("DPanelList")
	emblemPnl:SetPadding(15)
	emblemPnl:SetSpacing(10)

	local lbl = vgui.Create("DLabel")
	lbl:SetText("Personalize your Emblem shown on kill popups.")
	lbl:SetDark(true)
	emblemPnl:AddItem(lbl)

	local pathEntry = vgui.Create("DTextEntry")
	pathEntry:SetPlaceholderText("Material Path (e.g., vgui/icon_skull)")
	pathEntry:SetText(LocalPlayer():GetNWString("SND_EmblemMat", "vgui/white"))
	emblemPnl:AddItem(pathEntry)

	local steamBtn = vgui.Create("DButton")
	steamBtn:SetText("Use Steam Profile Avatar")
	steamBtn:SetTall(25)
	steamBtn.DoClick = function()
		pathEntry:SetText("steam")
		net.Start("SND_SetEmblem")
			net.WriteString("steam")
		net.SendToServer()
	end
	emblemPnl:AddItem(steamBtn)

	local saveBtn = vgui.Create("DButton")
	saveBtn:SetText("Save Emblem")
	saveBtn:SetTall(30)
	saveBtn.DoClick = function()
		local path = pathEntry:GetText()
		local mat = Material(path)

		-- Size Validation Logic
		if path != "steam" and not mat:IsError() then
			local w, h = mat:Width(), mat:Height()
			if w != 128 or h != 128 then
				chat.AddText(Color(255, 50, 50), "[SND] WARNING: ", Color(255, 255, 255), "Emblem must be exactly 128x128 pixels! Yours is " .. w .. "x" .. h)
			end
		end

		net.Start("SND_SetEmblem")
			net.WriteString(path)
		net.SendToServer()
		surface.PlaySound("buttons/button14.wav")
	end
	emblemPnl:AddItem(saveBtn)

	local previewLabel = vgui.Create("DLabel")
	previewLabel:SetText("\nPreview:")
	emblemPnl:AddItem(previewLabel)

	local preview = vgui.Create("DPanel")
	preview:SetSize(128, 128) -- Enforce 1:1 square
	local previewAvatar = vgui.Create("AvatarImage", preview)
	previewAvatar:Dock(FILL)
	previewAvatar:SetVisible(false)

	preview.Paint = function(self, w, h)
		local path = pathEntry:GetText()
		if path == "steam" then
			previewAvatar:SetVisible(true)
			previewAvatar:SetPlayer(LocalPlayer(), 128)
			return
		end
		
		previewAvatar:SetVisible(false)
		surface.SetDrawColor(255, 255, 255)
		local mat = Material(path)
		if mat:IsError() then mat = Material("vgui/white") surface.SetDrawColor(40, 40, 40) end
		surface.SetMaterial(mat)
		surface.DrawTexturedRect(0, 0, w, h)
	end
	emblemPnl:AddItem(preview)

	sheet:AddSheet("Emblem", emblemPnl, "icon16/medal_gold_1.png")

	for catName, settings in pairs(categories) do
		local pnl = vgui.Create("DPanelList")
		pnl:EnableVerticalScrollbar(true)
		pnl:SetSpacing(5)
		pnl:SetPadding(10)

		for _, row in ipairs(settings) do
			local cv  = GetConVar(row.key)
			local cur = cv and cv:GetFloat() or row.min
			local sl  = vgui.Create("DNumSlider")
			sl:SetText(row.lbl)
			sl:SetMinMax(row.min, row.max)
			sl:SetDecimals(row.dec or 0)
			sl:SetValue(cur)
			sl.OnValueChanged = function(_, val)
				net.Start("SND_SetCvar")
					net.WriteString(row.key)
					net.WriteString(tostring(val))
				net.SendToServer()
			end
			pnl:AddItem(sl)
		end
		sheet:AddSheet(catName, pnl)
	end
end
