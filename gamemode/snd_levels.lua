SND.Levels = SND.Levels or {}

if SERVER then
	util.AddNetworkString("SND_UpdateXP")
end

-- XP Curve: 2000 XP per level
local XP_PER_LEVEL = 2000

-- Ensure the levels icons directory exists
file.CreateDir("snd_mwclassic/levels")

local function getPlayerFile(ply)
	local sid = ply:SteamID64()
	if not sid or sid == "0" then return nil end
	return "snd_mwclassic/players/" .. sid .. ".json"
end

function SND.Levels.Save(ply)
	local path = getPlayerFile(ply)
	if not path then return end

	local data = {
		xp = ply.SND_XP or 0,
		lvl = ply.SND_Level or 1
	}
	file.Write(getPlayerFile(ply), util.TableToJSON(data))
end

function SND.Levels.Load(ply)
	-- Safety check: don't create or load files for bots
	if ply:IsBot() or ply.SND_IsBot then return end

	local path = getPlayerFile(ply)
	if not path then return end

	if file.Exists(path, "DATA") then
		local data = util.JSONToTable(file.Read(path, "DATA"))
		ply.SND_XP = data.xp or 0
		ply.SND_Level = data.lvl or 1
	else
		-- Ensure new players have initialized values so Save() works correctly
		ply.SND_XP = 0
		ply.SND_Level = 1
		SND.Levels.Save(ply)
		print("[SND] First-time join: Created data file for player " .. ply:Nick())
	end
	ply:SetNWInt("SND_Level", ply.SND_Level)
end

function SND.Levels.Sync(ply)
	if not IsValid(ply) or ply:IsBot() or ply.SND_IsBot then return end

	net.Start("SND_UpdateXP")
		net.WriteUInt(tonumber(ply.SND_XP) or 0, 32)
		net.WriteUInt(tonumber(ply.SND_Level) or 1, 16)
		net.WriteUInt(0, 16) -- Amount gained (0 for sync)
	net.Send(ply)
end

function SND.Levels.AddXP(ply, amount)
	if not IsValid(ply) or ply.SND_IsBot then return end
	
	print("[SND] Adding " .. amount .. " XP to " .. ply:Nick())
	
	ply.SND_XP = (ply.SND_XP or 0) + amount
	
	-- Level up logic
	local oldLvl = ply.SND_Level or 1
	local newLvl = math.floor(ply.SND_XP / XP_PER_LEVEL) + 1
	
	if newLvl > oldLvl and oldLvl > 0 then
		ply.SND_Level = newLvl
		ply:SetNWInt("SND_Level", newLvl) -- Immediate update for nameplates/HUD
		print("[SND] Player " .. ply:Nick() .. " LEVELED UP to " .. newLvl .. "!")
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
	-- Delayed sync to ensure client-side receiver is ready
	timer.Simple(2, function()
		if IsValid(ply) and not (ply:IsBot() or ply.SND_IsBot) then
			SND.Levels.Sync(ply)
		end
	end)
end)

hook.Add("PlayerDisconnected", "SND_LevelsSaveDisconnect", function(ply)
	SND.Levels.Save(ply)
end)

hook.Add("ShutDown", "SND_LevelsSaveShutdown", function()
	print("[SND] Server shutting down, saving all level data...")
	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) then
			SND.Levels.Save(ply)
		end
	end
end)

hook.Add("PlayerDeath", "SND_XPOnKill", function(victim, inflictor, attacker)
	if IsValid(attacker) and attacker:IsPlayer() and attacker ~= victim and attacker:Team() ~= victim:Team() then
		local amount = 100
		-- Award extra XP for headshots
		if victim:LastHitGroup() == HITGROUP_HEAD then
			amount = amount + 50
		end
		timer.Simple(0, function()
			if IsValid(attacker) then SND.Levels.AddXP(attacker, amount) end
		end)
	end
end)

hook.Add("SND_OnBombPlanted", "SND_XPOnPlant", function(ply)
	SND.Levels.AddXP(ply, 500)
end)

hook.Add("SND_OnBombDefused", "SND_XPOnDefuse", function(ply)
	SND.Levels.AddXP(ply, 500)
end)

-- Admin command to manually add XP to a player
concommand.Add("snd_addxp", function(ply, cmd, args)
	-- Restrict to Admins/SuperAdmins
	if IsValid(ply) and not ply:IsAdmin() then 
		ply:ChatPrint("[SND] Admin only command.")
		return 
	end

	local targetStr = args[1]
	local amount = tonumber(args[2])

	if not targetStr or not amount then
		if IsValid(ply) then ply:ChatPrint("Usage: snd_addxp <name/steamid> <amount>") end
		return
	end

	-- Search for the target player
	local target = nil
	for _, p in ipairs(player.GetAll()) do
		if string.find(string.lower(p:Nick()), string.lower(targetStr), 1, true) or p:SteamID() == targetStr or p:SteamID64() == targetStr then
			target = p
			break
		end
	end

	if IsValid(target) then
		SND.Levels.AddXP(target, amount)
		if IsValid(ply) then ply:ChatPrint("Added " .. amount .. " XP to " .. target:Nick()) end
	else
		if IsValid(ply) then ply:ChatPrint("Player not found: " .. targetStr) end
	end
end)

print("[SND] Levels System Loaded (Server)")