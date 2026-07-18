# Zorp Wiggles: Godot Conversion Tracker

## Status: PHASE 20 — Audio & Polish (COMPLETE) — ALL PHASES 1-20 DONE

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
| Individual Entity particles | `GPUParticles3D` | DONE |

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

### Phase 4: Full Combat & Abilities (COMPLETE — 10 of 10)
- [x] Damage numbers (floating 3D Label3D that rises and fades, with pop-in animation)
- [x] Kill combo system with milestones (x5, x10, x15... bonus XP + screen flash)
- [x] Pickup streak system with bonus XP (every 5 pickups = milestone XP)
- [x] Crit chain bonus (3x damage at 3+ consecutive crits, using constants)
- [x] Dash invulnerability frames with blink effect — smooth sinusoidal blink with cyan emission shimmer
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

### Phase 6: Particle Effects & Juice (COMPLETE — 11 of 11)
- [x] Movement trail particles (speed lines behind Zorp) — dash trail via GPUParticles3D
- [x] Idle regen sparkle stream (ambient sparkles) — green sparkle aura when idle and HP > 80%
- [x] Level-up shockwave burst (expanding ring + particles) — golden ring + upward sparkles
- [x] Combo milestone fireworks (6-color particle bursts) — tier-colored sphere bursts
- [x] Pickup lift animation (items float up, spin, shrink) — already done + sparkle burst added
- [x] Sky beam on rare pickup (vertical light column) — Meteor Shards get sky beam
- [x] Shield break shatter effect (fragment burst) — 40 shard fragments + light flash, triggers on buff expiration
- [x] Player damage flash (red model flash + screen vignette) — screen vignette via DamageFlash
- [x] Damage number popups (crit = bigger + gold color) — already done in Phase 4
- [x] Enemy death poof (scale down + particle burst) — death poof via GPUParticles3D
- [x] Biome ambient particles (snowflakes, embers, spores, bubbles, dust) — follows player per biome
- [x] Projectile impact explosion particles — small cyan burst on hit

### Phase 7: Missions & Progression (COMPLETE)
- [x] Mission system (collect X items, kill Y enemies, explore Z biomes) — mission_system.gd with 6 mission types (COLLECT, KILL, EXPLORE, LEVEL, COMBO, SURVIVE), auto-generates replacement missions on completion, progress tracking via GameManager signals
- [x] Mission board / quest log UI — quest_log.gd, Tab key toggles semi-transparent panel showing active missions with progress bars, descriptions, and rewards
- [x] Trader NPC with trade menu (buy items with Space Gloop) — trade_menu.gd, E key opens trade menu near trader, 8 items purchasable with Space Gloop, click-to-buy interface
- [x] Monolith buff system (activate for temporary buffs) — monolith.gd with buff activation on player contact, 3 buff types (Speed Surge 1.5x, Power Surge 1.4x, Wisdom Aura 2.0x XP), particle beam effect + light flash on activation, integrated into player speed/damage/XP calculations
- [x] Achievement system (first kill, combo milestones, biome explorer) — achievement_popup.gd with 12 achievements, signal-based tracking, slide-in/out popup animations
- [x] XP curve and level-up stat scaling — exponential XP curve (base * 1.35^level), tier-based stat scaling: HP +12+3/5lvls, damage +2+1/5lvls, speed +0.5/5lvls, level-up shockwave + message with stat breakdown
- [x] Difficulty scaling over time (more enemies, stronger, faster) — time-based difficulty tiers every 60s, +8% HP/+5% damage/+3% speed per tier, 12% faster spawns per tier, +10 max enemies cap, tier-up notification with screen shake

### Phase 8: Physics & Interaction (COMPLETE — 7 of 7 complete) 🆕 NEW FEATURE
- [x] Ragdoll death for player and enemies (RigidBody3D proxy) — `_spawn_physics_corpse()` in enemy_base.gd spawns a RigidBody3D sphere corpse with initial impulse + angular velocity, PhysicsMaterial bounce, fades out after 2s settle + 1s fade
- [x] Enemy knockback with physics impulse (enemies push each other) — `take_damage_from()` applies directional knockback; `_apply_enemy_separation()` pushes overlapping enemies apart
- [x] Collectible bounce and tumble (RigidBody3D with bounce material) — `start_tumble()` in collectible.gd spawns RigidBody3D proxy with PhysicsMaterial bounce (0.4), initial impulse + angular velocity, transitions to normal Area3D float after 1.2s; enemy drops auto-trigger tumble
- [x] Destructible environment objects (crates, crystals shatter into pieces) — `destructible.gd` + `destructible.tscn`, spawns RigidBody3D fragments with PhysicsMaterial bounce
- [x] Physics-based dash (Zorp slides and bounces off walls) — `_start_slide()`/`_update_slide()` in player.gd, friction decay + `velocity.bounce(normal)` on wall collision
- [x] Enemy corpse physics (tumble and settle realistically) — `_spawn_physics_corpse()` in enemy_base.gd, RigidBody3D with collision mask 1 (world only), fade-out after settle
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
- [x] Biome transition fog (exponential fog with per-biome color) — `biome_transition_fog.gdshader` screen-space canvas_item shader with depth-based exponential fog, animated drift, per-biome color/density cross-fade via ShaderManager `_on_biome_changed()` with ease-in-out blending
- [x] Dash afterimage shader (ghost trail with fade) — `_spawn_dash_afterimage()` in player.gd spawns semi-transparent MeshInstance3D copies every 30ms during dash + slide, fade alpha 0.5→0 via tween_method over 350ms, slight scale-up for dissipating energy look
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

### Phase 17: Dynamic Weather ✅ COMPLETE 🆕 NEW FEATURE
- [x] Weather state machine (clear → rain → storm → fog → flare → clear) — `weather_system.gd` autoload singleton, cycles through 6 `GameConstants.Weather` states with 35-70s duration each and 4s cross-fade transitions
- [x] Acid rain: damages player and enemies (reduced damage with shelter) — `_tick_acid_rain()` damages exposed entities every 1s, `_is_player_exposed_to_sky()` raycasts upward 30m to check shelter (75% damage reduction under overhang)
- [x] Solar flare: boosts energy regen, pulses orange light — `get_fire_rate_multiplier()` returns 1.5x, pulsing OmniLight3D (orange, 2.5 energy) follows player
- [x] Fog: reduces enemy detection range to 50% (stealth opportunity) — `get_detect_range_multiplier()` returns 0.5, WorldEnvironment fog density smoothly lerps to 3x baseline
- [x] Thunderstorm: random lightning strikes (AoE damage zones) — `_tick_thunderstorm()` schedules strikes every 5-12s, 1.2s telegraph warning, 45 damage in 6m radius, white-blue light flash + particle burst + camera shake
- [x] Snow: slows movement, icy physics (slide on surfaces) — `get_speed_multiplier()` returns 0.7x for player and enemies, `get_friction_multiplier()` returns 0.4x making dash slides last longer
- [x] Biome-specific weather (lava = ember storms, water = rain, etc.) — `WEATHER_BIOME_AFFINITY` table weights weather selection by current biome (+2.0 weight for affinity matches)
- [x] Weather transition effects (fog rolls in, rain starts with drops) — 4s cross-fade transition with `weather_transition_started`/`ended` signals, smooth fog density lerp
- [x] Weather UI indicator (current weather + upcoming) — `weather_indicator.gd`, top-right panel with icon + name + countdown timer bar, transition label showing next weather, color-matched per weather type
- [x] Weather-dependent enemy spawns (storms spawn Void Wisps, etc.) — `WEATHER_SPAWN_BONUS` table, `EnemySpawner._pick_enemy_type()` adds bonus-weighted enemy entries during special weather
- [x] Weather particles (acid rain, rain, snow storm, fog motes, embers) — `_create_weather_particles()` with 5 particle presets, follows player at y=12 offset
- [x] `WeatherSystem` registered as autoload in `project.godot`
- [x] WorldEnvironment added to `main.tscn` with baseline fog (density 0.01) for fog weather control
- [x] Player movement speed × weather multiplier, fire rate × solar flare multiplier, slide friction × snow storm multiplier
- [x] Enemy detection range × fog multiplier, enemy speed × snow storm multiplier

