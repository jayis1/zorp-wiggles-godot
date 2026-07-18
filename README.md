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
8. **Alien Companion Pet** — Summonable pet with 3 evolution stages (baby → adolescent → adult), auto-collects items, fetch command, idle animations, adult stage shields Zorp
9. **Weapon Mod Crafting** — 30 craftable weapon mods (homing laser, chain lightning, freeze ray, vampire beam, black hole, ricochet, spread shot, piercing, bouncing, black hole launcher, time freeze ray, shrink beam, meteor strike, lightning storm, poison nova, and more)
10. **Dynamic Weather** — 6 weather types (clear, acid rain, solar flare, fog, thunderstorm, snow) with gameplay effects (damage, fire rate boost, stealth, lightning, slow)
11. **Boss Arenas** — 3 arena types (lava, crystal, void) with walls, cover, environmental hazards, shrinking floors, and auto-spawn system
12. **Local Co-op** — Player 2 "Zerp" drops in anytime, shared camera with dynamic zoom, enemy scaling, shared combo, revive system, mega pulse wave sync, 7 co-op achievements

### Audio & Polish
- 24 procedurally generated sound effects (no external audio files needed)
- 12 per-biome ambient music tracks + boss fight music
- Trauma-based screen shake, input buffering, hit-stop freeze frames
- Pause menu, settings menu, death screen with stats and "Try Again"
- Smooth camera follow with deadzone, FOV kick on dash, look-ahead offset

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
- **Lore Stones** — 30 scattered ancient relics that reveal world-building lore fragments when approached (📜 icon, purple glow, +25 XP each)
- **Treasure Chests** — hidden chests with golden glimmer when close; contain rare loot (Meteor Shards, Quantum Fuzz, etc.); 25% are trapped (spawn a Chest Mimic)
- **Roaming Wildlife** — 8 biome-specific non-hostile species (Glimmer Hopper, Frost Mite, Sand Skitter, Bog Hopper, Void Mote, Tidal Sprite, Ember Wisp, Cloud Drifter) that flee from the player and drop loot when caught

---

## 🕹️ Controls

| Key | Action |
|---|---|
| WASD | Move (camera-relative) |
| Right-click + drag | Orbit camera |
| Left-click | Shoot tentacle laser |
| Space | Dash (with invulnerability frames) |
| Q | Pulse Wave (AoE attack, 8s cooldown) |
| E | Trade / Revive Zerp |
| M | Toggle minimap |
| Tab | Toggle missions panel |
| P | Pause |
| F | Summon/dismiss companion pet |
| G | Pet fetch mode (click collectible to fetch) |
| C | Open weapon mod crafting menu |
| K | Open skill tree |
| F2 | Open statistics page |
| **Player 2 (Zerp)** | |
| Arrow Keys | Move |
| / | Shoot |
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
- **9 weather types** with gameplay effects
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
- **Phase 24**: New weapon mods (Black Hole Launcher, Time Freeze Ray, Mind Control, Meteor Strike, Turret Deploy)
- **Phase 25**: Progression systems (skill tree, prestige, daily challenges, endless mode, boss rush)
- **Phase 26**: World life (wandering merchants, villages, wildlife, treasure chests, lore stones, fast travel) — **IN PROGRESS** (3/10 implemented: roaming wildlife with 8 biome-specific species, hidden treasure chests with traps, lore stones with 30 lore fragments)
- **Phase 27**: Pet evolution expansion (5 new paths, fusion, accessories, training, multi-pet)
- **Phase 28**: Weather expansion (meteor shower, aurora, sandstorm, blood moon, eclipse, gravity anomaly)
- **Phase 29**: Equipment (armor, consumables, accessories, upgrade system, set bonuses)
- **Phase 30**: Visual polish (character select, skins, photo mode, intro cinematic)
- **Phase 31**: Quality of life (auto-save, colorblind modes, tutorial, tooltips, FPS counter)
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