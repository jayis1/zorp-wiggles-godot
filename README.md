# Zorp Wiggles: Alien Adventure — Godot Edition

A 3D open-world alien adventure game, rebuilt from the Ursina/Python original in Godot 4.4 with GDScript.

## About

You are Zorp, a squishy green alien exploring a procedurally-generated 3D planet. Collect weird stuff, complete missions, blast enemies with your tentacle laser, and survive the alien wilderness!

Originally built with the Ursina engine (Python), this is a ground-up rewrite in Godot 4.4 using GDScript for better performance, export options, and a proper scene architecture.

## Controls

| Key | Action |
|---|---|
| WASD | Move (camera-relative) |
| Right-click + drag | Orbit camera |
| Left-click | Shoot tentacle laser |
| Space | Dash (with invulnerability frames) |
| Q | Pulse Wave (AoE attack, 8s cooldown) |
| E | Trade (near Trader) |
| M | Toggle minimap |
| Tab | Toggle missions panel |
|| P | Pause |
| F | Summon/dismiss companion pet |
| G | Pet fetch mode (click collectible to fetch) |
| C | Open weapon mod crafting menu |

## Building & Running

1. Install [Godot 4.4+](https://godotengine.org/downloads)
2. Open this project folder in Godot
3. Press F5 to run

## Project Structure

```
zorp-wiggles-godot/
├── project.godot           # Project settings, input mappings
├── scenes/
│   ├── main.tscn           # Main game scene (with EnemySpawner)
│   ├── main_menu.tscn       # Start menu
│   └── entities/
│       ├── enemy_blob.tscn      # Basic Slime Blob
│       ├── enemy_serpent.tscn   # Plasma Serpent (segmented)
│       ├── enemy_graviton.tscn  # Graviton (gravity pull)
│       ├── enemy_wisp.tscn      # Void Wisp (teleport)
│       ├── enemy_sentinel.tscn  # Starburst Sentinel (shockwave)
│       ├── enemy_bomber.tscn    # Void Bomber (kamikaze)
│       ├── enemy_spitter.tscn   # Spore Spitter (ranged)
│       ├── enemy_drake.tscn     # Plasma Drake (boss)
│       ├── enemy_projectile.tscn # Enemy ranged projectile
│       ├── shockwave.tscn       # Expanding shockwave ring
│       ├── spawn_warning.tscn   # Ground warning before spawn
│       ├── collectible.tscn     # Pickup items
│       ├── portal.tscn         # Linked teleporter portals
│       ├── trader.tscn         # Wandering trader NPC
│       ├── monolith.tscn       # Alien monolith (buffs)
│       ├── healing_shrine.tscn # Healing crystal shrine
│       ├── destructible.tscn # Breakable crates & crystal clusters (Phase 8)
│       ├── dimensional_rift.tscn # Rift portal to alternate dimensions (Phase 14)
│       ├── shadow_clone.tscn     # Void dimension shadow clone mini-boss (Phase 14)
│       └── companion_pet.tscn    # Alien companion pet (Phase 15)
├── scripts/
│   ├── game_constants.gd   # All game constants
│   ├── game_manager.gd     # Autoload singleton — game state
│   ├── player.gd           # Player controller
│   ├── camera_rig.gd       # Orbit camera
│   ├── sky_dome.gd         # Sky dome, stars, nebula, horizon glow
│   ├── decoration.gd       # Biome decorations (trees, crystals, mushrooms, etc.)
│   ├── portal.gd           # Linked portal teleporters
│   ├── trader.gd           # Wandering trader NPC
│   ├── monolith.gd         # Alien monolith buff structures
│   ├── healing_shrine.gd   # Healing crystal shrines
│   ├── enemy_base.gd       # Base enemy AI class
│   ├── enemy_serpent.gd    # Plasma Serpent (segments + scatter)
│   ├── enemy_graviton.gd   # Graviton (gravity pull + DoT)
│   ├── enemy_wisp.gd       # Void Wisp (teleport on hit)
│   ├── enemy_sentinel.gd   # Sentinel (shockwave rings)
│   ├── enemy_bomber.gd     # Bomber (fuse + explosion)
│   ├── enemy_spitter.gd    # Spitter (charge-up + projectile)
│   ├── enemy_drake.gd      # Drake boss (enrage + fire breath + charge)
│   ├── enemy_projectile.gd # Enemy projectile system
│   ├── shockwave.gd        # Expanding AoE ring
│   ├── spawn_warning.gd    # Spawn warning visual
│   ├── enemy_spawner.gd    # Dynamic spawner with difficulty scaling
│   ├── world_generator.gd  # Procedural world
│   ├── hud.gd              # HUD overlay
│   ├── collectible.gd      # Pickup items
│   ├── projectile.gd       # Player laser
│   ├── pulse_wave.gd       # Q ability
│   ├── damage_number.gd    # Floating 3D damage/XP/heal numbers
│   ├── spawn_direction_indicator.gd  # HUD arrows for off-screen enemies
│   ├── minimap.gd          # Top-down minimap with biome tiles & entity dots
│   ├── damage_direction_indicator.gd # Red arrows pointing to damage source
│   ├── boss_tension_vignette.gd     # Pulsing red vignette near boss
│   ├── death_screen.gd     # Death screen with stats & restart prompt
│   ├── biome_indicator.gd  # Current biome name display
│   ├── dash_cooldown_indicator.gd   # Dash cooldown ring with ⚡ icon
│   ├── kill_feed.gd        # Scrolling kill feed on right side
│   ├── achievement_popup.gd # Achievement unlock popups (12 achievements)
│   ├── powerup_timer_display.gd # Buff duration bars
│   ├── particle_effects.gd # GPUParticles3D factory for all particle effects
│   ├── ambient_particles.gd # Biome ambient particles (snow, embers, spores, etc.)
│   ├── damage_flash.gd     # Red screen vignette on player damage
│   ├── destructible.gd     # Breakable props that shatter into physics fragments (Phase 8)
│   ├── shader_manager.gd   # Screen-space post-process shader manager (Phase 9)
│   ├── enemy_ai_controller.gd  # Smart AI: LOS, flanking, retreat, ambush, pack, enrage (Phase 10)
│   ├── navigation_manager.gd   # NavMesh generation & pathfinding autoload (Phase 10)
│   ├── mutation_system.gd  # Biome mutation system autoload (Phase 13)
│   ├── dimension_system.gd # Dimensional rift system autoload (Phase 14)
│   ├── dimensional_rift.gd # Rift portal entity (Phase 14)
│   ├── shadow_clone.gd    # Void dimension shadow clone mini-boss (Phase 14)
│   ├── dimension_indicator.gd # Dimension HUD indicator + timer (Phase 14)
│   ├── companion_pet.gd   # Alien companion pet entity (Phase 15)
│   ├── companion_hud.gd   # Pet HUD indicator (Phase 15)
│   ├── weapon_mod_system.gd # Weapon mod crafting autoload singleton (Phase 16)
│   ├── crafting_menu.gd   # Crafting menu UI — combine materials into weapon mods (Phase 16)
│   └── main_menu.gd        # Menu logic
├── assets/
│   ├── shaders/              # GLSL shaders (.gdshader)
│   │   ├── heat_distortion.gdshader     # Lava biome heat haze
│   │   ├── frost_vignette.gdshader      # Snow biome frost edges
│   │   ├── chromatic_aberration.gdshader # Alien biome RGB split
│   │   ├── dissolve.gdshader            # Toxic bog corrosive dissolve
│   │   ├── crystal_refraction.gdshader  # Crystal biome prismatic shimmer
│   │   ├── water_surface.gdshader       # Animated water ripples (spatial)
│   │   ├── low_hp_vignette.gdshader     # Low-HP pulsing red warning
│   │   ├── boss_enrage.gdshader         # Boss enrage screen effect
│   │   ├── rift_vortex.gdshader        # Dimensional rift swirling vortex (Phase 14)
│   │   └── dimension_transition.gdshader # Screen wipe for dimension shifts (Phase 14)
│   ├── audio/                # Sound effects & music (TODO)
│   ├── models/               # 3D models (TODO)
│   └── textures/             # Textures (TODO)
└── CONVERSION_TRACKER.md   # Conversion progress tracker
```

## Conversion Status

See [CONVERSION_TRACKER.md](CONVERSION_TRACKER.md) for detailed progress.

**Phase 1 (Core Framework):** ✅ Complete
- Player movement, dash, camera
- Basic enemy AI
- Procedural world generation
- HUD (HP, XP, combo, boss bar)
- Collectibles with magnetic pull
- Projectile system
- Pulse wave ability

**Phase 2 (Enemy Varieties):** ✅ Complete
- 7 new enemy types: Plasma Serpent, Graviton, Void Wisp, Starburst Sentinel, Void Bomber, Spore Spitter, Plasma Drake (boss)
- Plasma Serpent: Segmented body that follows head, scatters into mini-enemies on death
- Graviton: Periodic gravity pull that drags player in, deals damage-per-second
- Void Wisp: Tiny, fast, semi-transparent, teleports behind player when hit
- Starburst Sentinel: Stationary turret firing expanding shockwave rings
- Void Bomber: Kamikaze with fuse warning ring, AoE explosion damages player + enemies
- Spore Spitter: Ranged enemy with charge-up telegraph, keeps distance, fires projectiles
- Plasma Drake: Boss with enrage phase (<30% HP), fire breath (cone of projectiles), charge attack
- Dynamic enemy spawner with difficulty scaling (tiered by distance + player level)
- Spawn warning rings before enemy materialization
- Enemy projectile system with pulsing aura
- Boss HP bar integration in HUD

**Phase 3 (World & Decorations):** ✅ Complete
- Sky dome: 24 gradient billboard panels (3 layers × 8 angles, purple→pink gradient)
- Star field: 80 twinkling stars with 8-color palette (white, cream, blue-white, orange, icy blue, pink, yellow, mint)
- Nebula clouds: 12 drifting translucent clouds in 8 colors (purple, blue, crimson, teal, amber, indigo, sky blue, rose)
- Horizon glow: 8 low-altitude translucent quads for atmospheric depth
- Biome decorations: trees (forest), crystals (crystal), alien mushrooms (mushroom), floating islands with crystals, toxic bog pools/spires/fungal stalks, desert ruins (pillars + broken walls)
- Water surface overlays (semi-transparent blue tint on water tiles)
- Lava glow overlays (orange glow disc on lava tiles)
- Portal system: 4 linked portal pairs (8 portals total) with animated spinning rings, ground glow, pillar markers, teleport on contact with cooldown
- Wandering Trader NPC: 2 initial traders that wander, glow when player is near, trade Space Gloop for rare items (press E)
- Alien Monoliths: Tall crystal-capped structures in crystal/snow biomes that grant random buffs (Speed Surge, Power Surge, Wisdom Aura) on contact, with cooldown
- Healing Crystal Shrines: Green glowing shrines in mushroom/swamp biomes that heal the player on contact, with long cooldown
- Biome fog colors and density values defined (per-biome, 0-1 normalized)

**Phase 4 (Full Combat & Abilities):** 🔄 Partial — 9 of 10 complete
- Damage numbers: Floating 3D Label3D with pop-in animation (scale overshoot), upward drift, fade out; white for normal, gold ★ for crits, yellow KILL! for kills, cyan-blue +XP for XP gains, green +N for heals
- Anti-overlap jitter: Random ±0.8 horizontal offset so simultaneous numbers don't stack
- Combo milestones: Every 5 kills (x5, x10, x15...) grants tier-based bonus XP + rainbow screen flash (5-color palette: red, cyan, gold, purple, green)
- Pickup streak milestones: Every 5 consecutive rapid pickups grants bonus XP + mint-cyan HUD label
- Crit chain: 3+ consecutive crits within 3s window = 3x damage (vs normal 2x), using centralized constants
- Spawn direction indicators: Screen-edge arrows (▲) pointing toward off-screen newly-spawned enemies, with rotation toward target
- Health fragment emergency magnet: When HP < 25%, Health Fragments pull from 14-unit radius at accelerated speed
- Enemy attack windup telegraph, spawn fade-in, and alert indicator (already from Phase 2)
- Dash invulnerability frames (partially done — blink effect needs polish)

**Phase 5 (HUD Polish):** ✅ Complete
- Minimap: Top-down _draw()-based minimap in bottom-right corner with biome terrain tiles, player/enemy/boss/collectible/portal/trader dots, facing direction indicator (toggle with M)
- Damage direction indicators: Red arrows on screen pointing toward damage source, fade over 1.5s
- Boss tension vignette: Pulsing red screen-edge vignette that intensifies with boss proximity
- Death screen: Staggered fade-in with "ZORP HAS FALLEN" title, stats (score with roll-up animation, kills, best combo, max pickup streak, time survived), press R/Space to restart
- Biome indicator: Top-center biome name display, color-matched to terrain, fades to dim after showing
- Dash cooldown indicator: Circular ring with ⚡ icon in bottom-left, green when ready with pulse animation
- Kill feed: Right-side scrolling kill entries ("Zorp ▸ EnemyName"), 5 max, 4s lifetime with fade
- Achievement popup system: 12 achievements (First Blood, On a Roll, Killing Spree, Unstoppable, Getting Stronger, Power Surge, Collector, Treasure Hunter, Giant Slayer, Explorer, Wanderer, Cartographer) with slide-in panels
- Power-up timer display: Buff duration bars for monolith buffs (Speed Surge, Power Surge, Wisdom Aura)

**Phase 6 (Particle Effects & Juice):** 🔄 Partial — 8 of 11 complete
- ParticleEffects system: Static factory class using GPUParticles3D for all particle effects (explosion, level-up burst, combo fireworks, pickup sparkle, death poof, sky beam, shield break, dash trail, ambient particles)
- Dash trail particles: Speed-line particles behind Zorp on dash start
- Level-up shockwave: Expanding golden ring + upward sparkle particles
- Combo milestone fireworks: Tier-colored particle bursts (6-color palette)
- Pickup sparkle: Small upward sparkle burst on item collection + sky beam on rare Meteor Shards
- Enemy death poof: Dark smoke cloud that expands and fades, scaled by enemy size
- Biome ambient particles: Continuous weather/ambient effects following player (snow in Snow, embers in Lava, spores in Mushroom/Swamp/Toxic, bubbles in Water, dust in Desert/Forest/etc.)
- Player damage flash: Red screen-edge vignette on damage taken
- Projectile impact explosion: Small cyan particle burst on hit

**Phase 8 (Physics & Interaction):** 🔄 Partial — 5 of 7 complete
- Enemy knockback: Projectiles apply directional impulse via `take_damage_from()`, enemies get pushed back from hit direction
- Enemy separation: Overlapping enemies softly push each other apart (prevents stacking)
- Destructible objects: Breakable crates (wooden) and crystal clusters (purple) scattered across biomes — shoot or dash to shatter into RigidBody3D physics fragments with bounce material, grants score + XP
- Physics-based dash: After dash burst, Zorp enters a slide phase with friction decay and bounces off walls (velocity reflection with 0.6 restitution) — dash into enemies to knock them back, dash into destructibles to smash them
- Graviton gravity well: Now uses an Area3D with `gravity_point = true` to apply real physics gravity to RigidBody3D fragments and collectibles during pull phase (player still pulled manually since CharacterBody3D ignores Area3D gravity)

**Phase 9 (Shaders & Visual Effects):** ✅ Complete
- 8 custom GLSL shaders in `assets/shaders/`:
  - **Heat Distortion** (Lava biome): Sine-wave UV displacement with warm orange edge tint and shimmering brightness pulse
  - **Frost Vignette** (Snow biome): Crystalline frost noise at screen edges with cold blue tint and breathing pulse
  - **Chromatic Aberration** (Alien biome): RGB channel split that intensifies toward corners with alien purple tint
  - **Dissolve** (Toxic bog): Animated value-noise corrosive fringe that drips downward, bright acid-green glow at dissolution edge
  - **Crystal Refraction** (Crystal biome): Faceted prismatic refraction with per-cell random direction and blue-purple shimmer
  - **Water Surface** (spatial shader): Vertex ripple displacement + scrolling UVs + specular highlights for water biome overlays
  - **Low-HP Vignette**: Pulsing red heartbeat vignette with desaturation, intensity scales with HP deficit
  - **Boss Enrage**: Red pulse + chromatic aberration + tunnel-vision darkening, activates when boss HP < 30%
- ShaderManager system (`shader_manager.gd`): CanvasLayer (layer 50) that manages all screen-space post-process shaders
  - Cross-fades biome ambient shaders on biome change (dual ColorRect A/B swap with exponential lerp)
  - Modulates low-HP vignette from HP ratio (activates below 30% HP, max at 0% HP)
  - Modulates boss enrage from boss HP ratio (activates below 30% boss HP)
  - Auto-fades and hides overlays when strength is negligible (GPU savings)
  - Resets all effects on player death / game restart
- Water biome overlays now use the animated water_surface shader (replaces flat unlit material)

**Phase 10 (Smart Enemy AI):** ✅ Complete — 🆕 New Feature
- **NavigationRegion3D**: Runtime nav mesh generation from static colliders (`navigation_manager.gd` autoload), baked after world generation. Enemies path around obstacles instead of walking in straight lines.
- **Line-of-sight checks**: RayCast3D every 0.3s determines if player is visible. Without LOS, enemy detection range is halved (heard but not seen).
- **Flanking**: 35% of alerted enemies circle around to the player's side/back instead of approaching directly. ±75° offset, perpendicular circling at 6m standoff.
- **Retreat**: Enemies at <25% HP back away from the player with a 1.15× speed boost. Resume fighting when HP recovers above 55%.
- **Ambush**: Unalerted enemies near cover hide and wait with reduced detection range. When the player approaches within 10m, they break ambush with a 1.6× speed rush.
- **Pack behavior**: Same-type enemies within 12m coordinate attacks. Surround slots are assigned so pack members approach from different angles instead of stacking. Pack frenzy triggers when any member drops below 10% HP — all nearby allies get 1.4× speed and a white flash.
- **Call for help**: Enemies at <35% HP alert all enemies within 16m. HUD message shows how many allies responded.
- **Enrage**: Enemies below 25% HP gain 1.35× speed, a smooth red color transition, and a pulsing red aura sphere. Proximity warnings are globally throttled.
- **Near-death shudder**: Enemies below 10% HP periodically shudder with X/Z scale jitter, signaling they're one hit from death.
- Smart AI is opt-in via `@export use_smart_ai` — disabled for stationary Sentinel, flanking/ambush disabled for Drake boss and Spore Spitter.

**Phase 14 (Dimensional Rifts):** ✅ Complete — 🆕 New Feature
- 4 alternate dimensions accessible via rift portals: **Void**, **Mirror**, **Time-Slow**, **Reverse Gravity**
- Rift portals spawn randomly every 25-45s near the player (max 2 active, 60s lifetime), with a swirling vortex shader (chromatic aberration, energy rings, pulsing glow)
- Entering a rift triggers a screen-wipe transition (sweep bands + chromatic aberration shader), then the dimension lasts 30s before auto-returning
- **Void Dimension**: Everything darkened to silhouettes; a shadow clone mini-boss spawns (80 HP, pure black with purple rim glow, strafes and shoots dark projectiles)
- **Mirror Dimension**: Collectibles become hostile (damage + knockback on touch, flash red), enemies become passive and won't attack
- **Time-Slow Dimension**: Enemies and enemy projectiles at 0.3x speed via `set_time_scale()`, player at 0.5x speed (relative advantage — Zorp is faster than the world)
- **Reverse Gravity Dimension**: Player smoothly rises to a 20m ceiling, mesh flips upside down; enemies and collectibles also relocate to ceiling height
- Exiting a dimension: 50% chance to spawn 2-4 rare collectibles (Meteor Shard, Quantum Fuzz, Nebula Dust) as rift rewards
- Dimension indicator HUD: top-center label with dimension name (color-matched) + countdown timer bar
- Rift portals visible on minimap as purple diamonds

**Phase 15 (Alien Companion Pet):** ✅ Complete — 🆕 New Feature
- Summon a loyal alien companion with **F key** (dismiss with F again)
- Pet follows Zorp using NavigationAgent3D pathfinding, floating at shoulder height
- **Auto-collect**: Pet vacuums nearby collectibles within a stage-scaled radius (8/12/16m) — items are pulled toward the pet and collected automatically
- **Fetch command**: Press **G** to enter fetch mode, then click any distant collectible to send the pet racing to retrieve it (20 m/s, 60m range)
- **3 evolution stages** (Baby → Adolescent → Adult), evolved by feeding on collected items:
  - **Baby** (light cyan, 0.3 scale): Collect only, 8m radius, 30 HP
  - **Adolescent** (teal, 0.5 scale, 8-particle aura): Collect + attack small enemies (≤30 HP), 12m radius, 60 HP
  - **Adult** (blue-purple, 0.7 scale, 20-particle aura): Collect + attack all enemies + 15% damage shield for Zorp, 16m radius, 100 HP
- Evolution thresholds: 100 points for Adolescent, 250 for Adult. Different collectible types grant different evolution points (XP_ORB=5, STAR_FRUIT=15, METEOR_SHARD=40, etc.)
- **Idle animations**: Pet randomly performs bounce, spin, tail-chase, or sleep animations every 5-8s when following
- Pet can take damage from enemies and dies with a 10s respawn timer
- Pet HUD: Bottom-left panel showing pet HP bar, evolution progress bar, stage name, and color-coded state (Follow/Fetch/Attack/Idle)
- Pet visible on minimap as a cyan-blue diamond
- Adult pet's 15% damage shield integrated into `GameManager.take_damage()`
- Pet vanishes when player dies

**Phase 16 (Weapon Mod Crafting):** ✅ Complete — 🆕 New Feature
- Collect **10 crafting material types** that drop from enemy kills (12% drop chance for normal enemies, 100% for bosses)
- 5 new material types: **Shield Crystal** (blue), **Fireball Scroll** (orange), **Regen Crystal** (green), **Magnet Core** (metallic), **Toxic Extract** (sickly green)
- Press **C** to open the crafting menu — select 2 materials (or 3 for mega mods) and craft them into a weapon mod
- **20 unique weapon mods**, each with distinct laser behavior:
  - **Homing Laser** — bolts track the nearest enemy
  - **Reflective Shield** — 40% damage reduction, defensive utility
  - **Chain Lightning** — damage chains to 3 nearby enemies on hit
  - **Spread Shot** — fires 3 bolts in a fan pattern
  - **Piercing Beam** — passes through up to 3 enemies
  - **Bouncing Bolt** — bounces off walls up to 3 times
  - **Freeze Ray** — slows enemies for 2 seconds
  - **Acid Trail** — leaves a lingering acid pool that damages enemies over time
  - **Mega Blast** — massive AoE explosion on impact (3-material recipe)
  - **Splitter Laser** — splits into two angled projectiles on hit
  - **Vampire Beam** — drains HP from enemies, healing Zorp for 25% of damage
  - **Gravity Well Laser** — pulls nearby enemies toward the projectile's path
  - **Ricochet Pulse** — bounces damage to the next nearest enemy
  - **Plasma Nova** — explodes in a plasma nova on impact
  - **Sniper Beam** — 2x damage, 2x speed, long-range single bolt
  - **Shrapnel Burst** — explodes into 6 directional fragments
  - **Blaze Trail** — sets enemies on fire, burning over 3 seconds
  - **Tesla Coil** — electric arcs zap nearby enemies in flight
  - **Void Ray** — slows enemies and drains energy
  - **Quantum Overdrive** — triple homing bolts with chain lightning (3-material mega)
- Each mod has unique **laser color**, **damage multiplier** (0.5x–2.5x), **fire rate multiplier**, and **projectile speed multiplier**
- **Discovery system**: Try unknown material combinations to discover new mods. Invalid combos refund half the materials
- **Equip system**: Only 1 mod active at a time. Switch freely between discovered mods in the crafting menu
- Crafting menu UI: Full-screen overlay with material grid (click to select), craft button, discovered mods panel with equip buttons
- HUD weapon mod indicator: bottom-center label showing current mod name (color-matched) and total material count
- `WeaponModSystem` autoload singleton manages inventory, crafting, and equip state

**Remaining phases:** Dynamic weather, boss arenas, co-op, audio & polish.

## License

Open source — same as the original Zorp Wiggles project.# v0.1.0-godot
