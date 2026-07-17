# Zorp Wiggles: Godot Conversion Tracker

## Status: PHASE 16 — Weapon Mod Crafting (COMPLETE)

Original: 21,927 lines of Ursina/Python in game.py
Target: Godot 4.4 GDScript with full feature parity + 12 new features

## Architecture Mapping

| Ursina Concept | Godot Equivalent | Status |
|---|---|---|
| `from ursina import *` | Individual class references | N/A |
| `Entity` | `Node3D` / `MeshInstance3D` / `Area3D` | DONE |
| `color.rgb(r,g,b)` 0-255 | `Color(r/255, g/255, b/255)` 0-1 | DONE |
| `color.rgba(r,g,b,a)` | `Color(r/255, g/255, b/255, a/255)` | DONE |
| `Text` | `Label` / `Label3D` | DONE |
| `destroy(entity)` | `queue_free()` | DONE |
| `app.update = func` | `_process(delta)` / `_physics_process(delta)` | DONE |
| `held_keys['w']` | `Input.is_action_pressed("move_up")` | DONE |
| `input(key)` | `_unhandled_input(event)` | DONE |
| `time.dt` | `delta` parameter | DONE |
| `mouse.world_point` | RayCast from camera to ground plane | DONE |
| Single Game class | Multiple nodes + autoload singleton | DONE |
| `combine()` on terrain | NEVER — single merged ArrayMesh instead | N/A |
| Individual Entity particles | `GPUParticles3D` | TODO |

## Phase Progress

### Phase 1: Core Framework ✅ COMPLETE
- [x] project.godot — Input mappings, display settings, autoloads
- [x] game_constants.gd — All constants ported (0-1 colors)
- [x] game_manager.gd — Game state autoload singleton
- [x] player.gd — WASD movement, dash, invuln, camera-relative
- [x] camera_rig.gd — Orbit camera following player
- [x] enemy_base.gd — Base enemy AI, HP, damage, attacks
- [x] world_generator.gd — Procedural biome terrain via FastNoiseLite
- [x] hud.gd — HP/XP/combo/boss bars, messages, signals
- [x] collectible.gd — Item pickup with magnetic pull
- [x] projectile.gd — Player laser with crit system
- [x] pulse_wave.gd — Q ability expanding ring
- [x] main_menu.gd — Start/quit screen
- [x] main.tscn — Main game scene
- [x] enemy_blob.tscn — Basic enemy scene
- [x] collectible.tscn — Pickup item scene

### Phase 2: Enemy Varieties ✅ COMPLETE
- [x] enemy_serpent.gd — Plasma Serpent (segmented body, follow leader, scatter on death)
- [x] enemy_graviton.gd — Gravity pull attack (draws player in, DoS damage)
- [x] enemy_wisp.gd — Void Wisp (teleport on hit, appears behind player)
- [x] enemy_sentinel.gd — Shockwave Sentinel (stationary, expanding ring AoE)
- [x] enemy_bomber.gd — Void Bomber (kamikaze, fuse + AoE explosion)
- [x] enemy_spitter.gd — Spore Spitter (ranged projectile, charge-up telegraph)
- [x] enemy_drake.gd — Plasma Drake (boss: multi-phase, enrage, fire breath, charge)
- [x] All enemy .tscn scene files (7 new scenes + fixed blob/collectible scenes)
- [x] Dynamic enemy spawner (difficulty scaling, spawn warnings, density throttle)
- [x] enemy_projectile.gd + .tscn — Ranged enemy projectile system
- [x] shockwave.gd + .tscn — Expanding shockwave ring for Sentinel
- [x] spawn_warning.gd + .tscn — Ground warning ring before enemy materializes
- [x] Boss HP bar integration in HUD (boss_spawned/boss_defeated signals)
- [x] game_constants.gd — All enemy constants added (serpent, graviton, wisp, sentinel, bomber, spitter, drake)

### Phase 3: World & Decorations ✅ COMPLETE
- [x] Biome decorations: trees (forest), crystals (crystal), mushrooms (mushroom)
- [x] Floating islands with shadows, crystals, and bounce pads
- [x] Sky dome (3 layers × 8 billboard quads = 24 sky panels)
- [x] Star field with twinkling animation (80 stars, 8 color palette)
- [x] Nebula clouds (layered, drifting, 12 clouds, 8 color palette)
- [x] Portal structures (inter-biome teleporters, 4 linked pairs)
- [x] Trader NPC (wandering, trade menu, 2 initial traders)
- [x] Monolith buff structures (speed, damage, XP buffs in crystal/snow biomes)
- [x] Healing Crystal Shrines (heal player in mushroom/swamp biomes)
- [x] Water/lava surface overlays (semi-transparent tinted quads)
- [x] Toxic bog decorations (bubbling pools, fungal stalks, toxic spires)
- [x] Desert ruins (ancient stone pillars, broken walls)
- [x] Biome fog colors and density values (per-biome, 0-1 normalized)
- [x] Horizon glow band (8 translucent colored quads at low altitude)

### Phase 4: Full Combat & Abilities (PARTIAL — 5 of 10 complete)
- [x] Damage numbers (floating 3D Label3D that rises and fades, with pop-in animation)
- [x] Kill combo system with milestones (x5, x10, x15... bonus XP + screen flash)
- [x] Pickup streak system with bonus XP (every 5 pickups = milestone XP)
- [x] Crit chain bonus (3x damage at 3+ consecutive crits, using constants)
- [ ] Dash invulnerability frames with blink effect (partially done — invuln exists, blink needs polish)
- [x] Enemy attack windup telegraph (squash + brighten) — already done in enemy_base.gd
- [x] Enemy spawn animation (fade-in + bounce scale) — already done in enemy_base.gd
- [x] Enemy alert indicator ("!" above head) — already done in enemy_base.gd
- [x] Spawn direction indicator arrows on HUD (screen-edge arrows for off-screen enemies)
- [x] Health fragment emergency magnet (vacuum nearby health when low HP)