### Phase 18: Boss Arenas ✅ COMPLETE 🆕 NEW FEATURE
- [x] Arena generation system (terrain morphs when boss spawns) — `boss_arena.gd` + `.tscn`, Node3D controller listens to `boss_spawned`/`boss_defeated` signals, builds enclosed arena around player position
- [x] Arena walls (impassable borders around fight zone) — 12 StaticBody3D wall segments in a ring, animated rising from underground via tween (2s duration), colored per arena type with emission glow
- [x] Arena cover (destructible pillars for hiding) — 6 Destructible pillars spawned at mid-radius, scaled 1.5x with 60 HP, crystal variant for crystal arena
- [x] Environmental hazards (lava geysers, falling crystals, shockwaves) — `arena_hazard.gd` + `.tscn`, 3 hazard types with telegraph warning (1.5s pulsing ground circle), activation particles, damage + knockback, fade-out
- [x] Arena shrinking (walls close in as fight progresses) — Lava arena shrinks every 15s by 4m (min 10m radius), walls animate inward, floor disc shrinks, particle burst + camera shake + warning message
- [x] Arena transition effect (ground ripples, walls rise) — 200-particle explosion burst on arena formation, camera shake (0.4 trauma), pulsing floor disc emission, walls rise with EASE_OUT + TRANS_CUBIC
- [x] Arena exit (portal appears on boss death) — Portal spawned at arena center on boss death, lasts 30s for player to teleport away
- [x] Drake arena: lava arena with geysers and shrinking floor — ArenaType.LAVA_ARENA, LAVA_GEYSER + FALLING_CRYSTAL hazards, shrinking enabled
- [x] Serpent King arena: crystal arena with falling stalactites — ArenaType.CRYSTAL_ARENA, FALLING_CRYSTAL + VOID_SHOCKWAVE hazards, crystal cover pillars
- [x] Graviton Prime arena: void arena with gravity shifts — ArenaType.VOID_ARENA, VOID_SHOCKWAVE + LAVA_GEYSER hazards
- [x] Boss auto-spawn system — BossArena auto-spawns bosses every 120s if player score ≥500, rotates through Drake/Serpent/Graviton, non-Drake bosses promoted with `is_arena_boss` flag + boosted HP
- [x] `is_arena_boss` flag on EnemyBase — non-Drake arena bosses emit `boss_defeated` on death, clearing `current_boss`
- [x] `GameManager.set_current_boss()`/`clear_current_boss()` — proper boss tracking for all boss types
- [x] Navigation mesh rebuild after arena construction/removal — `call_deferred("_rebuild_nav")` ensures NavigationManager updates after walls/cover added/removed
- [x] Hazard types: LAVA_GEYSER (tall column, knockback), FALLING_CRYSTAL (drops from height, extra damage, shatter effect), VOID_SHOCKWAVE (expanding ring, continuous damage)
- [x] Hazard telegraph system — 1.5s pulsing ground circle warning before activation, falling crystal visible during telegraph (drops from 25m)
- [x] `BossArena` node added to `main.tscn`

### Phase 19: Local Co-op ✅ COMPLETE 🆕 NEW FEATURE
- [x] Player 2 character "Zerp" (magenta-purple color, different stats) — `player2_zerp.gd` + `.tscn`, CharacterBody3D with 100 HP, 0.9x damage, 1.05x dash, shares weapon mods
- [x] Shared camera with dynamic zoom (frames both players) — `camera_rig.gd` dual-target mode, targets midpoint, zooms 22→42m based on spacing (COOP_CAMERA_MIN/MAX_DISTANCE)
- [x] Co-op enemy scaling (2x health, 1.5x damage) — `enemy_spawner.gd` applies COOP_ENEMY_HP_MULT/DAMAGE_MULT, 30% faster spawns, +15 max enemies
- [x] Shared combo system (both players contribute, +1s window bonus) — `GameManager.register_kill()` uses `CoOpManager.get_combo_window_bonus()`, shared XP pool
- [x] Revive system (downed player can be revived by partner) — P1: `GameManager._update_p1_downed()`, P2: `CoOpManager._update_downed()`, 3s hold, 30s bleed-out, 60 HP restore + 2s invuln
- [x] Co-op pulse wave (both players Q within sync window = mega wave) — `CoOpManager.report_pulse_wave()`, 1s sync window, 1.8x radius + 2.5x damage + 3 overlapping pulse rings + particle spectacle
- [x] Drop-in/drop-out (Player 2 presses Enter anytime, hold to drop out) — `CoOpManager.drop_in_p2()`/`drop_out_p2()`, 2s hold to drop out
- [x] Co-op achievement milestones (7 milestones: first kill, 50 kills, first revive, 5 revives, first mega pulse, 3 mega pulses) — `CoOpManager._check_coop_milestones()`
- [x] P2 input actions (arrow keys, [/] shoot, [Enter] dash, [RShift] pulse, [.] revive, [Enter] start) — 10 new input actions in `project.godot`
- [x] `CoOpManager` registered as autoload in `project.godot`
- [x] Enemies target nearest player in co-op — `enemy_base.gd` `_update_ai()` finds closest valid player, downed players deprioritized
- [x] Collectibles pull toward nearest player — `collectible.gd` finds nearest player, P2 score tracked separately
- [x] P2 projectiles tagged with `is_p2_projectile` meta — kills register to P2 score via `enemy_base.set_p2_hit()`
- [x] Co-op HUD (`co_op_hud.gd`) — P2 HP bar, score, downed/revive overlays for both players, drop-in prompt, milestone popups
- [x] P2 on minimap (magenta dot with facing direction) — integrated into `minimap.gd`
- [x] Weather system continues when P1 downed but P2 alive — `weather_system.gd` checks co-op state
- [x] Enemy spawner continues when P1 downed but P2 alive — `enemy_spawner.gd` checks co-op state
- [x] P1 downed visual (slumped + blinking mesh) — `player.gd` `_physics_process` shows downed state
- [x] Co-op reset on game restart — `CoOpManager.reset()` + `GameManager.restart_game()` clears all co-op state

### Phase 20: Audio & Polish ✅ COMPLETE
- [x] Sound effects (shoot, dash, pickup, level-up, damage, death) — `audio_manager.gd` autoload singleton, 24 procedurally generated SFX (no external files needed), 12-player SFX pool for overlapping sounds
- [x] Background music per biome — 12 unique looping ambient drone tracks, one per biome, auto-switches on `biome_changed` signal
- [x] Boss fight music — intense driving 8-second loop with bass pulse + dissonant tension layer, auto-starts on `boss_spawned`, stops on `boss_defeated`
- [x] Screen shake on big hits and explosions — already done (trauma-based screen shake in `camera_rig.gd`, triggered on dash/damage/enemy death/pulse wave/explosion)
- [x] Smooth camera follow (lerp-based, not instant snap) — already done (exponential lerp in `camera_rig.gd`)
- [x] Pause menu (resume, settings, quit) — `pause_menu.gd` + `.tscn` node in main scene, P key toggles, `PROCESS_MODE_ALWAYS` so buttons work while paused
- [x] Settings menu (resolution, volume, controls) — `settings_menu.gd` with Master/SFX/Music volume sliders (real-time), controls reference, accessible from pause menu and main menu
- [x] Death screen with full stats and "Try Again" button — enhanced `death_screen.gd` with clickable "Try Again" + "Quit to Menu" buttons (appear after fade-in), still supports R/Space restart

### Phase 21: Export & Distribution (SKIP — not scheduled)
- [ ] Windows export (.exe)
- [ ] Linux export (.x86_64)
- [ ] macOS export (.app)
- [ ] Web export (HTML5 via Emscripten)
- [ ] Export presets configured in project.godot

NOTE: Cron jobs should implement phases 1-20 and 22-35. Do NOT implement Phase 21 (export).

