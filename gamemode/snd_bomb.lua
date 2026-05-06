--[[ Bomb: plant at crosshair ground point, locked prop, CSS beeping, defuse
     REPLACES: gamemode/snd_bomb.lua ]]

AddCSLuaFile()

SND.Bomb = SND.Bomb or {}

SND.Bomb.State       = SND.BOMB_STATE_NONE
SND.Bomb.Carrier     = nil
SND.Bomb.PlantedSite = nil
SND.Bomb.PlantPos    = nil   -- exact world pos where bomb was placed (crosshair trace)
SND.Bomb.DefuseEnd   = 0
SND.Bomb.PlantTime   = nil
SND.Bomb.PropEnt     = nil

if SERVER then
	util.AddNetworkString("SND_Bomb")
	util.AddNetworkString("SND_BombProgress")
end

local FUSE_TIME = 45  -- seconds until detonation

-- ── CSS beep sound ────────────────────────────────────────────────────────
-- CS:S ships this at sound/weapons/c4/c4_beep1.wav
-- If CS:S is not mounted fall back to a stock GMod click
local BEEP_SOUND = "weapons/c4/c4_beep1.wav"
local PLANT_SOUND = "weapons/c4/c4_plant.wav"

-- Beep interval ramps from 1 s → 0.2 s over the fuse duration
local function beepInterval(elapsed)
	local frac = math.Clamp(elapsed / FUSE_TIME, 0, 1)
	return math.max(0.2, 1.0 - frac * 0.8)
end

local function startBeepTimer()
	timer.Remove("SND_BombBeep")

	local function scheduleNext()
		if SND.Bomb.State ~= SND.BOMB_STATE_PLANTED or not SND.Bomb.PlantTime then return end
		local elapsed  = CurTime() - SND.Bomb.PlantTime
		local interval = beepInterval(elapsed)

		-- Emit from bomb position so players can hear where it is
		for _, ply in ipairs(player.GetAll()) do
			if IsValid(ply) then
				ply:EmitSound(BEEP_SOUND, 75, 100, 1.0)
			end
		end

		timer.Create("SND_BombBeep", interval, 1, scheduleNext)
	end

	scheduleNext()
end

local function stopBeepTimer()
	timer.Remove("SND_BombBeep")
end

-- ── Sites helper ──────────────────────────────────────────────────────────
local function getSites()
	local map = game.GetMap()
	local t   = SND.Config.MapSites[map]
	if not t or #t == 0 then
		local o = Vector(0, 0, 0)
		for _, e in ipairs(ents.FindByClass("info_player_start")) do o = e:GetPos() break end
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
		local d = ply:GetPos():Distance2D(s.plantPos)
		if not best or d < best then best, bi = d, i end
	end
	return bi, sites[bi], best
end

-- ── Ground-look trace ─────────────────────────────────────────────────────
-- Returns the hit position if the player's crosshair is pointing at a
-- roughly horizontal surface within reach, otherwise returns nil.
local PLANT_REACH   = 120  -- max distance in front of player
local GROUND_DOT    = 0.65 -- surface normal dot with up-vector threshold
                           -- (0.65 ≈ within ~50° of flat ground)

local function getGroundPlantPos(ply)
	local eyePos = ply:EyePos()
	local fwd    = ply:EyeAngles():Forward()

	local tr = util.TraceLine({
		start  = eyePos,
		endpos = eyePos + fwd * PLANT_REACH,
		filter = ply,
		mask   = MASK_SOLID_BRUSHONLY,
	})

	if not tr.Hit then return nil, "No surface in reach." end

	-- Surface must face mostly upward (not a wall or ceiling)
	if tr.HitNormal:Dot(Vector(0, 0, 1)) < GROUND_DOT then
		return nil, "Look at the ground to plant."
	end

	return tr.HitPos, nil
end

