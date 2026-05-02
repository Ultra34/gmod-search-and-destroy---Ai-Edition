-- garrysmod/data/snd_mwclassic/loadouts.lua
-- Optional: uncomment and edit to lock both teams to fixed weapons
-- instead of drawing from the random iw4_ pools in snd_config.lua.

--[[
SND.Config.DefaultLoadouts = {
	attack = {
		random_primary   = false,
		random_secondary = false,
		primary          = "iw4_ak47",
		secondary        = "iw4_deserteagle",
		lethal           = "weapon_frag",
		tactical         = "",
	},
	defend = {
		random_primary   = false,
		random_secondary = false,
		primary          = "iw4_m4a1",
		secondary        = "iw4_usp",
		lethal           = "weapon_frag",
		tactical         = "",
	},
}
]]
