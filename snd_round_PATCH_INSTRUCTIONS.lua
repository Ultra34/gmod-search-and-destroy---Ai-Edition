-- ════════════════════════════════════════════════════════════════════
--  snd_round.lua  PATCH  (two lines to add — do NOT replace the file)
-- ════════════════════════════════════════════════════════════════════
--
-- CHANGE 1 — Inside SND.Round.StartNewRound(), after the line:
--
--   SND.Announcer.RoundFreeze()
--
-- Add this line immediately after it:
--
--   hook.Run("SND_RoundStart_Freeze")    -- opens gun picker for all humans
--
-- ────────────────────────────────────────────────────────────────────
-- CHANGE 2 — Inside SND.Round.EndRound(), after the line:
--
--   SND.Announcer.OnRoundEnd(reason)
--
-- Add this line immediately after it:
--
--   hook.Run("SND_RoundEnd", reason)     -- lets other modules react
--
-- ════════════════════════════════════════════════════════════════════
-- CHANGE 3 — In init.lua, add these two lines alongside the other
--            AddCSLuaFile / include calls:
--
--   AddCSLuaFile("cl_gunpicker.lua")     -- add near the top with others
--   ...
--   include("snd_loadout.lua")           -- already present, no change
--
-- And in cl_init.lua, add:
--   include("cl_gunpicker.lua")          -- after include("cl_hud.lua")
--
-- ════════════════════════════════════════════════════════════════════
--
-- That is the complete diff.  The gun picker, bomb progress bar, and
-- SND_RoundEnd hook all wire up automatically once those two hook.Run
-- calls exist in snd_round.lua.
--
-- ════════════════════════════════════════════════════════════════════

-- For reference, here is the exact context in StartNewRound where you insert:

--[[
    SND.Announcer.RoundFreeze()
    hook.Run("SND_RoundStart_Freeze")   -- ← ADD THIS LINE

    for _, ply in ipairs(player.GetAll()) do
        ply:Spawn()
    end
--]]

-- And in EndRound:

--[[
    SND.Announcer.OnRoundEnd(reason)
    hook.Run("SND_RoundEnd", reason)    -- ← ADD THIS LINE

    local lim = SND.Settings.GetInt("win_limit", 4)
--]]