### Phase 22: New Biomes & World Expansion (IN PROGRESS) 🆕
- [x] Deep Ocean biome (underwater sections, buoyancy physics, bioluminescent creatures) — `Biome.DEEP_OCEAN` enum value + `DEEP_OCEAN_*` constants; `_classify_biome` returns DEEP_OCEAN at elevation < -0.45; `_get_tile_height` returns -2.5 (below water plane); `_spawn_deep_ocean_overlay` translucent water surface + `_spawn_bioluminescent` glowing orbs in `decoration.gd`; BIOME_FOG entry with dark blue 0.024 density; BIOME_NAMES "Deep Ocean"; ambient particles "bubbles"; atmosphere "fireflies"; audio drone (65.41/130.81 Hz, 7.0s, 0.18 amp); mutation "Tidal Veil" (buoyancy + swim speed boost); BiomeEffects autoload applies upward velocity + slower movement; biome shader frost_vignette 0.35 strength; weather affinity acid_rain + thunderstorm
- [x] Volcano Core biome (erupting terrain, lava rivers, heat damage zones) — `Biome.VOLCANO_CORE` enum + `VOLCANO_CORE_*` constants; `_classify_biome` returns VOLCANO_CORE at elevation > 0.25 + temperature > 0.45 + moisture < -0.1; `_get_tile_height` 0.8 + variation; `_spawn_volcano_overlay` glowing lava river + `_spawn_lava_vent` bright cone in `decoration.gd`; BIOME_FOG dark red 0.022 density; ambient "embers" + atmosphere "fireflies"; audio drone (61.74/116.54 Hz, 2.5s, 0.38 amp); mutation "Magma Skin" (heat resistance 0.4-0.6); BiomeEffects heat damage ticks (3 dmg per 1.5s, reduced by fire resistance); biome shader heat_distortion 0.7 strength; weather affinity solar_flare + meteor_shower
- [x] Sky Citadel biome (floating platforms, wind currents, cloud navigation) — `Biome.SKY_CITADEL` enum + `SKY_CITADEL_*` constants; `_classify_biome` returns SKY_CITADEL at elevation > 0.65 + temperature < 0.0; `_get_tile_height` 8.0 + variation; `_spawn_sky_platform` floating cloud platform + shadow in `decoration.gd`; BIOME_FOG light blue 0.004 density; ambient "dust" + atmosphere "dust"; audio drone (196/392 Hz, 6.5s, 0.18 amp); mutation "Wind Walker" (1.1-1.2x speed + halved wind effect); BiomeEffects wind currents (3.0 m/s force, direction shifts every 6s); biome shader none; weather affinity thunderstorm + snow_storm
- [x] Digital Grid biome (cyberpunk aesthetic, wireframe terrain, glitch effects) — `Biome.DIGITAL_GRID` enum + `DIGITAL_GRID_*` constants; `_classify_biome` returns DIGITAL_GRID on rare roll (roll < 0.105); `_get_tile_height` 0.0; `_spawn_digital_glitch` neon cyan/pink wireframe cube in `decoration.gd`; BIOME_FOG dark blue 0.008 density; ambient "spores" + atmosphere "fireflies"; audio drone (123.47/246.94 Hz, 3.5s, 0.3 amp); mutation "Glitch Step" (15% chance random short teleport 2-5m); BiomeEffects darkness 0.6 ambient energy; biome shader chromatic_aberration 0.55 strength; weather affinity none (rare biome)
- [x] Biome transition zones (blended terrain between adjacent biomes) — `TRANSITION_BLEND_DISTANCE` (8 tiles) + `TRANSITION_BLEND_SPEED` (2.0) constants; biome fog cross-fades via ShaderManager `_on_biome_changed()` with ease-in-out blending already handled by existing `biome_transition_fog.gdshader`; biome indicator color lerps smoothly via `_current_color.lerp(_target_color, FADE_SPEED * delta)`; audio cross-fades via `_fade_player(_music_player, ..., MUSIC_FADE_IN_DURATION)` in audio_manager.gd; terrain vertex colors snap per-tile but fog/shader/music/audio all cross-fade for cohesive transitions
- [x] Underground caverns (subterranean areas with limited light, unique enemies) — `Biome.UNDERGROUND` enum + `UNDERGROUND_*` constants; `_classify_biome` returns UNDERGROUND at elevation < -0.2 + moisture > 0.2; `_get_tile_height` -4.0 (deep below surface); `_spawn_stalactite` + `_spawn_stalagmite` + `_spawn_underground_glow` (glowing fungus) in `decoration.gd`; BIOME_FOG near-black 0.030 density (very dense); ambient "spores" + atmosphere "fireflies"; audio drone (55/110 Hz, 7.5s, 0.15 amp — deepest, slowest track); mutation "Night Eye" (darkness vision — ambient light 0.7 instead of 0.15); BiomeEffects darkness modulation lerps WorldEnvironment ambient_light_energy toward 0.15 (or 0.7 with Night Eye); weather affinity fog
- [x] Crystal Caverns (reflective surfaces, prism light puzzles, crystal enemies) — `Biome.CRYSTAL_CAVERNS` enum + `CRYSTAL_CAVERNS_*` constants (including 6-color rainbow PRISM_COLORS array); `_classify_biome` returns CRYSTAL_CAVERNS at moisture < -0.4 + temperature < 0.1 + elevation < 0.1; `_get_tile_height` -1.5 (sunken cavern floor); `_spawn_crystal_cavern_cluster` spawns 2-5 prism-colored emissive crystals cycling through red/orange/yellow/green/blue/violet in `decoration.gd`; BIOME_FOG blue-cyan 0.009 density; ambient "dust" + atmosphere "fireflies"; audio drone (174.61/349.23 Hz, 5.5s, 0.22 amp — bright shimmering); mutation "Crystal Resonance"; BiomeEffects darkness 0.7 ambient energy; biome shader crystal_refraction 0.5 strength; weather affinity fog
- [x] Ancient Ruins biome (decayed structures, hidden traps, relic collectibles) — `Biome.ANCIENT_RUINS` enum + `ANCIENT_RUINS_*` constants; `_classify_biome` returns ANCIENT_RUINS on rare roll (0.105 ≤ roll < 0.115); `_get_tile_height` 0.3 + variation; `_spawn_ancient_pillar` broken stone pillar + occasional broken wall segment in `decoration.gd`; BIOME_FOG warm brown 0.013 density; ambient "dust" + atmosphere "dust"; audio drone (92.5/185.0 Hz, 5.0s, 0.25 amp); mutation "Relic Ward" (trap immunity + 0.15-0.25 damage reduction); BiomeEffects hidden traps — 20 procedural trap positions generated around player on biome entry, 3m radius, 20 damage, periodic 0.5s distance check, traps_disabled() check for Relic Ward mutation, trap_triggered signal for HUD feedback; weather affinity none (rare biome)
- [ ] (Phase 22 bonus) Biome-specific enemy variants for new biomes — deferred to Phase 23 (new enemy types)

