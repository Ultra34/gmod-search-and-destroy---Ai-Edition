SND.Levels = SND.Levels or {}

util.AddNetworkString("SND_UpdateXP")

-- XP Curve: 2000 XP per level
local XP_PER_LEVEL = 2000

local function getPlayerFile(ply)
	local sid = ply:SteamID64()
	return "snd_mwclassic/players/" .. sid .. ".json"
end

function SND.Levels.Save(ply)
	local data = {
		xp = ply.SND_XP or 0,
		lvl = ply.SND_Level or 1
	}
	file.CreateDir("snd_mwclassic/players")
	file.Write(getPlayerFile(ply), util.TableToJSON(data))
end

function SND.Levels.Load(ply)
	local path = getPlayerFile(ply)
	if file.Exists(path, "DATA") then
		local data = util.JSONToTable(file.Read(path, "DATA"))
		ply.SND_XP = data.xp or 0
		ply.SND_Level = data.lvl or 1
	else
		ply.SND_XP = 0
		ply.SND_Level = 1
	end
	ply:SetNWInt("SND_Level", ply.SND_Level)
	SND.Levels.Sync(ply)
end

function SND.Levels.Sync(ply)
	net.Start("SND_UpdateXP")
		net.WriteUInt(ply.SND_XP, 32)
		net.WriteUInt(ply.SND_Level, 16)
		net.WriteUInt(0, 16) -- Amount gained (0 for sync)
	net.Send(ply)
end

function SND.Levels.AddXP(ply, amount)
	if not IsValid(ply) or ply.SND_IsBot then return end
	
	ply.SND_XP = (ply.SND_XP or 0) + amount
	
	-- Level up logic
	local oldLvl = ply.SND_Level or 1
	local newLvl = math.floor(ply.SND_XP / XP_PER_LEVEL) + 1
	
	if newLvl > oldLvl then
		ply.SND_Level = newLvl
		ply:SetNWInt("SND_Level", newLvl)
		ply:ChatPrint("[SND] LEVEL UP! You are now level " .. newLvl)
	end

	net.Start("SND_UpdateXP")
		net.WriteUInt(ply.SND_XP, 32)
		net.WriteUInt(ply.SND_Level, 16)
		net.WriteUInt(amount, 16)
	net.Send(ply)
	
	SND.Levels.Save(ply)
end

hook.Add("PlayerInitialSpawn", "SND_LevelsInit", function(ply)
	SND.Levels.Load(ply)
end)

hook.Add("PlayerDeath", "SND_XPOnKill", function(victim, inflictor, attacker)
	if IsValid(attacker) and attacker:IsPlayer() and attacker ~= victim and attacker:Team() ~= victim:Team() then
		SND.Levels.AddXP(attacker, 100)
	end
end)