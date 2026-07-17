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
| Enter | Player 2 (Zerp) drop-in / hold to drop-out |
| Arrow Keys | P2 movement |
| / | P2 shoot |
| Enter | P2 dash |
| Right Shift | P2 pulse wave |
| . | P2 revive Zorp |
| E | P1 revive Zerp (when close) |

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
│   ├── weather_system.gd  # Dynamic weather autoload singleton (Phase 17)
│   ├── weather_indicator.gd # Weather HUD indicator (Phase 17)
│   ├── audio_manager.gd    # Procedural SFX + biome/boss music autoload (Phase 20)
│   ├── pause_menu.gd       # Pause menu — Resume/Settings/Quit (Phase 20)
│   ├── settings_menu.gd    # Settings — volume sliders, controls (Phase 20)
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

**Phase 17 (Dynamic Weather):** ✅ Complete — 🆕 New Feature
- 6 dynamic weather states cycle through the world: **Clear**, **Acid Rain**, **Solar Flare**, **Fog**, **Thunderstorm**, **Snow Storm**
- Each weather lasts 35–70 seconds with smooth 4-second cross-fade transitions
- Weather selection is **biome-biased**: acid rain more likely in toxic bogs, solar flares in lava/desert, fog in wetlands, thunderstorms near water, snow storms in frozen biomes
- **Acid Rain**: Damages all exposed entities (player + enemies) every second. Raycasts upward to check for shelter — 75% damage reduction under overhangs
- **Solar Flare**: Boosts fire rate by 1.5× with a pulsing orange world light that follows the player
- **Fog**: Reduces enemy detection range to 50% (stealth opportunity) and smoothly increases WorldEnvironment fog density to 3× baseline
- **Thunderstorm**: Random lightning strikes with 1.2s telegraph warning, 45 AoE damage in a 6m radius, bright light flash + camera shake
- **Snow Storm**: Slows all movement to 70% and reduces slide friction to 40% for icy, slidey physics
- Weather particles (300–400 GPUParticles3D) follow the player: streaking acid rain, rain drops, blowing snow, drifting fog motes, rising embers
- **Weather-dependent enemy spawning**: Void Wisps during thunderstorms, Spore Spitters during acid rain, Sentinels during fog/snow
- HUD weather indicator (top-right): shows current weather icon, name, countdown timer bar, and upcoming weather during transitions

**Phase 18 (Boss Arenas):** ✅ Complete — 🆕 New Feature
- When a boss spawns, the terrain around the player morphs into an **enclosed arena** with rising walls, a colored floor disc, and destructible cover pillars
- **3 arena types** determined by the boss:
  - **Lava Arena** (Plasma Drake): Lava geysers erupt from the ground + the arena floor **shrinks every 15 seconds**, walls closing in to increase pressure
  - **Crystal Arena** (Plasma Serpent): Falling crystal stalactites drop from above + crystal cover pillars
  - **Void Arena** (Graviton): Expanding void shockwaves push entities away
- **12 wall segments** (StaticBody3D) rise from underground with a 2s tween animation, forming an impassable ring around the fight zone
- **6 destructible cover pillars** (tougher than normal crates, 60 HP) provide tactical positioning
- **3 environmental hazard types**:
  - **Lava Geyser**: Erupts as a tall column after 1.5s telegraph, dealing 30 damage + knockback
  - **Falling Crystal**: Drops from 25m height with a shadow telegraph, 45 damage + shatter effect on impact
  - **Void Shockwave**: Expands outward continuously, pushing and damaging entities in its path
- Each hazard has a **telegraph warning** (pulsing ground circle for 1.5s) so players can dodge
- **Arena shrinking** (Lava arena): Walls close in by 4m every 15s (minimum 10m radius), with particle bursts + camera shake + warning messages
- **Arena transition effect**: 200-particle explosion on formation, 0.4 trauma camera shake, pulsing floor emission
- On boss death: walls sink back underground, floor fades, and an **exit portal** spawns at the arena center (lasts 30s)
- **Auto-spawn system**: BossArena auto-spawns bosses every 120s if player score ≥500, rotating through Drake/Serpent/Graviton for variety
- Non-Drake bosses (Serpent, Graviton) are promoted to boss-tier with boosted HP (250 + player level × 20) and the `is_arena_boss` flag
- Navigation mesh is rebuilt after arena construction and removal so enemy pathfinding accounts for walls and cover

