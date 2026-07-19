# 🟢 Zorp Wiggles: Alien Adventure — Godot Edition

**A 3D open-world alien adventure game built with Godot 4.4 and GDScript.**

You are Zorp, a squishy green alien exploring a procedurally-generated 3D planet. Collect weird stuff, complete missions, blast enemies with your tentacle laser, mutate from biome exposure, ride dimensional rifts, craft weapon mods, raise a companion pet, and survive the alien wilderness — solo or with a friend in local co-op!

---

## 🎮 Features

### Core Gameplay
- **3D open world** with 19 procedurally-generated biomes (grass, desert, water, lava, forest, crystal, snow, swamp, alien, mushroom, floating islands, toxic bog + Phase 22: deep ocean, volcano core, sky citadel, digital grid, crystal caverns, ancient ruins, underground)
- **24+ enemy types** with unique AI behaviors (Slime Blob, Plasma Drake, Graviton, Void Wisp, Spore Spitter, Starburst Sentinel, Plasma Serpent, Swarm Mite, Crystal Guardian, Phase Shifter, Toxic Spore, Swarm Queen, Crystal Wraith, Echo Knight, Plasma Stalker, Time Warden, Mirror Mimic, **Void Leviathan** boss, **Ancient Sentinel** mega-boss, **Gravity Elemental** elite, and more)
- **Smart enemy AI** with NavMesh pathfinding, flanking, retreat, ambush, pack coordination, line-of-sight checks, and enrage systems
- **Combat system** with crit chains, kill combos, pickup streaks, damage numbers, and 30+ weapon mods
- **Full HUD** with HP/XP bars, minimap, radar, boss HP bar, combo counter, kill feed, biome indicator, dash cooldown, achievement popups, death screen

