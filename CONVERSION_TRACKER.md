# Zorp Wiggles: Godot Conversion Tracker

## Status: PHASE 2 — Enemy Varieties (COMPLETE)

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

### Phase 3: World & Decorations (TODO)
- [ ] Biome decorations: trees (forest), crystals (crystal), mushrooms (mushroom)
- [ ] Floating islands with shadows, crystals, and bounce pads
- [ ] Sky dome (3 layers × 8 billboard quads = 24 sky panels)
- [ ] Star field with twinkling animation
- [ ] Nebula clouds (layered, drifting)
- [ ] Portal structures (inter-biome teleporters)
- [ ] Trader NPC (wandering, trade menu)
- [ ] Monolith buff structures (speed, damage, shield, health_regen)
- [ ] Water/lava surfaces with shader effects

### Phase 4: Full Combat & Abilities (TODO)
- [ ] Damage numbers (floating 3D Label3D that rises and fades)
- [ ] Kill combo system with milestones (x5, x10, x15 fireworks)
- [ ] Pickup streak system with bonus XP
- [ ] Crit chain bonus (3x damage at 3+ consecutive crits)
- [ ] Dash invulnerability frames with blink effect
- [ ] Enemy attack windup telegraph (squash + brighten)
- [ ] Enemy spawn animation (fade-in + bounce scale)
- [ ] Enemy alert indicator ("!" above head)
- [ ] Spawn direction indicator arrows on HUD
- [ ] Health fragment emergency magnet (vacuum nearby health when low HP)

### Phase 5: HUD Polish (TODO)
- [ ] Minimap (SubViewport with top-down camera, color-coded tiles)
- [ ] Enemy proximity radar dots
- [ ] Power-up timer display (buff duration bars)
- [ ] Damage direction indicators (8 directional arrows)
- [ ] Boss tension vignette (pulsing red screen edge near boss)
- [ ] Death screen with stats (best combo, time survived, kills)
- [ ] Achievement popup system
- [ ] Kill feed (recent kills scrolling)
- [ ] Biome indicator (current biome name + icon)
- [ ] Dash cooldown indicator
- [ ] Weapon/power-up icon display

### Phase 6: Particle Effects & Juice (TODO)
- [ ] Movement trail particles (speed lines behind Zorp)
- [ ] Idle regen sparkle stream (ambient sparkles)
- [ ] Level-up shockwave burst (expanding ring + particles)
- [ ] Combo milestone fireworks (6-color particle bursts)
- [ ] Pickup lift animation (items float up, spin, shrink)
- [ ] Sky beam on rare pickup (vertical light column)
- [ ] Shield break shatter effect (fragment burst)
- [ ] Player damage flash (red model flash + screen vignette)
- [ ] Damage number popups (crit = bigger + gold color)
- [ ] Enemy death poof (scale down + particle burst)
- [ ] Biome ambient particles (snowflakes, embers, spores, bubbles)

### Phase 7: Missions & Progression (TODO)
- [ ] Mission system (collect X items, kill Y enemies, explore Z biomes)
- [ ] Mission board / quest log UI
- [ ] Trader NPC with trade menu (buy items with Space Gloop)
- [ ] Monolith buff system (activate for temporary buffs)
- [ ] Achievement system (first kill, combo milestones, biome explorer)
- [ ] XP curve and level-up stat scaling
- [ ] Difficulty scaling over time (more enemies, stronger, faster)

### Phase 8: Physics & Interaction (TODO) 🆕 NEW FEATURE
- [ ] Ragdoll death for player and enemies (Skeleton + PhysicalBone3D)
- [ ] Enemy knockback with physics impulse (enemies push each other)
- [ ] Collectible bounce and tumble (RigidBody3D with bounce material)
- [ ] Destructible environment objects (crates, crystals shatter into pieces)
- [ ] Physics-based dash (Zorp slides and bounces off walls)
- [ ] Enemy corpse physics (tumble and settle realistically)
- [ ] Graviton gravity well uses actual physics force (Area3D gravity point)

