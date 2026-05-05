--[[ In-game Derma settings panel (SuperAdmin)
     REPLACES: gamemode/cl_settings.lua ]]

function SND.OpenSettingsMenu()
	local lp = LocalPlayer()
	if not IsValid(lp) or not lp:IsSuperAdmin() then return end

	local f = vgui.Create("DFrame")
	f:SetTitle("")
	f:SetSize(440, 540)
	f:Center()
	f:MakePopup()
	f.btnMaxim:SetVisible(false)
	f.btnMinim:SetVisible(false)

	f.Paint = function(self, w, h)
		draw.RoundedBox(0, 0, 0, w, h, Color(15, 15, 15, 245))
		surface.SetDrawColor(255, 120, 0, 255)
		surface.DrawRect(0, 0, w, 3)
		draw.SimpleText("MATCH CONFIG", "SND_BO3_Title", 15, 20, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	local sheet = vgui.Create("DPropertySheet", f)
	sheet:Dock(FILL)
	sheet:DockMargin(5, 30, 5, 5)

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

function SND.OpenPersonalizationMenu()
	local lp = LocalPlayer()
	if not IsValid(lp) then return end

	local f = vgui.Create("DFrame")
	f:SetTitle("")
	f:SetSize(500, 640)
	f:Center()
	f:MakePopup()
	f.btnMaxim:SetVisible(false)
	f.btnMinim:SetVisible(false)

	f.Paint = function(self, w, h)
		draw.RoundedBox(0, 0, 0, w, h, Color(15, 15, 15, 245))
		surface.SetDrawColor(255, 120, 0, 255)
		surface.DrawRect(0, 0, w, 3)
		draw.SimpleText("PLAYER IDENTITY", "SND_BO3_Title", 15, 20, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	local sheet = vgui.Create("DPropertySheet", f)
	sheet:Dock(FILL)
	sheet:DockMargin(10, 30, 10, 10)

	local titleEntry, pathEntry, embPathEntry, showTitleCheck, useTitleMatCheck, titleMatEntry

	local function drawFullPreview(pnl, w, h, av)
		local cardH = w / 4
		pnl:SetTall(cardH)
		local sc_local = w / 480
		local embSize = 64 * sc_local
		local embX_off = 15 * sc_local

		-- Transparent hint-of-grey background
		surface.SetDrawColor(30, 30, 30, 180)
		surface.DrawRect(0, 0, w, cardH)

		-- 1. Combined Strip Preview
		if showTitleCheck and showTitleCheck:GetChecked() and useTitleMatCheck and useTitleMatCheck:GetChecked() then
			local tPath = titleMatEntry and titleMatEntry:GetText() or lp:GetNWString("SND_TitleMat", "vgui/white")
			local tMat = SND.GetIMaterial(tPath)
			if tMat and not (tMat:IsError() and not tPath:match("[.gif|data/]")) then
				local tW, tH = 512 * sc_local, 64 * sc_local
				local frames = tMat:GetInt("$numframes") or 1
				if frames > 1 then tMat:SetInt("$frame", math.floor(CurTime() * 12) % frames) end
				surface.SetMaterial(tMat)
				surface.SetDrawColor(255, 255, 255)
				surface.DrawTexturedRect(0, 0, w, tH) -- Match HUD Top-Align
			end
		end

		-- 2. Emblem
		local ePath = embPathEntry and embPathEntry:GetText() or lp:GetNWString("SND_EmblemMat", "steam")
		local embX, embY = embX_off, (cardH - embSize) * 0.5
		if ePath == "steam" then
			if IsValid(av) then
				av:SetVisible(true)
				av:SetPos(embX, embY)
				av:SetSize(embSize, embSize)
				av:SetPlayer(lp, 64)
			end
		else
			if IsValid(av) then av:SetVisible(false) end
			local eMat = SND.GetIMaterial(ePath)
			if eMat and not (eMat:IsError() and not ePath:find(".gif")) then
				local frames = eMat:GetInt("$numframes") or 1
				if frames > 1 then eMat:SetInt("$frame", math.floor(CurTime() * 12) % frames) end
				surface.SetMaterial(eMat)
				surface.DrawTexturedRect(embX, embY, embSize, embSize)
			end
		end

		-- 3. Text Overlay
		local textX = 120 * sc_local -- Start text to the right of the emblem
		
		if showTitleCheck and showTitleCheck:GetChecked() and not (useTitleMatCheck and useTitleMatCheck:GetChecked()) then
			local tTxt = titleEntry and titleEntry:GetText() or lp:GetNWString("SND_CardTitle", "New Recruit")
			draw.SimpleText(tTxt:upper(), "SND_BO3_Team", textX + 1, 36 * sc_local, Color(0, 0, 0), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) -- Top half
			draw.SimpleText(tTxt:upper(), "SND_BO3_Team", textX, 35 * sc_local, Color(255, 210, 50), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) -- Top half
		end

		local tCol = team.GetColor(lp:Team())
		draw.SimpleText(lp:Nick():upper(), "SND_BO3_Player", textX + 1, 93 * sc_local, Color(0, 0, 0), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) -- Bottom half
		draw.SimpleText(lp:Nick():upper(), "SND_BO3_Player", textX, 92 * sc_local, Color(tCol.r, tCol.g, tCol.b), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) -- Bottom half

		-- 4. Rank
		local lvl = lp:GetNWInt("SND_Level", 1)
		local icon = (SND.Levels and SND.Levels.GetIcon) and SND.Levels.GetIcon(lvl)
		if icon then
			surface.SetMaterial(icon)
			surface.SetDrawColor(255, 255, 255)
			surface.DrawTexturedRect(w - 55 * sc_local, cardH * 0.5 - 20 * sc_local, 40 * sc_local, 40 * sc_local) -- MW2 Rank Icon size and position
		end

		surface.SetDrawColor(255, 120, 0, 100)
		surface.DrawOutlinedRect(0, 0, w, cardH, 2)
	end

	-- ── Calling Card Tab ────────────────────────────────────────────────
	local cardPnl = vgui.Create("DPanelList")
	cardPnl:SetPadding(15)
	cardPnl:SetSpacing(15)

	titleEntry = vgui.Create("DTextEntry")
	titleEntry:SetText(lp:GetNWString("SND_CardTitle", "New Recruit"))
	cardPnl:AddItem(titleEntry)

	local titleMatList = vgui.Create("DComboBox")
	titleMatList:SetValue("Select Banner Graphic (512x64)...")
	cardPnl:AddItem(titleMatList)
	for _, filename in ipairs(file.Find("snd_mwclassic/banners/*", "DATA")) do
		titleMatList:AddChoice(filename, "data/snd_mwclassic/banners/" .. filename)
	end

	titleMatEntry = vgui.Create("DTextEntry")
	titleMatEntry:SetText(lp:GetNWString("SND_TitleMat", "vgui/white"))
	cardPnl:AddItem(titleMatEntry)

	useTitleMatCheck = vgui.Create("DCheckBoxLabel")
	useTitleMatCheck:SetText("Use Image as Title")
	useTitleMatCheck:SetChecked(lp:GetNWBool("SND_UseTitleMat", false))
	cardPnl:AddItem(useTitleMatCheck)

	showTitleCheck = vgui.Create("DCheckBoxLabel")
	showTitleCheck:SetText("Overlay Title Text")
	showTitleCheck:SetChecked(lp:GetNWBool("SND_ShowTitle", true))
	cardPnl:AddItem(showTitleCheck)

	titleMatList.OnSelect = function(_, _, _, data) titleMatEntry:SetText(data) end

	local saveBtn = vgui.Create("DButton")
	saveBtn:SetText("SAVE IDENTITY")
	saveBtn:SetTall(40)
	saveBtn.DoClick = function()
		net.Start("SND_SetShowTitle") net.WriteBool(showTitleCheck:GetChecked()) net.SendToServer()
		net.Start("SND_SetUseTitleMat") net.WriteBool(useTitleMatCheck:GetChecked()) net.SendToServer()
		net.Start("SND_SetTitleMat") net.WriteString(titleMatEntry:GetText()) net.SendToServer()
		net.Start("SND_SetCallingCard")
			net.WriteString(titleEntry:GetText())
			net.WriteString("") -- Background banner now forced to transparent
		net.SendToServer()
		surface.PlaySound("buttons/button14.wav")
	end
	cardPnl:AddItem(saveBtn)

	local preview = vgui.Create("DPanel")
	preview:SetTall(100)
	local previewAv = vgui.Create("AvatarImage", preview)
	previewAv:SetVisible(false)
	preview.Paint = function(self, w, h) drawFullPreview(self, w, h, previewAv) end
	cardPnl:AddItem(preview)

	sheet:AddSheet("Calling Card", cardPnl, "icon16/vcard.png")

	-- ── Emblem Tab ──────────────────────────────────────────────────────
	local emblemPnl = vgui.Create("DPanelList")
	emblemPnl:SetPadding(15)
	emblemPnl:SetSpacing(15)

	local emblemList = vgui.Create("DComboBox")
	emblemList:SetValue("Select Emblem Image...")
	emblemPnl:AddItem(emblemList)
	for _, filename in ipairs(file.Find("snd_mwclassic/emblems/*", "DATA")) do
		emblemList:AddChoice(filename, "data/snd_mwclassic/emblems/" .. filename)
	end

	embPathEntry = vgui.Create("DTextEntry")
	embPathEntry:SetText(lp:GetNWString("SND_EmblemMat", "steam"))
	emblemPnl:AddItem(embPathEntry)
	emblemList.OnSelect = function(_, _, _, data) embPathEntry:SetText(data) end

	local steamBtn = vgui.Create("DButton")
	steamBtn:SetText("USE STEAM AVATAR")
	steamBtn.DoClick = function() embPathEntry:SetText("steam") end
	emblemPnl:AddItem(steamBtn)

	local saveEmbBtn = vgui.Create("DButton")
	saveEmbBtn:SetText("SAVE EMBLEM")
	saveEmbBtn:SetTall(40)
	saveEmbBtn.DoClick = function()
		local path = embPathEntry:GetText()
		local mat = Material(path)
		if path ~= "steam" and not mat:IsError() then
			local w, h = mat:Width(), mat:Height()
			if w ~= 64 or h ~= 64 then
				chat.AddText(Color(255, 50, 50), "[SND] NOTE: ", Color(255, 255, 255), "Ideal emblem size is 64x64. Yours is " .. w .. "x" .. h)
			end
		end
		net.Start("SND_SetEmblem")
			net.WriteString(path)
		net.SendToServer()
		surface.PlaySound("buttons/button14.wav")
	end
	emblemPnl:AddItem(saveEmbBtn)

	local embPreview = vgui.Create("DPanel")
	embPreview:SetTall(100)
	local av = vgui.Create("AvatarImage", embPreview)
	av:SetVisible(false)
	embPreview.Paint = function(self, w, h) drawFullPreview(self, w, h, av) end
	emblemPnl:AddItem(embPreview)

	sheet:AddSheet("Emblem", emblemPnl, "icon16/medal_gold_1.png")
end
