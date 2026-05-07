--[[ Team spawn placement when SND.Config.MapSpawns[map] is defined (data file or Rust auto-layout). ]]

SND.Spawns = SND.Spawns or {}

function SND.Spawns.Apply(ply)
	if not SERVER then return end
	if not IsValid(ply) or not ply:Alive() then return end

	local map = game.GetMap()
	local data = SND.Config.MapSpawns[map]
	
	-- Fallback: If no map data, split all info_player_start entities by location
	if not data then
		local spawns = ents.FindByClass("info_player_start")
		table.sort(spawns, function(a, b) return a:GetPos().x < b:GetPos().x end)
		
		local mid = math.floor(#spawns / 2)
		local attack = {}
		local defend = {}
		for i, ent in ipairs(spawns) do
			if i <= mid then table.insert(attack, { pos = ent:GetPos(), ang = ent:GetAngles() })
			else table.insert(defend, { pos = ent:GetPos(), ang = ent:GetAngles() }) end
		end
		
		data = {
			attack = attack,
			defend = defend
		}
	end

	local side = (ply:Team() == SND.TEAM_ATTACK) and "attack" or "defend"
	local list = data[side]
	if not list or #list == 0 then return end

	-- Attempt to find a spawn point that isn't currently occupied by another player
	local pool = table.Copy(list)
	local pick = nil
	local occupiedRadiusSqr = 70 * 70 -- Increased radius to prevent players from overlapping and "bouncing"

	while #pool > 0 do
		local k = math.random(#pool)
		local candidate = pool[k]

		local isOccupied = false
		for _, other in ipairs(player.GetAll()) do
			if other ~= ply and other:Alive() and other:GetPos():DistToSqr(candidate.pos) < occupiedRadiusSqr then
				isOccupied = true
				break
			end
		end

		if not isOccupied then
			pick = candidate
			break
		end
		table.remove(pool, k)
	end

	-- Fallback if all designated points are crowded, just pick one at random
	if not pick then
		pick = table.Random(list)
	end

	if pick.pos then
		ply:SetPos(pick.pos)
		if pick.ang then
			ply:SetEyeAngles(pick.ang)
		end
	end
end

-- ── Debug Visualization ──────────────────────────────────────────────────
hook.Add("Think", "SND_SpawnDebugDraw", function()
	if SND.Settings.GetInt("debug_mode", 0) == 0 then return end
	local map = game.GetMap()
	local data = SND.Config.MapSpawns[map]
	if not data then return end

	-- Draw Attack Spawns (Red)
	for _, s in ipairs(data.attack or {}) do
		debugoverlay.Box(s.pos, Vector(-16,-16,0), Vector(16,16,72), 0.1, Color(255, 0, 0, 255), true)
	end
	-- Draw Defend Spawns (Blue)
	for _, s in ipairs(data.defend or {}) do
		debugoverlay.Box(s.pos, Vector(-16,-16,0), Vector(16,16,72), 0.1, Color(0, 0, 255, 255), true)
	end
end)

-- ── Manual Spawn Management ──────────────────────────────────────────────
local function saveMapData(map, data)
	file.CreateDir("snd_mwclassic/maps")
	local path = "snd_mwclassic/maps/" .. map .. ".lua"
	
	local out = "return {\n"
	-- Preserve existing sites if they exist
	if data.sites then
		out = out .. "\tsites = {\n"
		for _, s in ipairs(data.sites) do
			out = out .. string.format("\t\t{ id = %q, plantPos = Vector(%f, %f, %f), defuseRadius = %f },\n", s.id, s.plantPos.x, s.plantPos.y, s.plantPos.z, s.defuseRadius)
		end
		out = out .. "\t},\n"
	end

	out = out .. "\tspawns = {\n"
	out = out .. "\t\tattack = {\n"
	for _, s in ipairs(data.spawns.attack or {}) do
		out = out .. string.format("\t\t\t{ pos = Vector(%f, %f, %f), ang = Angle(%f, %f, %f) },\n", s.pos.x, s.pos.y, s.pos.z, s.ang.p, s.ang.y, s.ang.r)
	end
	out = out .. "\t\t},\n"
	out = out .. "\t\tdefend = {\n"
	for _, s in ipairs(data.spawns.defend or {}) do
		out = out .. string.format("\t\t\t{ pos = Vector(%f, %f, %f), ang = Angle(%f, %f, %f) },\n", s.pos.x, s.pos.y, s.pos.z, s.ang.p, s.ang.y, s.ang.r)
	end
	out = out .. "\t\t}\n\t}\n}"
	
	file.Write(path, out)
end

local function addSpawnCommand(ply, teamKey)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	local map = game.GetMap()
	SND.Config.MapSpawns[map] = SND.Config.MapSpawns[map] or { attack = {}, defend = {} }
	
	local pos = ply:GetPos() + Vector(0, 0, 8) -- Slight offset to prevent floor sticking
	local ang = ply:GetEyeAngles()
	ang.p = 0 -- Keep spawns level

	table.insert(SND.Config.MapSpawns[map][teamKey], { pos = pos, ang = ang })
	
	-- We include existing site data in the save to avoid wiping it
	local fullData = { sites = SND.Config.MapSites[map], spawns = SND.Config.MapSpawns[map] }
	saveMapData(map, fullData)
	
	ply:ChatPrint("[SND] Added " .. teamKey .. " spawn at your position and saved to data.")
end

concommand.Add("snd_spawn_add_attack", function(ply) addSpawnCommand(ply, "attack") end)
concommand.Add("snd_spawn_add_defend", function(ply) addSpawnCommand(ply, "defend") end)
concommand.Add("snd_spawn_clear", function(ply)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	local map = game.GetMap()
	SND.Config.MapSpawns[map] = { attack = {}, defend = {} }
	saveMapData(map, { sites = SND.Config.MapSites[map], spawns = SND.Config.MapSpawns[map] })
	ply:ChatPrint("[SND] Cleared all custom spawns for " .. map)
end)

concommand.Add("snd_spawn_remove_nearest", function(ply)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	local map = game.GetMap()
	local spawns = SND.Config.MapSpawns[map]
	if not spawns then return end

	local pos = ply:GetPos()
	local best, bestDist, bestTeam, bestIdx

	for _, teamKey in ipairs({"attack", "defend"}) do
		for i, s in ipairs(spawns[teamKey] or {}) do
			local d = pos:DistToSqr(s.pos)
			if not bestDist or d < bestDist then
				bestDist, bestTeam, bestIdx = d, teamKey, i
			end
		end
	end

	if bestIdx and math.sqrt(bestDist) < 200 then
		table.remove(SND.Config.MapSpawns[map][bestTeam], bestIdx)
		saveMapData(map, { sites = SND.Config.MapSites[map], spawns = SND.Config.MapSpawns[map] })
		ply:ChatPrint("[SND] Removed nearest " .. bestTeam .. " spawn.")
	else
		ply:ChatPrint("[SND] No spawn point close enough to remove.")
	end
end)

concommand.Add("snd_spawn_goto", function(ply, cmd, args)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	local teamKey = (args[1] or "attack"):lower()
	local idx = tonumber(args[2]) or 1
	
	local spawns = SND.Config.MapSpawns[game.GetMap()]
	if not spawns or not spawns[teamKey] or #spawns[teamKey] == 0 then
		ply:ChatPrint("[SND] No " .. teamKey .. " spawns configured.")
		return
	end

	local s = spawns[teamKey][math.Clamp(idx, 1, #spawns[teamKey])]
	if s then
		ply:SetPos(s.pos + Vector(0,0,5))
		ply:ChatPrint("[SND] Teleported to " .. teamKey .. " spawn #" .. idx)
	end
end)
