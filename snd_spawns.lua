--[[ Team spawn placement when SND.Config.MapSpawns[map] is defined (data file or Rust auto-layout). ]]

SND.Spawns = SND.Spawns or {}

function SND.Spawns.Apply(ply)
	if not SERVER then return end
	if not IsValid(ply) or not ply:Alive() then return end

	local map = game.GetMap()
	local data = SND.Config.MapSpawns[map]
	if not data then return end

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
