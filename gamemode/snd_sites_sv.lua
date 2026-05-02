--[[ Server: broadcast bomb site positions to clients for 3D markers
     NEW FILE: gamemode/snd_sites_sv.lua
     Add to init.lua:  include("snd_sites_sv.lua")
]]

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
