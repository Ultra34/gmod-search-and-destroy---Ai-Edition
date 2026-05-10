-- ── Constants & Lookup Tables ──────────────────────────────────────────────
local SCAN_RADIUS     = 16384
local DEFAULT_RELOAD_TIME = 2.5
local TAP_HOLD_BOLT  = 0.15
local TAP_HOLD_SEMI  = 0.07
local SUPPRESS_MIN   = 260
local SUPPRESS_MAX   = 1200

local AIM_ERROR   = { [1] = 8.0,  [2] = 4.0,  [3] = 1.5 }
local NOISE_INTER = { [1] = 0.25, [2] = 0.40, [3] = 0.60 }
local REACT_DELAY = { [1] = 0.70, [2] = 0.38, [3] = 0.15 }
local AIM_THRESH  = { [1] = 0.90, [2] = 0.93, [3] = 0.96 }
local SEMI_SETTLE = { [1] = 0.10, [2] = 0.05, [3] = 0.02 }
local AIM_LERP    = { [1] = 0.12, [2] = 0.25, [3] = 0.55 }

local WEP_RANGE = {
	sniper   = { ideal = 2400, tooClose = 220, tooFar = 8000 },
	ar       = { ideal = 350,  tooClose = 120, tooFar = 800  },
	smg      = { ideal = 160,  tooClose = 50,  tooFar = 400  },
	lmg      = { ideal = 400,  tooClose = 150, tooFar = 900  },
	shotgun  = { ideal = 80,   tooClose = 20,  tooFar = 160  },
	pistol   = { ideal = 200,  tooClose = 80,  tooFar = 500  },
}

-- ── Internal Helpers ───────────────────────────────────────────────────────
local function getSkillBucket(skill)
	if skill <= 3 then return 1 end
	if skill <= 7 then return 2 end
	return 3
end

local function getWepCategory(cls)
	if table.HasValue(SND.Config.BO1_SR or {}, cls) or table.HasValue(SND.Config.MW3_SR or {}, cls) or table.HasValue(SND.Config.COD4E_SR or {}, cls) or table.HasValue(SND.Config.MW2E_SR or {}, cls) or table.HasValue(SND.Config.MW3E_SR or {}, cls) or table.HasValue(SND.Config.BO2_SR or {}, cls) or table.HasValue(SND.Config.WAW_SR or {}, cls) then return "sniper" end
	if table.HasValue(SND.Config.BO1_AR or {}, cls) or table.HasValue(SND.Config.MW3_AR or {}, cls) or table.HasValue(SND.Config.COD4E_AR or {}, cls) or table.HasValue(SND.Config.MW2E_AR or {}, cls) or table.HasValue(SND.Config.MW3E_AR or {}, cls) or table.HasValue(SND.Config.BO2_AR or {}, cls) or table.HasValue(SND.Config.WAW_AR or {}, cls) then return "ar" end
	if table.HasValue(SND.Config.BO1_SMG or {}, cls) or table.HasValue(SND.Config.MW3_SMG or {}, cls) or table.HasValue(SND.Config.COD4E_SMG or {}, cls) or table.HasValue(SND.Config.MW2E_SMG or {}, cls) or table.HasValue(SND.Config.MW3E_SMG or {}, cls) or table.HasValue(SND.Config.BO2_SMG or {}, cls) or table.HasValue(SND.Config.WAW_SMG or {}, cls) then return "smg" end
	if table.HasValue(SND.Config.BO1_LMG or {}, cls) or table.HasValue(SND.Config.MW3_LMG or {}, cls) or table.HasValue(SND.Config.COD4E_LMG or {}, cls) or table.HasValue(SND.Config.MW2E_LMG or {}, cls) or table.HasValue(SND.Config.MW3E_LMG or {}, cls) or table.HasValue(SND.Config.BO2_LMG or {}, cls) or table.HasValue(SND.Config.WAW_LMG or {}, cls) then return "lmg" end
	if table.HasValue(SND.Config.BO1_SG or {}, cls) or table.HasValue(SND.Config.MW3_SG or {}, cls) or table.HasValue(SND.Config.COD4E_SG or {}, cls) or table.HasValue(SND.Config.MW2E_SG or {}, cls) or table.HasValue(SND.Config.MW3E_SG or {}, cls) or table.HasValue(SND.Config.BO2_SG or {}, cls) or table.HasValue(SND.Config.WAW_SG or {}, cls) then return "shotgun" end
	if table.HasValue(SND.Config.BO1_PISTOLS or {}, cls) or table.HasValue(SND.Config.MW3_PISTOLS or {}, cls) or table.HasValue(SND.Config.COD4E_PISTOLS or {}, cls) or table.HasValue(SND.Config.MW2E_PISTOLS or {}, cls) or table.HasValue(SND.Config.MW3E_PISTOLS or {}, cls) or table.HasValue(SND.Config.BO2_PISTOLS or {}, cls) or table.HasValue(SND.Config.WAW_PISTOLS or {}, cls) then return "pistol" end
	return "ar" -- fallback
