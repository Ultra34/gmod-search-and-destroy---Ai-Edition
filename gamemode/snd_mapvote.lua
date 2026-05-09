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

SND.MapVote.Active = false
SND.MapVote.Votes = {}
SND.MapVote.CandidateList = {}

function SND.MapVote.Start()
	if not SND.Settings.GetInt("mapvote_enabled", 1) then return end
	local maps = readMapList()
	if #maps == 0 then
		print("[SND] No maps in data/snd_mwclassic/maps.txt — restarting current map in 5s.")
		timer.Simple(5, function()
			RunConsoleCommand("changelevel", game.GetMap())
		end)
		return
	end

	SND.MapVote.Active = true
	SND.MapVote.Votes = {}
	SND.MapVote.CandidateList = maps
	for _, m in ipairs(maps) do SND.MapVote.Votes[m] = 0 end

	local t = SND.Settings.GetInt("mapvote_time", 20)

	net.Start("SND_MapVote")
	net.WriteUInt(#maps, 8)
	for _, m in ipairs(maps) do
		net.WriteString(m)
	end
	net.WriteUInt(t, 8)
	net.Broadcast()

	timer.Simple(t, function()
		SND.MapVote.Active = false
		
		local winner = maps[1]
		local maxVotes = -1

		for _, m in ipairs(maps) do
			local vCount = SND.MapVote.Votes[m] or 0
			if vCount > maxVotes then
				maxVotes = vCount
				winner = m
			end
		end

		-- If no votes at all, pick truly random
		if maxVotes <= 0 then
			winner = table.Random(maps)
		end

		local pick = winner
		if pick then
			RunConsoleCommand("changelevel", pick)
		end
	end)
end

local function syncVotes()
	net.Start("SND_MapVoteSync")
		net.WriteUInt(#SND.MapVote.CandidateList, 8)
		for _, m in ipairs(SND.MapVote.CandidateList) do
			net.WriteString(m)
			net.WriteUInt(SND.MapVote.Votes[m] or 0, 8)
		end
	net.Broadcast()
end

net.Receive("SND_SubmitMapVote", function(_, ply)
	if not SND.MapVote.Active then return end
	local map = net.ReadString()

	-- Check if map is valid
	local valid = false
	for _, m in ipairs(SND.MapVote.CandidateList) do
		if m == map then valid = true break end
	end
	if not valid then return end

	-- Clear old vote if exists
	if ply.SND_LastMapVote then
		SND.MapVote.Votes[ply.SND_LastMapVote] = math.max(0, (SND.MapVote.Votes[ply.SND_LastMapVote] or 0) - 1)
	end

	ply.SND_LastMapVote = map
	SND.MapVote.Votes[map] = (SND.MapVote.Votes[map] or 0) + 1

	syncVotes()
end)

function SND.MapVote.StartMatchEnd()
	-- Reset match state variables for the next match
	SND.Round.MatchStarted = false
	SND.Round.AttackScore = 0
	SND.Round.DefendScore = 0
	SND.Round.RoundNumber = 0
	SND.Round.HalftimeReached = false -- Reset for a new match
	if SND.Settings.GetInt("mapvote_enabled", 1) then
		SND.MapVote.Start()
	else
		timer.Simple(2, function()
			RunConsoleCommand("changelevel", game.GetMap())
		end)
	end
end

util.AddNetworkString("SND_MapVote")
