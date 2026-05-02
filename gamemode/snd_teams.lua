--[[ Faction models / names ]]

SND.Teams = SND.Teams or {}

function SND.Teams.ApplyFactionModel(ply)
	if not IsValid(ply) then return end
	local t = ply:Team()
	local fac = (t == SND.TEAM_ATTACK) and SND.Config.Factions.attack or SND.Config.Factions.defend
	if not fac or not fac.models or #fac.models == 0 then return end
	ply:SetModel(table.Random(fac.models))
end
