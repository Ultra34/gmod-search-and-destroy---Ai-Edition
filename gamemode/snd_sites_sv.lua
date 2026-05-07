--[[ Server: broadcast bomb site positions to clients for 3D markers
     NEW FILE: gamemode/snd_sites_sv.lua
     Add to init.lua:  include("snd_sites_sv.lua")
]]

util.AddNetworkString("SND_SpawnData")
util.AddNetworkString("SND_SiteData")

local function broadcastSites(ply)
	local map   = game.GetMap()
	local sites = SND.Config.MapSites[map]

	-- Fall back to gm_construct defaults if no site data for this map
	if not sites or #sites == 0 then
		sites = {
			{ id = "A", plantPos = Vector(-2176, -896, -144), defuseRadius = 96 },
			{ id = "B", plantPos = Vector( 2176,  896, -144), defuseRadius = 96 },
		}
	end

	local function send(target)
		net.Start("SND_SiteData")
			net.WriteUInt(#sites, 8)
			for _, s in ipairs(sites) do
				net.WriteString(s.id or "?")
				net.WriteVector(s.plantPos)
				net.WriteFloat(s.defuseRadius or 96)
			end
		if target then net.Send(target) else net.Broadcast() end

		-- Also send spawn data for debug visualization
		local spawns = SND.Config.MapSpawns[map]
		net.Start("SND_SpawnData")
			if spawns and spawns.attack then
				net.WriteUInt(#spawns.attack, 8)
				for _, s in ipairs(spawns.attack) do
					net.WriteVector(s.pos)
					net.WriteAngle(s.ang or Angle(0, 0, 0))
				end
			else
				net.WriteUInt(0, 8)
			end
			if spawns and spawns.defend then
				net.WriteUInt(#spawns.defend, 8)
				for _, s in ipairs(spawns.defend) do
					net.WriteVector(s.pos)
					net.WriteAngle(s.ang or Angle(0, 0, 0))
				end
			else
				net.WriteUInt(0, 8)
			end
		if target then net.Send(target) else net.Broadcast() end
	end

	if IsValid(ply) then
		send(ply)
	else
		send()
	end
end

-- Send to everyone when freeze starts (so markers appear before round goes live)
hook.Add("SND_RoundStart_Freeze", "SND_BroadcastSites", function()
	broadcastSites()
end)

-- Send to a joining player so they get site data mid-round
hook.Add("PlayerInitialSpawn", "SND_SendSitesToNewPlayer", function(ply)
	timer.Simple(1, function()
		if IsValid(ply) then broadcastSites(ply) end
	end)
end)

-- Also send immediately when the map finishes loading (covers listen-server host)
hook.Add("InitPostEntity", "SND_SendSitesOnLoad", function()
	timer.Simple(2, function() broadcastSites() end)
end)

hook.Add("Think", "SND_SiteDebugDraw", function()
	local debugMode = SND.Settings.GetInt("debug_mode", 0) == 1
	local debugPhase = SND.Round and SND.Round.Phase == SND.PHASE_DEBUG
	if not debugMode and not debugPhase then return end
	local sites = SND.Config.MapSites[game.GetMap()]
	if not sites then return end

	for _, s in ipairs(sites) do
		debugoverlay.Sphere(s.plantPos, s.defuseRadius or 120, 0.1, Color(255, 255, 0, 255), true)
		debugoverlay.EntityText(0, s.plantPos + Vector(0,0,20), "SITE " .. (s.id or "?"), 0.1, Color(255, 255, 0))
	end
end)

-- ── Manual Site Management ──────────────────────────────────────────────
local function saveMapData(map, data)
	file.CreateDir("snd_mwclassic/maps")
	local path = "snd_mwclassic/maps/" .. map .. ".lua"
	
	local out = "return {\n"
	out = out .. "\tsites = {\n"
	for _, s in ipairs(data.sites or {}) do
		out = out .. string.format("\t\t{ id = %q, plantPos = Vector(%f, %f, %f), defuseRadius = %f },\n", s.id, s.plantPos.x, s.plantPos.y, s.plantPos.z, s.defuseRadius)
	end
	out = out .. "\t},\n"

	-- Preserve existing spawns if they exist
	if data.spawns then
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
		out = out .. "\t\t}\n\t}\n"
	end
	out = out .. "}"
	
	file.Write(path, out)
end

concommand.Add("snd_site_add", function(ply, cmd, args)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	local id = args[1] or "A"
	local radius = tonumber(args[2]) or 120
	local map = game.GetMap()

	SND.Config.MapSites[map] = SND.Config.MapSites[map] or {}
	
	-- Find ground below player
	local tr = util.TraceLine({
		start = ply:GetPos() + Vector(0,0,10),
		endpos = ply:GetPos() - Vector(0,0,100),
		mask = MASK_SOLID_BRUSHONLY
	})
	local pos = tr.Hit and tr.HitPos or ply:GetPos()

	table.insert(SND.Config.MapSites[map], { id = id, plantPos = pos, defuseRadius = radius })
	
	local fullData = { sites = SND.Config.MapSites[map], spawns = SND.Config.MapSpawns[map] }
	saveMapData(map, fullData)
	
	broadcastSites()
	ply:ChatPrint("[SND] Added site " .. id .. " at your position and saved to data.")
end)

concommand.Add("snd_site_clear", function(ply)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	local map = game.GetMap()
	SND.Config.MapSites[map] = {}
	
	local fullData = { sites = SND.Config.MapSites[map], spawns = SND.Config.MapSpawns[map] }
	saveMapData(map, fullData)
	
	broadcastSites()
	ply:ChatPrint("[SND] Cleared all custom sites for " .. map)
end)

concommand.Add("snd_site_goto", function(ply, cmd, args)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	local id = (args[1] or "A"):upper()
	local sites = SND.Config.MapSites[game.GetMap()]
	if not sites then return end

	for _, s in ipairs(sites) do
		if s.id == id then
			ply:SetPos(s.plantPos + Vector(0,0,10))
			ply:ChatPrint("[SND] Teleported to Site " .. id)
			return
		end
	end
	ply:ChatPrint("[SND] Site " .. id .. " not found.")
end)
