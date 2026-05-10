-- ============================================================
-- SND Bots / bot_nav.lua
-- Navigation: A* path planning + waypoint management.
-- Integrated from advanced navigation system.
-- ============================================================

local NAV_UPDATE_CHASE  = 0.25
local NAV_UPDATE_ROAM   = 2.00
local CHASE_REPATH_DIST     = 90
local CHASE_REPATH_DIST_SQR = CHASE_REPATH_DIST * CHASE_REPATH_DIST
local WAYPOINT_REACH_3D     = 100
local WAYPOINT_REACH_3D_SQR = WAYPOINT_REACH_3D * WAYPOINT_REACH_3D
local MAX_ASTAR_ITER = 6000
local PATH_CACHE_TTL = 3.0
local ROAM_SAMPLES         = 28
local ROAM_MIN_DIST        = 700
local VISIT_DECAY_PER_SEC  = 0.04
local STUCK_THRESHOLD  = 0.55
local JUMP_COOLDOWN    = 0.80
local VAULT_CHECK_DIST = 56
local DOOR_TRACE_DIST  = 85
local DOOR_USE_COOLDOWN = 0.8
local LADDER_HEIGHT_THRESH = 80

local DOOR_CLASSES = {
	["func_door"]          = true,
	["func_door_rotating"] = true,
	["prop_door_rotating"] = true,
}

-- ── Nav area cache + global state ────────────────────────────
local _navAreaCache  = nil
local _navCacheBuiltAt = 0
local _visitCount    = {}
local _visitLastDecay = 0
local _pathCache     = {}
local _pathCacheCount = 0

local function _DecayVisits(now)
	if now - _visitLastDecay < 1.0 then return end
	local dt = now - _visitLastDecay
	_visitLastDecay = now
	local drop = VISIT_DECAY_PER_SEC * dt
	for id, v in pairs(_visitCount) do
		local nv = v - drop
		if nv <= 0.05 then _visitCount[id] = nil else _visitCount[id] = nv end
	end
end

local function _PrunePathCache(now)
	if _pathCacheCount < 64 then return end
	for k, v in pairs(_pathCache) do
		if now >= (v.expire or 0) then
			_pathCache[k] = nil
			_pathCacheCount = _pathCacheCount - 1
		end
	end
end

local function _EnsureNavCache()
	local now = CurTime()
	if not _navAreaCache or #_navAreaCache == 0 or (now - _navCacheBuiltAt) > 60 then
		_navAreaCache = navmesh.GetAllNavAreas() or {}
		_navCacheBuiltAt = now
	end
	return _navAreaCache
end

local function IsDeadEndArea(area)
	if not area then return false end
	if area:IsBlocked() then return true end
	local adj = area:GetAdjacentAreas()
	if #adj == 0 then return true end
	if #adj == 1 then return true end
	if #adj == 2 then
		local sx = area:GetSizeX()
		local sy = area:GetSizeY()
		if sx < 100 and sy < 100 then return true end
	end
	return false
end

local function _MarkVisited(pos)
	if not navmesh or navmesh.GetNavAreaCount() == 0 then return end
	local area = navmesh.GetNearestNavArea(pos, true, 200, false, false)
	if not area then return end
	local id = area:GetID()
	_visitCount[id] = (_visitCount[id] or 0) + 1
end

-- ── Min-heap (priority queue for A*) ─────────────────────────
local function heapPush(h, item, priority)
	local n = #h + 1
	h[n] = { item = item, p = priority }
	local i = n
	while i > 1 do
		local parent = (i - i % 2) / 2
		if h[parent].p > h[i].p then h[i], h[parent] = h[parent], h[i]; i = parent
		else break end
	end
end