end

local function getFireMode(wep)
	if not IsValid(wep) then return "auto" end
	if wep.BoltAction or wep.ManualAction then return "bolt" end
	if wep.Semiauto then return "semi" end

	if wep.ARC9 and wep.GetCurrentFiremode then
		local arc9Mode = wep:GetCurrentFiremode()
		if arc9Mode == 1 then return "semi" end
		if arc9Mode > 1  then return "burst" end
	end

	local cat = getWepCategory(wep:GetClass())
	if cat == "sniper" then return "bolt" end
	if cat == "pistol" or cat == "shotgun" then return "semi" end
	
	return "auto"
end

local function isSniper(wep)
	if not IsValid(wep) then return false end
	return getWepCategory(wep:GetClass()) == "sniper"
end

local function glassInLane(bot, tgt)
	if not IsValid(tgt) then return false, nil end
	local tr = util.TraceLine({ start = bot:EyePos(), endpos = tgt:EyePos(), filter = bot, mask = MASK_SHOT })
	if not tr.Hit then return false, nil end
	local ent = tr.Entity
	if not IsValid(ent) then return false, nil end
	local cls = ent:GetClass()
	return (cls == "func_breakable" or cls == "func_breakable_surf" or cls:find("glass", 1, true) or cls:find("window", 1, true)), ent
end

local function addRecoil(ai, wep, dist, skill)
	local mode = getFireMode(wep)
	local bucket = getSkillBucket(skill)
	local burstCount = (mode == "semi" and IsValid(wep)) and (tonumber(wep.BurstCount) or 1) or 1
	local burstScale = (burstCount > 1) and (math.min(burstCount, 4) * 0.65) or 1.0

	local pb = (mode == "bolt" and 1.05) or (mode == "semi" and 0.75 * burstScale) or 0.42
	local sm = ({[1] = 1.18, [2] = 1.0, [3] = 0.84})[bucket] or 1.0
	local rm = 1.0 + math.Clamp(((dist or 300) - 280) / 920, 0, 1) * 0.95

	local pK = pb * sm * rm * math.Rand(0.85, 1.20)
	local yK = pK * math.Rand(0.30, 0.65) * ((math.random(0, 1) == 0) and -1 or 1)

	if (mode == "semi" or mode == "bolt") and (dist or 300) < 260 then
		pK, yK = pK * 0.40, yK * 0.30
	end

	ai.recoilPitch = math.Clamp((ai.recoilPitch or 0) + pK, 0, 7.0)
	ai.recoilYaw   = math.Clamp((ai.recoilYaw   or 0) + yK, -4.8, 4.8)
end

-- ── Targeting ──────────────────────────────────────────────────────────────
function SND.Bots.FindTarget(bot)
	local ai = bot.SND_AI
	local now = CurTime()
	if now < (ai.nextTargetScanAt or 0) then return ai.target end

	local best, bestD = nil, SCAN_RADIUS * SCAN_RADIUS
	local enemies = player.GetAll()
	
	for _, p in ipairs(enemies) do
		if p == bot or not p:Alive() or not SND.Bots.AreEnemies(bot, p) then continue end
		local dsq = bot:GetPos():DistToSqr(p:GetPos())
		if dsq < bestD then bestD = dsq; best = p end
	end
	
	ai.target = best
	ai.nextTargetScanAt = now + (best and 0.10 or 0.18)
	return best
end

-- ── Aiming & Noise ─────────────────────────────────────────────────────────
function SND.Bots.RefreshNoise(bot, dist)
	local ai = bot.SND_AI
	local now = CurTime()
	if now < (ai.nextNoiseAt or 0) then return end

	local skill = SND.Bots.GetSkill()
	local bucket = getSkillBucket(skill)
	local angErr = AIM_ERROR[bucket] or 4.0
	local itvl   = NOISE_INTER[bucket] or 0.40
	local wep    = bot:GetActiveWeapon()

	if isSniper(wep) then angErr, itvl = angErr * 0.10, itvl * 6.0 end

	local d = math.max(40, dist or 300)
	local wErr = math.tan(math.rad(math.max(angErr, 0.05))) * d
	ai.aimNoise = Vector(math.Rand(-wErr, wErr), math.Rand(-wErr, wErr), math.Rand(-wErr * 0.15, wErr * 0.15))
	ai.nextNoiseAt = now + itvl