-- ── Bomb prop (frozen, non-moveable) ─────────────────────────────────────
local function spawnBombProp(pos, isPhysics)
	if IsValid(SND.Bomb.PropEnt) then SND.Bomb.PropEnt:Remove() end

	-- Use prop_physics for dropped bomb, prop_dynamic for planted
	local e = ents.Create(isPhysics and "prop_physics" or "prop_dynamic")
	e:SetModel("models/weapons/w_c4.mdl")
	-- Fallback model if CS:S not mounted
	if not util.IsValidModel(e:GetModel()) then
		e:SetModel("models/props_junk/wood_crate001a.mdl")
	end
	e:SetPos(pos)
	e:SetAngles(Angle(0, 0, 0))
	e:Spawn()
	e:Activate()

	if isPhysics then
		e:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	else
	-- Make it non-solid to players so they don't get stuck on it,
	-- but keep it visible
	e:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	e:SetSolid(SOLID_NONE)
	end

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
	stopBeepTimer()

	-- Networked clear: Force all clients to reset their carrier index
	net.Start("SND_Bomb")
		net.WriteUInt(1, 3)
		net.WriteInt(-1, 16)
	net.Broadcast()

	for _, ply in ipairs(player.GetAll()) do
		timer.Remove("SND_Plant_"  .. ply:EntIndex())
		timer.Remove("SND_Defuse_" .. ply:EntIndex())
		ply.SND_Planting = false
		ply.SND_Defusing = false
	end
end

-- ── Drop bomb ─────────────────────────────────────────────────────────────
function SND.Bomb.Drop(ply)
	if SND.Bomb.State ~= SND.BOMB_STATE_CARRIED or not IsValid(ply) then return end
	
	local pos = ply:GetPos() + Vector(0, 0, 10)
	SND.Bomb.State = SND.BOMB_STATE_DROPPED
	SND.Bomb.Carrier = nil
	
	spawnBombProp(pos, true)
	
	-- Notify clients to clear icons
	net.Start("SND_Bomb")
		net.WriteUInt(1, 3)
		net.WriteInt(-1, 16)
	net.Broadcast()
end

-- ── Pickup logic ──────────────────────────────────────────────────────────
hook.Add("Think", "SND_BombPickupCheck", function()
	if SND.Bomb.State ~= SND.BOMB_STATE_DROPPED or not IsValid(SND.Bomb.PropEnt) then return end
	if SND.Round.Phase ~= SND.PHASE_LIVE then return end
	
	for _, ply in ipairs(player.GetAll()) do
		if ply:Alive() and ply:Team() == SND.TEAM_ATTACK and ply:GetPos():DistToSqr(SND.Bomb.PropEnt:GetPos()) < 4096 then
			SND.Bomb.Carrier = ply
			SND.Bomb.State = SND.BOMB_STATE_CARRIED
			removeBombProp()
			
			-- Sync new carrier to the attackers
			net.Start("SND_Bomb")
				net.WriteUInt(1, 3)
				net.WriteInt(ply:EntIndex(), 16)
			net.Send(team.GetPlayers(SND.TEAM_ATTACK))
			
			ply:ChatPrint("[SND] You picked up the bomb!")
			break
		end
	end
end)

-- ── Assign carrier ────────────────────────────────────────────────────────
function SND.Bomb.AssignCarrier()
	SND.Bomb.ResetForRound()
	SND.Bomb.State = SND.BOMB_STATE_CARRIED

	local humanAttackers = {}
	local botAttackers = {}

	for _, ply in ipairs(team.GetPlayers(SND.TEAM_ATTACK)) do
		if IsValid(ply) and ply:Alive() then
			if ply:IsBot() or ply.SND_IsBot then
				table.insert(botAttackers, ply)
			else
				table.insert(humanAttackers, ply)
			end
		end
	end

	local carrier = nil
	if #humanAttackers > 0 then carrier = table.Random(humanAttackers)
	elseif #botAttackers > 0 then carrier = table.Random(botAttackers) end

	if not IsValid(carrier) then return end -- No valid attacker to assign bomb to

	SND.Bomb.Carrier = carrier

	-- Clear carrier for everyone first
	net.Start("SND_Bomb")
		net.WriteUInt(1, 3)
		net.WriteInt(-1, 16)
	net.Broadcast()

	-- SECURE: Only the attack team receives the carrier EntIndex
	net.Start("SND_Bomb")
		net.WriteUInt(1, 3)
		net.WriteInt(carrier:EntIndex(), 16)
	net.Send(team.GetPlayers(SND.TEAM_ATTACK))
