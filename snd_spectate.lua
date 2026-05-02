--[[ Dead players only spectate living teammates (CHASE). M1 / M2 cycle. No enemies. ]]

SND.Spectate = SND.Spectate or {}

local COOLDOWN = 0.35

function SND.Spectate.TeamTargets(ply)
	local out = {}
	if not IsValid(ply) then return out end
	local tm = ply:Team()
	for _, o in ipairs(team.GetPlayers(tm)) do
		if o ~= ply and IsValid(o) and o:Alive() then
			out[#out + 1] = o
		end
	end
	table.sort(out, function(a, b)
		return a:EntIndex() < b:EntIndex()
	end)
	return out
end

function SND.Spectate.ApplyTarget(ply, idx, targets)
	targets = targets or SND.Spectate.TeamTargets(ply)
	if #targets == 0 then
		ply:Spectate(OBS_MODE_ROAMING)
		ply:SpectateEntity(NULL)
		ply.SND_SpecIdx = nil
		return
	end

	idx = math.Clamp(idx or 1, 1, #targets)
	ply.SND_SpecIdx = idx
	ply:Spectate(OBS_MODE_CHASE)
	ply:SpectateEntity(targets[idx])
end

function SND.Spectate.Ensure(ply)
	if not IsValid(ply) or ply:Alive() then return end

	local targets = SND.Spectate.TeamTargets(ply)
	if #targets == 0 then
		if ply:GetObserverMode() ~= OBS_MODE_ROAMING or IsValid(ply:GetObserverTarget()) then
			ply:Spectate(OBS_MODE_ROAMING)
			ply:SpectateEntity(NULL)
		end
		ply.SND_SpecIdx = nil
		return
	end

	local cur = ply:GetObserverTarget()
	local valid = IsValid(cur) and cur:Alive() and cur:Team() == ply:Team() and cur ~= ply

	if not valid then
		SND.Spectate.ApplyTarget(ply, ply.SND_SpecIdx or 1, targets)
		return
	end

	-- Keep index in sync if list order changed
	for i, t in ipairs(targets) do
		if t == cur then
			ply.SND_SpecIdx = i
			return
		end
	end

	SND.Spectate.ApplyTarget(ply, 1, targets)
end

function SND.Spectate.Cycle(ply, dir)
	if not IsValid(ply) or ply:Alive() then return end
	local targets = SND.Spectate.TeamTargets(ply)
	if #targets == 0 then return end

	local idx = (ply.SND_SpecIdx or 1) + dir
	if idx < 1 then idx = #targets end
	if idx > #targets then idx = 1 end

	ply.SND_SpecTap = ply.SND_SpecTap or 0
	if CurTime() < ply.SND_SpecTap then return end
	ply.SND_SpecTap = CurTime() + COOLDOWN

	SND.Spectate.ApplyTarget(ply, idx, targets)
end

hook.Add("KeyPress", "SND_SpectateCycle", function(ply, key)
	if not IsValid(ply) or ply:Alive() then return end
	if not SND.Round.WaitingForSpawn(ply) then return end

	if key == IN_ATTACK then
		SND.Spectate.Cycle(ply, 1)
	elseif key == IN_ATTACK2 then
		SND.Spectate.Cycle(ply, -1)
	end
end)

hook.Add("PlayerDeath", "SND_SpectateTargetDied", function(victim)
	if not IsValid(victim) then return end
	timer.Simple(0, function()
		for _, ply in ipairs(player.GetAll()) do
			if IsValid(ply) and not ply:Alive() and ply:GetObserverTarget() == victim then
				SND.Spectate.Ensure(ply)
			end
		end
	end)
end)