### Phase 23: New Enemy Types (COMPLETE) 🆕
- [x] Void Leviathan (giant serpentine boss, multi-stage, swims through terrain) — `enemy_void_leviathan.gd` + `.tscn`, `VOID_LEVIATHAN_*` constants in `game_constants.gd`; `EnemyType.VOID_LEVIATHAN` enum value; 600 HP, 3-stage fight (Stage 1 >66% HP: slow chase + void breath cone of 7 dark projectiles; Stage 2 33-66% HP: faster, summons Void Wisps every 8s, tail sweep contact damage on 6 segmented body parts; Stage 3 <33% HP: enraged 1.6× speed + 1.3× damage, vacuum pull sucks player toward maw at 14 m/s within 20m radius for 2s); segmented body follows head's trail (6 segments, 2.8m spacing, decreasing size toward tail), each segment has a contact-damage Area3D (25 dmg, 1s cooldown per segment); on death body collapses segment-by-segment with staggered 0.08s delays + cascading particle bursts; void breath fires 7-bolt cone (35° spread, 22 dmg per bolt, 22 m/s); added to BossArena auto-spawn rotation (VOID_ARENA type); `boss_spawned`/`boss_defeated` signals emitted in `_ready()`/`_die()`; LOOT_DROPS entry [6,10]; `enemy_types.gd` TYPES entry
- [x] Crystal Wraith (shatters into shards on death, shards reform into mini-wraiths) — `enemy_crystal_wraith.gd` + `.tscn`, `CRYSTAL_WRAITH_*` constants in `game_constants.gd`; `EnemyType.CRYSTAL_WRAITH` enum value; on death spawns 3-5 RigidBody3D crystal shards that scatter with physics impulse + angular velocity, after `CRYSTAL_WRAITH_SHARD_REFORM_DELAY` (0.9s) each shard transforms into a mini-wraith ("Crystal Shardling") — blob scene with overridden stats (18 HP, 7.0 speed, 6 damage, 0.4 scale, ice-blue color), materialization particle burst on reform; crystalline material (metallic 0.5, roughness 0.25, strong rim, ice-blue emission); smart AI enabled (flanking + retreat); added to MEDIUM and HARD tier pools; LOOT_DROPS entry [2,4]
- [x] Plasma Stalker (turns invisible, only visible by particle trail) — `enemy_plasma_stalker.gd` + `.tscn`, `PLASMA_STALKER_*` constants in `game_constants.gd`; `EnemyType.PLASMA_STALKER` enum value; cloak state machine (VISIBLE 2.5s → WARN 0.35s blink telegraph → CLOAKED 4.0s near-invisible at alpha 0.06); while cloaked emits plasma spark particle trail every 0.05s (the player's only visual cue) and moves 1.3× faster (ambush speed); cloak is visual stealth only — NOT intangible, projectiles still connect; smart AI enabled (flanking + retreat); hot pink-magenta emissive material (metallic 0.4, roughness 0.3, strong rim); added to MEDIUM and HARD tier pools; LOOT_DROPS entry [2,3]
- [x] Swarm Queen (spawns Swarm Mites continuously, must be killed to stop spawns) — `enemy_swarm_queen.gd` + `.tscn`, `SWARM_QUEEN_*` constants in `game_constants.gd`; `EnemyType.SWARM_QUEEN` enum value; slow tanky enemy (280 HP, 1.6 speed, 18 damage, 2.0 scale) that spawns Swarm Mites every 3-5s in batches of 1-3 around herself (2.5m radius), respects global enemy cap and own concurrent-mite cap (12 max), materialization particle burst on each mite spawn; on death releases a final burst of 2-4 mites ("swarm release"); reuses `enemy_swarm_mite.tscn` scene for spawned mites; smart AI disabled (simple slow chaser); added to HARD tier pool; LOOT_DROPS entry [4,6]
- [x] Time Warden (slows player in AoE, speeds up self, teleport attacks) — `enemy_time_warden.gd` + `.tscn`, `TIME_WARDEN_*` constants in `game_constants.gd`; `EnemyType.TIME_WARDEN` enum value; projects a `TIME_WARDEN_FIELD_RADIUS` (7m) slowing field around itself visualized as a translucent blue sphere + OmniLight3D; players inside the field are slowed to `TIME_WARDEN_PLAYER_SLOW_MULT` (0.55×) with smooth edge falloff, integrated into `player.gd` and `player2_zerp.gd` speed calculations via static `EnemyTimeWarden.get_player_slow_mult()` registry (strongest overlapping field wins, not product — prevents stacking oppression); warden itself moves at `TIME_WARDEN_SELF_SPEED_MULT` (1.35× always); teleport state machine every 6s: NORMAL → WARN (0.5s blink telegraph) → TELEPORTING (repositions behind player at 4m distance with particle bursts at departure + arrival + camera shake); tanky (140 HP); registry cleared on game restart via `GameManager.restart_game()` calling `EnemyTimeWarden.clear_registry()` and on `_exit_tree()`; smart AI enabled; added to HARD tier pool; LOOT_DROPS entry [3,5]
- [x] Mirror Mimic (copies player's weapon mod, fires it back at them) — `enemy_mirror_mimic.gd` + `.tscn`, `MIRROR_MIMIC_*` constants in `game_constants.gd`; `EnemyType.MIRROR_MIMIC` enum value; ranged enemy (24m attack range) that reads `WeaponModSystem.get_equipped_mod()` and fires `EnemyProjectile` bolts matching the mod's color; mimic's own material emission shifts to the equipped mod's color as a visual telegraph; projectile damage scaled by `MIRROR_MIMIC_MIMICRY_DAMAGE_MULT` (0.7× base); slight spread (6°) for fairness; overrides `_try_attack()` to no-op (suppresses inherited melee lunge — mimic is purely ranged); mirror-silver chrome material (metallic 0.7, roughness 0.2, strong rim); smart AI enabled (flanking + retreat keeps it at range); added to MEDIUM and HARD tier pools; LOOT_DROPS entry [2,4]
- [x] Ancient Sentinel (mega-boss, multiple attack phases, arena-wide hazards) — `enemy_ancient_sentinel.gd` + `.tscn`, `ANCIENT_SENTINEL_*` constants in `game_constants.gd`; `EnemyType.ANCIENT_SENTINEL` enum value; colossal stationary mega-boss (900 HP, speed 0, 35 damage, 3.5 scale) with a rotating cycle of 3 attack phases: Phase A (rotating beam) sweeps a death ray around the arena (1.2 rad/s, 40m length, 30 dmg/sec, 1.2s warn telegraph), Phase B (pillar barrage) summons 8 falling crystal pillars across the arena (40 dmg each, 3.5m radius, 1.0s warn telegraph with pulsing ground patch), Phase C (shockwave nova) fires 3 sequential expanding shockwave rings (35 dmg, 30m max radius, 14 m/s expand, 1.2s between rings); Phase D (enrage at <25% HP) runs a secondary phase simultaneously + 1.5× beam rotation + 0.6× phase cycle; overrides `_update_ai()` and `_try_attack()` to no-op (stationary, all attacks are phase-driven); uses RayCast3D for beam hit detection; reuses `shockwave.tscn` for nova rings; added to BossArena auto-spawn rotation (CRYSTAL_ARENA type); `boss_spawned`/`boss_defeated` signals emitted in `_ready()`/`_die()`; LOOT_DROPS entry [8,12]; `enemy_types.gd` TYPES entry
- [x] Toxic Spore (explodes into poison cloud on death, cloud damages over time) — `enemy_toxic_spore.gd` + `.tscn`, `TOXIC_SPORE_*` constants in `game_constants.gd`; `EnemyType.TOXIC_SPORE` enum value; on death spawns a self-contained `PoisonCloud` Node3D with translucent green sphere mesh (no_depth_test for visibility), OmniLight3D glow, pulsing emission animation; cloud ticks damage every 0.7s (6 dmg/tick to player, 3 to enemies via `TOXIC_SPORE_CLOUD_ENEMY_DAMAGE_MULT` 0.5) within 4.5m radius for 5.0s duration, then fades out over 0.5s; co-op aware (damages both P1 and P2); sickly-green emissive material with strong rim; smart AI disabled (simple slow chaser — the death cloud is the threat); added to EASY and MEDIUM tier pools; LOOT_DROPS entry [2,3]
- [x] Echo Knight (creates shadow copies of itself, all attack simultaneously) — `enemy_echo_knight.gd` + `.tscn`, `ECHO_KNIGHT_*` constants in `game_constants.gd`; `EnemyType.ECHO_KNIGHT` enum value; spawns 2 translucent shadow copies as MeshInstance3D children at fixed offsets (3.0m, 120° apart) — copies are intangible (no collision, not in "enemies" group) but deal reduced damage (`ECHO_KNIGHT_COPY_DAMAGE_MULT` 0.6) when the real knight attacks; copies lunge visually in sync with the real knight's attack; real knight is visually distinct (brighter `ECHO_KNIGHT_REAL_COLOR`, pulsing aura OmniLight3D); copies fade out on real knight's death; smart AI enabled (flanking spreads copies, harder to identify the real one); added to MEDIUM and HARD tier pools; LOOT_DROPS entry [2,4]
- [x] Gravity Elemental (gravity-manipulating elite, throws objects, repels player) — `enemy_gravity_elemental.gd` + `.tscn`, `GRAVITY_ELEMENTAL_*` constants in `game_constants.gd`; `EnemyType.GRAVITY_ELEMENTAL` enum value; elite enemy (160 HP, 3.2 speed, 20 damage, 1.6 scale) with a gravity field state machine (IDLE → CHARGING 0.8s warn telegraph with growing translucent sphere + brightening emission → ACTIVE 1.5s repel burst); active field repels the player outward (22 m/s force, smooth edge falloff, 9m radius) via direct `velocity` manipulation on CharacterBody3D, and flings nearby loose RigidBody3D objects (corpses tagged "physics_corpse" group — `enemy_base.gd` `_spawn_physics_corpse()` now adds this group) at the player as projectiles (up to 6 flung objects + 3 direct gravity bolts); field has 6s cooldown; gravitic-blue emissive material (metallic 0.5, roughness 0.3, strong rim); smart AI enabled (flanking); added to HARD tier pool; LOOT_DROPS entry [3,5]; `enemy_types.gd` TYPES entry

### Phase 24: New Weapon Mods & Abilities (IN PROGRESS) 🆕
- [x] Black Hole Launcher (creates gravity well that sucks enemies in, then explodes) — `WeaponMod.BLACK_HOLE_LAUNCHER` (25), 3-item recipe (Magnet Core + Meteor Shard + Nebula Dust); portable singularity that travels forward pulling enemies in (14m radius, 24 m/s pull force in flight), then collapses for 2.0× AoE damage with 12m radius; slow fire rate (2.4× cooldown), slow bolt (0.5× speed), high damage (1.4× mult); auto-collapses on lifetime expiry (1.8s) or terrain/enemy hit; `_spawn_black_hole_launcher_collapse()` in `projectile.gd` creates Area3D singularity with dark swirling sphere (negative light, purple emission), 0.8s pull phase (12 m/s pull, tick damage), then massive collapse explosion + light flash + 0.5 camera shake; deep void purple-black color
- [x] Time Freeze Ray (freezes enemy in place for 3 seconds) — `WeaponMod.TIME_FREEZE_RAY` (26), 3-item recipe (Regen Crystal + Quantum Fuzz + Star Fruit); freezes a single enemy in time for 3.0s via `set_time_scale(0.0)`; enemy can't move, attack, or take damage from other sources while frozen; scene-tree timer restores `time_scale` to 1.0 (survives projectile death); ice crystal particle burst + ice-blue OmniLight on freeze, shatter effect on unfreeze; slow fire rate (1.8× cooldown), low damage (0.6× mult — utility mod); crystalline ice-cyan color
- [x] Shrink Beam (enemy becomes tiny and slow for 5 seconds) — `WeaponMod.SHRINK_BEAM` (27), 2-item recipe (Toxic Extract + Shield Crystal); shrinks enemy for 5.0s — moves at 0.4× speed, deals 0.5× damage, visually scaled to 0.35× (TRANS_BACK scale-down tween); stores original speed/damage/scale in meta for restoration; refresh-on-rehit (doesn't stack, resets timer); green aura particle burst on shrink + restore (TRANS_ELASTIC scale-up); moderate fire rate (1.4× cooldown), low damage (0.7× mult — debuff mod); lime green color
- [ ] Mind Control Dart (enemy fights for you for 8 seconds) — deferred (requires AI faction system)
- [ ] Reflective Barrier (spawn wall that reflects enemy projectiles) — deferred (requires projectile reflection system)
- [x] Meteor Strike (call down meteor from sky at cursor location) — `WeaponMod.METEOR_STRIKE` (28), 3-item recipe (Meteor Shard + Fireball Scroll + Nebula Dust); the bolt is a low-damage marker (10 dmg), the meteor falls from 50m height after 0.9s telegraph (pulsing ground patch), dealing 3.5× base damage on impact with 9m radius AoE + falloff; massive explosion + 12.0 light flash + 0.6 camera shake; spinning meteor visual with trail light during fall; triggers on enemy hit, terrain hit, or lifetime expiry; very slow fire rate (3.0× cooldown), very high damage (2.8× mult — the meteor is the damage), slow bolt (0.4× speed); fiery orange-red color
- [x] Lightning Storm (chain lightning hits all enemies in radius) — `WeaponMod.LIGHTNING_STORM` (29), 3-item recipe (Regen Crystal + Magnet Core + Quantum Fuzz); on hit, chains lightning to up to 8 nearby enemies (10m chain range) with 12% damage falloff per jump; electric arc particles between each hit enemy + spark at each hit; slow fire rate (2.2× cooldown), moderate damage (1.2× mult); electric pale blue color
- [x] Poison Nova (expanding ring of poison, DoT to all enemies hit) — `WeaponMod.POISON_NOVA` (30), 3-item recipe (Nebula Dust + Space Gloop + Toxic Extract); on impact, expands a poison ring (12m max radius, 18 m/s expand) damaging all enemies it touches (20 dmg instant), plus a lingering poison cloud at the impact point (5m radius, 4.0s duration, 8 dmg/tick every 0.6s); ring uses `tween_method` for per-frame hit detection (each enemy hit once); slow fire rate (1.8× cooldown), moderate damage (1.3× mult — DoT is the main threat); toxic green color
- [ ] Shield Bubble (encase player in bubble, absorbs X damage, reflects projectiles) — deferred (requires player shield system)
- [ ] Turret Deploy (stationary turret that auto-fires at nearest enemy for 15s) — deferred (requires deployable system)
- [ ] Gravity Flip Field (area where gravity reverses, enemies fall up) — deferred (requires gravity zone system)
- [ ] Void Rift Cutter (opens a dimensional rift that damages enemies passing through) — deferred (requires rift zone system)

### Phase 25: Progression & Meta-Systems (IN PROGRESS) 🆕
- [x] Skill Tree (3 branches: Combat, Survival, Exploration — spend skill points from leveling) — `progression_system.gd` autoload singleton; 15 skills (5 per branch), 5 ranks each (75 total ranks); SP earned 1/level (+1 bonus every 5 levels) + prestige bonus; `skill_tree.gd` UI (K key) with 3-column layout, clickable skill nodes, rank bars, hover highlights, prestige button; Combat branch: Power Strike (+8% dmg/rank), Keen Eye (+3% crit/rank), Rapid Fire (+5% fire rate/rank), Extra Bolts (+1 projectile/2 ranks), Giant Slayer (+15% boss dmg/rank); Survival branch: Vitality (+20 HP/rank), Regeneration (+1 HP/sec/rank), Energy Shield (+5% dmg reduction/rank), Second Wind (auto-revive charges), Toughness (+3% dmg reduction/rank); Exploration branch: Swift Stride (+4% speed/rank), Quick Learner (+10% XP/rank), Lucky Find (+5% loot/rank), Biome Adaptation (+5% per biome), Fluid Motion (-6% dash cd/rank); all multipliers integrated into player.gd (speed, fire rate, damage, crit, dash cd, multishot), game_manager.gd (XP gain, damage reduction, HP regen, auto-revive), projectile.gd (boss damage, crit chance), enemy_base.gd (loot chance); persisted to `user://zorp_progression.json`
- [x] Permanent upgrades (persist across runs: +HP, +damage, +speed, +XP gain) — `ProgressionSystem.apply_permanent_upgrades()` called from `GameManager._start_game()`; max HP bonus from Vitality skill, damage multiplier from Power Strike, speed multiplier from Swift Stride, XP multiplier from Quick Learner + prestige; all persist via JSON save file
- [x] Prestige system (reset level for permanent multiplier, unlock cosmetic skins) — `ProgressionSystem.prestige()` requires level 20+; grants +5 SP per prestige level; +10% XP multiplier per prestige level; golden OmniLight aura on player (intensity scales with prestige); prestige button in skill tree UI; `prestige_1`/`prestige_5` achievements
- [ ] Daily Challenge (seed-based run, fixed biome/enemies/loot, one attempt per day) — deferred (requires seed system)
- [ ] Weekly Challenge (longer run with modifiers, global leaderboard seed) — deferred (requires server)
- [ ] Endless Mode (wave-based escalation, no world exploration, pure combat) — deferred (requires mode manager)
- [ ] Boss Rush Mode (fight all bosses back-to-back, timer tracking) — deferred (requires mode manager)
- [ ] Speedrun Timer (track biome-to-biome splits, total run time, personal best) — deferred (requires timer UI)
- [x] Achievement tracking system (50+ achievements with progress bars) — `achievement_popup.gd` expanded from 12 to 56 achievements across 6 categories (Combat, Survival, Exploration, Collection, Progression, Special); each achievement has target + progress_key linking to Statistics lifetime stats; `_check_progress_achievements()` auto-unlocks when current >= target; new achievements include kills (100/500/1000/5000), bosses (5/20), distance (1km/10km/50km), time (1h/5h/24h), items (100/1000/5000), shots (500/5000), dashes (100/1000), runs (10/50/100), prestige (1/5), pet feedings (10/50), rifts (5/25), weather (10/50), revives (1/10), best score/combo/survival; public API `get_unlocked_count()`, `get_total_count()`, `get_progress()`, `get_all_achievements()` for future achievements list UI
- [x] Statistics page (lifetime kills, distance traveled, time per biome, items collected) — `statistics.gd` autoload singleton tracks session + lifetime stats; persists to `user://zorp_stats.json`; auto-tracks via GameManager/WeaponModSystem/WeatherSystem/ProgressionSystem signals; distance tracking via player position delta; per-biome time, per-enemy-type kills, per-item-type collection, per-boss-type defeats; `statistics_page.gd` UI (F2 key) with 4 tabs (Session, Lifetime, Combat, Exploration); format_time() and format_distance() helpers; batched saves (5s debounce)

### Phase 26: NPC & World Life (IN PROGRESS) 🆕
- [ ] Wandering merchants (random NPCs that appear, sell rare items for Space Gloop)
- [ ] Friendly alien villages (small settlements with NPCs that give missions)
- [x] Roaming wildlife (non-hostile creatures that flee from player, drop loot) — `wildlife.gd` + `.tscn`, `WILDLIFE_*` constants in `game_constants.gd`; 8 species (Glimmer Hopper, Frost Mite, Sand Skitter, Bog Hopper, Void Mote, Tidal Sprite, Ember Wisp, Cloud Drifter) each with biome preferences; CharacterBody3D that wanders peacefully (WILDLIFE_WANDER_SPEED 1.8, 30m radius from home) then flees at WILDLIFE_FLEE_SPEED (9.0) when player approaches within WILDLIFE_FLEE_RANGE (14m); brightens emission when fleeing (alarmed); bob animation; caught on touch (WILDLIFE_CATCH_RANGE 1.5m) → drops XP orb + 30% chance of a crafting material (weighted loot table), +15 XP + 30 score, particle burst + death poof, fade-out + shrink; species-colored emissive material with rim lighting + glow light; 2 dark eyes for character; `Statistics.record_wildlife_caught(species_name)` tracks per-species catches; `_spawn_wildlife()` in `world_generator.gd` scatters across walkable biomes via `_pick_wildlife_species_for_biome()` (biome-specific fauna); skipped within 30m of spawn; `wildlife` + `non_hostile` groups (enemies don't target them, projectiles don't hit them); minimap shows species-colored dots when within flee range; 3 achievements (Critter Catcher, Wildlife Wrangler, Beast Master)
- [x] Environmental hazards (lava geysers, falling rocks, toxic vents, ice slides) — `environmental_hazard.gd` + `.tscn`, `ENV_HAZARD_*` constants + `ENV_HAZARD_TYPES` array in `game_constants.gd`; 4 hazard types (lava_geyser, falling_rock, toxic_vent, ice_patch) each with biome preferences; `EnvironmentalHazard` class_name extends Node3D with IDLE → TELEGRAPH (1.2s pulsing ground ring) → ACTIVE (2.5s danger phase) → COOLDOWN (8.0s) state machine that cycles indefinitely; lava_geyser: tall column, 22 dmg + knockback; falling_rock: boulder drops from 12m during telegraph, 25 dmg; toxic_vent: wide gas cloud, 12 dmg + 0.7s tick damage during active; ice_patch: flat icy surface, no damage but applies outward slide force to player; co-op aware (damages P1 + P2 via `CoOpManager.p2_take_damage()`); camera shake on impactful hazards; `_spawn_environmental_hazards()` in `world_generator.gd` scatters across hostile biomes (0.012 per-tile chance); skipped within 35m of spawn; `env_hazard` group; minimap shows type-colored dots (orange=geyser/rock, green=vent, cyan=ice)
- [x] Interactive objects (switches, doors, breakable walls, hidden passages) — `interactive_object.gd` + `.tscn`, `INTERACTIVE_*` constants + `INTERACTIVE_TYPES` array in `game_constants.gd`; `InteractiveObject` class_name extends StaticBody3D with 4 object types (switch, door, breakable_wall, hidden_passage); switches toggle on T key (interact input action), open/close linked doors and reveal/hide linked hidden passages via `linked_id` matching; doors animate lowering into ground (EASE_IN_OUT/CUBIC) + disable collision when open; breakable walls take damage from player projectiles (via `take_damage()`) and dash (via `dash_hit()`, 15 dmg), shatter at 0 HP with scale-down + fade + particle burst; hidden passages fade out + disable collision when revealed; switches have cooldown (0.5s), pulsing glow, floating "Press T to activate" Label3D prompt with pop-in animation; player `_try_interact()` finds nearest interactable (prioritizes dialogue NPCs, then switches); projectile `_on_body_entered()` damages breakable walls in `interactive_object` group; player `_dash_smash_destructibles()` also hits breakable walls; `_spawn_interactive_objects()` in `world_generator.gd` scatters across walkable biomes (0.006 per-tile chance) with 40% switch / 30% door / 20% breakable_wall / 10% hidden_passage distribution; skipped within 45m of spawn; `interactive_object` group; minimap shows switches (yellow squares) and breakable walls (brown squares)
- [x] Hidden treasure chests (buried, found via visual clues, contain rare loot) — `treasure_chest.gd` + `.tscn`, `TREASURE_CHEST_*` constants in `game_constants.gd`; Area3D with a low-profile chest (base + lid + glowing lock + ground glow disc + OmniLight); lid is closed (tilts back via tween on open); 25% are trapped (TREASURE_CHEST_TRAP_CHANCE) — trap deals 25 damage + spawns a "Chest Mimic" enemy (20 HP, 8 dmg, brown) before yielding loot; opening grants 60 XP + spawns 3 collectibles (weighted toward rare: 30% Meteor Shard, 25% Quantum Fuzz, 20% Nebula Dust, 15% Star Fruit, 10% Health Fragment) with tumble physics for a "burst out" feel; golden glimmer (ground glow + light) fades in based on player proximity (TREASURE_CHEST_GLOW_RANGE 12m) — chests are hidden from afar; `Statistics.record_treasure_chest_opened(trapped)` tracks total + trapped; `_spawn_treasure_chests()` in `world_generator.gd` scatters across walkable biomes (0.8% per tile); skipped within 60m of spawn; `treasure_chest` group; minimap shows gold squares only when within glow range (must explore to find); 3 achievements (Treasure Finder, Treasure Hunter, Treasure Hoarder)
- [ ] World bosses (roaming bosses not tied to arenas, very rare, very rewarding)
- [x] NPC dialogue system (talk to traders, villagers, ancient holograms) — `dialogue_npc.gd` + `.tscn`, `dialogue_panel.gd` autoload singleton, `DIALOGUE_*` constants + `DIALOGUE_NPC_TYPES` + `DIALOGUE_LINES` in `game_constants.gd`; 3 NPC archetypes (villager, elder, hologram) each with name pool, color, scale, and biome preferences (villagers in friendly biomes, elders in ancient/crystal/underground, holograms in digital/alien); CharacterBody3D that wanders within 12m home radius, stops when talking; floating "Press T to talk" Label3D prompt with pop-in animation when player within DIALOGUE_INTERACT_RANGE (4.5m); DialoguePanel CanvasLayer (layer 90) shows NPC name + typewriter-effect text (30 chars/sec) with BBCode blinking cursor, auto-advances after 5s or on T key, Esc skips; intro lines for first meeting, repeat lines after; completing first dialogue grants 10 XP; player `_try_interact()` finds nearest interactable NPC; `interact` input action (T key) added to project.godot; `_spawn_dialogue_npcs()` in `world_generator.gd` scatters across walkable biomes (0.3% per tile) with archetype-biome matching; skipped within 40m of spawn; `dialogue_npc` + `non_hostile` groups; minimap shows cyan dots
- [x] Lore stones (scattered relics that reveal game lore when collected) — `lore_stone.gd` + `.tscn`, `LORE_STONE_*` constants + `LORE_FRAGMENTS` (30 lore text entries) in `game_constants.gd`; Area3D with a tall purple-grey stone pillar + cap + glowing rune quad on front face + ground glow disc + pulsing OmniLight; 30 lore fragments reveal world-building text (Zorpions, Tribes, Void, biomes, enemies, weather, etc.) as HUD messages (6s display for lore, 3.5s for proximity prompt); fragments assigned sequentially so the story unfolds in order; reading grants 25 XP + small camera shake + particle burst; stone disappears after reading (fade-out + shrink + lift); `Statistics.record_lore_stone_read()` tracks count; `_spawn_lore_stones()` in `world_generator.gd` scatters across walkable biomes (1.2% per tile); skipped within 50m of spawn; `lore_stone` group; minimap shows pulsing purple dots; 3 achievements (Lore Seeker, Lore Keeper, Loremaster)
- [ ] Fast travel network (activate waypoints to teleport between explored biomes)

### Phase 27: Pet Evolution Expansion (TODO) 🆕
- [ ] 5 new pet evolution paths (Fire Pet, Ice Pet, Electric Pet, Void Pet, Nature Pet)
- [ ] Pet fusion system (combine 2 adult pets for a unique fusion pet)
- [ ] Pet accessories (equip items: collar, wings, armor — each gives passive bonus)
- [ ] Pet training mini-games (increase pet stats through active play)
- [ ] Pet emote system (pet reacts to events: happy on pickup, scared on damage, angry on enemy)
- [ ] Pet evolution stones (rare drops that force specific evolution path)
- [ ] Multi-pet system (own up to 3 pets, swap between them)
- [ ] Pet questline (series of missions that unlock new pet types)

### Phase 28: Weather Expansion (TODO) 🆕
- [ ] Meteor Shower (meteors fall from sky, damage everything in impact zone, rare materials)
- [ ] Aurora Borealis (beautiful light show, boosts XP gain while active)
- [ ] Sandstorm (reduces visibility to near-zero, enemies ambush from dust clouds)
- [ ] Magnetic Storm (disables minimap and radar, random EMP pulses disable dashing)
- [ ] Blood Moon (all enemies stronger and faster, but drop 3x loot and XP)
- [ ] Eclipse (darkness falls, shadow enemies spawn, light sources become critical)
- [ ] pollen Storm (heals everything slowly, peaceful period, good for exploration)
- [ ] Gravity Anomaly (random gravity shifts every 10 seconds, affects movement)
- [ ] Dimensional Storm (rifts open randomly during storm, dimension shifts every 15s)
- [ ] Weather combo system (two weather types can overlap for unique effects)

### Phase 29: Crafting & Equipment Expansion (TODO) 🆕
- [ ] Armor system (head, body, accessory slots — craft from enemy drops)
- [ ] Consumable items (craft health potions, speed potions, shield potions, bombs)
- [ ] Ring/Amulet accessories (passive bonuses: +crit, +XP, +speed, +loot)
- [ ] Upgrade system (spend materials to upgrade existing weapon mods to +1, +2, +3)
- [ ] Rare crafting materials (boss drops, weather-specific drops, biome-specific drops)
- [ ] Crafting recipes book (discovered recipes stay, undiscovered show as ???)
- [ ] Material refinement (combine 3 common materials into 1 rare material)
- [ ] Set bonuses (wearing matching armor pieces gives bonus effects)

### Phase 30: Visual & Audio Polish (TODO) 🆕
- [ ] Character selection screen (choose Zorp or Zerp with stat previews)
- [ ] Skin system (unlock cosmetic skins for Zorp: golden, void, crystal, lava)
- [ ] Trail customization (choose dash trail color and particle style)
- [ ] Death replay (show last 5 seconds of gameplay before death, slow-mo)
- [ ] Victory screen (for boss rush / endless modes with ranking)
- [ ] Dynamic music intensity (music intensifies as combo counter rises)
- [ ] Adaptive sound effects (weapon mods change shoot sound, biome changes ambient)
- [ ] Color filter modes (sepia, noir, thermal, x-ray — unlockable cosmetics)
- [ ] Photo mode (freeze game, free camera, capture screenshots with filters)
- [ ] Intro cinematic (procedural animation showing Zorp landing on the planet)

### Phase 31: Quality of Life (TODO) 🆕
- [ ] Auto-save system (saves game state every 30 seconds and on biome change)
- [ ] Save/load system (save to file: player stats, inventory, world seed, explored biomes)
- [ ] UI scaling option (adjust HUD size for different screen resolutions)
- [ ] Colorblind modes (protanopia, deuteranopia, tritanopia, achromatopsia)
- [ ] Control rebinding (customize all keys, save to settings)
- [ ] Tutorial mode (first-time player gets guided intro with tooltips)
- [ ] Tooltip system (hover over items/mods/enemies for info popups)
- [ ] Minimap zoom (scroll to zoom minimap in/out)
- [ ] Ping system (press key to ping location, shows marker on minimap and world)
- [ ] FPS counter and performance overlay (toggle with key, shows fps/draw calls/memory)

### Phase 32: Mutliplayer & Social (TODO) 🆕
- [ ] Online leaderboards (submit scores to server, view global rankings)
- [ ] Ghost mode (race against a replay of your best run, translucent ghost)
- [ ] Spectator mode (watch other players' runs in real-time via server)
- [ ] Challenge friends (send a seed to a friend, both run it, compare scores)
- [ ] 3-4 player co-op (expand beyond 2 players, shared screen or online)
- [ ] PvP arena mode (fight other players in an enclosed arena)
- [ ] Weekly tournaments (seed-based competition, top scores get cosmetic rewards)
- [ ] Replay system (record and play back gameplay, share replays)

### Phase 33: Procedural Content (TODO) 🆕
- [ ] Procedural dungeons (underground areas with rooms, corridors, traps, boss at end)
- [ ] Procedural quests (dynamically generated missions based on player level and biome)
- [ ] Procedural enemy variants (elite/golden/champion enemies with random modifiers)
- [ ] Procedural weapon mod fusions (combine any 2 mods for random unique effect)
- [ ] Procedural biomes (beyond the 12 fixed — algorithmically generate new biome types)
- [ ] Procedural music (generate ambient tracks from biome properties)
- [ ] Procedural boss generation (assemble boss from random attack patterns + visual parts)
- [ ] World modifiers (random rules each run: double enemies, no dash, extra loot, etc.)

### Phase 34: Endgame Content (TODO) 🆕
- [ ] New Game+ (enemies 2x stronger, new weapon mod slots, rare-only loot, new enemy types)
- [ ] New Game++ (3x enemies, all bosses roam freely, no minimap, permadeath option)
- [ ] Ultimate Challenge (all bosses at once, all weather active, all dimensions cycling)
- [ ] Survival Mode (no healing, no shops, one life, how long can you last)
- [ ] Gauntlet Mode (sequential biome challenges, no breaks between, timer running)
- [ ] Boss Gauntlet (every boss type in sequence, escalating difficulty, no healing between)
- [ ] Loot Cave (hidden area full of rare collectibles but guarded by elite enemies)
- [ ] Ancient Vault (puzzle-locked area with legendary loot, requires collecting lore stones)

### Phase 35: Polish & Bug Pass (TODO) 🆕
- [ ] Full playthrough QA pass (test every biome, enemy, weapon mod, dimension, weather)
- [ ] Performance optimization (object pooling, LOD, draw call reduction, texture compression)
- [ ] Memory leak audit (check all spawn/queue_free cycles for leaks)
- [ ] Balance pass (enemy stats, XP curve, loot tables, weapon mod damage, pet abilities)
- [ ] Difficulty curve audit (ensure smooth progression from spawn to endgame)
- [ ] Edge case testing (what happens at world borders, 0 HP during dimension shift, etc.)
- [ ] Input handling audit (no dropped inputs, all actions responsive in all states)
- [ ] Scene transition polish (smooth loading, no hitches, fade transitions between modes)
- [ ] Godot 4.5 compatibility check (verify all APIs still valid)
- [ ] Final code cleanup (remove dead code, unused variables, consolidate duplicate logic)

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
- **Projectile velocity-aligned stretch + energy flicker**: Laser bolts now orient toward their travel direction via `look_at` and stretch along Z (scale 0.75, 0.75, 2.4) so they read as fast laser streaks instead of static drifting spheres. The point light flickers at ~30Hz using wall-clock time (`Time.get_ticks_msec()`) so the flicker rate is consistent regardless of `Engine.time_scale` (hit-stop, Time-Slow dimension won't slow the visual crackle). Safe up-vector handling for nearly-vertical directions (homing mods).
- **Camera look-ahead offset**: The camera follow target shifts up to 3m in the player's horizontal velocity direction, proportional to speed fraction, smoothed via exponential lerp (`look_ahead_smoothing = 4.0`). Gives the player more forward visibility while moving and eases to zero when standing still. Configurable via `@export look_ahead_strength` / `look_ahead_smoothing`. Uses `CharacterBody3D.velocity` so it respects dash, slide, and weather speed multipliers.
- **Enemy hit squash pulse**: `take_damage_from()` now triggers a quick `body_mesh` scale pop (1.25× → 1.0× with `TRANS_ELASTIC` rebound) alongside the existing color/emission flash, for an extra layer of juicy combat feedback. Skipped during windup (windup tween controls `self.scale`) and death (death tween owns `self.scale`) — operates on `body_mesh.scale` (local mesh scale), which neither walk cycle nor windup touch, so there are no tween conflicts.
- **Collectible rarity-based spin + organic wobble**: Collectibles now spin at rarity-tiered speeds (common=1.5 rad/s, Star Fruit/Health=2.2, Meteor Shard/Quantum Fuzz/Nebula Dust/crafting materials=3.0) creating a visual hierarchy where valuable pickups draw the eye. Items also drift in a gentle figure-8 pattern (sin/cos on X/Z, 0.12m amplitude) when NOT being magnetically pulled, making them feel suspended in alien gravity rather than pinned to a rail. The wobble anchor updates to the current position when not pulling, so items released from a pull resume wobbling from where they left off rather than snapping back to spawn. `is_magnetic` is now reset each frame and only set true while actively pulling, fixing a latent bug where the flag stayed true forever after first pull.
- **Shared collectible mesh cache**: Collectibles now reuse a single cached `SphereMesh` per collectible type (static dict keyed by type ID) instead of allocating a new `SphereMesh` on every spawn. With enemy drops, world scatter, and rift exits spawning collectibles frequently, this eliminates per-spawn geometry allocation. The material remains per-instance because the emission pulse and mirror-dimension flash tween its properties independently.
- **Enemy attack lunge stretch**: When an enemy lunges forward to attack, the body mesh now stretches (Y +30%, X/Z −15%) and snaps back with `TRANS_ELASTIC` easing — the counterpart to the windup squash. This completes the squash-and-stretch cycle: windup compresses → lunge stretches → elastic recovery. Uses `body_mesh.scale` (local mesh scale) so it doesn't conflict with `self.scale` (which the windup/restore tweens control). Reads as a "coiled spring" lunge regardless of the horizontal attack angle.
- **Camera micro-recoil on shoot**: Each shot now adds a tiny camera trauma (0.015) for a subtle kick that makes shooting feel punchy. At ~9 shots/sec this stays well below the shake decay threshold (trauma² curve + 1.5/s decay) so it never accumulates into a wobble — it's a feather-touch that adds weight to every trigger pull. Multi-bolt weapon mods (Spread Shot, Quantum Overdrive) stack proportionally, making them feel slightly more powerful.
- **Enemy projectile visual parity**: Enemy projectiles (Spore Spitter, Plasma Drake) now have the same juice as player projectiles: shared SphereMesh (eliminates per-shot allocation), per-instance StandardMaterial3D with rim lighting for silhouette pop, an OmniLight3D point light with wall-clock-time energy flicker (consistent regardless of time-scale), velocity-aligned mesh stretch (0.7, 0.7, 2.2 via look_at) for a fast bolt silhouette, cached player reference (no per-frame group scan), and a retinted impact_burst on hit. Lifetime-expiry now fizzles with a small particle puff + light fade instead of a hard queue_free.
- **Impact burst color retinting**: ImpactBurst now supports an `impact_color` property (set before adding to tree) that retints both the material and the point light flash. This lets the same impact_burst.tscn scene be reused for player shots (cyan), enemy shots (orange/red), and weapon mod AoE effects — each with its own color identity. Default behavior (no color set) remains cyan for player projectiles.
- **Shockwave ring correct radius scaling**: Sentinel's shockwave ring now scales to the actual physical radius (current_radius / base_mesh_radius) instead of the 0→1 progress ratio. Previously the ring only reached 0.5m at max radius — nearly invisible despite the damage reaching 8m. Now the visual ring matches the damage area. Also added a center OmniLight3D flash that fades as the ring expands, matching the pulse wave's light flash for a consistent shockwave visual language.
- **Collectible pickup light flash**: Pickups now spawn a brief OmniLight3D at the collection point that flashes the item's color and fades over 0.25s. Rare items (Meteor Shard, Quantum Fuzz, Nebula Dust, crafting materials) get a brighter (3.5 energy) and wider (5m range) flash for a juicier reward feel. Gives pickups extra punch in dark biomes where sparkle particles alone can be subtle.

## Last Updated
Phase 8 (Physics) and Phase 9 (Shaders) TODO items completed. Phase 8: Enemy corpse physics — `_spawn_physics_corpse()` in enemy_base.gd spawns RigidBody3D sphere corpse with impulse + angular velocity, PhysicsMaterial bounce (0.3), collision mask world-only, fades out after 2s settle. Collectible bounce and tumble — `start_tumble()` in collectible.gd spawns RigidBody3D proxy with bounce PhysicsMaterial (0.4), initial scatter impulse + random angular velocity, transitions to normal Area3D float mode after 1.2s; enemy crafting material drops auto-trigger tumble. Ragdoll death uses same RigidBody3D proxy approach. Phase 9: Biome transition fog — `biome_transition_fog.gdshader` screen-space canvas_item shader with depth-based exponential fog, animated drift noise, per-biome fog color/density cross-fade with ease-in-out blending, integrated into ShaderManager with dedicated fog overlay rect. Dash afterimage — `_spawn_dash_afterimage()` in player.gd spawns semi-transparent MeshInstance3D ghost copies every 30ms during dash and slide (at 2× min slide speed), alpha tweens from 0.5→0 over 350ms with slight scale-up for dissipating energy effect. All 20 phases now fully complete with zero remaining TODO items.

## Enhancement Pack 1 — New Enemies, Weapon Mods & Weather

### New Enemy Types (expanding beyond original 8 → 10)
- **Swarm Mite** (`enemy_swarm_mite.gd` + `.tscn`) — Tiny, very fast (speed 9.0), very low HP (12) enemy that spawns in packs of 3-6. Individually weak (4 damage, dies in 1-2 hits) but they overwhelm from multiple directions. 40% of mite spawns are packs, creating swarming pressure. Smart AI disabled (pure rush behavior — cheaper to process when many are active). Orange-brown color with high emission for a "glowing bug" look. 6 XP / 25 score per kill.
- **Crystal Guardian** (`enemy_crystal_guardian.gd` + `.tscn`) — Slow (speed 1.8), high-HP (180) ranged enemy that fires crystal shard projectiles. 0.8s charge-up telegraph (grows + brightens) before firing. Crystal shards travel at 18 m/s with 16 damage. Tanky but predictable — kiting is the counter-strategy. Crystalline material (high metallic, low roughness, strong rim). 60 XP / 200 score per kill. Flanking disabled (holds position at range).
- **Pack spawning system** in EnemySpawner — when a Swarm Mite is picked, 40% chance to spawn 3-6 additional mites nearby as a pack with staggered spawn timers. Creates the "swarm" feel — multiple mites rushing from one direction.
- New constants in `game_constants.gd`: SWARM_MITE_* and CRYSTAL_GUARDIAN_* tuning parameters.
- New EnemyType enum values: SWARM_MITE (8), CRYSTAL_GUARDIAN (9).
- EnemySpawner updated: new types added to EASY/MEDIUM/HARD tier pools, scene paths, and type names.
- Both enemies added to `enemy_types.gd` data dictionary (entries already existed in TYPES but now have proper implementations).

### New Weapon Mods (expanding beyond original 20 → 22)
- **Black Hole Beam** (Magnet Core + Meteor Shard) — Creates a singularity on impact that pulls enemies toward its center over 1.2 seconds, dealing tick damage, then collapses for 1.5× AoE damage. Dark sphere visual with negative light (absorbs surrounding light), purple emission, grows during pull phase, then detonates with mega explosion + camera shake. Also pulls enemies in-flight (12m radius, 20 m/s pull strength). Slow fire rate (2× cooldown), moderate damage. Crowd-control mod — group enemies together then hit them with the collapse.
- **Photon Beam** (Regen Crystal + Shield Crystal) — Rapid-fire piercing photon bolts that pass through up to 5 enemies (more than Piercing Beam's 3). Very fast fire rate (0.5× cooldown = 2× as fast as standard) and very fast projectile speed (2× speed multiplier). Each bolt is weak (0.5× damage) but the sheer volume of fire makes it a sustained DPS monster. Warm white-gold color.
- New WeaponMod enum values: BLACK_HOLE_BEAM (21), PHOTON_BEAM (22).
- New entries in all parallel WEAPON_MOD_* arrays (names, descriptions, colors, damage/fire-rate/speed multipliers).
- New crafting recipes in CRAFTING_RECIPES dictionary.
- Black Hole Beam on-hit behavior: `_spawn_black_hole()` in `projectile.gd` — creates Area3D singularity with pull phase + collapse phase.
- Photon Beam pierce behavior: 5 pierces (vs 3 for Piercing Beam) in `_hit_enemy()`.
- Black Hole Beam in-flight behavior: extra-strong enemy pull (12m radius) in `_apply_mod_flight_behavior()`.

### New Weather Types (expanding beyond original 6 → 8)
- **Meteor Shower** (☄) — Random meteor strikes with 2-second telegraph (longer than lightning's 1.2s). Meteors are visible falling from 40m height as fiery spinning orbs with trail particles during the telegraph. On impact: 60 damage (vs lightning's 45), 8m radius (vs 6m), mega explosion particles, bigger camera shake (0.6 trauma). Strikes every 8-16 seconds. Biome affinity: Lava, Desert, Alien. Spawn bonus: Void Bombers + Crystal Guardians.
- **Aurora** (🌌) — Colorful shifting sky lights that boost XP gain by 50%. High-altitude OmniLight (40m above player) cycles through green-teal-purple hues via HSV color shifting. Soft drifting aurora particle globes (60 particles, 2m radius). Encourages aggressive play during auroras — farm XP faster. Biome affinity: Snow, Crystal, Floating Islands. Spawn bonus: Swarm Mites + Void Wisps.
- New Weather enum values: METEOR_SHOWER (6), AURORA (7).
- New constants: METEOR_SHOWER_INTERVAL_*, METEOR_DAMAGE, METEOR_RADIUS, METEOR_WARN_TIME, AURORA_XP_MULT, AURORA_LIGHT_ENERGY.
- New entries in WEATHER_BIOME_AFFINITY, WEATHER_SPAWN_BONUS, and WEATHER_INFO dictionaries.
- `WeatherSystem` updated: new candidates in `_pick_next_weather()`, `_tick_meteor_shower()`, `_schedule_meteor_strike()`, `_execute_meteor_strike()` functions, aurora light color shifting in `_process()`, aurora particle type in `_create_weather_particles()`, `get_xp_multiplier()` API method.
- `GameManager.gain_xp()` updated to apply aurora XP multiplier.
- Weather indicator HUD automatically displays new weather types via WEATHER_INFO dictionary.

## Enhancement Pack 2 — Phase Shifter, Spectral Beam, Magnet Mine & Sandstorm

### New Enemy Type (expanding beyond 10 → 11)
- **Phase Shifter** (`enemy_phase_shifter.gd` + `.tscn`) — An enemy that periodically shifts into a spectral phase, becoming intangible (immune to damage) for 2 seconds out of every 5.2-second cycle. The cycle is: MATERIAL phase (3.0s, vulnerable, vivid violet, normal speed) → WARN phase (0.4s, rapid blink telegraph between violet and translucent blue) → PHASED state (2.0s, intangible, translucent blue, still moves and attacks). Players must time their shots to land hits during the MATERIAL window. The Spectral Beam weapon mod ignores intangibility (see below). 60 HP, speed 4.5, 14 damage, 35 XP / 120 score per kill. Smart AI enabled (flanking + retreat make it harder to pin down). Strong rim lighting + emission for a spectral look. Particle bursts on each phase transition.
- New EnemyType enum value: PHASE_SHIFTER (10).
- New constants in `game_constants.gd`: PHASE_SHIFTER_* (HP, speed, damage, scale, XP, score, detect/attack range, colors, phase/material/warn durations, blink speed).
- EnemySpawner updated: PHASE_SHIFTER added to MEDIUM and HARD tier pools, scene path, and type name.
- `enemy_phase_shifter.gd` — Overrides `take_damage_from()` to block damage while intangible. Uses a static `_spectral_bypass_active` flag set by Spectral Beam projectiles before calling take_damage, allowing them to bypass intangibility. Phase state machine with visual telegraph (blink during warn, shimmer while phased, particle bursts on transitions).

### New Weapon Mods (expanding beyond 22 → 24)
- **Spectral Beam** (Quantum Fuzz + Toxic Extract) — Fires translucent violet bolts that phase through walls and terrain — never blocked by anything. Pierces through up to 4 enemies. The key feature: ignores Phase Shifter intangibility. Before calling `take_damage_from()`, the projectile sets `EnemyPhaseShifter.set_spectral_bypass(true)` so Phase Shifters take damage even while phased. The bolt itself is semi-transparent (alpha 0.7) for a ghostly look. Moderate fire rate (1.3× cooldown), decent damage (0.9× mult), moderate speed (1.1× mult). The ultimate counter to Phase Shifters — and useful for shooting through terrain in general.
- **Magnet Mine** (Magnet Core + Fireball Scroll) — Launches a slow-moving mine that strongly homes toward the nearest enemy (12.0 lerp strength vs Homing Laser's 8.0). On impact, it creates a detonation zone that pulls nearby enemies toward the center for 0.6 seconds (9m radius, 10 m/s pull), then explodes for 1.6× AoE damage with falloff. Orange-red glowing sphere visual with pulsing light during the pull phase, then mega explosion + light flash + camera shake (0.45 trauma) on detonation. Slow fire rate (1.8× cooldown), high damage (1.6× mult), slow projectile speed (0.7× mult). Crowd-control mod — the mine seeks a target, pulls enemies together, then detonates the cluster.
- New WeaponMod enum values: SPECTRAL_BEAM (23), MAGNET_MINE (24).
- New entries in all parallel WEAPON_MOD_* arrays (names, descriptions, colors, damage/fire-rate/speed multipliers).
- New crafting recipes: `"QUANTUM_FUZZ,TOXIC_EXTRACT": SPECTRAL_BEAM`, `"FIREBALL_SCROLL,MAGNET_CORE": MAGNET_MINE`.
- Spectral Beam behaviors in `projectile.gd`:
  - Wall phasing: `_on_body_entered()` — terrain/wall hits spawn a small ripple particle but don't stop the bolt.
  - Enemy piercing: `_hit_enemy()` — pierces through up to 4 enemies (like Photon Beam but fewer pierces).
  - Intangibility bypass: Sets `EnemyPhaseShifter.set_spectral_bypass(true)` before calling `take_damage_from()`, resets after.
- Magnet Mine behaviors in `projectile.gd`:
  - Strong homing: `_apply_mod_flight_behavior()` — 12.0 lerp strength homing toward nearest enemy.
  - Pull + detonation: `_spawn_magnet_mine_detonation()` — 0.6s pull phase (9m radius, 10 m/s), then 1.6× AoE explosion with mega explosion particles + light flash + camera shake.

### New Weather Type (expanding beyond 8 → 9)
- **Sandstorm** (🌪) — Scouring sandstorm that reduces visibility, damages exposed entities, and energizes enemies. Fast horizontal sand particles (500 grains, 15-25 m/s wind speed, strong turbulence). Dense fog (4× baseline fog density) for reduced visibility. Dim warm-orange ambient light at ground level (15m above player). Player is slowed 15% (fighting wind); enemies are sped up 25% (the storm energizes them). Sand-scour damage ticks every 1 second (2 damage per tick, 80% reduction under shelter). Biome affinity: Desert, Lava, Alien. Spawn bonus: Phase Shifters + Gravitons. Lasts 35-70 seconds like other weather types.
- New Weather enum value: SANDSTORM (8).
- New constants: SANDSTORM_SPEED_MULT (1.25 enemy), SANDSTORM_PLAYER_SPEED_MULT (0.85), SANDSTORM_DAMAGE_PER_TICK (2), SANDSTORM_TICK_INTERVAL (1.0), SANDSTORM_FOG_DENSITY_MULT (4.0), SANDSTORM_SHELTER_REDUCTION (0.80).
- New entries in WEATHER_BIOME_AFFINITY, WEATHER_SPAWN_BONUS, and WEATHER_INFO dictionaries.
- `WeatherSystem` updated: SANDSTORM candidate in `_pick_next_weather()`, `_tick_sandstorm()` damage tick function, `get_enemy_speed_multiplier()` new API method (returns 1.25 for sandstorm, 0.7 for snow storm, 1.0 otherwise), sandstorm particle type in `_create_weather_particles()`, sandstorm start in `_start_weather_effects()` (particles + fog + ambient light), sandstorm light position in `_update_weather_particle_position()` (lower than other weather — 15m).
- `enemy_base.gd` updated: Line 289 now uses `WeatherSystem.get_enemy_speed_multiplier()` instead of `get_speed_multiplier()`, so enemies are sped up by sandstorm (not slowed like the player). Snow storm still slows enemies via the same function.