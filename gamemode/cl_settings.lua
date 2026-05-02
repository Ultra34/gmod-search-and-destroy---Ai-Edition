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

	local sheet = vgui.Create("DPropertySheet", f)
	sheet:Dock(FILL)

	local pnl = vgui.Create("DPanelList")
	pnl:EnableVerticalScrollbar(true)

	local defs = {
		{ key = "snd_walk_speed",       lbl = "Walk speed",           min = 120,  max = 320,  dec = 0 },
		{ key = "snd_run_speed",        lbl = "Run speed",            min = 160,  max = 400,  dec = 0 },
		{ key = "snd_sprint_mult",      lbl = "Sprint multiplier",    min = 1,    max = 2.2,  dec = 2 },
		{ key = "snd_round_time",       lbl = "Round time (sec)",     min = 60,   max = 300,  dec = 0 },
		{ key = "snd_freeze_time",      lbl = "Freeze time (sec)",    min = 0,    max = 20,   dec = 0 },
		{ key = "snd_plant_time",       lbl = "Plant time (sec)",     min = 2,    max = 10,   dec = 1 },
		{ key = "snd_defuse_time",      lbl = "Defuse time (sec)",    min = 3,    max = 12,   dec = 1 },
		{ key = "snd_win_limit",        lbl = "Rounds to win",        min = 1,    max = 16,   dec = 0 },
		{ key = "snd_bot_count",        lbl = "Bots",                 min = 0,    max = 16,   dec = 0 },
		{ key = "snd_bot_skill",        lbl = "Bot skill (1-10)",     min = 1,    max = 10,   dec = 0 },
		{ key = "snd_team_balance",     lbl = "Team balance (0/1)",   min = 0,    max = 1,    dec = 0 },
		{ key = "snd_mapvote_enabled",  lbl = "Map vote (0/1)",       min = 0,    max = 1,    dec = 0 },
		{ key = "snd_announcer_volume", lbl = "Announcer volume",     min = 0,    max = 1,    dec = 2 },
		{ key = "snd_hud_scale",        lbl = "HUD scale",            min = 0.75, max = 1.5,  dec = 2 },
	}

	for _, row in ipairs(defs) do
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

	sheet:AddSheet("Gameplay", pnl, "icon16/wrench.png")
end
