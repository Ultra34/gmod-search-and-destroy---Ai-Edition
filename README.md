> **Disclaimer:** This project is a collaborative development effort between a human developer and Artificial Intelligence (Gemini). While AI was utilized for code generation, logic structuring, and documentation, all features have been reviewed, refined, and integrated by the human maintainer to ensure gameplay quality and technical stability.

# GMod Search & Destroy

A Garry's Mod **gamemode** built around Call of Duty-style Search & Destroy rules.  
One life per round, bomb plant and defuse, team scoring, visual map voting, Lua-driven bots with a full AI state machine, first-person legs, 3D bomb-site markers, and loadouts powered by **TFA Call of Duty weapon packs** (WaW, BO1, BO2, MW2, etc.).

**Repository:** Ultra34/gmod-search-and-destroy---Ai-Edition

---

## Features

- **One life per round** — no mid-round respawns; die and spectate teammates until the next round.
- **Bomb mechanics** — attacker carries the bomb, plants it by looking at the ground in a site and holding **E**; defenders defuse by standing on the bomb and holding **E**. CSS plant, defuse, and beep sounds included.
- **Dynamic Minimap** — CoD-style minimap with Nav Mesh-based floorplans, player rotation, and "red dot" pings that reveal enemy positions when they fire their weapons.
- **Screen-Space Objective Markers** — High-clarity diamond icons with distance tracking and off-screen directional arrows. Replaces traditional 3D2D world text for a jitter-free, modern UI feel.
- **Freeze phase** — nobody moves until the round goes live; a countdown progress bar fills the screen.
- **COD-styled Leaderboard** — High-fidelity Call of Duty (Black Ops III) inspired leaderboard with sleek translucent backgrounds, team headers, level icons, and UI scaling.
- **Calling Cards & Emblems** — MW2-style kill banners that slide onto the screen for both the killer and the victim. Supports custom titles, background images (PNG/JPG/GIF), and Steam avatars.
- **Level & XP System** — Persistent rank system with XP earned from kills, headshots, plants, and defuses. Data is saved automatically.
- **Crosshair Customization** — CS:GO/CS2 style crosshair menu (`!crosshair`) with real-time preview and profile support.
- **Quick Grenade Throw** — Dedicated 'G' key for instant grenade usage that automatically switches back to your previous weapon.
- **Health Regeneration** — Authentic CoD-style health regen with red damage vignettes and screen tinting.
- **MW2 Movement** — Tactical movement including sprint stamina, jump/landing fatigue, and authentic camera sway.
- **Gun picker UI** — Persistent 10-slot loadout manager. Restricted to the pre-game phase to ensure competitive integrity once the match begins.
- **Lua bots** — state-machine AI (Patrol → Engage → Chase → Plant → Defuse → Reload) with a **1–10 skill slider** that scales aim noise, reaction time, engage range, and reload thresholds. Bots switch weapons when empty and reload proactively when ammo is low.
- **CSS player models** — Terrorist and Counter-Terrorist skins on both factions; bots and players share the same model system.
- **Team-only spectating** — dead players follow living teammates only (**M1** next / **M2** previous); free-roam when all teammates are dead.
- **Map voting** — end-of-match vote driven by `data/snd_mwclassic/maps.txt`.
- **SuperAdmin settings panel** — live ConVar sliders accessible via `!snd_settings` or `snd_open_settings`.
- **Integrated Map Editor** — Dedicated Debug Mode (`F4`) with hotkeys for rapid placement of bomb sites and spawn points, with automatic saving to map-specific **JSON** data files.
- **Noclip disabled** — four independent enforcement layers prevent noclip for all players at all times.

### Debug & Map Editing (SuperAdmin Only)

| Action | Key |
|---|---|
| Toggle Debug Mode | **F4** |
| Set Bomb Site A | **F5** |
| Set Bomb Site B | **F6** |
| Add Attacker Spawn | **F7** |
| Add Defender Spawn | **F8** |

---

## Requirements

| Requirement | Notes |
|---|---|
| Garry's Mod (Steam) | Updated to the current branch |
| **[TFA] Call of Duty World at War SWEPs** | Workshop — provides `robotnik_waw_*` classes |
| **[TFA][AT] CoD Black Ops SWEPs Pack** | Workshop — provides `robotnik_bo1_*` classes |
| **[TFA][AT] CoD Black Ops II SWEPs** | Workshop — provides `mac_bo2_*` classes |
| **[TFA][AT] Call of Duty 4: Modern Warfare Weapons Pack** | Workshop — provides all `iw3_*` SWEP classes |
| **[TFA][AT] Call of Duty: Modern Warfare 2 Weapons Pack** | Workshop — provides all `iw4_*` SWEP classes |
| **[TFA][AT] Call of Duty: Modern Warfare 3 Weapons Pack** | Workshop — provides all `iw5_*` SWEP classes |
| **TFA Base** | Required by the weapon pack above |
| Counter-Strike: Source (mounted) | CSS player models and bomb sounds (`c4_plant.wav`, `c4_beep1.wav`, etc.) |

