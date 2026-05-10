SND.Bots = SND.Bots or {}

function SND.Bots.AreEnemies(ply1, ply2)
	if not IsValid(ply1) or not IsValid(ply2) then return false end
	return ply1:Team() ~= ply2:Team()
end

function SND.Bots.CanSee(bot, target)
	if not IsValid(target) then return false end
	local tr = util.TraceLine({
		start  = bot:GetShootPos(),
		endpos = target:EyePos(),
		filter = { bot, target },
		mask   = MASK_SHOT_HULL,
	})
	return tr.Entity == target or tr.Fraction >= 0.99
end

function SND.Bots.GetSkill()
	return SND.Settings.GetInt("bot_skill", 5)
end

-- Skill 1-10 -> internal float 0-1
function SND.Bots.SkillT(s)
	return (math.Clamp(s, 1, 10) - 1) / 9
end