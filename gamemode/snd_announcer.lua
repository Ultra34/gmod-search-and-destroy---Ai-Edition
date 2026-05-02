--[[ Announcer — drop sounds under garrysmod/sound/snd_mwclassic/announcer/ ]]

SND.Announcer = SND.Announcer or {}

local function playAll(rel)
	local cfg = SND.Config.Announcer
	local path = cfg.prefix .. rel
	local vol = SND.Settings.Get("announcer_volume", 1)

	for _, p in ipairs(player.GetAll()) do
		p:EmitSound(path, 75, 100, vol)
	end
end

function SND.Announcer.RoundFreeze()
	local s = SND.Config.Announcer.sounds.round_start
	if s then playAll(s) end
end

function SND.Announcer.RoundLive()
end

function SND.Announcer.BombPlanted()
	local s = SND.Config.Announcer.sounds.bomb_planted
	if s then playAll(s) end
end

function SND.Announcer.LastMan()
	local s = SND.Config.Announcer.sounds.last_alive
	if s then playAll(s) end
end

function SND.Announcer.OnRoundEnd(reason)
	local s
	if reason == SND.WIN_ATTACK_ELIM or reason == SND.WIN_ATTACK_PLANT then
		s = SND.Config.Announcer.sounds.attack_win
	elseif reason == SND.WIN_DEFEND_ELIM or reason == SND.WIN_DEFEND_DEFUSE or reason == SND.WIN_TIME then
		s = SND.Config.Announcer.sounds.defend_win
	end
	if s then playAll(s) end
end

function SND.Announcer.OnDeathContext(victim, attacker)
end
