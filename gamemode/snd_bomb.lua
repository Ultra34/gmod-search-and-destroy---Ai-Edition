--[[ Bomb carry, plant, defuse — with progress networking, bomb prop, screen effects ]]
-- REPLACES: gamemode/snd_bomb.lua

SND.Bomb = SND.Bomb or {}

SND.Bomb.State     = SND.BOMB_STATE_NONE
SND.Bomb.Carrier   = nil
SND.Bomb.PlantedSite = nil
SND.Bomb.PlantPos  = nil
SND.Bomb.DefuseEnd = 0
SND.Bomb.PlantTime = nil
SND.Bomb.PropEnt   = nil  -- the physical bomb prop in the world

util.AddNetworkString("SND_Bomb")
util.AddNetworkString("SND_BombProgress")  -- plant / defuse progress bar

-- ── Sites helper ──────────────────────────────────────────────────────────
local function getSites()
	local map = game.GetMap()
	local t   = SND.Config.MapSites[map]
	if not t or #t == 0 then
		local o = Vector(0, 0, 0)
		for _, e in ipairs(ents.FindByClass("info_player_start")) do
			o = e:GetPos() break
		end
		return {
			{ id = "A", plantPos = o + Vector( 400,   0, 0), defuseRadius = 96 },
			{ id = "B", plantPos = o + Vector(-400, 200, 0), defuseRadius = 96 },
		}
	end
	return t
end

local function nearestSite(ply)
	local best, bi
	local sites = getSites()
	for i, s in ipairs(sites) do
		local d = ply:GetPos():Distance(s.plantPos)
		if not best or d < best then best, bi = d, i end
	end
	return bi, sites[bi], best
end

-- ── Bomb prop (visible case on the ground) ────────────────────────────────
local function spawnBombProp(pos)
	if IsValid(SND.Bomb.PropEnt) then SND.Bomb.PropEnt:Remove() end

	local e = ents.Create("prop_physics_override")
	-- c4 prop from CS:S; falls back to a crate if CS:S isn't mounted
	e:SetModel("models/weapons/w_c4.mdl")
	if not e:GetModel() or e:GetModel() == "" then
		e:SetModel("models/props_junk/wood_crate001a.mdl")
	end
	e:SetPos(pos + Vector(0, 0, 4))
	e:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	e:Spawn()
	e:Activate()
	e:SetUnFreezable(true)
	SND.Bomb.PropEnt = e
end

local function removeBombProp()
	if IsValid(SND.Bomb.PropEnt) then
		SND.Bomb.PropEnt:Remove()
		SND.Bomb.PropEnt = nil
	end
end

-- ── Reset ─────────────────────────────────────────────────────────────────
function SND.Bomb.ResetForRound()
	SND.Bomb.State       = SND.BOMB_STATE_NONE
	SND.Bomb.Carrier     = nil
	SND.Bomb.PlantedSite = nil
	SND.Bomb.PlantPos    = nil
	SND.Bomb.DefuseEnd   = 0
	SND.Bomb.PlantTime   = nil
	removeBombProp()

	-- Cancel any pending timers
	for _, ply in ipairs(player.GetAll()) do
		timer.Remove("SND_Plant_"  .. ply:EntIndex())
		timer.Remove("SND_Defuse_" .. ply:EntIndex())
		ply.SND_Planting  = false
		ply.SND_Defusing  = false
	end
end

-- ── Assign carrier ────────────────────────────────────────────────────────
function SND.Bomb.AssignCarrier()
	SND.Bomb.ResetForRound()
	SND.Bomb.State = SND.BOMB_STATE_CARRIED

	local attackers = team.GetPlayers(SND.TEAM_ATTACK)
	if #attackers == 0 then return end

	local carrier = table.Random(attackers)
	SND.Bomb.Carrier = carrier

	net.Start("SND_Bomb")
		net.WriteUInt(1, 3)         -- type 1 = carrier assigned
		net.WriteEntity(carrier)
	net.Broadcast()
end