### 12 New Features (beyond the original Ursina game)
1. **Physics & Interaction** — Enemy knockback, destructible objects, physics-based dash slide, gravity wells
2. **Shaders & Visual Effects** — Heat distortion, crystal refraction, chromatic aberration, frost vignette, dissolve, water surface, boss enrage, low-HP warning (8 custom .gdshader files)
3. **Smart Enemy AI** — NavMesh pathfinding, flanking, retreat, ambush, pack behavior, call-for-help, enrage
4. **GPU Particles** — Mega explosions (1000+ particles), boss death spectacles, ambient biome weather, projectile trails, level-up shockwaves, materialization effects, atmosphere particles
5. **Animation System** — AnimationPlayer library with squash-and-stretch, walk cycles, hit reactions, blend trees
6. **Biome Mutation System** — Zorp evolves based on time spent in biomes (fire resistance, ice armor, refractive cloak, nature's pact, poison trail, void step)
7. **Dimensional Rifts** — 4 alternate dimensions: Void (shadow clone boss), Mirror (enemies friendly, items hostile), Time-Slow (world at 0.3x speed), Reverse Gravity (walk on ceiling)
8. **Alien Companion Pet** — Summonable pet with 3 evolution stages (baby → adolescent → adult), auto-collects items, fetch command, idle animations, adult stage shields Zorp; **Phase 27: 5 elemental evolution paths** (Fire/Ice/Electric/Void/Nature) each with unique passive abilities, ranged attacks for Fire/Void, pet emote system (8 emotes reacting to game events), and evolution stones as rare biome-themed drops
9. **Weapon Mod Crafting** — 34 craftable weapon mods (homing laser, chain lightning, freeze ray, vampire beam, black hole, ricochet, spread shot, piercing, bouncing, black hole launcher, time freeze ray, shrink beam, meteor strike, lightning storm, poison nova, shield bubble, turret deploy, gravity flip field, void rift cutter, and more)
10. **Dynamic Weather** — 15 weather types (clear, acid rain, solar flare, fog, thunderstorm, snow, meteor shower, aurora, sandstorm, blood moon, eclipse, pollen storm, magnetic storm, gravity anomaly, dimensional storm) with gameplay effects (damage, fire rate boost, stealth, lightning, slow, XP/loot multipliers, minimap disable, EMP dash disable, gravity shifts, dimension rifts) + weather combo system (two weathers overlap for bonus XP/loot)
11. **Boss Arenas** — 3 arena types (lava, crystal, void) with walls, cover, environmental hazards, shrinking floors, and auto-spawn system
12. **Local Co-op** — Player 2 "Zerp" drops in anytime, shared camera with dynamic zoom, enemy scaling, shared combo, revive system, mega pulse wave sync, 7 co-op achievements

### Audio & Polish
- 24 procedurally generated sound effects (no external audio files needed)
- 12 per-biome ambient music tracks + boss fight music
- Dynamic music intensity — 5 tiers (Calm/Engaged/Heated/Intense/Frenzied) that scale with the combo counter (pitch + volume)
- Trauma-based screen shake, input buffering, hit-stop freeze frames
- Pause menu, settings menu, death screen with stats and "Try Again"
- Smooth camera follow with deadzone, FOV kick on dash, look-ahead offset
- **Color Filters** — 4 cosmetic modes (sepia, noir, thermal, x-ray) + 4 colorblind correction modes (protanopia, deuteranopia, tritanopia, achromatopsia), F6/F7 to cycle, persists to disk
- **UI Scaling** — F8/Shift+F8 to scale HUD elements for different screen resolutions (75%-150%)
- **Photo Mode** — F9 freezes the game and spawns a free-look camera; WASD/Space/Shift to fly, drag to orbit, scroll for FOV, F to capture a screenshot to `user://screenshots/`, C to cycle color filters in-frame
- **Cosmetic Skins** — 9 unlockable skins for Zorp (Classic Green, Golden, Void, Crystal, Lava, Sky, Rainbow, Noir, Cosmic) that recolor the body + emission; RAINBOW cycles hue at runtime; unlock via prestige, kills, biome visits, achievements, level; F10 to cycle
- **Trail Customization** — 5 dash-trail styles (Classic, Spark, Comet, Glitch, Aurora) with per-style mesh shape (sphere/cube/ellipsoid), alpha, lifetime, scale, and jitter; 8 trail colors independent of skin; persists to disk
- **Victory Screen** — ranked letter grade (S/A/B/C/D) for Boss Rush, Speedrun, and Endless milestone waves (10/25/50/100); shows total time, biome splits, personal best comparison with "★ NEW PB ★" callout; Play Again + Quit buttons
- **Character Select** — choose Zorp (tanky all-rounder, 120 HP) or Zerp (fast & fragile, 100 HP, +8% speed, +10% dash, -10% damage) for solo runs; full-screen card UI with stat preview bars, ← → navigation, click-to-select; persists to `user://zorp_character.json`; in co-op P1 is always Zorp
- **Adaptive Shoot SFX** — 12 per-weapon-mod shoot sound variants (standard, homing whistle, energy bolt, piercing whine, freeze chime, poison hiss, fire whoosh, void pulse, lightning zap, heavy cannon, utility chime, vampire hum); each mod has a distinct auditory identity so the player hears the weapon change
- **Death Replay** — last 5 seconds of gameplay recorded at 60Hz; on death, plays back in slow-motion (0.25× time scale) as a "death cam" before the death screen appears
- **Intro Cinematic** — procedural landing animation at run start: Zorp descends from y=40 in a glowing light column with particle trail, impacts with dust ring + camera shake + mesh squash, then the camera eases to gameplay angle as the HUD fades in; player input suppressed during the 3-second cinematic

### Missions & Progression
- Mission system (collect, kill, explore, boss missions)
- Quest log UI with progress tracking
- Trader NPC with trade menu
- Monolith buff structures (speed, damage, XP buffs)
- Achievement system with popups (56 achievements across 6 categories with progress tracking)
- XP curve and level-up stat scaling
- Difficulty scaling over time
- **Skill Tree** — 3 branches (Combat, Survival, Exploration), 15 skills, 75 ranks, spend SP from leveling (K key)
- **Permanent Upgrades** — skill bonuses persist across runs via JSON save (+HP, +damage, +speed, +XP, +crit, +loot, +fire rate, +multishot, +dash cooldown, +HP regen, +dmg reduction, auto-revive)
- **Prestige System** — reset at level 20+ for +10% XP multiplier per prestige level, bonus SP, and golden aura cosmetic
- **Statistics Page** — lifetime + session stats (kills, distance, time, items, biome time, enemy/boss breakdowns) with 4 tabs (F2 key)
- **Game Modes** — 4 selectable game modes (Normal, Endless, Boss Rush, Speedrun) chosen on the main menu; Endless escalates waves every 30s, Boss Rush fights all 5 bosses back-to-back with timer + full heal between, Speedrun tracks biome splits + personal best with a timer HUD; mode persists to disk
- **Lore Stones** — 30 scattered ancient relics that reveal world-building lore fragments when approached (📜 icon, purple glow, +25 XP each)
- **Treasure Chests** — hidden chests with golden glimmer when close; contain rare loot (Meteor Shards, Quantum Fuzz, etc.); 25% are trapped (spawn a Chest Mimic)
- **Roaming Wildlife** — 8 biome-specific non-hostile species (Glimmer Hopper, Frost Mite, Sand Skitter, Bog Hopper, Void Mote, Tidal Sprite, Ember Wisp, Cloud Drifter) that flee from the player and drop loot when caught

---

## 🕹️ Controls

| Key | Action |
|---|---|
| WASD | Move (camera-relative) |
| Right-click + drag | Orbit camera |
| Left-click | Shoot tentacle laser (hold to auto-fire) |
| Space | Dash (with invulnerability frames) |
| Q | Pulse Wave (AoE attack, 8s cooldown) |
| E | Trade / Revive Zerp |
| M | Toggle minimap |
| Scroll wheel (over minimap) | Zoom minimap in/out |
| Tab | Toggle missions panel |
| P | Pause |
| F | Summon/dismiss companion pet |
| G | Pet fetch mode (click collectible to fetch) |
| B | Use evolution stone on pet (locks in elemental path) |
| C | Open weapon mod crafting menu |
| V | Deploy ability (activate equipped deployable mod: Shield Bubble, Turret, Gravity Flip, Void Rift) |
| X | Open equipment menu (armor, consumables, refine, materials) |
| Z | Toggle pinned auto-fire (continuous fire with no input — [AUTO] badge shows on HUD) |
| K | Open skill tree |
| H | Open fast travel menu (teleport to activated waypoints) |
| T | Interact (talk to NPCs, activate switches) |
| 1-5 | Use consumable (health/speed/shield/power potion, void bomb) |
| F2 | Open statistics page |
| F3 | Toggle FPS counter & performance overlay |
| F6 | Cycle color filter (sepia/noir/thermal/x-ray) |
| F7 | Cycle colorblind correction mode |
| F8 / Shift+F8 | Increase / decrease UI scale |
| F9 | Toggle photo mode (free-look camera + screenshots) |
| F10 | Cycle cosmetic skin (golden/void/crystal/lava/sky/rainbow/noir/cosmic) |
| Middle Mouse | Drop a ping marker (Shift=danger, Alt=loot, Ctrl=nav) |
| **Player 2 (Zerp)** | |
| Arrow Keys | Move |
| / | Shoot (hold to auto-fire) |
| Enter | Dash / Drop-in / Hold to drop-out |
| Right Shift | Pulse wave |
| . | Revive Zorp |

---

## 🚀 Getting Started

1. Install [Godot 4.4+](https://godotengine.org/downloads)
2. Open this project folder in Godot
3. Press **F5** to run

No external assets needed — all sounds, music, particles, and meshes are generated procedurally at runtime.

---

## 📁 Project Structure

```
zorp-wiggles-godot/
├── project.godot                # Project settings, input mappings, autoloads
├── scenes/
│   ├── main.tscn                # Main game scene
│   ├── main_menu.tscn           # Start menu
│   └── entities/                # Enemy, collectible, effect, structure scenes
├── scripts/
│   ├── game_constants.gd        # All game constants (autoload)
│   ├── game_manager.gd           # Game state singleton (autoload)
│   ├── enemy_types.gd            # Enemy type definitions (autoload)
│   ├── player.gd                 # Player controller
│   ├── player2_zerp.gd           # Player 2 co-op controller
│   ├── camera_rig.gd             # Orbit camera with screen shake
│   ├── enemy_base.gd             # Base enemy AI
│   ├── enemy_ai_controller.gd   # Smart AI (NavMesh, flanking, pack)
│   ├── enemy_drake.gd            # Plasma Drake boss
│   ├── enemy_serpent.gd          # Plasma Serpent (segmented)
│   ├── enemy_graviton.gd         # Gravity pull enemy
│   ├── enemy_wisp.gd             # Void Wisp (teleport on hit)
│   ├── enemy_sentinel.gd         # Shockwave Sentinel
│   ├── enemy_bomber.gd           # Void Bomber (kamikaze)
│   ├── enemy_spitter.gd          # Spore Spitter (ranged)
│   ├── enemy_spawner.gd          # Dynamic enemy spawner
│   ├── world_generator.gd        # Procedural biome terrain
│   ├── hud.gd                    # HUD overlay
│   ├── minimap.gd                # Top-down minimap
│   ├── collectible.gd            # Pickup items with magnetic pull
│   ├── projectile.gd             # Player laser projectile
│   ├── pulse_wave.gd             # Q ability AoE ring
│   ├── weapon_mod_system.gd      # 20 weapon mods (autoload)
│   ├── crafting_menu.gd          # Weapon mod crafting UI
│   ├── mutation_system.gd        # Biome mutation system (autoload)
│   ├── dimension_system.gd       # Dimensional rifts (autoload)
│   ├── companion_pet.gd          # Alien companion pet
│   ├── weather_system.gd         # Dynamic weather (autoload)
│   ├── boss_arena.gd             # Boss arena generation
│   ├── shader_manager.gd         # Post-process shader manager
│   ├── particle_effects.gd       # GPU particle effects
│   ├── audio_manager.gd          # Procedural SFX + music (autoload)
│   ├── mission_system.gd         # Mission tracking (autoload)
│   ├── animation_system.gd       # AnimationPlayer library
│   ├── navigation_manager.gd     # NavMesh generation (autoload)
│   ├── co_op_manager.gd          # Co-op system (autoload)
│   └── ...                       # 50+ scripts total
├── assets/
│   └── shaders/                  # 10 custom .gdshader files
├── CONVERSION_TRACKER.md         # Development progress tracker
└── README.md
```

---

## 🔄 Conversion History

This game was originally built with the **Ursina engine** (Python/Panda3D) as a 21,927-line single-file `game.py`. It has been fully converted to **Godot 4.4 GDScript** with a proper scene-tree architecture:

- Single `Game` class → 15+ autoloads and scene scripts
- `color.rgb()` 0-255 → `Color()` 0-1 normalized
- `held_keys[]` → `Input.is_action_pressed()`
- `time.dt` → `delta` parameter
- `destroy()` → `queue_free()`
- Manual particle spawning → `GPUParticles3D`
- Straight-line enemy movement → `NavigationAgent3D` pathfinding
- Manual tween chains → `AnimationPlayer` + `create_tween()`

**Original Ursina repo:** [github.com/jayis1/zorp-wiggles-alien-adventure](https://github.com/jayis1/zorp-wiggles-alien-adventure)

---

## 📊 Stats

- **21,000+ lines** of GDScript
- **70+ files** (scripts + scenes + shaders)
- **20+ enemy types** with unique AI
- **20+ weapon mods** craftable
- **19 biomes** with procedural generation (12 original + 7 Phase 22 new)
- **15 weather types** with gameplay effects (6 original + 3 Enhancement + 6 Phase 28) + weather combo system
- **13 biome mutations** (6 original + 7 Phase 22 new)
- **4 dimensional rifts** with unique mechanics
- **3 pet evolution stages** with abilities
- **Local co-op** with Player 2 "Zerp"
- **24 procedural SFX** + 12 biome music tracks
- **80+ git commits** of development history

---

## 🗺️ Roadmap

Phases 1-20 (core game + 12 new features) are **COMPLETE**. Ongoing development includes:

- **Phase 22**: New biomes (Deep Ocean, Volcano Core, Sky Citadel, Digital Grid, Crystal Caverns, Ancient Ruins, Underground) — **IN PROGRESS** (7/8 biomes implemented with decorations, mutations, biome effects, audio, weather affinities)
- **Phase 23**: New enemy types (Toxic Spore, Swarm Queen, Crystal Wraith, Echo Knight, Plasma Stalker, Time Warden, Mirror Mimic implemented; Void Leviathan, Ancient Sentinel pending) — **IN PROGRESS** (7/10 enemy types implemented)
- **Phase 24**: New weapon mods (Black Hole Launcher, Time Freeze Ray, Shrink Beam, Meteor Strike, Lightning Storm, Poison Nova, Shield Bubble, Turret Deploy, Gravity Flip Field, Void Rift Cutter)
- **Phase 25**: Progression systems (skill tree, prestige, daily challenges, endless mode, boss rush, speedrun) — **IN PROGRESS** (7/10: skill tree with 3 branches/15 skills/75 ranks, permanent upgrades, prestige system, endless mode with wave escalation, boss rush with 5-boss queue + timer, speedrun with biome splits + PB, 56 achievements, statistics page; daily/weekly challenge deferred)
- **Phase 26**: World life (wandering merchants, villages, wildlife, treasure chests, lore stones, fast travel) — **COMPLETE** (10/10: wandering merchants with discounted rare goods, friendly alien villages via clustered dialogue NPCs, roaming wildlife with 8 biome-specific species, hidden treasure chests with traps, lore stones with 30 lore fragments, NPC dialogue system with 3 archetypes + typewriter-effect HUD panel, environmental hazards with 4 types cycling through telegraph/active/cooldown, interactive objects with switches/doors/breakable walls/hidden passages linked via linked_id, world bosses that roam the open world with loot showers, fast travel network with auto-activating waypoints)
- **Phase 27**: Pet evolution expansion (5 new paths, fusion, accessories, training, multi-pet) — **IN PROGRESS** (3/8 implemented: 5 elemental evolution paths [Fire/Ice/Electric/Void/Nature] with unique passive abilities + ranged attacks for Fire/Void, pet emote system with 8 emotes reacting to game events, pet evolution stones as rare biome-themed drops with dedicated inventory + B-key to use)
- **Phase 28**: Weather expansion (meteor shower, aurora, sandstorm, blood moon, eclipse, pollen storm, magnetic storm, gravity anomaly, dimensional storm, weather combo system) — **COMPLETE** (10/10: 6 new weather types with unique gameplay effects + weather combo system allowing two weathers to overlap for +25% XP/loot bonuses; Blood Moon triples XP/loot but empowers enemies, Magnetic Storm disables minimap + EMP pulses disable dashing, Gravity Anomaly shifts gravity every 10s, Dimensional Storm opens rifts + forces dimension shifts, Pollen Storm heals everything, Eclipse darkens the world, all with biome affinities + spawn bonuses + unique particle effects)
- **Phase 29**: Equipment (armor, consumables, accessories, upgrade system, set bonuses) — **COMPLETE** (8/8: 12 equipment pieces across 4 sets [Plasma/Crystal/Void/Ancient] with head/body/accessory slots, 5 consumables [potions + Void Bomb] with hotkeys 1-5, +1/+2/+3 upgrade system, 12 rare materials dropping from bosses/weather/biomes, equipment menu UI [X key] with 4 tabs, material refinement, 2-piece and 3-piece set bonuses)
- **Phase 30**: Visual polish (dynamic music intensity, character select, skins, photo mode, intro cinematic, color filters) — **IN PROGRESS** (2/10: dynamic music intensity — 5 tiers [Calm/Engaged/Heated/Intense/Frenzied] rising with kill combo, modulates pitch +8% and volume +3.5 dB, eases smoothly, boss music exempt; cosmetic color filters [F6] — sepia/noir/thermal/x-ray screen-space shader with cycle button in settings)
- **Phase 31**: Quality of life (FPS counter, minimap zoom, auto-save, colorblind modes, tutorial, tooltips, ping system, UI scaling, color filters) — **IN PROGRESS** (6/10: FPS counter + performance overlay [F3] with 60-point sparkline graph and color-coded FPS, minimap scroll-wheel zoom 40-400 world units with zoom indicator, ping system [middle mouse] with 4 ping types [default/danger/loot/nav] + 3D beacons + minimap diamonds + edge arrows, UI scaling [F8/Shift+F8] 75-150% with proportional HUD element + font scaling, colorblind correction modes [F7] for protanopia/deuteranopia/tritanopia/achromatopsia via 3×3 color transform shader, cosmetic color filters [F6] sepia/noir/thermal/x-ray via screen-space shader)
- **Phase 32**: Multiplayer (online leaderboards, ghost mode, 3-4 player co-op, PvP, replays)
- **Phase 33**: Procedural content (dungeons, quests, enemy variants, boss generation, world modifiers)
- **Phase 34**: Endgame (New Game+, survival mode, gauntlet, loot caves, ancient vaults)
- **Phase 35**: Final polish (QA pass, performance, balance, edge cases, code cleanup)

See [CONVERSION_TRACKER.md](CONVERSION_TRACKER.md) for detailed progress.

---

## 📜 License

Open source — same as the original Zorp Wiggles project.

## 🤖 Development

This game is developed with automated AI cron jobs running every 10 hours:
- **Enhancement** — adds new features, enemies, biomes, weapon mods
- **Bug Hunt** — finds and fixes GDScript bugs
- **Improver** — polishes game feel, optimizes, improves code quality

All changes are automatically committed and pushed to this repository.