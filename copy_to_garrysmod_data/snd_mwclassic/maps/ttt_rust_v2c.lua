-- garrysmod/data/snd_mwclassic/maps/ttt_rust_v2c.lua
-- Bomb sites for ttt_rust_v2c provided by server owner.
-- Copy this file to:  garrysmod/data/snd_mwclassic/maps/ttt_rust_v2c.lua

return {
	sites = {
		{
			id          = "A",
			plantPos    = Vector(-3470.440918, 1881.995605, 180.214050),
			defuseRadius = 120,
		},
		{
			id          = "B",
			plantPos    = Vector(-2583.791260, 2552.381104, 188.091049),
			defuseRadius = 120,
		},
	},

	-- No spawn override — let ttt_rust_v2c use the auto-layout from snd_rust.lua.
	-- Add spawn entries here if auto-layout feels wrong:
	-- spawns = {
	--     attack = { { pos = Vector(...), ang = Angle(...) }, ... },
	--     defend = { { pos = Vector(...), ang = Angle(...) }, ... },
	-- },
}
