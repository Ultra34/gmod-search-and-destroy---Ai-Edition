SND.Levels = SND.Levels or {}
local iconCache = {}

function SND.Levels.GetIcon(lvl)
	if iconCache[lvl] then return iconCache[lvl] end
	
	local path = "data/snd_mwclassic/levels/" .. lvl .. ".png"
	if file.Exists("snd_mwclassic/levels/" .. lvl .. ".png", "DATA") then
		iconCache[lvl] = Material(path, "noclamp smooth")
		return iconCache[lvl]
	end
	
	return nil
end

net.Receive("SND_UpdateXP", function()
	local xp = net.ReadUInt(32)
	local lvl = net.ReadUInt(16)
	local gained = net.ReadUInt(16)
	
	LocalPlayer().SND_XP = xp
	LocalPlayer().SND_Level = lvl
	
	if gained > 0 then
		SND.Client.XPPopups = SND.Client.XPPopups or {}
		table.insert(SND.Client.XPPopups, { amount = gained, time = CurTime() })
	end
end)