> If CS:S is not mounted, player models will show as ERROR and bomb sounds will be silent.
> Subscribe to TFA Base **before** the weapon packs or weapons will not register.

---

## Installation

### Step 1 — Get the files

```
git clone https://github.com/Ultra34/gmod-search-and-destroy---Ai-Edition.git
```

Or download the ZIP from GitHub and extract it.

### Step 2 — Place the gamemode

Copy the **`snd_mwclassic`** folder into:

```
garrysmod/gamemodes/snd_mwclassic/
```

The folder **must** contain `snd_mwclassic.txt` and a `gamemode/` subfolder.  
The descriptor file must be named exactly `snd_mwclassic.txt` — GMod will not detect the gamemode otherwise.

### Step 3 — Copy data files

Copy the contents of `copy_to_garrysmod_data/snd_mwclassic/` into:

```
garrysmod/data/snd_mwclassic/
```

Edit **`maps.txt`** to list the maps you want in the vote rotation (one name per line, no `.bsp`):

```
ttt_rust_v1a
ttt_rust_v2c
```

### Step 4 — Workshop addons

1. Subscribe to **TFA Base**.
2. Subscribe to **[TFA][AT] Call of Duty: Modern Warfare 2 Weapons Pack**.
3. Enable both addons in the GMod Addons menu.

### Step 5 — Launch

```
gamemode snd_mwclassic
map ttt_rust_v1a
```

Or select the gamemode from the **Create Game** menu.

---

## Weapon Classes

All weapons use the `iw4_` prefix from the TFA MW2 pack.

The gamemode supports weapons from CoD4 (IW3), MW2 (IW4), and MW3 (IW5) TFA packs.

| Game | Category | Classes (Examples) |
|---|---|---|
| **WaW (Robotnik)** | Rifles / SMGs | `robotnik_waw_stg` `robotnik_waw_mp40` |
| | Special | `robotnik_waw_rg` (Ray Gun) |
| **Black Ops (Robotnik)** | ARs / SMGs | `robotnik_bo1_ak47` `robotnik_bo1_74u` |
| | Special | `robotnik_bo1_dm` (Death Machine) |
| **Black Ops II ([MAC])** | ARs / SMGs | `mac_bo2_an94` `mac_bo2_mp7` |
| | Special | `mac_bo2_warmach` (War Machine) |
| **CoD4 (IW3)** | Assault Rifles | `iw3_ak47` `iw3_m16a4` `iw3_g36c` |
| | SMGs | `iw3_mp5` `iw3_p90` `iw3_ak74u` |
| | Sniper Rifles | `iw3_barrett` `iw3_m40a3` `iw3_dragunov` |
| | LMGs & Shotguns | `iw3_m249` `iw3_m1014` |
| | Pistols | `iw3_usp` `iw3_deserteagle` |
| | Launchers | `iw3_at4` `iw3_rpg` |
| **MW2 (IW4)** | Assault Rifles | `iw4_acr` `iw4_m4a1` `iw4_famas` |
| | SMGs | `iw4_mp5` `iw4_vector` `iw4_ump45` |
| | Sniper Rifles | `iw4_barrett` `iw4_cheytac` `iw4_wa2000` |
| | LMGs & Shotguns | `iw4_rpd` `iw4_aa12` `iw4_spas12` |
| | Pistols | `iw4_anaconda` `iw4_glock` `iw4_usp` |
| | Launchers | `iw4_at4` `iw4_javelin` `iw4_rpg` |
| **MW3 (IW5)** | Assault Rifles | `iw5_acr` `iw5_m4a1` `iw5_scar` |
| | SMGs | `iw5_mp7` `iw5_p90` `iw5_ump45` |
| | Sniper Rifles | `iw5_msr` `iw5_barrett` `iw5_as50` |
| | LMGs & Shotguns | `iw5_mk46` `iw5_striker` |
| | Pistols | `iw5_anaconda` `iw5_fmg9` `iw5_usp` |
| | Launchers | `iw5_xm25` `iw5_stinger` `iw5_rpg` |