-- ── Plant ─────────────────────────────────────────────────────────────────
local PLANT_MOVE_CANCEL = 48  -- units; cancel if player moves this far during planting

function SND.Bomb.TryPlant(ply)
	if SND.Round.Phase ~= SND.PHASE_LIVE       then return end
	if not IsValid(ply)                         then return end
	if ply:Team() ~= SND.TEAM_ATTACK           then return end
	if SND.Bomb.State ~= SND.BOMB_STATE_CARRIED then return end
	if ply ~= SND.Bomb.Carrier                 then return end
	if ply.SND_Planting                        then return end  -- already planting

	local _, site, dist = nearestSite(ply)
	if not site or dist > (site.defuseRadius or 96) + 32 then
		ply:ChatPrint("[SND] Move to a bomb site (A or B) to plant.")
		return
	end

	local plantTime   = SND.Settings.Get("plant_time", 5)
	local startPos    = ply:GetPos()
	ply.SND_Planting  = true
	local endTime     = CurTime() + plantTime

	-- Broadcast progress bar start to everyone
	net.Start("SND_BombProgress")
		net.WriteUInt(1, 2)           -- 1 = plant started
		net.WriteEntity(ply)
		net.WriteFloat(plantTime)
	net.Broadcast()

	-- Poll every 0.1s so we can cancel if they move or take damage
	local tid = "SND_Plant_" .. ply:EntIndex()
	timer.Create(tid, 0.1, 0, function()
		if not IsValid(ply) or not ply:Alive() then
			SND.Bomb.CancelAction(ply, "plant")
			return
		end

		-- Cancel if moved out of site
		local _, st2, d2 = nearestSite(ply)
		if not st2 or d2 > (st2.defuseRadius or 96) + 80 then
			SND.Bomb.CancelAction(ply, "plant")
			ply:ChatPrint("[SND] Plant cancelled — left the bomb site.")
			return
		end

		-- Done?
		if CurTime() >= endTime then
			timer.Remove(tid)
			if not IsValid(ply) or not ply:Alive() then return end
			if ply ~= SND.Bomb.Carrier then return end

			ply.SND_Planting = false

			SND.Bomb.State       = SND.BOMB_STATE_PLANTED
			SND.Bomb.Carrier     = nil
			SND.Bomb.PlantedSite = st2 and st2.id or "?"
			SND.Bomb.PlantPos    = st2 and st2.plantPos or ply:GetPos()
			SND.Bomb.PlantTime   = CurTime()

			spawnBombProp(SND.Bomb.PlantPos)

			SND.Announcer.BombPlanted()

			net.Start("SND_Bomb")
				net.WriteUInt(2, 3)   -- type 2 = bomb planted
				net.WriteVector(SND.Bomb.PlantPos)
				net.WriteString(SND.Bomb.PlantedSite)
			net.Broadcast()

			-- Tell clients to hide progress bar
			net.Start("SND_BombProgress")
				net.WriteUInt(0, 2)   -- 0 = hidden
				net.WriteEntity(ply)
				net.WriteFloat(0)
			net.Broadcast()
		end
	end)
end