**Phase 19 (Local Co-op):** ✅ Complete — 🆕 New Feature
- **Player 2 "Zerp"** drops in with **Enter** key for shared-screen local co-op — a magenta-purple alien with 100 HP, 0.9× damage, and 1.05× dash range
- **Controls:** Arrow keys (move), `/` (shoot), Enter (dash), Right Shift (pulse wave), `.` (revive Zorp), hold Enter 2s (drop out)
- **Shared camera** dynamically zooms from 22m → 42m based on player spacing, targeting the midpoint between both players so both stay on-screen
- **Co-op enemy scaling:** 2× HP, 1.5× damage, 30% faster spawns, +15 max enemies — the planet fights back harder with two players
- **Shared combo system:** Both players contribute to the same combo counter, with a +1s window bonus in co-op so the streak lasts longer
- **Revive system:** When a player's HP hits 0, they enter a **downed state** with a 30-second bleed-out timer. The partner must get within 3.5m and hold the revive key for 3 seconds. Revive restores 60 HP + 2s invulnerability. If the timer runs out, the player dies for real
- **Co-op mega pulse wave:** If both players fire their pulse wave (Q / RShift) within a 1-second sync window, a **mega pulse** triggers — 1.8× radius, 2.5× damage, 3 overlapping magenta pulse rings, particle spectacle, and heavy camera shake
- **Drop-in / drop-out:** Player 2 can join or leave at any time — press Enter to drop in, hold Enter for 2 seconds to drop out
- **7 co-op achievements:** First co-op kill, 50 co-op kills, first revive, 5 revives, first mega pulse, 3 mega pulses
- Enemies intelligently target the **nearest valid player** (downed players are deprioritized), collectibles pull toward the nearest player, and P2 kills track to P2's score
- **Co-op HUD** shows P2 HP bar, score, downed/revive overlays for both players, drop-in prompt, and milestone popups
- P2 appears on the **minimap** as a magenta dot with facing direction
- Weather and enemy spawning continue when P1 is downed but P2 is still alive

**Phase 20 (Audio & Polish):** ✅ Complete — 🆕 New Feature
- **24 procedurally generated sound effects** — all SFX synthesized at runtime as AudioStreamWAV with raw PCM data (no external audio files needed). Includes: shoot, dash, dash bump, pickup, rare pickup, level up, combo milestone, damage, heal, death, enemy hit, enemy death, boss spawn, boss defeated, explosion, pulse wave, thunder, arena rise, mutation, rift, revive, pet summon, craft, UI click
- **12-player SFX pool** allows overlapping sounds without cutting each other off (important for rapid-fire combat)
- **Per-biome ambient music** — 12 unique looping drone tracks, one per biome, each with a distinct base frequency and harmonic set. Music auto-switches when the player crosses biome boundaries (via `biome_changed` signal)
- **Boss fight music** — intense driving 8-second loop with a bass pulse on every beat, dissonant tension layer, and percussive noise hits. Auto-starts on `boss_spawned`, stops on `boss_defeated`, biome music resumes afterward
- **Pause menu** (P key): Full-screen overlay with Resume, Settings, and Quit to Menu buttons. Uses `PROCESS_MODE_ALWAYS` so the UI remains responsive while the scene tree is paused
- **Settings menu**: Master/SFX/Music volume sliders with real-time adjustment via `AudioServer`. Full controls reference (single + co-op). Accessible from both the pause menu and the main menu
- **Death screen enhanced** with clickable "Try Again" and "Quit to Menu" buttons that appear after the fade-in animation. Still supports R/Space keyboard restart
- **Main menu** updated with a Settings button for pre-game volume configuration
- Screen shake (trauma-based) and smooth camera follow (exponential lerp) were already implemented in `camera_rig.gd` from earlier phases
- `AudioManager` registered as autoload singleton in `project.godot`

**All Phases 1–20 Complete!** Phase 21 (Export & Distribution) is intentionally skipped.

## Enhancement Pack 1 — New Content

### New Enemy Types (8 → 10)
- **Swarm Mite** — Tiny, very fast enemy (speed 9.0, HP 12) that spawns in packs of 3–6. Individually weak but they overwhelm from multiple directions. 40% of mite spawns are packs, creating swarming pressure. Orange-brown glowing bug aesthetic.
- **Crystal Guardian** — Slow, tanky ranged enemy (HP 180) that fires crystal shard projectiles with a charge-up telegraph. High metallic crystalline material. Kiting is the counter-strategy. 60 XP per kill.
- **Pack spawning system** — Swarm Mites have a 40% chance to spawn as a pack of 3–6 with staggered spawn timers, creating the "swarm" feel.

### New Weapon Mods (20 → 22)
- **Black Hole Beam** (Magnet Core + Meteor Shard) — Creates a singularity on impact that pulls enemies in over 1.2s, dealing tick damage, then collapses for 1.5× AoE damage. Dark sphere with negative light absorption, purple emission. Crowd-control mod.
- **Photon Beam** (Regen Crystal + Shield Crystal) — Rapid-fire piercing photon bolts that pass through up to 5 enemies. 2× fire rate and 2× projectile speed. Each bolt is weak but the volume of fire makes it a sustained DPS monster. Warm white-gold color.

### New Weather Types (6 → 8)
- **Meteor Shower** (☄) — Random meteor strikes with 2-second telegraph. Meteors are visible falling from the sky as fiery spinning orbs during the telegraph. 60 damage, 8m radius AoE — bigger and more damaging than lightning. Biome affinity: Lava, Desert, Alien.
- **Aurora** (🌌) — Colorful shifting sky lights that boost XP gain by 50%. High-altitude light cycles through green-teal-purple hues. Encourages aggressive play during auroras. Biome affinity: Snow, Crystal, Floating Islands.

## License

Open source — same as the original Zorp Wiggles project.# v0.1.0-godot