end

function SND.Bots.ComputeLiveAim(bot)
	local ai = bot.SND_AI
	local now = CurTime()

	if now < (ai.suppressUntil or 0) and ai.suppressPos then
		local ang = (ai.suppressPos + Vector(math.Rand(-26, 26), math.Rand(-26, 26), math.Rand(26, 54)) - bot:EyePos()):Angle()
		ang.p = ang.p - (ai.recoilPitch or 0)
		ang.y = ang.y + (ai.recoilYaw or 0)
		return ang
	end

	local target = ai.target
	if not IsValid(target) or not target:Alive() then
		return ai.lastKnownPos and (ai.lastKnownPos - bot:EyePos()):Angle() or nil
	end

	if now - (ai.lastSeenAt or 0) > 0.9 then
		return ai.lastKnownPos and (ai.lastKnownPos - bot:EyePos()):Angle() or nil
	end

	local dist = bot:GetPos():Distance(target:GetPos())
	local aimPos = target:EyePos() - Vector(0, 0, 13) + (ai.aimNoise or Vector(0, 0, 0))
	local ang = (aimPos - bot:EyePos()):Angle()
	
	ang.p = ang.p - (ai.recoilPitch or 0)
	ang.y = ang.y + (ai.recoilYaw or 0)
	return ang
end

-- ── State Machine Runners ──────────────────────────────────────────────────
local function runGrenadeFSM(bot, cmd, now)
	local ai = bot.SND_AI
	if not ai.grenPhase then return end

	cmd:ClearMovement()
	if ai.grenPhase == 1 then
		if ai.grenClass then bot:SelectWeapon(ai.grenClass) end
		ai.grenPhase, ai.grenPhaseAt = 2, now + 0.5
	elseif ai.grenPhase == 2 and now >= ai.grenPhaseAt then
		if ai.grenTargetPos then
			local ang = (ai.grenTargetPos - bot:EyePos()):Angle()
			bot:SetEyeAngles(ang)
			cmd:SetViewAngles(ang)
		end
		ai.wantAttack = true
		ai.grenPhase, ai.grenPhaseAt = 3, now + math.Rand(0.8, 1.5)
	elseif ai.grenPhase == 3 and now >= ai.grenPhaseAt then
		ai.wantAttack = false
		ai.grenPhase, ai.grenPhaseAt = 4, now + 0.8
	elseif ai.grenPhase == 4 and now >= ai.grenPhaseAt then
		if ai.grenSwitchBackTo then bot:SelectWeapon(ai.grenSwitchBackTo) end
		ai.grenPhase, ai.grenCooldown = nil, now + math.Rand(15, 30)
	end
end

local function runGadgetFSM(bot, cmd, now)
	local ai = bot.SND_AI
	if not ai.gadgetPhase then return end

	cmd:ClearMovement()
	if ai.gadgetPhase == 1 then
		if ai.gadgetWeapon then bot:SelectWeapon(ai.gadgetWeapon) end
		ai.gadgetPhase, ai.gadgetPhaseAt = 2, now + 0.5
	elseif ai.gadgetPhase == 2 and now >= ai.gadgetPhaseAt then
		ai.wantAttack = true
		ai.gadgetPhase, ai.gadgetPhaseAt = 3, now + 1.5
	elseif ai.gadgetPhase == 3 and now >= ai.gadgetPhaseAt then
		ai.wantAttack = false
		if ai.gadgetSwitchBackTo then bot:SelectWeapon(ai.gadgetSwitchBackTo) end
		ai.gadgetPhase, ai.gadgetCooldown = nil, now + 30
	end
end

