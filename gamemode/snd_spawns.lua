--[[ Team spawn placement when SND.Config.MapSpawns[map] is defined (data file or Rust auto-layout). ]]

SND.Spawns = SND.Spawns or {}

function SND.Spawns.Apply(ply)
	if not SERVER then return end
	if not IsValid(ply) or not ply:Alive() then return end

	local map = game.GetMap()
	local data = SND.Config.MapSpawns[map]
	
	-- Fallback: If no map data, split all info_player_start entities by location
	if not data then
		local spawns = ents.FindByClass("info_player_start")
		table.sort(spawns, function(a, b) return a:GetPos().x < b:GetPos().x end)
		
		local mid = math.floor(#spawns / 2)
		local attack = {}
		local defend = {}
		for i, ent in ipairs(spawns) do
			if i <= mid then table.insert(attack, { pos = ent:GetPos(), ang = ent:GetAngles() })
			else table.insert(defend, { pos = ent:GetPos(), ang = ent:GetAngles() }) end
		end
		
		data = {
			attack = attack,
			defend = defend
		}
	end

	local side = (ply:Team() == SND.TEAM_ATTACK) and "attack" or "defend"
	local list = data[side]
	if not list or #list == 0 then return end

	-- Attempt to find a spawn point that isn't currently occupied by another player
	local pool = table.Copy(list)
	local pick = nil
	local occupiedRadiusSqr = 48 * 48 -- Distance squared threshold to avoid spawning on others (approx 4ft)

	while #pool > 0 do
		local k = math.random(#pool)
		local candidate = pool[k]

		local isOccupied = false
		for _, other in ipairs(player.GetAll()) do
			if other ~= ply and other:Alive() and other:GetPos():DistToSqr(candidate.pos) < occupiedRadiusSqr then
				isOccupied = true
				break
			end
		end

		if not isOccupied then
			pick = candidate
			break
		end
		table.remove(pool, k)
	end

	-- Fallback if all designated points are crowded, just pick one at random
	if not pick then
		pick = table.Random(list)
	end

	if pick.pos then
		ply:SetPos(pick.pos)
		if pick.ang then
			ply:SetEyeAngles(pick.ang)
		end
	end
end
