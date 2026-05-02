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

	local pick = table.Random(list)
	if pick.pos then
		ply:SetPos(pick.pos)
		if pick.ang then
			ply:SetEyeAngles(pick.ang)
		end
	end
end
