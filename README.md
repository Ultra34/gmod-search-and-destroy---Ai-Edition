# Search & Destroy (ARC9 MW Classic)

Garry’s Mod **gamemode** inspired by Call of Duty Search & Destroy: one life per round, bomb plant/defuse, team scores, optional map voting, Lua-driven bots, and loadouts aimed at **[ARC9](https://steamcommunity.com/workshop/filedetails/?id=2910505837)** with the **Modern Warfare Classic** weapon pack (install separately from the Workshop).

**Repository:** [Ultra34/gmod-search-and-destroy---Ai-Edition](https://github.com/Ultra34/gmod-search-and-destroy---Ai-Edition)

---

## Requirements

- Garry’s Mod (dedicated or listen server)
- **ARC9** base and your **[ARC9] Modern Warfare Classic** (or compatible) SWEPs  
  Weapon **class names** must match what you put in ConVars or `data/snd_mwclassic/loadouts.lua`. Use the spawn menu or `gm_giveswep` to confirm names.
- Custom announcer audio is optional: place files under `garrysmod/sound/snd_mwclassic/announcer/` to match paths in `gamemode/snd_config.lua`.

---

## Installation

1. Clone or download this repo.
2. Copy the **`snd_mwclassic`** folder (the one that contains `gamemode.txt` and `gamemode/`) into:
   ```
   garrysmod/gamemodes/snd_mwclassic
   ```
3. Copy the contents of **`copy_to_garrysmod_data/snd_mwclassic/`** into:
   ```
   garrysmod/data/snd_mwclassic/
   ```
   Edit **`maps.txt`** for map voting (one map name per line, no `.bsp`).
4. Start the gamemode from the main menu, or on a server:
   ```
   gamemode snd_mwclassic
   map gm_construct
   ```

---

## Controls & rules

| Action | Default |
|--------|--------|
| Plant bomb (attacker with bomb, in site) | Hold **E** in radius |
| Defuse (defender, on planted bomb) | Hold **E** near bomb |
| Sprint | **Shift** (speed uses `snd_sprint_mult`) |

- **Freeze** at round start, then **live** play. **Defenders** win if time runs out. **Attackers** win if the bomb detonates. Elimination wins if one team is wiped.
- Bomb fuse after plant: **45 seconds** (see `gamemode/snd_bomb.lua` to change).

---

## Configuration

### Bomb sites & factions

Edit **`gamemode/snd_config.lua`**:

- **`SND.Config.MapSites`** — per-map A/B (or more) sites: `plantPos`, `defuseRadius`, `id`.  
  Unknown maps fall back to offsets from `info_player_start` (good for testing only).
- **`SND.Config.Factions`** — team display names and player `models/` lists.
- **`SND.Config.Announcer`** — sound filenames under `sound/snd_mwclassic/announcer/`.

### Loadouts (ARC9)

1. **`garrysmod/data/snd_mwclassic/loadouts.lua`** (optional) — see the example in **`copy_to_garrysmod_data`**. Loaded on server start.
2. ConVars (server / cfg):
   - `snd_loadout_attack_pri`, `snd_loadout_attack_sec`
   - `snd_loadout_defend_pri`, `snd_loadout_defend_sec`  
   Non-empty values override defaults in `snd_config.lua`.

### Main gameplay ConVars (`snd_*`)

| ConVar | Role |
|--------|------|
| `snd_walk_speed`, `snd_run_speed` | Movement |
| `snd_sprint_mult` | Sprint multiplier while holding **Shift** on ground |
| `snd_air_accel_scale` | Air control tweak |
| `snd_round_time` | Seconds per round (after freeze) |
| `snd_freeze_time` | Pre-round freeze |
| `snd_plant_time`, `snd_defuse_time` | Bomb timers |
| `snd_win_limit` | Rounds needed to win match |
| `snd_bot_count` | Number of `player.CreateNextBot` bots |
| `snd_bot_skill` | 0.15–1 (aim / strafe noise) |
| `snd_team_balance` | `1` shuffles players when team counts differ by more than one |
| `snd_mapvote_enabled`, `snd_mapvote_time` | End-of-match vote using `data/snd_mwclassic/maps.txt` |
| `snd_announcer_volume`, `snd_hud_scale` | Client-facing / replicated tuning |

### In-game settings menu

- **SuperAdmin:** chat **`!snd_settings`** or console **`snd_open_settings`**
- Also under **Utilities → SND → S&D Settings** (spawn menu tools tab)

Changes are applied on the **server** via network messages.

### Admin / console

- **`snd_start_mapvote`** — SuperAdmin: start a map vote manually.

---

## Bots

Bots use **`player.CreateNextBot`**. Your server must allow bot creation (listen server usually does; dedicated servers may need appropriate settings). They are **Lua-assisted** (aim, fire, move toward enemies, bomb carrier sprints); they are **not** parity with AAA FPS AI.

---

## Map voting

- Candidates come only from **`garrysmod/data/snd_mwclassic/maps.txt`**.
- Lines starting with `#` are comments.
- After a match win, a vote runs (if enabled); if no custom vote tally is implemented, the server picks a random candidate from the list after `snd_mapvote_time` seconds (see `gamemode/snd_mapvote.lua` to extend with real player votes).

---

## License

No license file is included by default. Add one (e.g. MIT) in the repo if you want others to reuse the code under clear terms.

---

## Contributing

Issues and pull requests are welcome on [GitHub](https://github.com/Ultra34/gmod-search-and-destroy---Ai-Edition).