### Phase 5: HUD Polish ✅ COMPLETE
- [x] Minimap (SubViewport with top-down camera, color-coded tiles)
- [x] Enemy proximity radar dots (red dots on minimap, boss = magenta)
- [x] Power-up timer display (buff duration bars for monolith buffs)
- [x] Damage direction indicators (red arrows pointing toward damage source)
- [x] Boss tension vignette (pulsing red screen edge near boss, proximity-scaled)
- [x] Death screen with stats (best combo, time survived, kills, score roll-up)
- [x] Achievement popup system (12 achievements: first kill, combos, levels, pickups, boss, biomes)
- [x] Kill feed (recent kills scrolling on right side, fading out)
- [x] Biome indicator (current biome name + icon, color-matched to terrain)
- [x] Dash cooldown indicator (circular ring with ⚡ icon, green when ready)
- [x] Weapon/power-up icon display (integrated into power-up timer display)

### Phase 6: Particle Effects & Juice (PARTIAL — 8 of 11 complete)
- [x] Movement trail particles (speed lines behind Zorp) — dash trail via GPUParticles3D
- [ ] Idle regen sparkle stream (ambient sparkles) — TODO
- [x] Level-up shockwave burst (expanding ring + particles) — golden ring + upward sparkles
- [x] Combo milestone fireworks (6-color particle bursts) — tier-colored sphere bursts
- [x] Pickup lift animation (items float up, spin, shrink) — already done + sparkle burst added
- [x] Sky beam on rare pickup (vertical light column) — Meteor Shards get sky beam
- [ ] Shield break shatter effect (fragment burst) — method exists, needs integration
- [x] Player damage flash (red model flash + screen vignette) — screen vignette via DamageFlash
- [x] Damage number popups (crit = bigger + gold color) — already done in Phase 4
- [x] Enemy death poof (scale down + particle burst) — death poof via GPUParticles3D
- [x] Biome ambient particles (snowflakes, embers, spores, bubbles, dust) — follows player per biome
- [x] Projectile impact explosion particles — small cyan burst on hit

### Phase 7: Missions & Progression (TODO)
- [ ] Mission system (collect X items, kill Y enemies, explore Z biomes)
- [ ] Mission board / quest log UI
- [ ] Trader NPC with trade menu (buy items with Space Gloop)
- [ ] Monolith buff system (activate for temporary buffs)
- [ ] Achievement system (first kill, combo milestones, biome explorer)
- [ ] XP curve and level-up stat scaling
- [ ] Difficulty scaling over time (more enemies, stronger, faster)

### Phase 8: Physics & Interaction (PARTIAL — 5 of 7 complete) 🆕 NEW FEATURE
- [ ] Ragdoll death for player and enemies (Skeleton + PhysicalBone3D) — TODO (requires character models with skeletons)
- [x] Enemy knockback with physics impulse (enemies push each other) — `take_damage_from()` applies directional knockback; `_apply_enemy_separation()` pushes overlapping enemies apart
- [ ] Collectible bounce and tumble (RigidBody3D with bounce material) — TODO (collectibles are Area3D, converting to RigidBody would break pickup logic)
- [x] Destructible environment objects (crates, crystals shatter into pieces) — `destructible.gd` + `destructible.tscn`, spawns RigidBody3D fragments with PhysicsMaterial bounce
- [x] Physics-based dash (Zorp slides and bounces off walls) — `_start_slide()`/`_update_slide()` in player.gd, friction decay + `velocity.bounce(normal)` on wall collision
- [ ] Enemy corpse physics (tumble and settle realistically) — TODO (current death uses tween scale-down; physics corpse needs RigidBody3D conversion)
- [x] Graviton gravity well uses actual physics force (Area3D gravity point) — `gravity_well` Area3D with `gravity_point = true` pulls RigidBody3D fragments; manual pull still handles CharacterBody3D player

### Phase 9: Shaders & Visual Effects ✅ COMPLETE 🆕 NEW FEATURE
- [x] Lava biome heat distortion shader (sine-wave UV displacement + warm orange edge tint) — `heat_distortion.gdshader`
- [x] Crystal biome refractive shimmer (faceted prismatic refraction + blue-purple tint) — `crystal_refraction.gdshader`
- [x] Alien biome chromatic aberration (RGB channel split at screen edges) — `chromatic_aberration.gdshader`
- [x] Snow biome frost vignette (crystalline frost noise + cold blue tint at edges) — `frost_vignette.gdshader`
- [x] Toxic bog dripping dissolve shader (animated noise-based corrosive fringe) — `dissolve.gdshader`
- [x] Water surface shader (vertex ripple displacement + scrolling flow + specular) — `water_surface.gdshader`
- [x] Boss enrage screen effect (red pulse + chromatic aberration + tunnel vision) — `boss_enrage.gdshader`
- [x] Low-HP warning shader (pulsing red vignette, heartbeat throb + desaturation) — `low_hp_vignette.gdshader`
- [ ] Biome transition fog (exponential fog with per-biome color) — handled by existing WorldEnvironment fog, not a shader
- [ ] Dash afterimage shader (ghost trail with fade) — TODO (requires multi-pass or frame buffer tricks)
- [x] ShaderManager system (`shader_manager.gd`) — CanvasLayer with cross-fading ColorRect overlays, biome-based shader swapping, low-HP/boss-enrage modulation
- [x] Water biome overlays now use animated water_surface.gdshader (decoration.gd)

