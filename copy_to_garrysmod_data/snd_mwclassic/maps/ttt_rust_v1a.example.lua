-- Rename to ttt_rust_v1a.lua to override auto-generated bomb sites / spawns for Workshop map [TTT] Rust.
-- Subscribe: https://steamcommunity.com/sharedfiles/filedetails/?id=2922376072
-- BSP name: ttt_rust_v1a
--
-- Uncomment and edit Vectors after using in-game:
--   snd_rust_dump_spawn_line   (SuperAdmin — prints one spawn entry)
--   snd_rust_dump_site_vectors (SuperAdmin — prints plant position at feet)

--[[
return {
	sites = {
		{ id = "A", plantPos = Vector(0, 0, 0), defuseRadius = 120 },
		{ id = "B", plantPos = Vector(0, 0, 0), defuseRadius = 120 },
	},
	spawns = {
		attack = {
			{ pos = Vector(0, 0, 0), ang = Angle(0, 90, 0) },
		},
		defend = {
			{ pos = Vector(0, 0, 0), ang = Angle(0, -90, 0) },
		},
	},
}
]]

return {}
