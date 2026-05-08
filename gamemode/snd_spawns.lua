--[[ Team spawn placement when SND.Config.MapSpawns[map] is defined (data file or Rust auto-layout). ]]

SND.Spawns = SND.Spawns or {}

-- Ensure config tables are initialized to prevent nil errors during setup
SND.Config = SND.Config or {}
SND.Config.MapSites = SND.Config.MapSites or {}
SND.Config.MapSpawns = SND.Config.MapSpawns or {}

function SND.Spawns.Apply(ply)
	if not SERVER then return end
	if not IsValid(ply) or not ply:Alive() then return end

	local map = game.GetMap()
	local data = SND.Config.MapSpawns[map]
	
	-- Fallback: If no map data OR data is empty, split all info_player_start entities
	local hasData = data and ((data.attack and #data.attack > 0) or (data.defend and #data.defend > 0))
	if not hasData then
		local spawns = ents.FindByClass("info_player_start")
		if #spawns == 0 then spawns = ents.FindByClass("info_player_deathmatch") end
		
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

-- ── Debug Ghost Entities ─────────────────────────────────────────────────
local debugGhosts = {}

local function clearDebugGhosts()
	for _, ent in ipairs(debugGhosts) do
		if IsValid(ent) then ent:Remove() end
	end
	debugGhosts = {}
end

local function spawnDebugGhosts()
	clearDebugGhosts()
	local map = game.GetMap()
	local data = SND.Config.MapSpawns[map]
	if not data then return end

	local function createGhost(pos, ang, model, col)
		local e = ents.Create("prop_dynamic")
		e:SetModel(model)
		e:SetPos(pos)
		e:SetAngles(ang)
		e:SetColor(col)
		e:SetRenderMode(RENDERMODE_TRANSCOLOR)
		e:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
		e:SetSolid(SOLID_NONE)
		e:Spawn()
		table.insert(debugGhosts, e)
	end

	for _, s in ipairs(data.attack or {}) do
		local mdl = SND.Config.Factions.attack.models[1]
		createGhost(s.pos, s.ang or Angle(0,0,0), mdl, Color(255, 100, 100, 200))
	end
	for _, s in ipairs(data.defend or {}) do
		local mdl = SND.Config.Factions.defend.models[1]
		createGhost(s.pos, s.ang or Angle(0,0,0), mdl, Color(100, 100, 255, 200))
	end
end

-- Hook into phase changes to manage ghosts
hook.Add("Think", "SND_DebugGhostManager", function()
	local isDebug = SND.Round and SND.Round.Phase == SND.PHASE_DEBUG
	if isDebug and #debugGhosts == 0 then
		spawnDebugGhosts()
	elseif not isDebug and #debugGhosts > 0 then
		clearDebugGhosts()
	end
end)

-- ── Manual Spawn Management ──────────────────────────────────────────────
local function addSpawnCommand(ply, teamKey)
	if IsValid(ply) and not (ply:IsSuperAdmin() or game.SinglePlayer() or ply:IsListenServerHost()) then 
		ply:ChatPrint("[SND] ERROR: You must be a SuperAdmin to save map data.")
		return 
	end
	local map = game.GetMap()
	SND.Config.MapSpawns[map] = SND.Config.MapSpawns[map] or { attack = {}, defend = {} }
	SND.Config.MapSpawns[map].attack = SND.Config.MapSpawns[map].attack or {}
	SND.Config.MapSpawns[map].defend = SND.Config.MapSpawns[map].defend or {}
	
	local pos = ply:GetPos() + Vector(0, 0, 8) -- Slight offset to prevent floor sticking
	local ang = ply:EyeAngles()
	ang.p = 0 -- Keep spawns level

	table.insert(SND.Config.MapSpawns[map][teamKey], { pos = pos, ang = ang })
	
	-- We include existing site data in the save to avoid wiping it
	SND.Config.SaveMapData(map)
	
	ply:ChatPrint("[SND] Added " .. teamKey .. " spawn at your position and saved to data.")
	if SND.Round.Phase == SND.PHASE_DEBUG then
		spawnDebugGhosts() -- Refresh models instantly
	end
end

concommand.Add("snd_spawn_add_attack", function(ply) addSpawnCommand(ply, "attack") end)
concommand.Add("snd_spawn_add_defend", function(ply) addSpawnCommand(ply, "defend") end)
concommand.Add("snd_spawn_clear", function(ply)
	if IsValid(ply) and not (ply:IsSuperAdmin() or game.SinglePlayer() or ply:IsListenServerHost()) then return end
	local map = game.GetMap()
	SND.Config.MapSpawns[map] = { attack = {}, defend = {} }
	SND.Config.SaveMapData(map)
	clearDebugGhosts()
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
		SND.Config.SaveMapData(map)
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
