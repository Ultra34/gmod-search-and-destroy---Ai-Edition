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