Launchers are in `SND.Config.Mw2eSpecial` and are **not** given on spawn by default. Wire them to pickups or a data loadout if wanted.

To fix a weapon for both teams instead of using the random pool, edit `garrysmod/data/snd_mwclassic/loadouts.lua`:

```lua
SND.Config.DefaultLoadouts = {
    attack = {
        random_primary   = false,
        random_secondary = false,
        primary          = "iw4_ak47",
        secondary        = "iw4_deserteagle",
        lethal           = "weapon_frag",
    },
    defend = {
        random_primary   = false,
        random_secondary = false,
        primary          = "iw4_m4a1",
        secondary        = "iw4_usp",
        lethal           = "weapon_frag",
    },
}
```

---

## Controls

### Movement

| Action | Key |
|---|---|
| Move | **W A S D** |
| Look | **Mouse** |
| Jump | **Space** |
| Crouch | **Ctrl** |
| Sprint | Hold **Shift** while moving |

### Combat & Bomb

| Action | Key |
|---|---|
| Primary / secondary fire | **M1 / M2** |
| Reload | **R** |
| **Plant bomb** (attacker, in site, looking at ground) | Hold **E** |
| **Defuse bomb** (defender, on bomb) | Hold **E** |

### Spectating

| Action | Key |
|---|---|
| Next living teammate | **M1** |
| Previous living teammate | **M2** |

### Admin

| Action | How |
|---|---|
| Settings panel | Chat `!snd_settings` or console `snd_open_settings` |
| Identity menu | Chat `!card`, `!emblem`, or `!identity` |
| Start map vote manually | Console `snd_start_mapvote` |
| Reopen gun picker | Console `snd_gunpicker` |

---

## Bots

Bots are created with `player.CreateNextBot` and driven entirely by Lua.

### Enabling bots

```
snd_bot_count 4    -- number of bots (0 = disabled)
snd_bot_skill 5    -- 1 (weakest) to 10 (strongest)
```

Set these in `server.cfg`, the in-game settings panel, or console.

### Bot AI states

| State | Behaviour |
|---|---|
| **Patrol** | Wanders randomly; changes direction every 2–4 s |
| **Engage** | Spots a visible enemy; waits out a reaction delay (scaled by skill) then shoots and strafes |
| **Chase** | Lost sight; walks to last known position for up to 5 s |
| **Plant** | Attacker with bomb; sprints to the nearest site, looks down, holds E |
| **Defuse** | Defender; walks to the planted bomb, holds E |
| **Reload** | Weapon empty or clip low; presses reload and pauses all other actions |

### Skill breakdown

| Skill | Aim noise | Reaction delay | Engage range |
|---|---|---|---|
| 1 | ~70° | 1.3 s | 600 u |
| 5 | ~36° | 0.67 s | 2200 u |
| 10 | ~2° | 0.04 s | 3800 u |

Bots cannot see through walls — they use a last-known-position system and only fire when line-of-sight is clear.

---

## Configuration

### Server ConVars

| ConVar | Default | Description |
|---|---|---|
| `snd_walk_speed` | 190 | Walk speed |
| `snd_run_speed` | 280 | Base run speed |
| `snd_sprint_mult` | 1.65 | Sprint speed multiplier (hold Shift) |
| `snd_round_time` | 120 | Live round duration (seconds) |
| `snd_freeze_time` | 6 | Pre-round freeze (seconds) |
| `snd_plant_time` | 5 | Bomb plant duration (seconds) |
| `snd_defuse_time` | 8 | Bomb defuse duration (seconds) |
| `snd_win_limit` | 4 | Rounds needed to win the match |
| `snd_bot_count` | 0 | Number of bots (0 = off) |
| `snd_bot_skill` | 5 | Bot skill 1–10 |
| `snd_team_balance` | 1 | Auto-shuffle teams when uneven |
| `snd_mapvote_enabled` | 1 | Enable end-of-match map vote |
| `snd_mapvote_time` | 20 | Seconds before server picks a map |
| `snd_rust_swap_spawns` | 0 | Flip attacker/defender spawns on Rust maps |
| `snd_cat_[id]` | 1 | Enable/Disable specific weapon categories |

### Debugging Commands

| ConVar | Default | Description |
|---|---|---|
| `snd_bot_debug_paths` | 0 | (Cheat) Visualizes bot pathfinding nodes and segments with 3D lines. |

> Use `snd_bot_debug_paths 1` to troubleshoot bot navigation or stuck points.

### Loadout ConVar overrides

Force a specific weapon for a slot instead of drawing from the pool:

```
snd_loadout_attack_pri  iw4_ak47
snd_loadout_attack_sec  iw4_deserteagle
snd_loadout_defend_pri  iw4_m4a1
snd_loadout_defend_sec  iw4_usp
```

---

## Maps

### Bomb sites

Site positions for a map are loaded from:

```
garrysmod/data/snd_mwclassic/maps/<mapname>.lua
```

The file must return a table:

```lua
return {
    sites = {
        { id = "A", plantPos = Vector(x, y, z), defuseRadius = 120 },
        { id = "B", plantPos = Vector(x, y, z), defuseRadius = 120 },
    },
    spawns = {
        attack = { { pos = Vector(...), ang = Angle(...) }, ... },
        defend = { { pos = Vector(...), ang = Angle(...) }, ... },
    },
}
```

Use these SuperAdmin commands in-game to capture positions:

```
snd_rust_dump_site_vectors    -- prints plantPos at your feet
snd_rust_dump_spawn_line      -- prints one spawn entry at your position
```

### Supported maps

| Map | BSP name | Notes |
|---|---|---|
| Rust (v1) | `ttt_rust_v1a` | Auto-layout if no data file present |
| Rust (v2) | `ttt_rust_v2c` | Exact site positions included in data files |

Any map can be used — unknown maps fall back to offset sites from `info_player_start` for testing.

---

## Troubleshooting

**Weapons show as ERROR / missing class warnings**  
→ TFA Base or the MW2 weapon pack is not subscribed/enabled. Verify in the GMod Addons menu and restart the server.

**Player models show as ERROR**  
→ Counter-Strike: Source is not mounted. Go to GMod main menu → Games and mount CS:S.

**Bots never appear**  
→ On a dedicated server `player.CreateNextBot` may require a bot plugin or `sv_cheats 1`. Check the server console for `[SND Bots]` messages.

**Bomb sites in the wrong place on a custom map**  
→ Create a data override file at `garrysmod/data/snd_mwclassic/maps/<mapname>.lua` with your traced positions (see Maps section above).

**Gamemode does not appear in the menu**  
→ The folder must be named exactly `snd_mwclassic` and contain `snd_mwclassic.txt`. Fully quit and restart GMod after moving files. Check the main-menu console for KeyValues parse errors.

**Noclip still works**  
→ Make sure `snd_rules.lua` is included in `init.lua`. The file runs four independent enforcement layers.

---

## File Structure

```
snd_mwclassic/
├── snd_mwclassic.txt          gamemode descriptor
└── gamemode/
    ├── init.lua               server entry point
    ├── shared.lua             shared constants and includes
    ├── cl_init.lua            client entry point
    ├── cl_hud.lua             HUD: scores, freeze bar, bomb info, progress bars
    ├── cl_gunpicker.lua       gun picker Derma panel
    ├── cl_legs.lua            first-person legs
    ├── cl_settings.lua        SuperAdmin settings UI
    ├── cl_sites.lua           3D bomb-site markers
    ├── snd_announcer.lua      announcer sound hooks
    ├── snd_bomb.lua           bomb carry / plant / defuse / explosion
    ├── snd_bots.lua           bot AI state machine
    ├── snd_bot_anim.lua       CSS model animation fix
    ├── snd_config.lua         weapon pools, factions, map sites
    ├── snd_loadout.lua        loadout application + gun picker server side
    ├── snd_mapvote.lua        end-of-match map vote
    ├── snd_movement.lua       sprint, air accel, freeze lock
    ├── snd_round.lua          round/match state machine
    ├── snd_rules.lua          noclip disable, weapon drop removal
    ├── snd_rust.lua           Rust map auto-layout
    ├── snd_settings.lua       ConVar definitions
    ├── snd_sites_sv.lua       site position broadcast
    ├── snd_spawns.lua         team spawn placement
    ├── snd_spectate.lua       teammate-only spectating
    └── snd_teams.lua          faction model assignment

copy_to_garrysmod_data/snd_mwclassic/
    ├── maps.txt               map vote candidates
    ├── loadouts.lua           optional fixed loadout override
    └── maps/
        ├── ttt_rust_v1a.example.lua
        └── ttt_rust_v2c.lua   exact site positions for Rust v2
```

---

## License

No license file is included. Add one (e.g. MIT) if you want others to reuse the code under clear terms.

## Contributing

Issues and pull requests welcome at [github.com/Ultra34/gmod-search-and-destroy---Ai-Edition](https://github.com/Ultra34/gmod-search-and-destroy---Ai-Edition).