-- ── Main Combat Loop ───────────────────────────────────────────────────────
function SND.Bots.CombatThink(bot, cmd)
	local ai = bot.SND_AI
	local now = CurTime()
	local skill = SND.Bots.GetSkill()
	local bucket = getSkillBucket(skill)

	-- 1. Recoil Decay
	local dt = now - (ai.recoilLastAt or now)
	ai.recoilLastAt = now
	local decay = 3.0 * dt
	local rPitch, rYaw = ai.recoilPitch or 0, ai.recoilYaw or 0
	ai.recoilPitch = math.max(0, rPitch - decay)
	ai.recoilYaw   = rYaw > 0 and math.max(0, rYaw - decay) or math.min(0, rYaw + decay)

	-- 2. Target & Visibility
	local target = SND.Bots.FindTarget(bot)
	local canSee = SND.Bots.CanSee(bot, target)
	if not canSee then
		local hasGlass, _ = glassInLane(bot, target)
		if hasGlass then canSee = true end
	end

	if canSee then
		ai.lastSeenAt = now
		ai.lastKnownPos = target:GetPos()
	end

	-- 3. FSM Checks
	if ai.grenPhase then runGrenadeFSM(bot, cmd, now) return end
	if ai.gadgetPhase then runGadgetFSM(bot, cmd, now) return end

	-- 4. Engagement Logic
	if IsValid(target) and canSee then
		local dist = bot:GetPos():Distance(target:GetPos())
		local wep = bot:GetActiveWeapon()
		if not IsValid(wep) then return end

		SND.Bots.RefreshNoise(bot, dist)
		local liveAim = SND.Bots.ComputeLiveAim(bot)
		if liveAim then
			local lerp = AIM_LERP[bucket] or 0.25
			ai.aimAngles = LerpAngle(lerp, ai.aimAngles or bot:EyeAngles(), liveAim)
			bot:SetEyeAngles(ai.aimAngles)
			cmd:SetViewAngles(ai.aimAngles)
		end

		-- Firing Logic
		local mode = getFireMode(wep)
		local nextFire = wep:GetNextPrimaryFire()
		local aligned = false
		if ai.aimAngles then
			local toTgt = (target:EyePos() - bot:EyePos()):GetNormalized()
			aligned = ai.aimAngles:Forward():Dot(toTgt) > (AIM_THRESH[bucket] or 0.93)
		end

		if aligned and now >= nextFire then
			if mode == "bolt" then
				ai.tapUntil = now + TAP_HOLD_BOLT
				addRecoil(ai, wep, dist, skill)
				if IsValid(wep) and wep.ARC9 then wep:PlayAnimation("fire") end
				bot:SetAnimation(PLAYER_ATTACK1)
			elseif mode == "semi" then
				if now >= (ai.semiSettleUntil or 0) then
					ai.tapUntil = now + TAP_HOLD_SEMI
					addRecoil(ai, wep, dist, skill)
					ai.semiSettleUntil = now + (SEMI_SETTLE[bucket] or 0.1)
					if IsValid(wep) and wep.ARC9 then wep:PlayAnimation("fire") end
					bot:SetAnimation(PLAYER_ATTACK1)
				end
			else
				ai.wantAttack = true
				addRecoil(ai, wep, dist, skill)
				-- Trigger third-person attack gesture
				if IsValid(wep) and wep.ARC9 then wep:PlayAnimation("fire") end
				bot:SetAnimation(PLAYER_ATTACK1)
			end
		else
			ai.wantAttack = false
		end

		-- Suppression Setup (LMGs)
		if wep:GetClass():find("_lm_", 1, true) and dist > SUPPRESS_MIN and dist < SUPPRESS_MAX then
			if math.random() < 0.05 and now > (ai.nextSuppressAt or 0) then
				ai.suppressUntil = now + math.Rand(1.5, 3.0)
				ai.suppressPos = target:GetPos()
				ai.nextSuppressAt = now + 10
			end
		end
	else
		ai.wantAttack = false
		-- LMG Suppressing a ghost
		if now < (ai.suppressUntil or 0) and ai.suppressPos then
			ai.wantAttack = true
		end
	end

	-- 5. Weapon Maintenance
	SND.Bots.WeaponCheck(bot, cmd)
end

function SND.Bots.WeaponCheck(bot, cmd)
	local wep = bot:GetActiveWeapon()
	if not IsValid(wep) then return end
	local ai = bot.SND_AI

	local clip = wep:Clip1()
	local max = wep:GetMaxClip1()

	-- Emergency Switch
	if clip <= 0 and ai.state == 2 then
		for _, sClass in ipairs(SND.Config.Mw2eSecondaries or {}) do
			local sw = bot:GetWeapon(sClass)
			if IsValid(sw) and sw:Clip1() > 0 then
				bot:SelectWeapon(sClass)
				if sw.ARC9 then sw:Deploy() end
				return
			end
		end
	end

	-- Reloading
	if max > 0 and bot:GetAmmoCount(wep:GetPrimaryAmmoType()) > 0 then
		if clip <= 0 or (clip < max * 0.5 and ai.state ~= 2) then
			cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_RELOAD))
			if wep.ARC9 then wep:Reload() end
		end
	end
end

-- Legacy wrappers for compatibility
function SND.Bots.HandleFiring(bot, cmd, enemy, dist, skill)
	-- Logic moved to SND.Bots.CombatThink
end

function SND.Bots.GetAimVector(bot, target, skill)
	return SND.Bots.ComputeLiveAim(bot)
end