### Phase 9: Shaders & Visual Effects (TODO) 🆕 NEW FEATURE
- [ ] Lava biome heat distortion shader (sine-wave vertex displacement)
- [ ] Crystal biome refractive shimmer (screen-space refraction)
- [ ] Alien biome chromatic aberration (RGB split post-process)
- [ ] Snow biome frost vignette (screen-edge frost shader)
- [ ] Toxic bog dripping dissolve shader (alpha cutoff animation)
- [ ] Water surface shader (scrolling normal map, depth-based opacity)
- [ ] Boss enrage screen effect (red pulse + chromatic aberration)
- [ ] Dash afterimage shader (ghost trail with fade)
- [ ] Low-HP warning shader (pulsing red vignette)
- [ ] Biome transition fog (exponential fog with per-biome color)

### Phase 10: Smart Enemy AI (TODO) 🆕 NEW FEATURE
- [ ] NavigationRegion3D for each biome (generated with nav mesh)
- [ ] Enemy pathfinding around obstacles (NavigationAgent3D)
- [ ] Flanking behavior (enemies try to circle around)
- [ ] Retreat behavior (enemies back off at low HP)
- [ ] Ambush AI (enemies hide behind terrain, then rush)
- [ ] Pack behavior (nearby same-type enemies coordinate attacks)
- [ ] Drake boss multi-phase AI (phase transitions, new attack patterns)
- [ ] Line-of-sight checks (RayCast3D for detection, not just distance)
- [ ] Enemy call for help (wounded enemy alerts nearby allies)

### Phase 11: GPU Particles (TODO) 🆕 NEW FEATURE
- [ ] GPUParticles3D for explosions (1000+ particles per burst)
- [ ] Ambient biome weather (rain, snow, embers, spores, bubbles)
- [ ] Trail effects (dash trail, projectile trail, movement particles)
- [ ] Boss death spectacles (multi-layer particle cascade)
- [ ] Level-up shockwave (ring + sparkles via GPUParticles3D)
- [ ] Collectible pickup sparkle burst
- [ ] Enemy spawn materialization particles
- [ ] Atmosphere particles (dust motes, floating pollen, fireflies)

### Phase 12: Animation System (TODO) 🆕 NEW FEATURE
- [ ] AnimationPlayer for Zorp idle bob (subtle breathing float)
- [ ] Dash squash-and-stretch (compress → launch → extend)
- [ ] Attack windup animation (anticipation → strike → recovery)
- [ ] Hit reaction animation (stagger + flash)
- [ ] Enemy walk cycle (bob + sway per type)
- [ ] Enemy death animation (dramatic collapse + particle burst)
- [ ] Collectible spawn animation (bounce in from below)
- [ ] Blend trees for smooth transitions (idle ↔ walk ↔ dash)
- [ ] Animation events for syncing sound/particles to frames

### Phase 13: Biome Mutation System (TODO) 🆕 NEW FEATURE
- [ ] Mutation tracker (time spent in each biome)
- [ ] Zorp visual changes per active mutation (color shift, particle aura, model scale)
- [ ] Lava mutation: fire resistance + flame dash (leave fire trail)
- [ ] Crystal mutation: refractive cloak (partial invisibility) + crystal shard attack
- [ ] Snow mutation: freeze pulse (AoE slow) + ice armor (damage reduction)
- [ ] Alien mutation: gravity flip (walk on ceiling briefly) + plasma burst
- [ ] Forest mutation: nature's ally (enemies in forest biome become passive)
- [ ] Toxic mutation: poison trail (damage-over-time zone behind Zorp)
- [ ] Mutation UI indicator (which mutations active, progress bars)
- [ ] Mutation decay (mutations fade after leaving biome for 60s)
- [ ] Mutation combo (2+ active = enhanced version)

