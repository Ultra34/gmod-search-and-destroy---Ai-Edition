--[[ Server: broadcast bomb site positions to clients for 3D markers
     NEW FILE: gamemode/snd_sites_sv.lua
     Add to init.lua:  include("snd_sites_sv.lua")
]]

-- Ensure config tables are initialized to prevent nil errors during setup
SND.Config = SND.Config or {}
SND.Config.MapSites = SND.Config.MapSites or {}
SND.Config.MapSpawns = SND.Config.MapSpawns or {}

util.AddNetworkString("SND_SpawnData")
util.AddNetworkString("SND_SiteData")

-- ── Bomb Site Entity ─────────────────────────────────────────────────────
local SITE_ENT = {
	Type = "point",
	Base = "base_point",
}

function SITE_ENT:Initialize()
	self:SetNWString("SND_SiteID", self.SiteID or "A")
	self:SetNWFloat("SND_SiteRadius", self.SiteRadius or 120)
end

scripted_ents.Register(SITE_ENT, "snd_site")

SND.Sites = SND.Sites or {}

-- ── Broadcasting & Sync ──────────────────────────────────────────────────
local function broadcastSites(ply)
	local map   = game.GetMap()
	local sites = SND.Config.MapSites[map] or {}

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
		local spawns = SND.Config.MapSpawns[map] or {}
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

function SND.Sites.RefreshEntities()
	for _, e in ipairs(ents.FindByClass("snd_site")) do e:Remove() end

	local map = game.GetMap()
	local sites = SND.Config.MapSites[map] or {}
	
	for _, s in ipairs(sites) do
		local e = ents.Create("snd_site")
		e.SiteID = s.id
		e.SiteRadius = s.defuseRadius or 120
		e:SetPos(s.plantPos)
		e:Spawn()
	end
end

-- Send to everyone when freeze starts (so markers appear before round goes live)
hook.Add("SND_RoundStart_Freeze", "SND_BroadcastSites", function()
	broadcastSites()
	SND.Sites.RefreshEntities()
end)

-- Send to a joining player so they get site data mid-round
hook.Add("PlayerInitialSpawn", "SND_SendSitesToNewPlayer", function(ply)
	timer.Simple(1, function()
		if IsValid(ply) then 
			broadcastSites(ply)
			-- Entities are networked automatically, no need to refresh for one player
		end
	end)
end)

-- Also send immediately when the map finishes loading (covers listen-server host)
hook.Add("InitPostEntity", "SND_SendSitesOnLoad", function()
	timer.Simple(2, function() broadcastSites() end)
end)

-- ── Manual Site Management ──────────────────────────────────────────────
concommand.Add("snd_site_add", function(ply, cmd, args)
	if IsValid(ply) and not (ply:IsSuperAdmin() or game.SinglePlayer() or ply:IsListenServerHost()) then 
		ply:ChatPrint("[SND] ERROR: You must be a SuperAdmin to save map data.")
		return 
	end
	local id = (args[1] or "A"):upper()
	local radius = tonumber(args[2]) or 120
	local map = game.GetMap()

	SND.Config.MapSites[map] = SND.Config.MapSites[map] or {}
	
	-- Find ground below player
	local tr = util.TraceLine({
		start = ply:GetPos() + Vector(0,0,10),
		endpos = ply:GetPos() - Vector(0,0,100),
		mask = MASK_SOLID
	})
	local pos = tr.Hit and tr.HitPos or ply:GetPos()

	-- Replace existing site with same ID if it exists, otherwise insert new
	local sites = SND.Config.MapSites[map]
	local found = false
	for k, s in ipairs(sites) do
		if s.id == id then
			sites[k] = { id = id, plantPos = pos, defuseRadius = radius }
			found = true
			break
		end
	end
	
	if not found then
		table.insert(sites, { id = id, plantPos = pos, defuseRadius = radius })
	end

	SND.Config.SaveMapData(map)
	
	broadcastSites()
	SND.Sites.RefreshEntities()
	ply:ChatPrint("[SND] Added site " .. id .. " at your position and saved to data.")
end)

concommand.Add("snd_site_clear", function(ply)
	if IsValid(ply) and not (ply:IsSuperAdmin() or game.SinglePlayer() or ply:IsListenServerHost()) then return end
	local map = game.GetMap()
	SND.Config.MapSites[map] = {}
	
	SND.Config.SaveMapData(map)
	
	broadcastSites()
	SND.Sites.RefreshEntities()
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
