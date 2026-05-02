--[[ Map voting — stores candidate maps in data/snd_mwclassic/maps.txt (one map name per line) ]]

SND.MapVote = SND.MapVote or {}

local function readMapList()
	local path = "snd_mwclassic/maps.txt"
	if not file.Exists(path, "DATA") then return {} end
	local txt = file.Read(path, "DATA") or ""
	local out = {}
	for line in string.gmatch(txt, "[^\r\n]+") do
		line = string.match(line, "^%s*(.-)%s*$") or line
		if line ~= "" and not line:StartWith("#") then
			out[#out + 1] = line
		end
	end
	return out
end

function SND.MapVote.Start()
	if not SND.Settings.GetInt("mapvote_enabled", 1) then return end
	local maps = readMapList()
	if #maps == 0 then
		print("[SND] No maps in data/snd_mwclassic/maps.txt — add one map name per line.")
		return
	end

	net.Start("SND_MapVote")
	net.WriteUInt(#maps, 8)
	for _, m in ipairs(maps) do
		net.WriteString(m)
	end
	net.Broadcast()

	local t = SND.Settings.GetInt("mapvote_time", 20)
	timer.Simple(t, function()
		-- Server picks random if no votes implemented — extend with net votes as needed
		local pick = table.Random(maps)
		if pick and pick ~= game.GetMap() then
			RunConsoleCommand("changelevel", pick)
		end
	end)
end

function SND.MapVote.StartMatchEnd()
	if SND.Settings.GetInt("mapvote_enabled", 1) then
		SND.MapVote.Start()
	else
		timer.Simple(2, function()
			RunConsoleCommand("changelevel", game.GetMap())
		end)
	end
end

util.AddNetworkString("SND_MapVote")