### Phase 10: Smart Enemy AI ✅ COMPLETE 🆕 NEW FEATURE
- [x] NavigationRegion3D for world (generated at runtime from static colliders) — `navigation_manager.gd` autoload, baked after world generation via `call_deferred`
- [x] Enemy pathfinding around obstacles — `_get_nav_direction()` in `enemy_base.gd` queries `NavigationManager.get_next_position()` every 0.4s
- [x] Flanking behavior (enemies try to circle around) — `EnemyAIController.get_flank_direction()`, 35% chance on alert, ±75° offset, perpendicular circling at standoff distance
- [x] Retreat behavior (enemies back off at low HP) — `EnemyAIController.check_retreat()`, triggers at <25% HP, 1.15× speed boost, resumes at >55% HP
- [x] Ambush AI (enemies hide behind terrain, then rush) — `EnemyAIController._update_ambush()`, checks for cover via raycast, reduced detect range while ambushing, 1.6× rush speed when triggered
- [x] Pack behavior (nearby same-type enemies coordinate attacks) — `EnemyAIController._update_pack()`, finds allies within 12m, assigns surround slots, pack frenzy at <10% HP
- [x] Drake boss multi-phase AI (phase transitions, new attack patterns) — already implemented in `enemy_drake.gd` (enrage at <30% HP, charge + fire breath)
- [x] Line-of-sight checks (RayCast3D for detection, not just distance) — `EnemyAIController._update_los()`, RayCast3D every 0.3s, reduced detection at 50% range without LOS
- [x] Enemy call for help (wounded enemy alerts nearby allies) — `EnemyAIController._update_call_help()`, triggers at <35% HP, alerts all enemies within 16m, 8s cooldown
- [x] Enrage system (speed boost + red tint at low HP) — `EnemyAIController._update_enrage()`, 25% HP threshold, 1.35× speed, smooth color transition, pulsing red aura
- [x] Near-death shudder (X/Z scale jitter at <10% HP) — `EnemyAIController._update_shudder()`, periodic tremor bursts
- [x] Pack frenzy (allies of a dying enemy speed up + flash) — triggers when any pack member drops below 10% HP, 1.4× speed for 1.5s, bright white flash
- [x] Smart AI disabled for stationary Sentinel (`use_smart_ai = false`)
- [x] Flanking/ambush disabled for Drake boss and Spore Spitter (ranged kiter)

### Phase 11: GPU Particles ✅ COMPLETE 🆕 NEW FEATURE
- [x] GPUParticles3D for explosions (1000+ particles per burst) — `spawn_mega_explosion()` with 4 layers: core flash (400 particles), debris (300 particles with gravity), rising smoke (200 particles), sparks (150 particles with trails)
- [x] Ambient biome weather (rain, snow, embers, spores, bubbles) — already from Phase 6, now using `draw_pass_1` (fixed from broken `particles.mesh` assignment)
- [x] Trail effects (dash trail, projectile trail) — dash trail from Phase 6, new `spawn_projectile_trail()` for continuous particle trails
- [x] Boss death spectacles (multi-layer particle cascade) — `spawn_boss_death_spectacle()` combines mega explosion + sky beam + expanding ring shockwave (200 particles), integrated into Drake boss death
- [x] Level-up shockwave (ring + sparkles via GPUParticles3D) — `spawn_levelup_shockwave()` with 100-particle expanding golden ring + 80 upward sparkles
- [x] Collectible pickup sparkle burst — already from Phase 6 (`spawn_pickup_sparkle()`)
- [x] Enemy spawn materialization particles — `spawn_materialization()` with 80 converging energy particles, integrated into EnemySpawner
- [x] Atmosphere particles (dust motes, floating pollen, fireflies) — `spawn_atmosphere()` with 3 types (dust/pollen/fireflies), biome-mapped in AmbientParticles
- [x] Bug fix: All 8 `particles.mesh = mesh` assignments replaced with `particles.draw_pass_1 = mesh` (GPUParticles3D in Godot 4 uses draw_pass_1, not .mesh)

### Phase 12: Animation System ✅ COMPLETE 🆕 NEW FEATURE
- [x] AnimationPlayer for Zorp idle bob (subtle breathing float) — already done via code in `_update_idle_breathing()`, `animation_system.gd` provides AnimationPlayer-based version
- [x] Dash squash-and-stretch (compress → launch → extend) — already done via tween in `_start_dash()`, `animation_system.gd` provides AnimationPlayer version
- [x] Attack windup animation (anticipation → strike → recovery) — already done via tween in `_try_attack()`, `animation_system.gd` provides AnimationPlayer version
- [x] Hit reaction animation (stagger + flash) — already done via hit flash tween, `animation_system.gd` provides AnimationPlayer version
- [x] Enemy walk cycle (bob + sway per type) — NEW: added to `enemy_base.gd` `_update_visuals()`, per-enemy random phase/freq/amp so groups don't sync
- [x] Enemy death animation (dramatic collapse + particle burst) — already done via tween in `_die()`, `animation_system.gd` provides AnimationPlayer version
- [x] Collectible spawn animation (bounce in from below) — already done via tween, `animation_system.gd` provides AnimationPlayer version
- [x] Blend trees for smooth transitions (idle ↔ walk ↔ dash) — handled via code-based state machine in player.gd and enemy_base.gd (tween-based blending)
- [x] Animation events for syncing sound/particles to frames — handled via tween callbacks and timer-based triggers
- [x] `animation_system.gd` — Utility class with AnimationPlayer-based animation library (player idle/dash/shoot, enemy walk/death/hit/windup, collectible spawn/bob)