-- ── Defuse ────────────────────────────────────────────────────────────────
function SND.Bomb.TryDefuse(ply)
	if SND.Round.Phase ~= SND.PHASE_LIVE       then return end
	if SND.Bomb.State ~= SND.BOMB_STATE_PLANTED then return end
	if not IsValid(ply)                         then return end
	if ply:Team() ~= SND.TEAM_DEFEND           then return end
	if not SND.Bomb.PlantPos                   then return end
	if ply:GetPos():Distance(SND.Bomb.PlantPos) > 128 then return end
	if ply.SND_Defusing                        then return end

	ply.SND_Defusing  = true
	local defuseTime  = SND.Settings.Get("defuse_time", 8)
	local endTime     = CurTime() + defuseTime

	net.Start("SND_BombProgress")
		net.WriteUInt(2, 2)           -- 2 = defuse started
		net.WriteEntity(ply)
		net.WriteFloat(defuseTime)
	net.Broadcast()

	local tid = "SND_Defuse_" .. ply:EntIndex()
	timer.Create(tid, 0.1, 0, function()
		if not IsValid(ply) or not ply:Alive() then
			SND.Bomb.CancelAction(ply, "defuse")
			return
		end
		if SND.Bomb.State ~= SND.BOMB_STATE_PLANTED then
			SND.Bomb.CancelAction(ply, "defuse")
			return
		end
		-- Cancel if walked away
		if ply:GetPos():Distance(SND.Bomb.PlantPos) > 160 then
			SND.Bomb.CancelAction(ply, "defuse")
			ply:ChatPrint("[SND] Defuse cancelled — too far from the bomb.")
			return
		end
		if CurTime() >= endTime then
			timer.Remove(tid)
			ply.SND_Defusing = false

			net.Start("SND_BombProgress")
				net.WriteUInt(0, 2)
				net.WriteEntity(ply)
				net.WriteFloat(0)
			net.Broadcast()

			SND.Round.EndRound(SND.WIN_DEFEND_DEFUSE)
		end
	end)
end

-- ── Cancel helper ─────────────────────────────────────────────────────────
function SND.Bomb.CancelAction(ply, kind)
	if not IsValid(ply) then return end
	if kind == "plant" then
		timer.Remove("SND_Plant_" .. ply:EntIndex())
		ply.SND_Planting = false
	elseif kind == "defuse" then
		timer.Remove("SND_Defuse_" .. ply:EntIndex())
		ply.SND_Defusing = false
	end
	net.Start("SND_BombProgress")
		net.WriteUInt(0, 2)
		net.WriteEntity(ply)
		net.WriteFloat(0)
	net.Broadcast()
end

-- ── USE key ───────────────────────────────────────────────────────────────
hook.Add("PlayerButtonDown", "SND_BombUse", function(ply, btn)
	if btn ~= KEY_E then return end
	if SND.Bomb.State == SND.BOMB_STATE_CARRIED and ply == SND.Bomb.Carrier then
		SND.Bomb.TryPlant(ply)
	elseif SND.Bomb.State == SND.BOMB_STATE_PLANTED and ply:Team() == SND.TEAM_DEFEND then
		SND.Bomb.TryDefuse(ply)
	end
end)

-- Cancel plant/defuse on taking damage
hook.Add("EntityTakeDamage", "SND_BombCancelOnDmg", function(ent, dmg)
	if not IsValid(ent) or not ent:IsPlayer() then return end
	if ent.SND_Planting then SND.Bomb.CancelAction(ent, "plant")
		ent:ChatPrint("[SND] Plant cancelled — took damage.")
	end
	if ent.SND_Defusing then SND.Bomb.CancelAction(ent, "defuse")
		ent:ChatPrint("[SND] Defuse cancelled — took damage.")
	end
end)

-- ── Explosion countdown ───────────────────────────────────────────────────
local FUSE_TIME = 45  -- seconds; matches README

timer.Create("SND_BombExplode", 1, 0, function()
	if SND.Round.Phase ~= SND.PHASE_LIVE then return end
	if SND.Bomb.State  ~= SND.BOMB_STATE_PLANTED then return end
	if not SND.Bomb.PlantPos or not SND.Bomb.PlantTime then return end

	if CurTime() >= SND.Bomb.PlantTime + FUSE_TIME then
		-- Explosion effect at planted position
		local eff = EffectData()
		eff:SetOrigin(SND.Bomb.PlantPos)
		eff:SetScale(4)
		util.Effect("Explosion", eff)

		-- Screen shake for everyone nearby
		for _, ply in ipairs(player.GetAll()) do
			if IsValid(ply) and ply:Alive() then
				local d = ply:GetPos():Distance(SND.Bomb.PlantPos)
				if d < 2000 then
					util.ScreenShake(ply:GetPos(), 20 * (1 - d/2000), 10, 1.5, 500)
				end
			end
		end

		removeBombProp()
		SND.Bomb.PlantTime = nil
		SND.Round.EndRound(SND.WIN_ATTACK_PLANT)
	end
end)
