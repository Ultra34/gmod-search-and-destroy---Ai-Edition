--[[ Bomb carry, plant at configured sites, defuse ]]

SND.Bomb = SND.Bomb or {}

SND.Bomb.State = SND.BOMB_STATE_NONE
SND.Bomb.Carrier = nil
SND.Bomb.PlantedSite = nil
SND.Bomb.PlantPos = nil
SND.Bomb.DefuseEnd = 0
SND.Bomb.PlantTime = nil

util.AddNetworkString("SND_Bomb")

local function getSites()
	local map = game.GetMap()
	local t = SND.Config.MapSites[map]
	if not t or #t == 0 then
		local o = Vector(0, 0, 0)
		for _, e in ipairs(ents.FindByClass("info_player_start")) do
			o = e:GetPos()
			break
		end
		return {
			{ id = "A", plantPos = o + Vector(400, 0, 0), defuseRadius = 96 },
			{ id = "B", plantPos = o + Vector(-400, 200, 0), defuseRadius = 96 },
		}
	end
	return t
end

function SND.Bomb.ResetForRound()
	SND.Bomb.State = SND.BOMB_STATE_NONE
	SND.Bomb.Carrier = nil
	SND.Bomb.PlantedSite = nil
	SND.Bomb.PlantPos = nil
	SND.Bomb.DefuseEnd = 0
	SND.Bomb.PlantTime = nil
end

function SND.Bomb.AssignCarrier()
	SND.Bomb.ResetForRound()
	SND.Bomb.State = SND.BOMB_STATE_CARRIED

	local attackers = team.GetPlayers(SND.TEAM_ATTACK)
	if #attackers == 0 then return end

	local carrier = table.Random(attackers)
	SND.Bomb.Carrier = carrier
	net.Start("SND_Bomb")
	net.WriteUInt(1, 3)
	net.WriteEntity(carrier)
	net.Broadcast()
end

local function distToSite(ply, site)
	return ply:GetPos():Distance(site.plantPos)
end

local function nearestSite(ply)
	local best, bi
	local sites = getSites()
	for i, s in ipairs(sites) do
		local d = distToSite(ply, s)
		if not best or d < best then
			best, bi = d, i
		end
	end
	return bi, sites[bi], best
end

function SND.Bomb.TryPlant(ply)
	if SND.Round.Phase ~= SND.PHASE_LIVE then return end
	if not IsValid(ply) or ply:Team() ~= SND.TEAM_ATTACK then return end
	if SND.Bomb.State ~= SND.BOMB_STATE_CARRIED then return end
	if ply ~= SND.Bomb.Carrier then return end

	local _, site, dist = nearestSite(ply)
	if not site or dist > (site.defuseRadius or 96) + 32 then return end

	local plantTime = SND.Settings.Get("plant_time", 5)
	timer.Remove("SND_Plant_" .. ply:EntIndex())
	ply.SND_Planting = true
	ply:ChatPrint("[SND] Planting…")

	timer.Create("SND_Plant_" .. ply:EntIndex(), plantTime, 1, function()
		if not IsValid(ply) or not ply:Alive() then return end
		if ply ~= SND.Bomb.Carrier then return end
		local _, st, d = nearestSite(ply)
		if not st or d > (st.defuseRadius or 96) + 48 then return end

		SND.Bomb.State = SND.BOMB_STATE_PLANTED
		SND.Bomb.Carrier = nil
		SND.Bomb.PlantedSite = st.id
		SND.Bomb.PlantPos = st.plantPos
		SND.Bomb.PlantTime = CurTime()
		ply.SND_Planting = false

		SND.Announcer.BombPlanted()
		net.Start("SND_Bomb")
		net.WriteUInt(2, 3)
		net.WriteVector(st.plantPos)
		net.WriteString(st.id or "?")
		net.Broadcast()
	end)
end

function SND.Bomb.TryDefuse(ply)
	if SND.Round.Phase ~= SND.PHASE_LIVE then return end
	if SND.Bomb.State ~= SND.BOMB_STATE_PLANTED then return end
	if not IsValid(ply) or ply:Team() ~= SND.TEAM_DEFEND then return end
	if not SND.Bomb.PlantPos then return end

	if ply:GetPos():Distance(SND.Bomb.PlantPos) > 128 then return end

	if ply.SND_Defusing then return end
	ply.SND_Defusing = true

	local defuseTime = SND.Settings.Get("defuse_time", 8)
	ply:ChatPrint("[SND] Defusing…")

	local tid = "SND_Defuse_" .. ply:EntIndex()
	timer.Remove(tid)
	timer.Create(tid, defuseTime, 1, function()
		if IsValid(ply) then ply.SND_Defusing = false end
		if not IsValid(ply) or not ply:Alive() then return end
		if SND.Bomb.State ~= SND.BOMB_STATE_PLANTED then return end
		if ply:GetPos():Distance(SND.Bomb.PlantPos) > 140 then return end

		SND.Round.EndRound(SND.WIN_DEFEND_DEFUSE)
	end)
end

hook.Add("PlayerButtonDown", "SND_BombUse", function(ply, btn)
	if btn ~= KEY_E then return end
	if SND.Bomb.State == SND.BOMB_STATE_CARRIED and ply == SND.Bomb.Carrier then
		SND.Bomb.TryPlant(ply)
	elseif SND.Bomb.State == SND.BOMB_STATE_PLANTED and ply:Team() == SND.TEAM_DEFEND then
		SND.Bomb.TryDefuse(ply)
	end
end)

hook.Add("EntityTakeDamage", "SND_BombCancelPlant", function(ent, dmg)
	if not IsValid(ent) or not ent:IsPlayer() then return end
	if ent.SND_Planting then
		timer.Remove("SND_Plant_" .. ent:EntIndex())
		ent.SND_Planting = false
	end
	if ent.SND_Defusing then
		timer.Remove("SND_Defuse_" .. ent:EntIndex())
		ent.SND_Defusing = false
	end
end)

timer.Create("SND_BombExplode", 1, 0, function()
	if SND.Round.Phase ~= SND.PHASE_LIVE then return end
	if SND.Bomb.State ~= SND.BOMB_STATE_PLANTED then return end
	if not SND.Bomb.PlantPos then return end
	-- Simple fuse: 45s after plant — track plant time
	if not SND.Bomb.PlantTime then return end
	if CurTime() >= SND.Bomb.PlantTime + 45 then
		local eff = EffectData()
		eff:SetOrigin(SND.Bomb.PlantPos)
		util.Effect("Explosion", eff)
		SND.Round.EndRound(SND.WIN_ATTACK_PLANT)
		SND.Bomb.PlantTime = nil
	end
end)