local function heapPop(h)
	if #h == 0 then return nil end
	local top = h[1].item
	h[1] = h[#h]; h[#h] = nil
	local i, n = 1, #h
	while true do
		local l, r, m = 2*i, 2*i+1, i
		if l <= n and h[l].p < h[m].p then m = l end
		if r <= n and h[r].p < h[m].p then m = r end
		if m == i then break end
		h[i], h[m] = h[m], h[i]; i = m
	end
	return top
end

local function SnapToNavArea(pos)
	if not navmesh or navmesh.GetNavAreaCount() == 0 then return nil end
	local a = navmesh.GetNearestNavArea(pos, true, 500, false, false)
	if a then return a end
	a = navmesh.GetNearestNavArea(pos, false, 2000, false, false)
	if a then return a end
	local cache = _EnsureNavCache()
	if not cache or #cache == 0 then return nil end
	local best, bestD = nil, math.huge
	for i = 1, #cache do
		local c = cache[i]
		if c then
			local d = c:GetCenter():DistToSqr(pos)
			if d < bestD then bestD = d; best = c end
		end
	end
	return best
end

-- ── A* path builder ────────────────────────────────────────────
local function BuildNavPath(fromPos, toPos)
	if not navmesh or navmesh.GetNavAreaCount() == 0 then return { toPos } end
	local startArea = SnapToNavArea(fromPos)
	local endArea   = SnapToNavArea(toPos)
	if not startArea or not endArea then return { toPos } end
	if startArea == endArea then return { toPos } end

	local now      = CurTime()
	local cacheKey = startArea:GetID() .. ":" .. endArea:GetID()
	local cached   = _pathCache[cacheKey]
	if cached and now < cached.expire and cached.areaList then
		local path = {}
		local prevPoint = fromPos
		for _, area in ipairs(cached.areaList) do
			local wp = area:GetClosestPointOnArea(prevPoint)
			path[#path + 1] = wp
			prevPoint = wp
		end
		path[#path + 1] = toPos
		return path
	end

	local endID     = endArea:GetID()
	local endCenter = endArea:GetCenter()
	local openHeap = {}
	local gScore   = {}
	local prev     = {}
	local closed   = {}
	gScore[startArea:GetID()] = 0
	heapPush(openHeap, startArea, startArea:GetCenter():Distance(endCenter))
	local found, iter  = nil, 0
	while #openHeap > 0 and iter < MAX_ASTAR_ITER do
		iter = iter + 1
		local cur = heapPop(openHeap)
		if not cur then break end
		local curID = cur:GetID()
		if curID == endID then found = cur; break end
		if closed[curID] then continue end
		closed[curID] = true
		local g = gScore[curID] or 0
		for _, nb in ipairs(cur:GetAdjacentAreas()) do
			local nbID = nb:GetID()
			if closed[nbID] or nb:IsBlocked() then continue end
			local penalty = (IsDeadEndArea(nb) and nbID ~= endID) and 4500 or 0
			local hChange = cur:ComputeAdjacentConnectionHeightChange(nb)
			if hChange > 18 then penalty = penalty + hChange * 12 end
			local newG = g + cur:GetCenter():Distance(nb:GetCenter()) + penalty
			if newG < (gScore[nbID] or math.huge) then
				gScore[nbID] = newG
				prev[nbID]   = cur
				heapPush(openHeap, nb, newG + nb:GetCenter():Distance(endCenter))
			end
		end
	end

	if not found then
		local bestID, bestH = nil, math.huge
		for id, _ in pairs(gScore) do
			local area = navmesh.GetNavAreaByID(id)
			if area then
				local h = area:GetCenter():DistToSqr(endCenter)
				if h < bestH then bestH = h; bestID = id end
			end
		end
		if bestID and bestID ~= startArea:GetID() then found = navmesh.GetNavAreaByID(bestID) else return { toPos } end
	end

	local areaList = {}
	local cur = found
	while prev[cur:GetID()] do table.insert(areaList, 1, cur); cur = prev[cur:GetID()] end
	_pathCache[cacheKey] = { areaList = areaList, expire = now + PATH_CACHE_TTL }
	_pathCacheCount = _pathCacheCount + 1
	_PrunePathCache(now)

	local path = {}
	local prevPoint = fromPos
	for _, area in ipairs(areaList) do
		local wp = area:GetClosestPointOnArea(prevPoint)
		table.insert(path, wp)
		prevPoint = wp
	end
	table.insert(path, toPos)
	return path
end

-- ── High-level Nav Helpers ─────────────────────────────────────

local function CheckDoorAhead(bot, ai, now, goal)
	if not goal or now < (ai.nextDoorCheck or 0) then return end
	ai.nextDoorCheck = now + 0.30
	local toGoal = goal - bot:GetPos(); toGoal.z = 0
	if toGoal:LengthSqr() < 50*50 then return end
	toGoal:Normalize()
	local tr = util.TraceLine({
		start  = bot:EyePos(),
		endpos = bot:EyePos() + toGoal * DOOR_TRACE_DIST,
		filter = bot,
		mask   = MASK_SOLID,
	})
	if tr.Hit and IsValid(tr.Entity) and DOOR_CLASSES[tr.Entity:GetClass()] then
		if now >= (ai.lastDoorUseAt or 0) + DOOR_USE_COOLDOWN then
			ai.wantUse = true
			ai.lastDoorUseAt = now
		end
	end
end

local function TryVaultWindow(bot, ai, cmd, goal, now)
	if not goal or now < (ai.nextVaultCheck or 0) or not bot:IsOnGround() or now < (ai.nextJumpAllowed or 0) then return false end
	ai.nextVaultCheck = now + 0.40
	local toGoal = goal - bot:GetPos(); toGoal.z = 0
	if toGoal:LengthSqr() < 120*120 then return false end
	toGoal:Normalize()
	local chest = bot:GetPos() + Vector(0,0,40)
	local trLow = util.TraceLine({start=chest, endpos=chest+toGoal*VAULT_CHECK_DIST, filter=bot, mask=MASK_PLAYERSOLID})
	if not trLow.Hit then return false end
	local cls = IsValid(trLow.Entity) and trLow.Entity:GetClass() or ""
	local isWindowLike = cls=="func_breakable" or cls=="func_breakable_surf" or cls:find("glass",1,true) or cls:find("window",1,true)
	if not isWindowLike and trLow.HitWorld then
		local h = trLow.HitPos.z - bot:GetPos().z
		if h < 16 or h > 72 then return false end
	elseif not isWindowLike then return false end
	local trHi = util.TraceLine({start=bot:GetPos()+Vector(0,0,62), endpos=bot:GetPos()+Vector(0,0,62)+toGoal*72+Vector(0,0,18), filter=bot, mask=MASK_PLAYERSOLID})
	if trHi.Hit then return false end
	cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_JUMP))
	ai.nextJumpAllowed = now + JUMP_COOLDOWN
	return true
end

function SND.Bots.MoveToward(bot, cmd, targetPos, speed)
	if not isvector(targetPos) then return 0 end
	local ai = bot.SND_AI
	local myPos = bot:GetPos()
	local now = CurTime()

	if not navmesh.IsLoaded() then
		cmd:ClearMovement()
		return myPos:Distance(targetPos)
	end

	if now >= (ai.nextVisitMark or 0) then
		ai.nextVisitMark = now + 1.0
		_MarkVisited(myPos)
	end

	-- ── Rebuild A* path ───────────────────────────────────────
	local chasingLive = IsValid(ai.target) and ai.target:Alive() and SND.Bots.CanSee(bot, ai.target)
	local navInterval = chasingLive and NAV_UPDATE_CHASE or NAV_UPDATE_ROAM
	local repathDistSqr = chasingLive and CHASE_REPATH_DIST_SQR or (160*160)
	local destChanged = (not ai.lastNavDest) or ai.lastNavDest:DistToSqr(targetPos) > repathDistSqr

	if now >= (ai.nextNav or 0) or not ai.navPath or destChanged then
		ai.nextNav     = now + navInterval
		ai.lastNavDest = targetPos
		
		local useDirect = false
		if chasingLive then
			local trFeet = util.TraceHull({
				start  = myPos + Vector(0,0,18),
				endpos = targetPos + Vector(0,0,18),
				filter = bot,
				mask   = MASK_PLAYERSOLID,
				mins   = Vector(-12,-12,0),
				maxs   = Vector( 12, 12,48),
			})
			useDirect = not trFeet.Hit
		end
		ai.navPath = useDirect and { targetPos } or BuildNavPath(myPos, targetPos)
		ai.navStep = 1
	end

	-- ── Advance through waypoints ────────────────────────────
	local path = ai.navPath or { targetPos }
	local step = ai.navStep or 1
	while path[step] do
		if (myPos - path[step]):LengthSqr() < WAYPOINT_REACH_3D_SQR then
			step = step + 1
		else break end
	end
	ai.navStep = step
	local rawGoal = path[step] or targetPos

	-- ── Stuck Logic ──────────────────────────────────────────
	if not ai.stuckSnapshotPos then
		ai.stuckSnapshotPos = myPos
		ai.stuckSnapshotAt  = now
	elseif now - ai.stuckSnapshotAt >= STUCK_THRESHOLD then
		local sdx = myPos.x - ai.stuckSnapshotPos.x
		local sdy = myPos.y - ai.stuckSnapshotPos.y
		local movedEnough = (sdx * sdx + sdy * sdy) >= 80 * 80
		ai.stuckSnapshotPos = myPos
		ai.stuckSnapshotAt  = now
		if not movedEnough then
			ai.stuckCount = (ai.stuckCount or 0) + 1
			if ai.stuckCount == 1 then
				cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_JUMP))
				ai.nextJumpAllowed = now + JUMP_COOLDOWN
				ai.strafeDir = (math.random(0,1) == 0) and 250 or -250
				ai.nextStrafeFlip = now + 0.5
			elseif ai.stuckCount >= 2 then
				ai.navPath = nil
				ai.nextNav = now
				ai.stuckCount = 0
			end
		else
			ai.stuckCount = 0
		end
	end

	-- ── Obstacle Avoidance ───────────────────────────────────
	CheckDoorAhead(bot, ai, now, rawGoal)
	TryVaultWindow(bot, ai, cmd, rawGoal, now)

	-- Ladder Logic
	local hDiff = rawGoal.z - myPos.z
	if hDiff > LADDER_HEIGHT_THRESH then
		if bot:IsOnGround() and now >= (ai.nextJumpAllowed or 0) then
			cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_JUMP))
			ai.nextJumpAllowed = now + 0.5
		end
	end

	-- ── Movement Application ─────────────────────────────────
	local goal = rawGoal
	if now >= (ai.nextWanderFlip or 0) then
		ai.nextWanderFlip = now + math.Rand(0.5, 1.5)
		ai.wanderOffset = math.Rand(-110, 110)
	end
	local wander = ai.wanderOffset or 0
	if math.abs(wander) > 10 and myPos:Distance(goal) > 150 then
		local toGoal = (goal - myPos):GetNormalized()
		local left = Vector(-toGoal.y, toGoal.x, 0)
		goal = goal + left * wander
	end

	-- View Angles
	local distToGoal = goal:Distance(myPos)
	if ai.state ~= 2 and distToGoal > 15 then
		local goalAngle = (goal - myPos):Angle()
		if now > (ai.nextScan or 0) then
			ai.isScanning = math.random() < 0.4
			ai.scanOffset = ai.isScanning and math.random(-60, 60) or 0
			ai.nextScan = now + math.Rand(0.5, 2.0)
		end
		local targetYaw = goalAngle.y + (ai.scanOffset or 0)
		local curAng = bot:EyeAngles()
		local diff = math.NormalizeAngle(targetYaw - curAng.y)
		curAng.y = curAng.y + diff * (ai.isScanning and 0.05 or 0.15)
		bot:SetEyeAngles(curAng)
		cmd:SetViewAngles(curAng)
	end

	-- Convert movement to cmd space
	local moveYaw = (goal - myPos):Angle().y
	local viewYaw = cmd:GetViewAngles().y
	local diff = math.NormalizeAngle(moveYaw - viewYaw)
	local moveFwd = math.cos(math.rad(diff)) * speed
	local moveSide = math.sin(math.rad(diff)) * speed
	
	cmd:SetForwardMove(moveFwd)
	cmd:SetSideMove(moveSide)

	return myPos:Distance(targetPos)
end