end

-- ── Sync for late joiners ────────────────────────────────────────────────
hook.Add("PlayerInitialSpawn", "SND_BombSync", function(ply)
	timer.Simple(2, function()
		if not IsValid(ply) or ply:Team() ~= SND.TEAM_ATTACK then return end
		if SND.Bomb.State == SND.BOMB_STATE_CARRIED and IsValid(SND.Bomb.Carrier) then
			net.Start("SND_Bomb")
				net.WriteUInt(1, 3)
				net.WriteInt(SND.Bomb.Carrier:EntIndex(), 16)
			net.Send(ply)
		end
	end)
end)

-- ── Plant ─────────────────────────────────────────────────────────────────
function SND.Bomb.TryPlant(ply)
	if SND.Round.Phase ~= SND.PHASE_LIVE       then return end
	if not IsValid(ply)                         then return end
	if ply:Team() ~= SND.TEAM_ATTACK           then return end
	if SND.Bomb.State ~= SND.BOMB_STATE_CARRIED then return end
	if ply ~= SND.Bomb.Carrier                 then return end
	if ply.SND_Planting                        then return end

	-- Must be within the nearest site radius
	local _, site, dist = nearestSite(ply)
	if not site or dist > (site.defuseRadius or 96) + 32 then
		ply:ChatPrint("[SND] Move to a bomb site (A or B) to plant.")
		return
	end

	-- Must be looking at the ground
	local groundPos, err = getGroundPlantPos(ply)
	if not groundPos then
		ply:ChatPrint("[SND] " .. (err or "Look at the ground to plant."))
		return
	end

	local plantTime  = SND.Settings.Get("plant_time", 5)
	ply.SND_Planting = true
	local endTime    = CurTime() + plantTime
	ply.SND_NextPlantBeep = 0

	-- Cache the intended plant position at the start of the plant action
	-- so it doesn't jump around if the player looks away
	local intendedPos = groundPos

	net.Start("SND_BombProgress")
		net.WriteUInt(1, 2)
		net.WriteEntity(ply)
		net.WriteFloat(plantTime)
	net.Send(team.GetPlayers(SND.TEAM_ATTACK))

	local tid = "SND_Plant_" .. ply:EntIndex()
	timer.Create(tid, 0.1, 0, function()
		if not IsValid(ply) or not ply:Alive() then
			SND.Bomb.CancelAction(ply, "plant") return
		end

		-- Cancel if player moves
		if ply:GetVelocity():Length2DSqr() > 10 then
			SND.Bomb.CancelAction(ply, "plant")
			ply:ChatPrint("[SND] Plant cancelled — you moved.")
			return
		end

		-- Cancel if walked out of site
		local _, st2, d2 = nearestSite(ply)
		if not st2 or d2 > (st2.defuseRadius or 96) + 80 then
			SND.Bomb.CancelAction(ply, "plant")
			ply:ChatPrint("[SND] Plant cancelled — left the bomb site.")
			return
		end

		-- Play keypad button noises while planting
		if CurTime() > (ply.SND_NextPlantBeep or 0) then
			ply:EmitSound("weapons/c4/c4_click.wav", 65, math.random(92, 108), 0.6)
			ply.SND_NextPlantBeep = CurTime() + 0.3
		end

		if CurTime() >= endTime then
			timer.Remove(tid)
			if not IsValid(ply) or not ply:Alive() then return end
			if ply ~= SND.Bomb.Carrier then return end

			ply.SND_Planting = false

			SND.Bomb.State       = SND.BOMB_STATE_PLANTED
			SND.Bomb.Carrier     = nil
			SND.Bomb.PlantedSite = (st2 or site).id
			SND.Bomb.PlantPos    = intendedPos   -- exact crosshair point on ground
			SND.Bomb.PlantTime   = CurTime()

			-- XP for planting
			hook.Run("SND_OnBombPlanted", ply)

			-- Spawn locked prop at the exact ground position
			spawnBombProp(intendedPos, false)

			-- Play plant sound at the bomb's location
			if IsValid(SND.Bomb.PropEnt) then
				SND.Bomb.PropEnt:EmitSound(PLANT_SOUND, 75, 100, 1.0)
			end

			-- Start CSS beeping
			startBeepTimer()

			SND.Announcer.BombPlanted()

			net.Start("SND_Bomb")
				net.WriteUInt(2, 3)
				net.WriteVector(intendedPos)
				net.WriteString(SND.Bomb.PlantedSite)
			net.Broadcast()

			net.Start("SND_BombProgress")
				net.WriteUInt(0, 2)
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
	if ply:GetPos():Distance2D(SND.Bomb.PlantPos) > 128 then return end
	if ply.SND_Defusing                        then return end

	ply.SND_Defusing = true
	local defuseTime = SND.Settings.Get("defuse_time", 8)
	local endTime    = CurTime() + defuseTime

	net.Start("SND_BombProgress")
		net.WriteUInt(2, 2)
		net.WriteEntity(ply)
		net.WriteFloat(defuseTime)
	net.Send(team.GetPlayers(SND.TEAM_DEFEND))

	local tid = "SND_Defuse_" .. ply:EntIndex()
	timer.Create(tid, 0.1, 0, function()
		if not IsValid(ply) or not ply:Alive() then
			SND.Bomb.CancelAction(ply, "defuse") return
		end
		if SND.Bomb.State ~= SND.BOMB_STATE_PLANTED then
			SND.Bomb.CancelAction(ply, "defuse") return
		end
		-- Cancel if player moves
		if ply:GetVelocity():Length2DSqr() > 10 then
			SND.Bomb.CancelAction(ply, "defuse")
			ply:ChatPrint("[SND] Defuse cancelled — you moved.")
			return
		end
		if ply:GetPos():Distance2D(SND.Bomb.PlantPos) > 160 then
			SND.Bomb.CancelAction(ply, "defuse")
			ply:ChatPrint("[SND] Defuse cancelled — too far from the bomb.")
			return
		end
		if CurTime() >= endTime then
			timer.Remove(tid)
			ply.SND_Defusing = false

			stopBeepTimer()
			removeBombProp()

			net.Start("SND_BombProgress")
				net.WriteUInt(0, 2)
				net.WriteEntity(ply)
				net.WriteFloat(0)
			net.Broadcast()

			-- XP for defusing
			hook.Run("SND_OnBombDefused", ply)

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

-- Reassign bomb if carrier dies (basic fix)
hook.Add("PlayerDeath", "SND_BombCarrierDeathFix", function(victim)
	if SND.Bomb.State == SND.BOMB_STATE_CARRIED and victim == SND.Bomb.Carrier then
		SND.Bomb.Drop(victim)
	end
end)

-- Authoritative: If a player is no longer an attacker, they CANNOT have the bomb icon
hook.Add("OnPlayerChangedTeam", "SND_BombTeamClearClient", function(ply, oldTeam, newTeam)
	if newTeam ~= SND.TEAM_ATTACK then
		net.Start("SND_Bomb")
			net.WriteUInt(1, 3)
			net.WriteInt(-1, 16)
		net.Send(ply)
	end
end)

-- Ensure only attackers can carry the bomb (reassign if team changes)
hook.Add("OnPlayerChangedTeam", "SND_BombTeamChangeFix", function(ply, oldTeam, newTeam)
	if SND.Bomb.State == SND.BOMB_STATE_CARRIED and ply == SND.Bomb.Carrier then
		if newTeam ~= SND.TEAM_ATTACK then
			SND.Bomb.Carrier = nil
			timer.Simple(1, function() SND.Bomb.AssignCarrier() end)
		end
	end
end)

-- ── Interaction Logic (Key + Bot Support) ────────────────────────────────
local function handleInteraction(ply)
	if not IsValid(ply) or not ply:Alive() then return end
	
	-- Allow cancelling by pressing E again
	if ply.SND_Planting then
		SND.Bomb.CancelAction(ply, "plant")
		ply:ChatPrint("[SND] Plant cancelled.")
		return
	elseif ply.SND_Defusing then
		SND.Bomb.CancelAction(ply, "defuse")
		ply:ChatPrint("[SND] Defuse cancelled.")
		return
	end

	if SND.Bomb.State == SND.BOMB_STATE_CARRIED and ply == SND.Bomb.Carrier then
		SND.Bomb.TryPlant(ply)
	elseif SND.Bomb.State == SND.BOMB_STATE_PLANTED and ply:Team() == SND.TEAM_DEFEND then
		SND.Bomb.TryDefuse(ply)
	end
end

-- Cancel on damage
hook.Add("EntityTakeDamage", "SND_BombCancelOnDmg", function(ent, dmg)
	if not IsValid(ent) or not ent:IsPlayer() then return end
	if ent.SND_Planting then
		SND.Bomb.CancelAction(ent, "plant")
		ent:ChatPrint("[SND] Plant cancelled — took damage.")
	end
	if ent.SND_Defusing then
		SND.Bomb.CancelAction(ent, "defuse")
		ent:ChatPrint("[SND] Defuse cancelled — took damage.")
	end
end)

-- ── Explosion countdown ───────────────────────────────────────────────────
timer.Create("SND_BombExplode", 1, 0, function()
	if SND.Round.Phase ~= SND.PHASE_LIVE        then return end
	if SND.Bomb.State  ~= SND.BOMB_STATE_PLANTED then return end
	if not SND.Bomb.PlantPos or not SND.Bomb.PlantTime then return end

	if CurTime() >= SND.Bomb.PlantTime + FUSE_TIME then
		stopBeepTimer()

		local eff = EffectData()
		eff:SetOrigin(SND.Bomb.PlantPos)
		eff:SetScale(4)
		util.Effect("Explosion", eff)

		for _, ply in ipairs(player.GetAll()) do
			if IsValid(ply) and ply:Alive() then
				local d = ply:GetPos():Distance(SND.Bomb.PlantPos)
				if d < 2000 then
					util.ScreenShake(ply:GetPos(), 20 * (1 - d / 2000), 10, 1.5, 500)
				end
			end
		end

		removeBombProp()
		SND.Bomb.PlantTime = nil
		SND.Round.EndRound(SND.WIN_ATTACK_PLANT)
	end
end)

-- ── Interaction Hooks ────────────────────────────────────────────────────
hook.Add("PlayerButtonDown", "SND_BombUse", function(ply, btn)
	if btn == KEY_E then handleInteraction(ply) end
end)

-- Bots use CUserCmd buttons, so we check IN_USE in a Think hook
timer.Create("SND_BotInteractionCheck", 0.2, 0, function()
	for _, ply in ipairs(player.GetAll()) do
		if ply.SND_IsBot and ply:KeyDown(IN_USE) then
			-- Prevent rapid-fire triggering
			if not ply.SND_Planting and not ply.SND_Defusing then
				handleInteraction(ply)
			end
		end
	end
end)
