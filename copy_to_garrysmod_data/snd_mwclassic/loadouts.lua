-- Optional: garrysmod/data/snd_mwclassic/loadouts.lua
-- Override defaults; use arc9_cod4e_* classes from your ARC9 COD4 pack.

--[[ Example (uncomment to use fixed guns instead of random pools):

SND.Config.DefaultLoadouts = {
	attack = {
		random_primary = false,
		random_secondary = false,
		primary = "arc9_cod4e_m4m16",
		secondary = "arc9_cod4e_m9",
		lethal = "arc9_cod4e_frag",
		tactical = "",
	},
	defend = {
		random_primary = false,
		random_secondary = false,
		primary = "arc9_cod4e_ak47",
		secondary = "arc9_cod4e_usp",
		lethal = "arc9_cod4e_frag",
		tactical = "",
	},
}
]]
