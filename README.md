# Search & Destroy (ARC9 MW2)

Garry’s Mod **gamemode** inspired by Call of Duty Search & Destroy: one life per round, bomb plant/defuse, team scores, optional map voting, Lua-driven bots, **team-only spectating** (mouse **M1** / **M2** to cycle living teammates), and **ARC9 MW2 Extended** (`arc9_mw2e_*`) random primaries/secondaries from configurable pools (override via `data/snd_mwclassic/loadouts.lua` or `snd_loadout_*` ConVars).

**Repository:** [Ultra34/gmod-search-and-destroy---Ai-Edition](https://github.com/Ultra34/gmod-search-and-destroy---Ai-Edition)

**Full setup walkthrough:** see **`INSTALLATION.txt`** in this folder (paths, Workshop, `data/`, ConVars, Rust map, troubleshooting).

---

## Requirements

- Garry’s Mod (dedicated or listen server)
- **ARC9** base and **MW2 Extended** (`arc9_mw2e_*`) SWEPs (or change `SND.Config.Mw2ePrimaries` / `Mw2eSecondaries` in `gamemode/snd_config.lua`).  
  Weapon **class names** must match your pack (spawn menu / `gm_giveswep`). Launchers are listed in `SND.Config.Mw2eSpecial` (not given on spawn by default).
- Custom announcer audio is optional: place files under `garrysmod/sound/snd_mwclassic/announcer/` to match paths in `gamemode/snd_config.lua`.

---

## Installation

1. Clone or download this repo.
2. Copy the **`snd_mwclassic`** folder (must contain **`snd_mwclassic.txt`** and **`gamemode/`**) into:
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

## Controls

Default bindings follow standard Garry’s Mod / Source (you can rebind in **Settings → Keyboard**).

### Movement

| Action | Default key |
|--------|-------------|
| Move | **W A S D** |
| Look | **Mouse** |
| Jump | **Space** |
| Crouch | **Ctrl** (if bound in GMod) |
| **Sprint** (faster move on ground) | Hold **Shift** while moving (`snd_sprint_mult` scales speed) |

### Combat & equipment

| Action | Default key |
|--------|-------------|
| Primary / secondary fire | **Mouse 1** / **Mouse 2** (weapon-dependent) |
| Reload | **R** (typical) |
| **Use** (plant / defuse — see below) | **E** |

### Bomb (Search & Destroy)

| Situation | What to do |
|-----------|----------------|
| **Plant** — you are the bomb carrier (**attacker**), bomb is not planted, you stand in a site | Hold **E** until the plant timer finishes (`snd_plant_time`). Moving out of range or taking damage can cancel. |
| **Defuse** — you are **defender**, bomb is planted, you are on the bomb | Hold **E** until defuse finishes (`snd_defuse_time`). Taking damage can cancel. |

Bomb sites are map-specific (config / data overrides). If you see no prompt, you are not in site radius or not the right role.

### Spectating (after you die for the round)

| Action | Default key |
|--------|-------------|
| Watch **teammates only** (camera follows them) | Automatic when alive teammates exist |
| **Next** teammate | **Mouse 1** (primary attack while spectating) |
| **Previous** teammate | **Mouse 2** (secondary attack while spectating) |
| No living teammates | **Free roam** camera until the round ends |

### Menus & admin (optional)

| Action | How |
|--------|-----|
| Spawn / context menu | **Q** (default) — **Utilities → SND** for the settings shortcut |
| SuperAdmin settings UI | Chat **`!snd_settings`** or console **`snd_open_settings`** |

### Round rules (short)

- **Freeze** at round start, then **live** play. One life per player per round until the next round respawn.
- **Defenders** win the round if time runs out. **Attackers** win if the bomb explodes. Either team can win by eliminating the other.
- After plant, bomb detonates after **45 seconds** unless defused (timer in `gamemode/snd_bomb.lua`).

---

## Bots — how to enable and access them

Bots are **not** a separate menu tab. They are **extra player slots** created with `player.CreateNextBot` when **`snd_bot_count`** is greater than **0**.

### 1. Set how many bots you want

Pick **one** of these:

- **Before starting a game** — In the **Create Multiplayer** / new game screen, if your build shows **gamemode options** from `snd_mwclassic.txt`, set **Bots** there (same ConVar: `snd_bot_count`).
- **Console (server / listen host)** — After the map loads:
  ```
  snd_bot_count 4
  ```
  Change map or reconnect so the gamemode can run its bot logic (`changelevel gm_construct` or restart).
- **SuperAdmin in-game** — **`snd_open_settings`** or **`!snd_settings`** → adjust sliders if your build shows **Bots** there.
- **Dedicated server** — Put `snd_bot_count 4` in `server.cfg` or your host’s startup config, then restart the map.

### 2. What you should see

- Bots appear as normal **player names** in the scoreboard / world (often named like **SNDBot1**).
- They fill empty slots up to **`snd_bot_count`**. Difficulty is roughly **`snd_bot_skill`** (0.15–1).

### 3. If bots never appear

- **Listen server:** try `snd_bot_count 2` then `changelevel` the same map.
- **Dedicated:** many hosts need **`bot`** / quota / permissions enabled; `player.CreateNextBot` can fail silently — check the **server console** for `[SND]` messages from `gamemode/snd_bots.lua`.
- Set **`snd_bot_count 0`** to turn bots off.

---

## Workshop map: Rust (`ttt_rust_v1a`)

The MW2-style Rust port **[TTT] Rust** on the Steam Workshop ([file `2922376072`](https://steamcommunity.com/sharedfiles/filedetails/?id=2922376072)) uses BSP name **`ttt_rust_v1a`**.

1. Subscribe and enable the addon so the map appears under **Sandbox / map browser**.
2. Launch it with this gamemode, for example:
   ```
   gamemode snd_mwclassic
   map ttt_rust_v1a
   ```
3. On first load, the gamemode **auto-builds** two bomb sites and attacker/defender spawn lists by scanning the map’s player spawn entities and tracing down to the ground (site **A** biased toward the **top-right** of the spawn hull, site **B** near the **center** — aligned with classic Rust layout).
4. If attackers/defenders feel **swapped** relative to the map, set **`snd_rust_swap_spawns 1`** (or use a data override — below).
5. To **hand-tune** positions, stand where you want a spawn or site and run (SuperAdmin):
   - **`snd_rust_dump_spawn_line`** — prints one `{ pos, ang }` line for `data/snd_mwclassic/maps/ttt_rust_v1a.lua`
   - **`snd_rust_dump_site_vectors`** — prints a `plantPos` line at your feet (ground-traced)

Copy **`copy_to_garrysmod_data/snd_mwclassic/maps/ttt_rust_v1a.example.lua`** → rename to **`ttt_rust_v1a.lua`**, uncomment the `return { ... }` block, and paste Vectors from the console. That file overrides auto-layout.

---

## Configuration

### Bomb sites & factions

Edit **`gamemode/snd_config.lua`**:

- **`SND.Config.MapSites`** — per-map A/B (or more) sites: `plantPos`, `defuseRadius`, `id`.  
  Unknown maps fall back to offsets from `info_player_start` (good for testing only).
- **`garrysmod/data/snd_mwclassic/maps/<mapname>.lua`** — optional Lua file returning `{ sites = {...}, spawns = { attack = {...}, defend = {...} } }` (see **`maps/ttt_rust_v1a.example.lua`** in `copy_to_garrysmod_data`). Overrides auto-layout when present.
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
| `snd_rust_swap_spawns` | `ttt_rust_v1a` only: swap attacker/defender auto-spawn halves (`0` / `1`) |

### In-game settings menu

- **SuperAdmin:** chat **`!snd_settings`** or console **`snd_open_settings`**
- Also under **Utilities → SND → S&D Settings** (spawn menu tools tab)

Changes are applied on the **server** via network messages.

### Admin / console

- **`snd_start_mapvote`** — SuperAdmin: start a map vote manually.

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
