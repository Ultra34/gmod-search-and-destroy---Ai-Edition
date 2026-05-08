--[[
	Workshop map ttt_rust_v1a — [TTT] Rust (MW2-style Rust).
	https://steamcommunity.com/sharedfiles/filedetails/?id=2922376072

	When no data/snd_mwclassic/maps/ttt_rust_v1a.lua override exists, we infer:
	- Bomb site A: toward “top-right” of player spawn hull (tank yard area on overhead).
	- Bomb site B: near map center (tower area).
	- Team spawns: split spawn entities by median Y (top half ≈ attackers, bottom ≈ defenders).

	If your match feels mirrored, set ConVar snd_rust_swap_spawns 1 or edit the data override.
]]

SND.Rust = SND.Rust or {}

local RUST_MAP = "ttt_rust_v1a"

if SERVER then
	CreateConVar("snd_rust_swap_spawns", "0", FCVAR_ARCHIVE, "Swap attacker/defender auto-spawn halves on ttt_rust_v1a")
end

local function groundPos(v)
	local tr = util.TraceLine({
		start = v + Vector(0, 0, 512),
		endpos = v - Vector(0, 0, 8192),
		mask = MASK_SOLID_BRUSHONLY,
	})
	return tr.HitPos + Vector(0, 0, 2)
end

local function collectSpawnPoints()
	local pts = {}
	local classes = {
		"info_player_deathmatch",
		"info_player_start",
		"info_player_terrorist",
		"info_player_counterterrorist",
	}

	for _, cls in ipairs(classes) do
		for _, e in ipairs(ents.FindByClass(cls)) do
			if IsValid(e) then
				pts[#pts + 1] = e:GetPos()
			end
		end
	end
	return pts
end

function SND.Rust.ApplyAutoLayout()
	local map = string.lower(game.GetMap())
	if map ~= RUST_MAP then return end

	local needSites = not SND.Config.MapSites[map] or #SND.Config.MapSites[map] < 2
	local sp = SND.Config.MapSpawns[map]
	local needSpawns = not sp or not sp.attack or not sp.defend or #sp.attack == 0 or #sp.defend == 0

	if not needSites and not needSpawns then return end

	local pts = collectSpawnPoints()
	if #pts < 2 then
		print("[SND] " .. map .. ": need at least 2 player spawn entities for auto-layout (found " .. #pts .. "). Place overrides in data/snd_mwclassic/maps/" .. map .. ".lua")
		return
	end

	local minx, maxx = math.huge, -math.huge
	local miny, maxy = math.huge, -math.huge
	local sum = Vector()

	for _, p in ipairs(pts) do
		minx = math.min(minx, p.x)
		maxx = math.max(maxx, p.x)
		miny = math.min(miny, p.y)
		maxy = math.max(maxy, p.y)
		sum = sum + p
	end

	local centroid = sum / #pts

	if needSites then
		-- Top-right of bounding region (tanks / site A); center mass (tower / site B)
		local rawA = Vector(maxx - 128, maxy - 128, centroid.z + 400)
		local rawB = Vector(centroid.x, centroid.y, centroid.z + 400)

		SND.Config.MapSites[map] = {
			{ id = "A", plantPos = groundPos(rawA), defuseRadius = 120 },
			{ id = "B", plantPos = groundPos(rawB), defuseRadius = 120 },
		}
	end

	if needSpawns then
		table.sort(pts, function(a, b)
			return a.y > b.y
		end)

		local mid = math.max(1, math.ceil(#pts / 2))
		local attackPts = {}
		local defendPts = {}
		for i, p in ipairs(pts) do
			if i <= mid then
				attackPts[#attackPts + 1] = p
			else
				defendPts[#defendPts + 1] = p
			end
		end

		local cv = GetConVar("snd_rust_swap_spawns")
		if cv and cv:GetBool() then
			attackPts, defendPts = defendPts, attackPts
		end

		local function toEntries(vecList)
			local out = {}
			for _, p in ipairs(vecList) do
				local jitter = Vector(math.random(-24, 24), math.random(-24, 24), 32)
				local pos = groundPos(p + jitter)
				local ang = Angle(0, math.random(0, 360), 0)
				out[#out + 1] = { pos = pos, ang = ang }
			end
			return out
		end

		SND.Config.MapSpawns[map] = {
			attack = toEntries(attackPts),
			defend = toEntries(defendPts),
		}
	end

	print("[SND] " .. map .. ": auto-layout applied (sites=" .. tostring(needSites) .. " spawns=" .. tostring(needSpawns) .. ").")
end

function SND.Rust.InitPostEntity()
	local map = string.lower(game.GetMap())

	if map == RUST_MAP then
		local sitesEmpty = not SND.Config.MapSites[map] or #SND.Config.MapSites[map] < 2
		local sp = SND.Config.MapSpawns[map]
		local spawnsEmpty = not sp or not sp.attack or #sp.attack == 0 or not sp.defend or #sp.defend == 0
		if sitesEmpty or spawnsEmpty then
			SND.Rust.ApplyAutoLayout()
			SND.Config.SaveMapData(map) -- Save the auto-generated layout
		end
	end
end

concommand.Add("snd_rust_dump_spawn_line", function(ply)
	if IsValid(ply) and not (ply:IsSuperAdmin() or ply:IsListenServerHost()) then return end
	local who = IsValid(ply) and ply or player.GetAll()[1]
	if not IsValid(who) then return end
	local p = who:GetPos()
	local a = who:EyeAngles()
	local line = string.format("  { pos = Vector(%.2f, %.2f, %.2f), ang = Angle(%.2f, %.2f, %.2f) },", p.x, p.y, p.z, a.p, a.y, a.r)
	MsgN("[SND] Paste into data/snd_mwclassic/maps/" .. game.GetMap() .. ".lua → spawns:")
	MsgN(line)
	if IsValid(ply) then ply:ChatPrint("[SND] Printed one spawn line to server console.") end
end)

concommand.Add("snd_rust_dump_site_vectors", function(ply)
	if IsValid(ply) and not (ply:IsSuperAdmin() or ply:IsListenServerHost()) then return end
	local who = IsValid(ply) and ply or player.GetAll()[1]
	if not IsValid(who) then return end
	local p = groundPos(who:GetPos() + Vector(0, 0, 8))
	MsgN("[SND] Standing bomb site (ground traced):")
	MsgN(string.format("  plantPos = Vector(%.2f, %.2f, %.2f), defuseRadius = 120,", p.x, p.y, p.z))
	if IsValid(ply) then ply:ChatPrint("[SND] Printed site Vector to server console.") end
end)