### Phase 14: Dimensional Rifts (TODO) 🆕 NEW FEATURE
- [ ] Rift portal structures (swirling vortex mesh + shader)
- [ ] Dimension shift system (4 dimensions: Normal, Void, Mirror, Time-slow)
- [ ] Void dimension: everything is silhouettes, shadow clone boss fight
- [ ] Mirror dimension: collectibles are hostile, enemies are friendly
- [ ] Time-slow dimension: everything at 0.3x speed, Zorp at 0.5x (relative advantage)
- [ ] Reversed gravity dimension: walk on ceiling, collectibles fall up
- [ ] Dimension transition effect (screen wipe + chromatic shift)
- [ ] Dimension timer (30 seconds then auto-return)
- [ ] Dimension-exclusive collectibles (rare items only in rifts)
- [ ] Rift spawn system (random portals appear, pulse and shimmer)

### Phase 15: Alien Companion Pet (TODO) 🆕 NEW FEATURE
- [ ] Pet companion entity (follows Zorp with smooth pathfinding)
- [ ] Auto-collect nearby items (increased vacuum radius when pet is out)
- [ ] Send-to-fetch command (click distant item, pet fetches it)
- [ ] Pet evolution system (3 stages: baby → adolescent → adult)
- [ ] Pet feeding (feed collectibles to evolve, different items = different evolution paths)
- [ ] Pet abilities per evolution: baby (collect only), adolescent (attack small enemies), adult (shield + attack)
- [ ] Pet visual evolution (color, size, particle aura changes)
- [ ] Pet idle animations (bounce, spin, chase tail, sleep)
- [ ] Pet HUD indicator (pet HP, evolution progress, current ability)

### Phase 16: Weapon Mod Crafting (TODO) 🆕 NEW FEATURE
- [ ] Crafting menu UI (combine 2 items → new weapon mod)
- [ ] 20 weapon mods (each changes laser behavior):
  - [ ] Homing Laser (Meteor Shard + Quantum Fuzz)
  - [ ] Reflective Shield (Shield Crystal + Fireball Scroll)
  - [ ] Chain Lightning (Nebula Dust + Star Fruit)
  - [ ] Spread Shot (Fireball Scroll + Quantum Fuzz)
  - [ ] Piercing Beam (Meteor Shard + Star Fruit)
  - [ ] Bouncing Bolt (Quantum Fuzz + Space Gloop)
  - [ ] Freeze Ray (Regen Crystal + Star Fruit)
  - [ ] Acid Trail (Magnet Core + Toxic extract)
  - [ ] Mega Blast (all 3 rare items)
  - [ ] + 11 more combinations
- [ ] Mod equip system (1 active mod at a time, swap in inventory)
- [ ] Visual laser changes per mod (color, trail, impact effect)
- [ ] Crafting discovery system (try unknown combos to discover new mods)

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

### Phase 21: Export & Distribution (TODO)
- [ ] Windows export (.exe)
- [ ] Linux export (.x86_64)
- [ ] macOS export (.app)
- [ ] Web export (HTML5 via Emscripten)
- [ ] Export presets configured in project.godot

## Notes
- All Ursina color.rgb() 0-255 values converted to Godot Color() 0-1 range
- Single Game class split into: GameManager (autoload), WorldGenerator, Player, HUD, etc.
- Ursina's global update() → per-node _process()/_physics_process()
- Ursina's global input(key) → _unhandled_input(event) + Input actions
- Scene tree architecture replaces single-file imperative approach
- Godot 4.4 GDScript syntax throughout (not Godot 3)
- GameManager registered as autoload singleton in project.godot

## Last Updated
Phase 2 complete. All 7 enemy types implemented (Serpent, Graviton, Wisp, Sentinel, Bomber, Spitter, Drake) with dynamic spawner, enemy projectiles, shockwave rings, and spawn warnings. Phases 3-21 planned. Cron jobs active.