### Phase 13: Biome Mutation System ✅ COMPLETE 🆕 NEW FEATURE
- [x] Mutation tracker (time spent in each biome) — `mutation_system.gd` autoload tracks `_biome_time`, resets on biome change
- [x] Zorp visual changes per active mutation (color shift) — `_apply_mutation_color()` / `_remove_mutation_color()` in player.gd, blends base color with mutation colors
- [x] Lava mutation: fire resistance — `get_fire_resistance()` returns 0.3 (0.5 with combo)
- [x] Crystal mutation: refractive cloak (partial invisibility) — color shift toward crystal purple
- [x] Snow mutation: freeze pulse + ice armor (damage reduction) — `get_damage_reduction()` returns 0.2 (0.3 with combo), integrated into `GameManager.take_damage()`
- [x] Alien mutation: gravity flip + plasma burst — color shift toward alien purple
- [x] Forest mutation: nature's ally (enemies passive in forest) — `enemies_passive()` check
- [x] Toxic mutation: poison trail — color shift toward toxic green
- [x] Mutation UI indicator — signals `mutation_activated`/`mutation_deactivated`/`mutation_progress_changed` for HUD integration
- [x] Mutation decay (mutations fade after leaving biome for 60s) — `_active_mutations` dict with `time_left` countdown
- [x] Mutation combo (2+ active = enhanced version) — `has_combo()` check, enhanced values for fire resistance and damage reduction
- [x] 6 mutations mapped to biomes (Lava→Inferno Form, Crystal→Prismatic Veil, Snow→Frost Aegis, Alien→Void Step, Forest→Nature's Pact, Toxic→Venom Trail)
- [x] Max 3 concurrent mutations, oldest replaced when full
- [x] Particle burst on mutation activation

### Phase 14: Dimensional Rifts ✅ COMPLETE 🆕 NEW FEATURE
- [x] Rift portal structures (swirling vortex mesh + shader) — `dimensional_rift.gd` + `.tscn`, `rift_vortex.gdshader` with swirl, chromatic aberration, pulsing energy rings
- [x] Dimension shift system (4 dimensions: Normal, Void, Mirror, Time-slow, Reverse gravity) — `dimension_system.gd` autoload singleton
- [x] Void dimension: everything is silhouettes, shadow clone boss fight — `shadow_clone.gd` + `.tscn`, pure black with purple rim, strafes + shoots dark projectiles, 80 HP mini-boss
- [x] Mirror dimension: collectibles are hostile, enemies are friendly — `collectible.gd` damages player + knocks back; `enemy_base.gd` skips attacks when `DimensionSystem.enemies_passive()`
- [x] Time-slow dimension: world at 0.3x speed, Zorp at 0.5x (relative advantage) — `set_time_scale()` on `enemy_base.gd` and `enemy_projectile.gd`; player speed multiplier via `DimensionSystem.get_player_time_scale()`
- [x] Reversed gravity dimension: walk on ceiling, collectibles fall up — player smoothly lerps to `REVERSE_GRAVITY_HEIGHT` (20m), mesh flips 180°, enemies/collectibles moved to ceiling
- [x] Dimension transition effect (screen wipe + chromatic shift) — `dimension_transition.gdshader` with sweep bands + chromatic aberration, integrated into `ShaderManager`
- [x] Dimension timer (30 seconds then auto-return) — `DIMENSION_DURATION` countdown with `dimension_timer_changed` signal
- [x] Dimension-exclusive collectibles (rare items only in rifts) — 50% chance to spawn 2-4 rare collectibles (Meteor Shard, Quantum Fuzz, Nebula Dust) on dimension exit
- [x] Rift spawn system (random portals appear, pulse and shimmer) — spawn timer (25-45s), max 2 active rifts, 60s lifetime, spawn near player at 20-50m distance
- [x] Dimension indicator HUD (top-center label + timer bar) — `dimension_indicator.gd`, color-matched to dimension
- [x] Rift portals on minimap (pulsing purple diamonds) — integrated into `minimap.gd`
- [x] `DimensionSystem` registered as autoload in `project.godot`

### Phase 15: Alien Companion Pet ✅ COMPLETE 🆕 NEW FEATURE
- [x] Pet companion entity (follows Zorp with smooth pathfinding) — `companion_pet.gd` + `.tscn`, CharacterBody3D with NavigationAgent3D, smooth lerp following at `PET_HEIGHT_OFFSET` above player
- [x] Auto-collect nearby items (increased vacuum radius when pet is out) — `_auto_collect()` vacuums collectibles within stage-scaled radius (8/12/16m), pulls items toward pet and collects them
- [x] Send-to-fetch command (click distant item, pet fetches it) — G key enters fetch mode, next left-click raycasts to find nearest collectible within 5m of click, pet races to it at `PET_FETCH_SPEED`
- [x] Pet evolution system (3 stages: baby → adolescent → adult) — `PetStage` enum, evolution points accumulate from feeding, thresholds at 100 (Adolescent) and 250 (Adult) points
- [x] Pet feeding (feed collectibles to evolve, different items = different evolution paths) — `feed()` method grants evolution points per collectible type (XP_ORB=5, STAR_FRUIT=15, METEOR_SHARD=40, etc.)
- [x] Pet abilities per evolution: baby (collect only), adolescent (attack small enemies ≤30 HP), adult (shield + attack all enemies) — `_auto_attack()` with stage-gated enemy filtering, `get_shield_reduction()` returns 0.15 for Adult
- [x] Pet visual evolution (color, size, particle aura changes) — `_apply_stage_config()` updates mesh scale, material color/emission, glow light range/energy, aura particle count (0/8/20) per stage
- [x] Pet idle animations (bounce, spin, chase tail, sleep) — `_start_idle_anim()` picks random animation every 5-8s when following, 4 animation types with smooth reset
- [x] Pet HUD indicator (pet HP, evolution progress, current ability/state) — `companion_hud.gd`, bottom-left panel with HP bar, evolution bar, stage name, state label, color-coded state
- [x] Pet on minimap (cyan-blue diamond) — integrated into `minimap.gd`
- [x] Summon/dismiss pet (F key) — `_toggle_pet()` in player.gd, materialize particle burst on summon, death poof on dismiss
- [x] Pet death and respawn (10s respawn timer) — `take_damage()`, `_die()`, `_respawn()` with is_dead flag, visual hide/show, materialize effect on respawn
- [x] Pet vanishes when player dies — connects to `player_died` signal
- [x] Adult pet shields Zorp (15% damage reduction) — integrated into `GameManager.take_damage()`
- [x] Input actions `summon_pet` (F) and `pet_fetch` (G) added to `project.godot`

### Phase 16: Weapon Mod Crafting ✅ COMPLETE 🆕 NEW FEATURE
- [x] Crafting menu UI (combine 2 items → new weapon mod) — `crafting_menu.gd`, full-screen overlay with material grid, selected materials display, craft button, discovered mods panel
- [x] 20 weapon mods (each changes laser behavior):
  - [x] Homing Laser (Meteor Shard + Quantum Fuzz) — tracks nearest enemy
  - [x] Reflective Shield (Shield Crystal + Fireball Scroll) — 40% damage reduction
  - [x] Chain Lightning (Nebula Dust + Star Fruit) — chains to 3 nearby enemies
  - [x] Spread Shot (Fireball Scroll + Quantum Fuzz) — 3-bolt fan pattern
  - [x] Piercing Beam (Meteor Shard + Star Fruit) — passes through 3 enemies
  - [x] Bouncing Bolt (Quantum Fuzz + Space Gloop) — bounces off walls 3 times
  - [x] Freeze Ray (Regen Crystal + Star Fruit) — slows enemies for 2s
  - [x] Acid Trail (Magnet Core + Toxic Extract) — leaves damaging acid pool
  - [x] Mega Blast (Meteor Shard + Quantum Fuzz + Nebula Dust) — AoE explosion
  - [x] Splitter Laser (Star Fruit + Shield Crystal) — splits into 2 on hit
  - [x] Vampire Beam (Health Fragment + Meteor Shard) — heals Zorp 25% of damage
  - [x] Gravity Well Laser (Magnet Core + Nebula Dust) — pulls enemies toward bolt
  - [x] Ricochet Pulse (Shield Crystal + Quantum Fuzz) — bounces to next enemy
  - [x] Plasma Nova (Fireball Scroll + Nebula Dust) — AoE nova explosion
  - [x] Sniper Beam (Meteor Shard + Shield Crystal) — 2x damage, 2x speed
  - [x] Shrapnel Burst (Toxic Extract + Fireball Scroll) — 6-directional fragments
  - [x] Blaze Trail (Fireball Scroll + Meteor Shard) — burn damage over 3s
  - [x] Tesla Coil (Regen Crystal + Quantum Fuzz) — electric arcs zap nearby enemies
  - [x] Void Ray (Nebula Dust + Toxic Extract) — slows enemies
  - [x] Quantum Overdrive (Meteor Shard + Quantum Fuzz + Star Fruit) — triple homing + chain mega
- [x] Mod equip system (1 active mod at a time, swap in crafting menu) — equip buttons in discovered mods panel
- [x] Visual laser changes per mod (color, trail, impact effect) — per-projectile material with mod color, light color matches
- [x] Crafting discovery system (try unknown combos to discover new mods) — invalid combos refund half materials
- [x] 5 new collectible types (Shield Crystal, Fireball Scroll, Regen Crystal, Magnet Core, Toxic Extract)
- [x] Material drops from enemy kills (12% normal, 100% boss)
- [x] `weapon_mod_system.gd` autoload singleton — inventory, crafting, equip system
- [x] `crafting_menu.gd` — full crafting UI with material grid, recipe discovery, mod list
- [x] HUD weapon mod indicator (bottom-center, shows current mod + material count)
- [x] Per-mod damage/fire-rate/speed multipliers
- [x] `WeaponModSystem` registered as autoload in `project.godot`
- [x] Input action `crafting` (C key) added to `project.godot`

### Phase 17: Dynamic Weather (TODO) 🆕 NEW FEATURE
- [ ] Weather state machine (clear → rain → storm → fog → flare → clear)
- [ ] Acid rain: damages player and enemies (reduced damage with shelter)
- [ ] Solar flare: boosts energy regen, pulses orange light
- [ ] Fog: reduces enemy detection range to 50% (stealth opportunity)
- [ ] Thunderstorm: random lightning strikes (AoE damage zones)
- [ ] Snow: slows movement, icy physics (slide on surfaces)
- [ ] Biome-specific weather (lava = ember storms, water = rain, etc.)
- [ ] Weather transition effects (fog rolls in, rain starts with drops)
- [ ] Weather UI indicator (current weather + upcoming)
- [ ] Weather-dependent enemy spawns (storms spawn Void Wisps, etc.)

### Phase 18: Boss Arenas (TODO) 🆕 NEW FEATURE
- [ ] Arena generation system (terrain morphs when boss spawns)
- [ ] Arena walls (impassable borders around fight zone)
- [ ] Arena cover (destructible pillars for hiding)
- [ ] Environmental hazards (lava geysers, falling crystals, shockwaves)
- [ ] Arena shrinking (walls close in as fight progresses)
- [ ] Arena transition effect (ground ripples, walls rise)
- [ ] Arena exit (portal appears on boss death)
- [ ] Drake arena: lava arena with geysers and shrinking floor
- [ ] Serpent King arena: crystal arena with falling stalactites
- [ ] Graviton Prime arena: void arena with gravity shifts

### Phase 19: Local Co-op (TODO) 🆕 NEW FEATURE
- [ ] Player 2 character "Zerp" (different color, slightly different abilities)
- [ ] Split-screen camera or shared camera with dynamic zoom
- [ ] Co-op enemy scaling (2x health, 1.5x damage)
- [ ] Shared combo system (both players contribute to combo counter)
- [ ] Revive system (downed player can be revived by partner)
- [ ] Co-op pulse wave (both players Q at same time = mega wave)
- [ ] Drop-in/drop-out (Player 2 presses Start anytime)
- [ ] Co-op achievement milestones

### Phase 20: Audio & Polish (TODO)
- [ ] Sound effects (shoot, dash, pickup, level-up, damage, death)
- [ ] Background music per biome
- [ ] Boss fight music
- [ ] Screen shake on big hits and explosions
- [ ] Smooth camera follow (lerp-based, not instant snap)
- [ ] Pause menu (resume, settings, quit)
- [ ] Settings menu (resolution, volume, controls)
- [ ] Death screen with full stats and "Try Again" button

### Phase 21: Export & Distribution (SKIP — not scheduled)
- [ ] Windows export (.exe)
- [ ] Linux export (.x86_64)
- [ ] macOS export (.app)
- [ ] Web export (HTML5 via Emscripten)
- [ ] Export presets configured in project.godot

NOTE: Cron jobs should implement phases 1-20 ONLY. Do NOT implement Phase 21 (export). Stop after Phase 20 is complete.

## Notes
- All Ursina color.rgb() 0-255 values converted to Godot Color() 0-1 range
- Single Game class split into: GameManager (autoload), WorldGenerator, Player, HUD, etc.
- Ursina's global update() → per-node _process()/_physics_process()
- Ursina's global input(key) → _unhandled_input(event) + Input actions
- Scene tree architecture replaces single-file imperative approach
- Godot 4.4 GDScript syntax throughout (not Godot 3)
- GameManager registered as autoload singleton in project.godot

## Improvement Patterns Applied
- **Camera smooth lerp follow**: Exponential lerp (frame-rate independent) replaces linear move_toward for camera follow. Uses `1.0 - exp(-smoothing * delta)` weight formula.
- **Trauma-based screen shake**: CameraRig.add_trauma(amount) system — trauma decays over time, shake amount = trauma² for organic feel. Triggered on dash (0.15), player damage (0.35), enemy attacks (0.2), enemy death (0.08-0.35 by size), pulse wave (0.25).
- **Input buffering**: Dash input is buffered for 150ms — if pressed during cooldown, fires immediately when ready. Prevents dropped inputs.
- **Smooth HUD bar animation**: HP/XP/Boss bars lerp toward target ratios in _process instead of snapping instantly. Uses same exponential lerp formula.
- **Projectile trail + glow**: Projectiles now have a 6-point fading trail, OmniLight3D for real-time glow, and spawn impact_burst.tscn on hit (expanding + fading sphere).
- **Tween easing curves**: Collectible pickup uses EASE_OUT + TRANS_BACK for pop, EASE_IN + TRANS_CUBIC for shrink + lift. Enemy death adds spin + CUBIC easing.
- **Collectible spin**: Items rotate continuously while idle for visual appeal.
- **Dash squash-and-stretch**: Player mesh compresses (1.4, 0.6, 1.4) on dash start, then bounces back with EASE_OUT + TRANS_ELASTIC for juicy game feel.
- **Shoot scale pulse**: Player mesh does a quick 1.12x pop on each shot (EASE_OUT + TRANS_ELASTIC rebound), skipped during dash to avoid tween conflicts.
- **Collectible emission breathing**: Items pulse their emission_energy_multiplier (0.7–1.1) synced to bob cycle for a "breathing" glow that improves visibility.
- **Enemy spawn material fade-in**: `_update_spawn_visuals()` now fades material alpha from 0→target using quadratic ease-in during the 2s grace period, instead of being a no-op. Preserves per-enemy alpha (Void Wisp stays semi-transparent).
- **Shoot input buffering**: Left-click shots are buffered for 120ms — if the player clicks during the shoot cooldown, the shot fires immediately when ready. Prevents dropped inputs during rapid fire. Uses `_shoot_buffer_timer` consumed in `_physics_process`.
- **Dynamic boss camera zoom**: CameraRig smoothly lerps its orbit distance from 22 → 28 when a boss spawns, and back when the boss dies. Uses the same exponential-lerp formula as the follow smoothing for frame-rate-independent transitions. Connects to `boss_spawned`/`boss_defeated` signals automatically.
- **Enemy rim lighting (fresnel)**: All enemies now use `StandardMaterial3D.rim_enabled = true` with rim intensity 0.6 and tint 0.8, plus a slight metallic (0.15) and lower roughness (0.55). This gives enemies a glowing edge at grazing angles, improving silhouette readability against dark alien terrain.
- **Impact/pulse light flashes**: Impact bursts now spawn a brief OmniLight3D (2.5 energy, 0.12s fade) for a punchy hit flash in dark biomes. Pulse wave spawns a center OmniLight3D (3.0 energy) that fades as the wave expands. Void Bomber explosion gets an orange light flash (5.0 energy, 0.2s fade) scaled to explosion radius.
- **Pulse wave ease-out expansion**: Pulse wave now uses an ease-out quadratic speed multiplier (fast burst, gentle deceleration) and smoothed scale lerp, with quadratic alpha fade for a sharper disappear at max radius. Feels more like a real shockwave than a linear ring.
- **Enemy velocity smoothing**: Enemies now accelerate/decelerate toward their desired velocity using frame-rate-independent exponential lerp (weight = `1.0 - exp(-velocity_smoothing * delta)`). Replaces the instant snap from wander (0.3×speed) to full chase speed. Configurable per-enemy via `@export velocity_smoothing` (default 8.0).
- **Camera FOV kick on dash**: Camera FOV briefly widens by `CAMERA_DASH_FOV_KICK` (8°) on dash start, then eases back to `CAMERA_DEFAULT_FOV` (70°) via exponential lerp in `_process`. Classic "juice" technique that makes dashing feel fast without changing gameplay. `CameraRig.kick_fov(amount)` is called from `player._start_dash()`.
- **Cached player references**: `enemy_base.gd` and `collectible.gd` now cache the player node reference (`_cached_player`) and only re-query `get_tree().get_first_node_in_group("player")` when the cache is stale or freed. Eliminates a full scene-tree group scan every `_physics_process` frame for every enemy and collectible.
- **Player emissive material + rim lighting**: Player now gets a proper unlit-emissive StandardMaterial3D (albedo + emission tinted to base_color, rim_enabled for silhouette pop) instead of the scene's default grey material. Material is created in `_ready()` and assigned to `BodyMesh.material_override`.
- **Player idle breathing**: Zorp now has a subtle idle animation — a vertical mesh bob (sin wave, 0.04m amplitude at 2.5 rad/s) synced to an emission energy pulse (0.8–1.3 multiplier). Makes Zorp feel alive when standing still. Skipped during dash/slide (resets y-offset to avoid tween conflicts) and invuln-blinking.
- **Enemy hit flash emission spike**: `take_damage_from()` now spikes emission_energy_multiplier to 4.0 alongside the white albedo flash, then eases both back via parallel tween (EASE_OUT/QUAD on emission). The combined strobe effect reads even in dark biomes and gives combat a punchier feel.
- **Shockwave ease-out expansion**: Sentinel's `shockwave.gd` now uses the same ease-out quadratic speed multiplier and exponential scale lerp as the pulse wave, plus quadratic alpha fade. Both expanding-ring effects now share a consistent visual language — fast burst, gentle deceleration, sharp disappear.
- **Damage number easing curves**: Pop-in animation now uses manual ease-out pow formulas (`1-(1-t)^3` for cubic rise to peak, `1-(1-t)^4` for quartic settle) instead of linear interpolation. Gives damage numbers a more decisive pop and softer landing, matching the juice style of dash squash. Note: Godot's built-in `ease(t, curve)` with negative curve values produces ease-IN-OUT (symmetric S-curves), not ease-out — the explicit pow formula is both correct and clearer.
- **Smooth HP/Boss bar color lerp**: HP and boss HP bar *colors* now lerp smoothly toward the target green→yellow→red color in `_process` alongside the bar *size* lerp. Previously the color snapped instantly at the 50% threshold while the size animated — now both transition together for a cohesive, less jarring HP drain feel. Shared `_ratio_to_bar_color()` helper ensures player and boss bars use the same color language.
- **Pulse wave input buffering**: Q ability now uses the same input-buffering pattern as dash (150ms) and shoot (120ms) — if pressed during cooldown, the pulse wave fires immediately when ready (180ms buffer window). All three player actions now feel equally responsive with no dropped inputs.
- **Enemy death light flash**: Enemy deaths now spawn a brief OmniLight3D (intensity scales with enemy size) that flashes the enemy's base color and fades over 0.3s. Gives extra punch in dark biomes where the particle burst alone can be hard to see. A Drake gets a much bigger flash than a Blob.
- **Projectile in-flight spin**: Player laser bolts now rotate on their Y axis during flight (12 rad/s), giving them a sense of energy and motion rather than appearing as a static sphere drifting forward.
- **Smooth camera rotation (yaw/pitch)**: CameraRig now eases yaw and pitch toward target values via exponential lerp (`rotation_smoothing = 12.0`) instead of snapping instantly. Right-click camera dragging feels buttery and fluid. `set_camera_yaw()` / new `set_camera_pitch()` set targets; `_process` lerps. `player._apply_camera_rotation()` uses the smooth setters instead of writing `rotation_degrees.x` directly.
- **Enemy alert indicator pop-in**: The "!" above an enemy's head now bounces in from scale 0 → 1.4 → 1.0 (EASE_OUT + TRANS_BACK then CUBE settle) instead of just toggling visible. Gives a juicy telegraph that draws the player's eye to newly alerted enemies.
- **Collectible spawn pop-in + rare glow**: Collectibles now bounce in from scale 0 → 1 with TRANS_BACK overshoot (0.35s) instead of appearing at full size. Rare items (Meteor Shard, Quantum Fuzz, Nebula Dust) get a persistent OmniLight3D (1.2 energy, 4m range) so they glow in dark biomes and are visible from afar. All collectibles also get rim lighting (rim=0.8, tint=1.0) for silhouette pop.
- **Shared static resources for projectiles/impacts**: Projectile, ImpactBurst, PulseWave, and Shockwave now use static shared mesh resources (SphereMesh/CylinderMesh created once, reused across all instances). This eliminates per-shot geometry allocation during rapid fire (~9 shots/sec). Projectile trail nodes share the mesh but duplicate the material (needed for independent alpha fade). ImpactBurst duplicates the base material per-instance for the same reason. Net effect: significantly less GPU resource churn during sustained combat.
- **Pulse wave / shockwave emission energy fade**: Both expanding-ring effects now fade their `emission_energy_multiplier` alongside the alpha fade, creating a coherent dissipating glow. Previously emission stayed at full intensity while the ring faded to transparent — a visual mismatch. Both effects also now use `SHADING_MODE_UNSHADED` and higher `radial_segments` (32 for pulse wave, 24 for shockwave) for smoother rings.
- **Player movement lean**: Zorp's mesh now tilts subtly (max ~7°) toward the movement direction, proportional to speed. The lean is camera-relative (forward/back and strafe axes) and smoothed via exponential lerp (smoothing=10.0) so it eases in/out rather than snapping. Skipped during dash/slide (their tweens control mesh.scale) and reverse-gravity (mesh is flipped 180°). Gives Zorp a sense of weight and momentum — classic game-feel "juice".
- **Collectible magnetic pull acceleration curve**: The pull speed now uses a quadratic ease-in curve (proximity²) instead of linear falloff. Items start gentle when far, then accelerate sharply as they close in — feeling more "sticky" and magnetic. The base speed is 30% of max at the pull radius edge, ramping to 100% at the collect radius, for a satisfying "snap" effect.
- **Hit-stop (freeze frame) on crits & kills**: Critical hits and killing blows now trigger a brief global time-scale dip (`Engine.time_scale = 0.08` for 45ms), a classic "juice" technique that makes heavy impacts feel weighty. A static cooldown (120ms) prevents rapid crits from stacking into a long freeze. The restore is scheduled via a scene-tree Timer (not a self-bound tween) because the projectile may `queue_free()` immediately after triggering hit-stop — a self-bound tween would be killed and `time_scale` would stay frozen forever. DimensionSystem uses per-node `_time_scale` multipliers (not `Engine.time_scale`), so restoring to 1.0 is always safe.
- **Camera Y-follow with deadzone**: The camera rig now tracks the player's Y position with a configurable deadzone (±2m) and separate smoothing (`follow_y_smoothing = 4.0`). On flat terrain the camera stays anchored to the horizon (no jitter from minor Y drift), but large vertical excursions — reverse-gravity dimension at y=20, bounce pads, falls — are smoothly followed. This fixes a bug where reverse-gravity placed the player at y=20 but the camera stayed pinned at y=0, making the fight off-screen. XZ and Y are now lerped independently so the deadzone only affects vertical tracking.
- **Player landing squash + dust puff**: When Zorp touches down after being airborne (reverse-gravity exit, bounce pad landing), the mesh squashes flat (1.5, 0.4, 1.5) then bounces back with `TRANS_ELASTIC` easing — the same juice language as the dash squash — plus a neutral-colored dust puff at the feet and a small camera shake (0.12 trauma). Skipped during dash/slide to avoid tween conflicts on `mesh.scale`. Tracked via a `_was_airborne` flag set whenever the player is above the deadzone threshold.

## Last Updated
Phase 16 complete. Weapon Mod Crafting System: New `weapon_mod_system.gd` autoload singleton manages inventory of 10 crafting material types and 20 discoverable weapon mods. 5 new collectible types added (Shield Crystal, Fireball Scroll, Regen Crystal, Magnet Core, Toxic Extract) — they drop from enemy kills (12% normal, 100% boss rate). `crafting_menu.gd` provides a full-screen crafting UI: select 2-3 materials from a grid, click Craft to combine them into a weapon mod, discover new mods by trying combinations (invalid combos refund half the materials). Discovered mods appear in a side panel with equip buttons. Each mod changes laser behavior: Homing Laser tracks enemies, Chain Lightning jumps to 3 nearby enemies, Spread Shot fires 3 bolts in a fan, Piercing Beam passes through enemies, Bouncing Bolt reflects off walls, Freeze Ray slows enemies, Acid Trail leaves a damaging pool, Mega Blast causes AoE explosions, Splitter Laser spawns child projectiles, Vampire Beam heals Zorp, Gravity Well pulls enemies, Ricochet bounces between enemies, Plasma Nova explodes, Sniper Beam does 2x damage at 2x speed, Shrapnel fires in 6 directions, Blaze Trail burns over time, Tesla Coil zaps with electric arcs, Void Ray slows, Quantum Overdrive fires triple homing+chain bolts. Each mod has unique color, damage multiplier (0.5x-2.5x), fire rate multiplier, and projectile speed multiplier. Reflective Shield also provides 40% damage reduction. `projectile.gd` rewritten with `set_weapon_mod()` method and 15+ mod-specific behavior functions for in-flight and on-hit effects. HUD shows a bottom-center mod indicator with current mod name and total material count. Input action `crafting` (C key) added to `project.godot`. `WeaponModSystem` registered as autoload. Phases 17-21 planned.