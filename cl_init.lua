include("shared.lua")
include("snd_settings.lua")
include("cl_hud.lua")
include("cl_settings.lua")

SND = SND or {}
SND.Client = SND.Client or {}
SND.Client.Phase = SND.PHASE_WAIT
SND.Client.AttackScore = 0
SND.Client.DefendScore = 0

net.Receive("SND_RoundState", function()
	SND.Client.Phase = net.ReadUInt(3)
	net.ReadUInt(4)
	SND.Client.AttackScore = net.ReadUInt(8)
	SND.Client.DefendScore = net.ReadUInt(8)
end)

net.Receive("SND_Bomb", function()
	local t = net.ReadUInt(3)
	if t == 1 then
		SND.Client.BombCarrier = net.ReadEntity()
	elseif t == 2 then
		SND.Client.PlantPos = net.ReadVector()
		SND.Client.PlantId = net.ReadString()
	end
end)

net.Receive("SND_MapVote", function()
	local n = net.ReadUInt(8)
	local maps = {}
	for i = 1, n do
		maps[i] = net.ReadString()
	end
	chat.AddText(Color(120, 200, 255), "[SND] Map vote — candidates: ", Color(255, 255, 255), table.concat(maps, ", "))
end)

hook.Add("PopulateToolMenu", "SND_SettingsMenu", function()
	spawnmenu.AddToolMenuOption("Utilities", "SND", "SND_Settings", "S&D Settings", "", "", function(panel)
		panel:ClearControls()
		panel:Help("SuperAdmin / listen-server host: tune gameplay ConVars (snd_*) in console or open frame.")
		panel:Button("Open settings", "snd_open_settings")
	end)
end)

concommand.Add("snd_open_settings", function()
	SND.OpenSettingsMenu()
end)
